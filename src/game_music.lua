-- Observe queued BGM envelopes only; playback and PCM remain untouched.
return function(mod)
  local G={capacities=setmetatable({},{__mode='k'}),sources=setmetatable({},{__mode='k'}),hooks={}}
  local audio
  local function current()
    -- The mod sandbox exposes permitted engine imports, not package.loaded.
    -- Resolve only this game's audio backend and keep its live module table.
    if not audio then
      local name=require('src.core.GameVersion').generation()==3
        and 'src.core.game3.audio' or 'src.core.ChipAudio'
      local ok,result=pcall(require,name)
      if ok and type(result)=='table' then audio=result end
    end
    local a=audio
    if a and a._bgmSource then return a._bgmSource end
    if a and a.currentSource then local ok,s=pcall(a.currentSource);if ok then return s end end
  end
  function G:queued(source,data)
    if source~=current() or not data or not data.getSampleCount then return end
    local n,rate,channels=data:getSampleCount(),data:getSampleRate(),data:getChannelCount()
    local record=self.sources[source]
    if not record then
      local at=source:tell('seconds') or 0
      local capacity=self.capacities[source]
      if capacity then at=at+math.max(0,capacity-source:getFreeBufferCount()-1)*n/rate end
      record={samples={},endAt=at};self.sources[source]=record
    end
    if n<=0 or rate<=0 or channels<=0 then return end
    local step=math.max(1,math.floor(rate*.02))
    for start=0,n-1,step do
      local sum,count=0,0
      local finish=math.min(n-1,start+step-1)
      for i=start,finish,math.max(1,math.floor(step/64)) do
        for ch=1,channels do local x=data:getSample(i,ch);sum=sum+x*x;count=count+1 end
      end
      record.samples[#record.samples+1]={time=record.endAt+start/rate,level=math.sqrt(sum/math.max(1,count))}
    end
    record.endAt=record.endAt+n/rate
    while #record.samples>1024 do table.remove(record.samples,1)end
  end
  function G:attach(source)
    local mt=getmetatable(source)
    local index=type(mt)=='table' and mt.__index
    if type(index)~='table' or type(index.queue)~='function' or self.hooks[index] then return end
    local queue,stop=index.queue,index.stop
    local queued=function(src,data,...)
      local result=queue(src,data,...)
      if result~=false then pcall(self.queued,self,src,data)end
      return result
    end
    local stopped=function(src,...)
      local result=stop(src,...);self.sources[src]=nil;return result
    end
    self.hooks[index]={queue=queue,stop=stop,queued=queued,stopped=stopped}
    index.queue=queued;if stop then index.stop=stopped end
  end
  function G:install()
    if self.factory or not (love and love.audio and love.audio.newQueueableSource)then return end
    self.factory=love.audio.newQueueableSource
    self.wrapper=function(...)
      local args={...};local source=self.factory(...);self.capacities[source]=args[4] or 8;self:attach(source);return source
    end
    love.audio.newQueueableSource=self.wrapper
    local s=current();if s then self:attach(s)end
  end
  function G:sample()
    self:install()
    local source=current();local record=source and self.sources[source]
    if not record then return end
    local ok,playing=pcall(source.isPlaying,source)
    if not ok or not playing then return end
    local volOk,volume=pcall(source.getVolume,source)
    if volOk and volume<=0 then return end
    local tellOk,time=pcall(source.tell,source,'seconds')
    if not tellOk or type(time)~='number' then return end
    while #record.samples>1 and record.samples[2].time<=time do table.remove(record.samples,1)end
    local sample=record.samples[1]
    if not sample or sample.time>time+.04 or time>record.endAt+.04 then return end
    return sample.level*(volOk and volume or 1),source,time
  end
  function G:dispose()
    if self.factory and love.audio.newQueueableSource==self.wrapper then love.audio.newQueueableSource=self.factory end
    for index,h in pairs(self.hooks)do
      if index.queue==h.queued then index.queue=h.queue end
      if index.stop==h.stopped then index.stop=h.stop end
    end
    self.hooks={};self.sources=setmetatable({},{__mode='k'})
  end
  return G
end
