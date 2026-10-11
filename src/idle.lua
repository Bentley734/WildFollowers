-- Optional idle poses and bounded wandering, using the same legal return routes.
return function(mod,include)
  local A,Y,T=include('adapter'),include('avoidance'),include('trail')
  local J=include('jumps')
  local I={}
  local faces={'down','left','up','right'}
  local modes={'look','jump','wave','spin','bounce','pulse','stretch','doze','cheer','copycat','dance'}
  local waves={'wave','spin','bounce','pulse'}
  local cycle=5
  local stagger=.22
  local function reset(e)
    e.idleAge=0;e.idleMode=nil;e.idlePose=nil;e.idleEpoch=nil
  end
  function I:tick(c,e,dt)
    local p=A:player()
    local selected=mod.options:get('OW_FOLLOWERS_IDLE_MODE') or 'none'
    local delay=math.max(0,tonumber(mod.options:get('OW_FOLLOWERS_IDLE_TIME')) or 3)
    if self.owner~=c or self.epoch~=T.points or self.selection~=selected or self.delay~=delay or p.moving or A:busy() then
      self.owner=c
      self.epoch=T.points;self.selection=selected;self.delay=delay;self.groupMode=nil;self.groupTime=0
    end
    if c.followers and e==c.followers[1] and not p.moving and not A:busy() then
      self.groupTime=(self.groupTime or 0)+dt
    end
    local changed=e.idleSelection~=nil and e.idleSelection~=selected
      or e.idleDelay~=nil and e.idleDelay~=delay
    e.idleDelay=delay
    local interrupted=p.moving or A:busy() or e.ballPhase or e.awaitingTile or e.yielding
      or e.hidden or selected=='none' or changed or e.idleEpoch and e.idleEpoch~=T.index
    if interrupted then
      if e.idleWander then e.yielding=true;e.idleWander=nil end
      reset(e);e.idleSelection=selected
      return false
    end
    if e.moving and not e.spacingPaused then
      if e.idleWander then return true end
      reset(e);return false
    end
    e.idleAge=(e.idleAge or 0)+dt
    if e.idleAge<delay then e.idlePose=nil;return false end
    if e.idleSelection~=selected then e.idleMode=nil;e.idleSelection=selected end
    if selected=='random' or selected=='random_wave' then
      local pool=selected=='random_wave' and waves or modes
      self.groupMode=self.groupMode or pool[math.random(#pool)]
      e.idleMode=self.groupMode
    else
      e.idleMode=e.idleMode or (selected=='mixed' and modes[math.random(#modes)] or selected)
    end
    e.idleEpoch=T.index
    local t=math.max(0,e.idleAge-delay)
    local rank=math.max(0,(e.lineSlot or e.slot or 1)-1)
    local mode=e.idleMode
    -- Every wave follows the same stop clock, even if companions settle on
    -- different frames. Don't wrap a negative phase into the previous cycle.
    local waveTime=math.max(0,(self.groupTime or 0)-delay)-rank*stagger
    local phase=waveTime>=0 and waveTime%cycle or nil
    local pose={facing=e.facing,hop=0,sx=1,sy=1,frame=0}
    local function hop(time)
      if time and time>=0 and time<J.duration then
        pose.hop=J:offset(time/J.duration,J.duration)
        pose.jumping=true;pose.frame=1
      end
    end
    if mode=='look' then
      local at=t%5
      if at<.9 then pose.facing=faces[(rank+1)%4+1]
      elseif at<1.8 then pose.facing=faces[(rank+3)%4+1] end
    elseif mode=='walk' then
      local at=t%4
      if at<1.2 then pose.frame=math.floor(at*6)%4 end
    elseif mode=='copycat' then pose.facing=p.facing or e.facing
    elseif mode=='dance' then
      local at=t%4
      if at<2 then
        pose.facing=faces[(math.floor(at/.35)+rank)%4+1]
        pose.frame=math.floor(at*6)%4
        pose.sx=1+math.sin(at*6+rank)*.05;pose.sy=2-pose.sx
      end
    elseif mode=='pulse' then
      if phase and phase<.7 then
        local pulse=math.sin(phase/.7*math.pi)
        pose.sx=1+pulse*.12;pose.sy=1-pulse*.08
      end
    elseif mode=='spin' then
      -- One turn, then rest; never spin continuously throughout the cycle.
      if phase and phase<.8 then
        local base=1
        for i,face in ipairs(faces) do if face==e.facing then base=i end end
        pose.facing=faces[(base-1+math.floor(phase/.2)+1)%4+1]
      end
    elseif mode=='jump' then hop(t%3)
    elseif mode=='wave' then hop(phase)
    elseif mode=='wave_single' then
      -- Finish each full jump before starting the next companion. One shared
      -- modulo keeps the tail and head from overlapping across loop boundaries.
      local count=math.max(1,#(c.followers or {}))
      local spacing=J.duration+.1
      local clock=math.max(0,(self.groupTime or 0)-delay)%(count*spacing)
      hop(clock-rank*spacing)
    elseif mode=='bounce' then
      if phase then
        if phase<J.duration then hop(phase)
        else hop(phase-J.duration-.25) end
      end
    elseif mode=='cheer' then
      hop(t%3)
      local dx,dy=p.cellX-e.cellX,p.cellY-e.cellY
      pose.facing=math.abs(dx)>math.abs(dy) and (dx<0 and 'left' or 'right') or (dy<0 and 'up' or 'down')
    elseif mode=='stretch' then
      local at=t%4
      if at<1.2 then
        local amount=math.sin(at/1.2*math.pi)*.10
        pose.sx=1-amount/2;pose.sy=1+amount
      end
    elseif mode=='doze' then
      local amount=math.sin(t*2*math.pi/3.5)*.025
      pose.sx=1-amount/2;pose.sy=1+amount;pose.sleep=true
    elseif mode=='wander' then
      if e.spacingPaused then
        e.moving=false;e.targetX=nil;e.targetY=nil;e.targetStep=nil;e.spacingPaused=nil
      end
      e.idleWander=e.idleWander or {x=e.cellX,y=e.cellY,next=0}
      local anchor=e.idleWander;anchor.next=anchor.next-dt
      if anchor.next<=0 then
        anchor.next=1+math.random()
        local d=({{0,-1},{0,1},{-1,0},{1,0}})[math.random(4)]
        local x,y=e.cellX+d[1],e.cellY+d[2]
        local range=tonumber(mod.options:get('OW_FOLLOWERS_WANDER_RANGE')) or 2
        if math.abs(x-anchor.x)+math.abs(y-anchor.y)<=range and Y:legal(c,e,x,y) then
          c:move(e,x,y,16/60)
        end
      end
    end
    e.idlePose=pose
    return true
  end
  return I
end
