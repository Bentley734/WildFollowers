local root=arg[1]
local checks=0
local function check(v,m)checks=checks+1;assert(v,m)end
local function read(n)local f=assert(io.open(root..'/src/'..n..'.lua'));local s=f:read('*a');f:close();return s end
local stamp=1000;local signal
local values={OW_FOLLOWERS_IDLE_MODE='music',OW_FOLLOWERS_IDLE_TIME=0,music_sensitivity=1}
local mod={read=function()return signal end,options={get=function(_,key)return values[key]end}}
local env=setmetatable({os={time=function()return stamp end}},{__index=_G})
local Music=assert(load(read('music'),'music','t',env))()(mod)
local function packet(seq,beats,level,bass,state,time)
 signal=('WFMusic1 %d %d %.6f %.6f %d %s\n'):format(seq,time or stamp,level or .025,bass or .02,beats,state or 'ready')
end
packet(1,0);Music:tick(.05);check(Music.state=='ready','fresh bridge connects')
packet(2,1);Music:tick(.05);Music:tick(.09)
check(Music:pose(0,'down').hop<0,'bass onset causes head hop')
check(Music:pose(5,'down').hop==0,'tail hop waits for beat wave')
for seq=3,8 do packet(seq,1);Music:tick(.05)end
check(Music:pose(5,'down').hop<0,'bass onset reaches tail without moving cells')
local p={moving=false,cellX=10,cellY=10,facing='down'};local busy=false
local A={player=function()return p end,busy=function()return busy end}
local T={points={},index=0}
local e={cellX=9,cellY=10,px=144,py=160,facing='down',slot=1,clock=0}
local c={followers={e},move=function()error('music mode must never move cells')end}
local modules={adapter=A,trail=T,music=Music,jumps={duration=.53},avoidance={}}
local I=assert(load(read('idle')))()(mod,function(n)return assert(modules[n],n)end)
packet(9,2);check(I:tick(c,e,.05),'music uses idle pipeline')
packet(10,2);I:tick(c,e,.1)
check(e.idlePose and e.idlePose.music and e.idlePose.jumping,'music pose drives existing jump renderer')
check(e.cellX==9 and e.cellY==10 and e.px==144 and e.py==160,'dancing preserves trail coordinates')
p.moving=true;check(not I:tick(c,e,.05) and not e.idlePose,'walking immediately cancels dancing')
p.moving=false;busy=true;check(not I:tick(c,e,.05) and not e.idlePose,'menus and battles cancel dancing')
busy=false;packet(11,0);Music:tick(.05);check(#Music.events<=2,'helper restart never fabricates a huge beat wave')
for _,bad in ipairs({'garbage','return os.execute("bad")',string.rep('1',300),'WFMusic1 1 1000 99 0 0 ready','WFMusic1 1 990 0.1 0.1 1 ready','WFMusic1 1 1009 0.1 0.1 1 ready'})do
 signal=bad;Music:tick(.05);check(Music.state=='not running' and Music:pose(0,'down').hop==0,'invalid or stale input rests safely')
end
packet(12,0,0,0);Music:tick(.05)
for seq=13,70 do packet(seq,0,0,0);Music:tick(.05)end
local pose=Music:pose(0,'down');check(pose.frame==0 and pose.hop==0 and math.abs(pose.sx-1)<.00001,'silence settles without invented dancing')
Music:tick(.6);check(Music.state=='not running','frozen helper stops animation quickly')
packet(71,0,0,0,'paused');Music:tick(.05);check(Music.state=='paused' and Music.level==0,'paused helper rests')
signal=nil;Music:tick(.05);check(Music.state=='not running','missing helper is harmless')
print('PASS '..checks..' local music bridge, beat wave, idle interruption, silence and malformed/stale input checks')
