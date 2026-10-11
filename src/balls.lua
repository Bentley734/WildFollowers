-- Hoennto's .30-second shrink/ball effect, played backwards on release.
return function(mod,include)
  local A=include('adapter')
  local B={}
  local unpack=table.unpack or unpack
  function B:cancel()
    local q=self.pending
    self.pending=nil
    if q then q.unlock() end
  end
  function B:begin(c,old,...)
    if self.pending then return true end
    if mod.options:get('enabled')==false or mod.options:get('OW_FOLLOWERS_ENABLED')==false
        or #c.followers==0 then return old(...) end
    if mod.options:get('OW_FOLLOWERS_POKEBALLS')==false then
      c.ballArrival=true;c.ballArrivalStable=0
      local result=old(...)
      if result==false then c.ballArrival=nil end
      return result
    end
    local args={n=select('#',...),...}
    local p=A:player();local unlock
    if A.generation==3 then
      local f=require('src.core.game3.field');f.lock('wildfollowers-balls')
      unlock=function() f.unlock('wildfollowers-balls') end
    else
      local locked=p.inputLocked;p.inputLocked=true
      unlock=function() p.inputLocked=locked end
    end
    self.pending={old=old,args=args,time=0,save=A:save(),map=A:mapId(),unlock=unlock}
    for _,e in ipairs(c.followers) do e.ballPhase='recall';e.ballTime=0;e.moving=false;e.hidden=false end
    return true
  end
  function B:tick(c,dt)
    local q=self.pending
    if not q then return false end
    if q.save~=A:save() or q.map~=A:mapId() then self:cancel();return false end
    q.time=q.time+dt
    for _,e in ipairs(c.followers) do e.ballTime=math.min(.30,q.time) end
    if q.time>=.30 then
      self.pending=nil;q.unlock()
      for _,e in ipairs(c.followers) do e.hidden=true;e.ballPhase=nil end
      c.ballArrival=true;c.ballArrivalStable=0
      local ok,result=pcall(q.old,unpack(q.args,1,q.args.n))
      if not ok or result==false then
        c.ballArrival=nil
        for _,e in ipairs(c.followers) do e.hidden=false end
      end
      if not ok then error(result,0) end
    end
    return true
  end
  function B:arrivalReady(c)
    local p,w=A:player(),A:world()
    local waiting=A:busy() or not p or p.moving or p.inputLocked
    -- Gen 1 queues the automatic door step before the player starts moving.
    for _,move in ipairs(w and w.scriptMoves or {}) do
      if move.entity==p and ((move.remaining or 0)>0 or p.moving) then waiting=true end
    end
    -- Gold/Silver/Crystal schedule their forced step from the door tile in
    -- the world update, sometimes after a turn delay. Wait for that tile to
    -- be vacated, even when no script move has been queued yet.
    local m=w and w.map
    if p and m and A.generation==2 and m.cellCollision then
      local dir=require('src.world.gen2.Permissions').doorForcedDirection(m:cellCollision(p.cellX,p.cellY))
      if dir and A:allowed(p.cellX,p.cellY+1,A:water(p.cellX,p.cellY+1) and 'water' or 'land') then waiting=true end
    end
    if p and m and A.generation==1 and m.isDoorTileCell and m:isDoorTileCell(p.cellX,p.cellY)
        and A:allowed(p.cellX,p.cellY+1,A:water(p.cellX,p.cellY+1) and 'water' or 'land') then waiting=true end
    if waiting then c.ballArrivalStable=0;return false end
    -- input.step precedes the world's movement update. Give the native door
    -- logic a complete update to start a queued/automatic walk-out first.
    c.ballArrivalStable=(c.ballArrivalStable or 0)+1
    return c.ballArrivalStable>=2
  end
  function B:place(c,e)
    local p=A:player();local area=A:area()
    if not area or p.moving then e.hidden=true;e.awaitingTile=true;return false end
    -- Party order fills the horizontal left row first, then the right row.
    -- The facing tile is never a release candidate, even in cramped rooms.
    local d=({up={0,-1},down={0,1},left={-1,0},right={1,0}})[p.facing] or {0,1}
    local kind=A:water(p.cellX,p.cellY) and 'water' or 'land'
    local function place(x,y)
      if x==p.cellX and y==p.cellY or x==p.cellX+d[1] and y==p.cellY+d[2]
          or x==p.targetX and y==p.targetY then return false end
      if c:occupied(x,y,e) or not A:allowed(x,y,kind) then return false end
      e.cellX,e.cellY,e.px,e.py=x,y,x*16,y*16;e.surface=kind
      e.currentElevation,e.elevation=A:elevations(x,y)
      e.facing=p.facing;e.ballPhase=mod.options:get('OW_FOLLOWERS_POKEBALLS')~=false and 'release' or nil;e.ballTime=0;e.hidden=false
      e.arrivalAnchor=true;e.awaitingTile=nil
      return true
    end
    for _,sign in ipairs({-1,1}) do
      for distance=1,area.width do
        if place(p.cellX+distance*sign,p.cellY) then return true end
        -- Do not release beyond a wall or doorway in the same row.
        if not A:allowed(p.cellX+distance*sign,p.cellY,kind) then break end
      end
    end
    -- Rooms without enough side cells use nearby legal floor, still excluding
    -- the player's forward tile. No safe floor means stay recalled and retry.
    for radius=1,area.width+area.height do
      for dy=-radius,radius do
        local dx=radius-math.abs(dy)
        for _,sign in ipairs(dx==0 and {1} or {-1,1}) do
          if place(p.cellX+dx*sign,p.cellY+dy) then return true end
        end
      end
    end
    e.hidden=true;e.awaitingTile=true
    return false
  end
  function B:seedTrail(c,T)
    if T.index~=0 or T.arrivalSeed then return end
    local p=A:player();if not p or p.moving then return end
    local lead=c.followers[1]
    if not lead or not lead.arrivalAnchor or lead.hidden or lead.cellY~=p.cellY then return end
    local side=lead.cellX<p.cellX and -1 or 1
    local distance=0
    for _,e in ipairs(c.followers) do
      if e.arrivalAnchor and not e.hidden and e.cellY==p.cellY and (e.cellX-p.cellX)*side>0 then
        distance=math.max(distance,math.abs(e.cellX-p.cellX))
      end
    end
    local duration=math.max(1,tonumber(p.stepFramesCur or p.stepFrames) or 16)/60
    local facing=side<0 and 'right' or 'left'
    for offset=1,distance do
      local x,y=p.cellX+side*offset,p.cellY
      local kind=A:water(x,y) and 'water' or 'land'
      -- Seed only the connected legal row; actual steps retain native checks.
      if not A:allowed(x,y,kind) then break end
      local current,elevation=A:elevations(x,y)
      T.points[-offset]={x=x,y=y,n=-offset,duration=duration,facing=facing,
        currentElevation=current,elevation=elevation}
      T.first=-offset
    end
    T.arrivalSeed=true
    for _,e in ipairs(c.followers) do
      local n=-(e.cellX-p.cellX)*side
      local point=T.points[n]
      if e.arrivalAnchor and point and point.x==e.cellX and point.y==e.cellY then
        e.trailStep=n;e.arrivalAnchor=nil;e.lineSlot=e.slot
      end
    end
  end
  function B:approach(c,e,target)
    if math.abs(target.x-e.cellX)+math.abs(target.y-e.cellY)==1 then
      if c:occupied(target.x,target.y,e) then return nil end
      e.arrivalAnchor=nil;return target
    end
    local queue={{x=e.cellX,y=e.cellY}};local seen={[e.cellX..':'..e.cellY]=true};local head=1
    local area=A:area();local limit=area and area.width*area.height or 0
    while head<=#queue and head<=limit do
      local node=queue[head];head=head+1
      for _,d in ipairs({{0,-1},{-1,0},{1,0},{0,1}}) do
        local x,y=node.x+d[1],node.y+d[2];local key=x..':'..y
        if not seen[key] then
          seen[key]=true
          local kind=A:water(x,y) and 'water' or 'land'
          local from={cellX=node.x,cellY=node.y,facing=d[1]>0 and 'right' or d[1]<0 and 'left' or d[2]>0 and 'down' or 'up',currentElevation=e.currentElevation}
          if not c:occupied(x,y,e) and A:allowed(x,y,kind,from) then
            local first=node.first or {x=x,y=y}
            if x==target.x and y==target.y then return first end
            queue[#queue+1]={x=x,y=y,first=first}
          end
        end
      end
    end
  end
  return B
end
