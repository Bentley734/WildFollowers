-- Data-only local bridge. Audio never enters the mod or its save files.
return function(mod)
  local M={state='not running',level=0,events={},history={},age=0,poll=0}
  local function unit(v)return math.max(0,math.min(1,v))end
  function M:tick(dt)
    self.age=self.age+dt;self.poll=self.poll+dt
    while self.events[1] and self.age-self.events[1].time>8 do table.remove(self.events,1)end
    if self.poll<.05 then return end
    local elapsed=self.poll;self.poll=0
    local ok,text=pcall(mod.read,mod,'music-signal.txt')
    local seq,stamp,level,bass,beats,state
    if ok and type(text)=='string' and #text<256 then
      seq,stamp,level,bass,beats,state=text:match('^WFMusic1 (%d+) (%d+) ([%d%.]+) ([%d%.]+) (%d+) ([%a]+)%s*$')
    end
    seq,stamp,level,bass,beats=tonumber(seq),tonumber(stamp),tonumber(level),tonumber(bass),tonumber(beats)
    local now=os.time()
    local valid=seq and stamp and level and bass and beats and seq<=9007199254740991 and beats<=9007199254740991 and level<=1 and bass<=1
      and stamp<=now+1 and now-stamp<=2
    if not valid or state~='ready' then
      self.state=valid and state or 'not running';self.level=0;self.events={};self.history={};self.lastPulse=nil;self.seq=nil;self.beats=nil;return
    end
    if seq~=self.seq then self.unchanged=0 else self.unchanged=(self.unchanged or 0)+elapsed end
    if (self.unchanged or 0)>.5 then self.state='not running';self.level=0;self.events={};self.history={};return end
    self.state='ready'
    if self.beats and (beats<self.beats or seq<(self.seq or seq)) then self.events={};self.history={};self.lastPulse=nil end
    local gain=math.max(.5,math.min(4,tonumber(mod.options:get('music_sensitivity')) or 1))
    local target=unit(math.sqrt(level)*3*gain)
    self.level=self.level+(target-self.level)*math.min(1,elapsed*12*self:speed())
    if self.beats and beats>self.beats and seq~=self.seq
        and (not self.lastPulse or self.age-self.lastPulse>=.4/self:speed()) then
      self.lastPulse=self.age
      self.events[#self.events+1]={time=self.age,strength=unit(math.max(.25,math.sqrt(bass)*4*gain))}
      if #self.events>16 then table.remove(self.events,1)end
    end
    self.history[#self.history+1]={time=self.age,level=self.level}
    if #self.history>192 then table.remove(self.history,1)end
    self.seq=seq;self.beats=beats
  end
  function M:speed()
    return math.max(.1,math.min(2,tonumber(mod.options:get('music_speed')) or .5))
  end
  function M:bar(rank,speed)
    local time=self.age-rank*.08/speed
    local previous
    for _,sample in ipairs(self.history)do
      if sample.time>=time then
        if not previous then return sample.level end
        local span=sample.time-previous.time
        local alpha=span>0 and unit((time-previous.time)/span) or 1
        return previous.level+(sample.level-previous.level)*alpha
      end
      previous=sample
    end
    return previous and previous.level or self.level
  end
  function M:pose(rank,facing)
    local pose={facing=facing,hop=0,sx=1,sy=1,frame=0,music=true,offsetY=0}
    if self.state~='ready' then return pose end
    local speed=self:speed()
    local effect=mod.options:get('music_effect') or 'dance'
    local pulse=0
    for _,event in ipairs(self.events)do
      local age=(self.age-event.time)*speed-rank*.065
      if age>=0 and age<.36 then pulse=math.max(pulse,math.sin(age/.36*math.pi)*event.strength)end
    end
    if effect=='wave' then
      pose.hop=-10*pulse;pose.jumping=pulse>.001
      pose.frame=pulse>.001 and 1 or 0
    elseif effect=='bars' or effect=='stretch' then
      local level=self:bar(rank,speed)
      if level<.01 then level=0 end
      if effect=='stretch' then
        pose.sy=1+level*.7;pose.sx=1-level*.12
      else
        -- Render displacement only: cells, trail indices and collision stay put.
        local height=16*level
        self.barHeights=self.barHeights or {}
        local bar=self.barHeights[rank] or {height=height}
        if math.abs(height-bar.height)>.015 then
          bar.facing=height>bar.height and 'up' or 'down'
          bar.untilAt=self.age+.18/speed
        end
        bar.height=height;self.barHeights[rank]=bar
        local moving=self.age<(bar.untilAt or 0)
        pose.offsetY=-height
        if moving then
          pose.facing=bar.facing
          pose.frame=math.floor(self.age*(level>.65 and 12 or 8)*speed)%4
        end
      end
    else
      pose.hop=-8*pulse;pose.jumping=pulse>.001
      local sway=self.level*math.sin(self.age*8*speed+rank*.65)
      pose.sx=1+sway*.035-pulse*.03;pose.sy=1-sway*.035+pulse*.05
      if self.level>.035 then
        pose.frame=math.floor(self.age*(4+self.level*8)*speed+rank)%4
        pose.facing=({'down','left','up','right'})[(math.floor(self.age*1.5*speed)+rank)%4+1]
      end
    end
    return pose
  end
  return M
end
