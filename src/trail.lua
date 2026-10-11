-- Fresh shared command history. Record committed destinations; followers replay
-- the cells the player vacates with the native step duration and a slot delay.
return function(mod)
  local T={points={},index=0,first=0}
  function T:spacing(key)
    return math.max(1,math.min(4,math.floor((tonumber(mod and mod.options:get(key)) or 1)*10+.5)/10))
  end
  function T:gap(slot)
    local gap=self:spacing('OW_FOLLOWERS_TRAINER_SPACING')+(slot-1)*self:spacing('OW_FOLLOWERS_SPACING')
    return math.floor(gap*10+.5)/10
  end
  function T:cellGap(slot) return math.ceil(self:gap(slot)-.000001) end
  function T:joinGap(slot)
    -- Leave space for source/destination reservations during moving returns.
    return math.max(self:cellGap(slot),slot*2-1)
  end
  function T:clear() self.points={};self.index=0;self.first=0;self.halfHop=nil;self.arrivalSeed=nil end
  function T:project(dx,dy)
    for _,point in pairs(self.points) do point.x=point.x+dx;point.y=point.y+dy end
  end
  function T:reset(p)
    self:clear()
    self.points[0]={n=0,x=p.cellX,y=p.cellY,currentElevation=p.currentElevation or p.elevation or 3,
      elevation=p.elevation or p.currentElevation or 3}
  end
  function T:cellIndex(x,y)
    for n=self.index,self.first,-1 do
      local point=self.points[n]
      if point and point.x==x and point.y==y then return n end
    end
    return self.index
  end
  function T:observe(p)
    if not self.points[self.index] then self:reset(p) end
    local x,y=p.cellX,p.cellY
    if p.moving and p.targetX~=nil and p.targetY~=nil then x,y=p.targetX,p.targetY end
    local previous=self.points[self.index]
    if x==previous.x and y==previous.y then return true end
    local dx,dy=x-previous.x,y-previous.y
    local distance=math.abs(dx)+math.abs(dy)
    if distance>2 or (dx~=0 and dy~=0) then return false end
    local frames=math.max(1,tonumber(p.stepFramesCur or p.stepFrames) or 16)
    local point={x=x,y=y,duration=frames/60,currentElevation=p.currentElevation or p.elevation or 3,
      elevation=p.elevation or p.currentElevation or 3,
      jump=distance==2,facing=dx>0 and 'right' or dx<0 and 'left' or dy>0 and 'down' or 'up'}
    -- Gen 1 represents a ledge as two scripted one-cell steps. Keep its
    -- unwalkable middle cell in history, but consume the pair as one hop.
    if p.ledgeHop and distance==1 then
      if self.halfHop and self.halfHop.facing==point.facing then
        point.jump=true;point.duration=point.duration+self.halfHop.duration;self.halfHop=nil
      else point.interior=true;self.halfHop=point end
    elseif self.halfHop then
      point.jump=true;point.duration=point.duration+self.halfHop.duration;self.halfHop=nil
    end
    self.index=self.index+1;point.n=self.index;self.points[self.index]=point
    return true
  end
  function T:eligible(slot,p)
    local gap=self:gap(slot)
    local position=self.index
    if p and p.moving and math.abs(gap-math.floor(gap+.000001))>.000001 then
      local from,to=self.points[self.index-1],self.points[self.index]
      if from and to then
        local span=math.abs(to.x-from.x)+math.abs(to.y-from.y)
        if span>0 then
          local remaining=math.abs(to.x*16-(p.px or p.cellX*16))+math.abs(to.y*16-(p.py or p.cellY*16))
          position=position-math.max(0,math.min(1,remaining/(span*16)))
        end
      end
    end
    return position-gap
  end
  function T:next(actor,slot,p)
    if self.arrivalSeed and self.index==0 then return nil end
    local eligible=self:eligible(slot,p)
    local fractional=math.abs(eligible-math.floor(eligible+.000001))>.000001
    while actor.trailStep<eligible do
      local n=actor.trailStep+1
      local point=self.points[n]
      if not point then return nil,'lost' end
      if point.interior then
        if n+1>eligible then return nil end
        point=self.points[n+1];if not point then return nil,'lost' end
      end
      if fractional and point.jump and point.n>eligible then return nil end
      if point.x==actor.cellX and point.y==actor.cellY then actor.trailStep=point.n
      else
        local duration=point.duration or 16/60
        if eligible-point.n>=1 and not point.jump
            and (not mod or mod.options:get('OW_FOLLOWERS_RUN_TO_CATCH_UP')~=false) then duration=duration/math.max(1,math.min(6,tonumber(mod and mod.options:get('OW_FOLLOWERS_CATCH_UP_SPEED')) or 2)) end
        return point,nil,duration
      end
    end
  end
  function T:trim(followers)
    local keep=self.index-256
    for _,e in ipairs(followers) do keep=math.min(keep,e.trailStep) end
    keep=math.max(keep,self.index-1024)
    while self.first<keep do self.points[self.first]=nil;self.first=self.first+1 end
  end
  return T
end
