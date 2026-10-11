-- Yield to committed player steps, then fill a free position on the trail.
return function(mod,include)
  local A,T=include('adapter'),include('trail')
  local M={}
  local directions={{0,-1},{-1,0},{1,0},{0,1}}
  local delta={up={0,-1},down={0,1},left={-1,0},right={1,0}}
  local function facing(dx,dy) return dx>0 and 'right' or dx<0 and 'left' or dy>0 and 'down' or 'up' end
  function M:legal(c,e,x,y,fromX,fromY,transit)
    local from={follower=e.follower,cellX=fromX or e.cellX,cellY=fromY or e.cellY,
      currentElevation=e.currentElevation,elevation=e.elevation,
      facing=facing(x-(fromX or e.cellX),y-(fromY or e.cellY))}
    return not c:occupied(x,y,e,e.follower or transit) and A:allowed(x,y,e.surface,from)
  end
  function M:duration(urgent)
    local p=A:player()
    local duration=math.max(1,tonumber(p.stepFramesCur or p.stepFrames) or 16)/60
    if urgent or mod.options:get('OW_FOLLOWERS_RUN_TO_CATCH_UP')~=false then duration=duration/(urgent and 2 or math.max(1,math.min(6,tonumber(mod.options:get('OW_FOLLOWERS_CATCH_UP_SPEED')) or 2))) end
    return duration
  end
  function M:threatened(e)
    if mod.options:get('OW_FOLLOWERS_PLAYER_YIELD')==false then return false end
    local p=A:player()
    return p and p.moving and p.targetX~=nil and p.targetY~=nil and not e.hidden
      and (e.cellX==p.targetX and e.cellY==p.targetY
        or e.targetX==p.targetX and e.targetY==p.targetY)
  end
  function M:yield(c,e)
    if not self:threatened(e) then return false end
    e.yielding=true;e.targetStep=nil;e.rejoinGoal=nil
    local p=A:player()
    if e.moving then
      if not (e.targetX==p.cellX and e.targetY==p.cellY
          or e.targetX==p.targetX and e.targetY==p.targetY) then return true end
      -- Back out of an in-flight step from a safe source without snapping pixels.
      if not (e.cellX==p.cellX and e.cellY==p.cellY
          or e.cellX==p.targetX and e.cellY==p.targetY) then
        e.startX,e.startY=e.px,e.py;e.targetX,e.targetY=e.cellX,e.cellY
        e.progress=0;e.duration=self:duration(true);return true
      end
      e.moving=false;e.targetX=nil;e.targetY=nil
    end
    local d=delta[p.facing] or delta.down
    -- Perpendicular cells clear the player's line of travel before trying
    -- farther ahead. Every step checks both occupied and reserved cells.
    local choices={{-d[2],d[1]},{d[2],-d[1]},{d[1],d[2]},{-d[1],-d[2]}}
    for _,offset in ipairs(choices) do
      local x,y=e.cellX+offset[1],e.cellY+offset[2]
      if self:legal(c,e,x,y) and c:move(e,x,y,self:duration(true)) then return true end
    end
    -- A narrow corridor has no side tile. Remain nonblocking and retry the
    -- route after the player vacates its source; never teleport through a wall.
    return true
  end
  function M:committed(c)
    if A:busy() then return end
    for _,e in ipairs(c.followers) do self:yield(c,e) end
  end
  function M:prepare(c)

    local active=false

    for _,e in ipairs(c.followers) do active=active or e.yielding end

    if not active then c.lineRejoining=nil;return end

    if c.lineRejoining then return end

    c.lineRejoining=true

    local line,returning={},{}

    for _,e in ipairs(c.followers) do

      if e.yielding then returning[#returning+1]=e

      else line[#line+1]=e end

    end

    -- Retain assigned order within the walking group and the returning group.
    -- Only displaced companions move behind the established moving line.
    local function assigned(a,b) return (a.lineSlot or a.slot)<(b.lineSlot or b.slot) end
    table.sort(line,assigned);table.sort(returning,assigned)
    -- Keep companions already in the procession in front. Reserve the open

    -- positions behind them once, instead of repeatedly trading their slots.

    local rank=0

    for _,list in ipairs({line,returning}) do

      for _,e in ipairs(list) do

        rank=rank+1;e.lineSlot=rank;e.joinTarget=nil;e.joinBlocked=nil

        e.joinSlot=e.yielding and rank or nil

        -- Both source and destination stay reserved during a step. Leave

        -- room for that live movement pipeline when joining from the side;

        -- normal trail replay compacts the procession after landing.

        e.joinGap=e.yielding and T:joinGap(rank) or nil

      end

    end

  end

  function M:goals(c,e)
    local goals,tail={},{};local seen={}
    -- Prefer the active line; older recorded cells provide a tail when NPCs
    -- or repeated route coordinates leave no usable hole in that line.
    local firstGap=T:cellGap(1)
    local lastGap=T:cellGap(#c.followers)
    for index=T.index-firstGap,math.max(T.first,T.index-lastGap-16),-1 do
      local target=T.points[index]
      local distance=T.index-index
      local slot=1
      while slot<#c.followers and distance>=T:cellGap(slot+1) do slot=slot+1 end
      if target and not target.interior and (distance==T:cellGap(slot) or distance>lastGap) then
        local key=target.x..':'..target.y
        local reserved=false
        for _,other in ipairs(c.followers) do
          local goal=other.joinTarget
          if other~=e and (other.joinSlot==slot or goal and goal.x==target.x and goal.y==target.y) then reserved=true;break end
        end
        if not seen[key] and not reserved and not c:occupied(target.x,target.y,e)
            and A:allowed(target.x,target.y,e.surface,
              {follower=e.follower,cellX=e.cellX,cellY=e.cellY,currentElevation=e.currentElevation,elevation=e.elevation}) then
          local list=distance<=lastGap and goals or tail
          list[#list+1]={x=target.x,y=target.y,n=index,
            slot=slot,epoch=T.index}
          seen[key]=true
        end
      end
    end
    return goals,tail
  end
  function M:route(c,e,goals)
    local area=A:area()
    if not area or #goals==0 then return nil end
    local targets={};local available=false
    for _,goal in ipairs(goals) do
      if not c:occupied(goal.x,goal.y,e) then targets[goal.x..':'..goal.y]=goal;available=true end
      if e.cellX==goal.x and e.cellY==goal.y then return nil,goal end
    end
    if not available then return nil end
    local queue={{x=e.cellX,y=e.cellY}}
    local seen={[e.cellX..':'..e.cellY]=true};local head=1
    local ordered={}
    for _,d in ipairs(directions) do ordered[#ordered+1]=d end
    local preferred=goals[1]
    table.sort(ordered,function(a,b)
      return math.abs(e.cellX+a[1]-preferred.x)+math.abs(e.cellY+a[2]-preferred.y)
        < math.abs(e.cellX+b[1]-preferred.x)+math.abs(e.cellY+b[2]-preferred.y)
    end)
    -- Most displaced companions only need to approach an open trail cell.
    -- Try a single closer step before considering a bounded detour search.
    local distance=math.abs(e.cellX-preferred.x)+math.abs(e.cellY-preferred.y)
    if targets[preferred.x..':'..preferred.y] then
      for _,d in ipairs(ordered) do
        local x,y=e.cellX+d[1],e.cellY+d[2]
        if math.abs(x-preferred.x)+math.abs(y-preferred.y)<distance
            and self:legal(c,e,x,y) then return {x=x,y=y},preferred end
      end
    end
    -- Shared by all companions: a blocked formation cannot multiply an
    -- unbounded flood-fill by six on every rendered frame.
    c.routeBudget=c.routeBudget or 64
    c.routeAllowances=c.routeAllowances or {}
    local allowance=c.routeAllowances[e]
    if allowance==nil then allowance=math.min(48,math.floor(64/math.max(1,#c.followers))) end
    while head<=#queue and head<=math.min(48,area.width*area.height) and c.routeBudget>0 and allowance>0 do
      local node=queue[head];head=head+1;c.routeBudget=c.routeBudget-1;allowance=allowance-1
      c.routeAllowances[e]=allowance
      for _,d in ipairs(ordered) do
        local x,y=node.x+d[1],node.y+d[2];local key=x..':'..y
        if not seen[key] then
          seen[key]=true
          -- Terrain and non-follower obstacles still constrain each detour step.
          if self:legal(c,e,x,y,node.x,node.y) then
            local first=node.first or {x=x,y=y}
            local goal=targets[key]
            if goal then return first,goal end
            queue[#queue+1]={x=x,y=y,first=first}
          end
        end
      end
    end
  end
  function M:claim(c,e,slot)
    if e.lineSlot==slot then e.joinSlot=slot;return end
    local old=e.lineSlot or e.slot
    for _,other in ipairs(c.followers) do
      if other~=e and other.lineSlot==slot then
        other.lineSlot=old;other.joinSlot=old
        other.joinTarget=nil;other.joinBlocked=nil
        other.yielding=true
        -- A step in progress lands normally, then routes to its new position.
        other.targetStep=nil
        break
      end
    end
    e.lineSlot=slot;e.joinSlot=slot
  end
  function M:join(c,e,goal)
    local old=e.lineSlot or e.slot
    for _,other in ipairs(c.followers) do
      if other~=e and other.lineSlot==goal.slot then
        other.lineSlot=old
        local point=T.points[T.index-old]
        if not point or other.cellX~=point.x or other.cellY~=point.y then
          other.yielding=true;other.targetStep=nil
        end
        break
      end
    end
    e.lineSlot=goal.slot;e.trailStep=goal.n
    e.yielding=nil;e.arrivalAnchor=nil;e.joinTarget=nil;e.joinSlot=nil;e.joinGap=nil;e.joinBlocked=nil
  end
  function M:tick(c,e)
    self:yield(c,e)
    if not e.yielding then return false end
    if e.moving or e.ballPhase or e.awaitingTile then return true end
    if (e.clock or 0)<(e.nextRouteAt or 0) then return true end
    e.nextRouteAt=(e.clock or 0)+.2
    local goals,tail
    local step,goal
    if A:player().moving and not e.joinSlot then e.joinSlot=e.lineSlot or e.slot end
    if e.joinSlot and (A:player().moving or e.joinGap) then e.joinGap=T:joinGap(e.joinSlot) end
    if e.joinSlot then
      -- Keep one procession position as the trail advances. Do not chase a
      -- different nearest hole on every committed player step.
      local n=T.index-(e.joinGap or T:cellGap(e.joinSlot))
      local point=T.points[n]
      if point and not point.interior then
        local locked={x=point.x,y=point.y,n=n,slot=e.joinSlot,epoch=T.index}
        step,goal=self:route(c,e,{locked})
        if not goal and math.abs(e.cellX-point.x)+math.abs(e.cellY-point.y)>1 then
          -- A teammate may still be vacating the reserved position. Approach
          -- its nearest free neighbor now; only the final step must wait.
          local neighbors={}
          for _,d in ipairs(directions) do
            neighbors[#neighbors+1]={x=point.x+d[1],y=point.y+d[2],n=n,slot=e.joinSlot,epoch=T.index}
          end
          local approach=self:route(c,e,neighbors)
          if approach and math.abs(approach.x-point.x)+math.abs(approach.y-point.y)
              <math.abs(e.cellX-point.x)+math.abs(e.cellY-point.y) then
            step,goal=approach,locked
          end
        end
      end
      if not goal then
        e.joinBlocked=(e.joinBlocked or 0)+1
        if e.joinBlocked<3 then return true end
        e.joinSlot=nil;e.joinGap=nil;e.joinTarget=nil;e.joinBlocked=nil
      else e.joinBlocked=0 end
    end
    if not goal then goals,tail=self:goals(c,e);step,goal=self:route(c,e,goals) end
    if not goal then
      -- Pull a nearby teammate into a forward vacancy to propagate the hole
      -- back through a narrow line instead of crossing occupied cells.
      for _,other in ipairs(c.followers) do
        if other~=e and not other.moving and not other.ballPhase then
          local holes=self:goals(c,other)
          for _,hole in ipairs(holes) do
            if hole.n>(other.trailStep or 0) and math.abs(hole.x-other.cellX)+math.abs(hole.y-other.cellY)==1
                and self:legal(c,other,hole.x,hole.y) then
              if c:move(other,hole.x,hole.y,self:duration()) then
                other.yielding=true;other.joinTarget=hole;other.rejoinGoal=hole
                return true
              end
            end
          end
        end
      end
    end
    if not goal and not A:player().moving then step,goal=self:route(c,e,tail) end
    e.joinTarget=goal
    if goal then self:claim(c,e,goal.slot) end
    if goal and not step then self:join(c,e,goal);return false end
    if step and c:move(e,step.x,step.y,self:duration()) then
      e.nextRouteAt=nil
      -- Landing completes the reserved join even if the leader commits a new
      -- step in the meantime. Continue forward from this trail index next.
      if step.x==goal.x and step.y==goal.y then e.rejoinGoal=goal end
    end
    return true
  end
  return M
end
