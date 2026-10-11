using System.Globalization;
using NAudio.Wave;
using NAudio.CoreAudioApi;

// Only scalar sound energy and beat events leave memory; no audio is written.
sealed class Analyzer {
    public double Level, Bass;
    public long Beats;
    double low, baseline, lastBeat = -1;
    public void Analyze(float[] samples, int rate, double now) {
        if (samples.Length == 0) return;
        double sum=0, bass=0, alpha=1-Math.Exp(-2*Math.PI*180/rate);
        foreach (float sample in samples) {
            double x=double.IsFinite(sample)?Math.Clamp(sample,-1,1):0;
            low+=alpha*(x-low);sum+=x*x;bass+=low*low;
        }
        double rms=Math.Sqrt(sum/samples.Length), brms=Math.Sqrt(bass/samples.Length);
        // Fast attack, slow release, plus an adaptive bass-onset threshold.
        Level=Math.Max(rms,Level*.8);Bass=Math.Max(brms,Bass*.8);
        if (brms>.0015 && brms>baseline*1.55+.0005 && now-lastBeat>.22) { Beats++;lastBeat=now; }
        baseline=baseline*.94+brms*.06;
    }
    public static void SelfTest(string report) {
        var a=new Analyzer();int rate=48000;
        for(int block=0;block<250;block++) {
            var samples=new float[960];
            if(block%25<4) for(int i=0;i<samples.Length;i++)samples[i]=(float)(.12*Math.Sin(2*Math.PI*100*(block*960+i)/rate));
            a.Analyze(samples,rate,block*.02);
        }
        if(a.Beats<8 || a.Beats>12)throw new Exception("Bass pulses were not detected reliably: "+a.Beats);
        double silent=a.Level;
        for(int block=0;block<100;block++)a.Analyze(new float[960],rate,5+block*.02);
        if(a.Level>.00001 || a.Level>=silent)throw new Exception("Silence must settle");
        File.WriteAllText(report,"PASS adaptive bass beats, silence settling, finite signal; beats="+a.Beats);
    }
}
sealed class CaptureApp : ApplicationContext {
    readonly string output;
    readonly Analyzer analyzer=new();
    readonly NotifyIcon tray;
    readonly System.Windows.Forms.Timer timer;
    WasapiLoopbackCapture? capture;
    readonly object gate=new();
    readonly System.Diagnostics.Stopwatch clock=System.Diagnostics.Stopwatch.StartNew();
    string status="starting";long sequence;double lastData, retryAt;
    bool paused;double nextDeviceCheck;string deviceId="";MMDevice? device;
    public CaptureApp(string path,int seconds) {
        output=Path.GetFullPath(path);Directory.CreateDirectory(Path.GetDirectoryName(output)!);
        tray=new NotifyIcon {Icon=System.Drawing.SystemIcons.Information,Text="WildFollowers Music — PC audio",Visible=true};
        var menu=new ContextMenuStrip();
        var pause=menu.Items.Add("Pause audio analysis");pause.Click+=(s,e)=>{paused=!paused;pause.Text=paused?"Resume audio analysis":"Pause audio analysis";Stop();retryAt=0;};
        menu.Items.Add("Exit").Click+=(s,e)=>ExitThread();tray.ContextMenuStrip=menu;
        timer=new System.Windows.Forms.Timer{Interval=50};timer.Tick+=(s,e)=> {
            if(seconds>0 && clock.Elapsed.TotalSeconds>=seconds){ExitThread();return;}
            if(!paused && clock.Elapsed.TotalSeconds>=nextDeviceCheck) {
                nextDeviceCheck=clock.Elapsed.TotalSeconds+2;
                try {
                    using var enumerator=new MMDeviceEnumerator();using var current=enumerator.GetDefaultAudioEndpoint(DataFlow.Render,Role.Multimedia);
                    if(capture!=null && current.ID!=deviceId){Stop();retryAt=0;}
                } catch {Stop();status="unavailable";retryAt=clock.Elapsed.TotalSeconds+2;}
            }
            if(!paused && capture==null && clock.Elapsed.TotalSeconds>=retryAt)Start();
            Publish();
        };timer.Start();
    }
    void Start() {
        try {
            using var enumerator=new MMDeviceEnumerator();
            device=enumerator.GetDefaultAudioEndpoint(DataFlow.Render,Role.Multimedia);
            deviceId=device.ID;capture=new WasapiLoopbackCapture(device);
            // Explicit PCM avoids ambiguous extensible/float device formats.
            capture.WaveFormat=new WaveFormat(48000,16,2);
            capture.DataAvailable+=(s,e)=> {
                int channels=capture?.WaveFormat.Channels??2;
                int frames=e.BytesRecorded/(2*channels);var mono=new float[frames];
                for(int i=0;i<frames;i++) {
                    float sum=0;for(int ch=0;ch<channels;ch++)sum+=BitConverter.ToInt16(e.Buffer,(i*channels+ch)*2)/32768f;
                    mono[i]=sum/channels;
                }
                lock(gate){analyzer.Analyze(mono,48000,clock.Elapsed.TotalSeconds);lastData=clock.Elapsed.TotalSeconds;}
            };
            capture.RecordingStopped+=(s,e)=>{if(e.Exception!=null){lock(gate){status="unavailable";retryAt=clock.Elapsed.TotalSeconds+2;}}};
            capture.StartRecording();status="ready";
        } catch {Stop();status="unavailable";retryAt=clock.Elapsed.TotalSeconds+2;}
    }
    void Stop(){var old=capture;capture=null;try{old?.StopRecording();old?.Dispose();}catch{} try{device?.Dispose();device=null;}catch{} }
    void Publish() {
        try {
            if(status=="unavailable" && capture!=null)Stop();
            string payload;
            lock(gate) {
                double level=clock.Elapsed.TotalSeconds-lastData>.25?0:analyzer.Level;
                double bass=clock.Elapsed.TotalSeconds-lastData>.25?0:analyzer.Bass;
                string state=paused?"paused":status;
                payload=string.Format(CultureInfo.InvariantCulture,"WFMusic1 {0} {1} {2:F6} {3:F6} {4} {5}\n",++sequence,DateTimeOffset.UtcNow.ToUnixTimeSeconds(),level,bass,analyzer.Beats,state);
            }
            string temp=output+".tmp";File.WriteAllText(temp,payload);File.Move(temp,output,true);
            tray.Text=paused?"WildFollowers Music — paused":"WildFollowers Music — "+status;
        } catch(IOException) {} catch(UnauthorizedAccessException) {}
    }
    protected override void ExitThreadCore(){timer.Stop();Stop();status="stopped";Publish();tray.Visible=false;tray.Dispose();timer.Dispose();base.ExitThreadCore();}
}
static class Program {
    [STAThread]static void Main(string[] args) {
        string output=Path.Combine(AppContext.BaseDirectory,"..","music-signal.txt");int seconds=0;
        for(int i=0;i<args.Length;i++) {
            if(args[i]=="--self-test"){Analyzer.SelfTest(args[i+1]);return;}
            if(args[i]=="--output")output=args[++i];
            else if(args[i]=="--seconds")seconds=int.Parse(args[++i],CultureInfo.InvariantCulture);
        }
        using var mutex=new Mutex(true,"Local\\WildFollowersMusic-"+Convert.ToHexString(System.Security.Cryptography.SHA256.HashData(System.Text.Encoding.UTF8.GetBytes(Path.GetFullPath(output))))[..16],out bool created);
        if(!created)return;
        Application.EnableVisualStyles();Application.Run(new CaptureApp(output,seconds));
    }
}
