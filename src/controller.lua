return function(mod,include)
  local A,S,T,W,G=include('adapter'),include('sprites'),include('trail'),include('areas'),include('grass')
  local B=include('balls')
  local Y=include('avoidance')
  local I=include('idle')
  local V=include('voxel')
  local E=include('ecology')
  local C={wilds={},followers={},wrappers={},serial=0,loadArrival=true}
  local delta={up={0,-1},down={0,1},left={-1,0},right={1,0}}
  local function option(key) return mod.options:get(key) end
  local function removeOwned(list)
    for i=#(list or {}),1,-1 do if list[i]._wildFollowersRewrite then table.remove(list,i) end end
  end
  function C:detach()
    if self.world then removeOwned(self.world.npcs);removeOwned(self.world.entities) end
  end
  function C:clear()
    self.storyRecalled=nil;self.storyRecallTime=nil
    A.crossingArea=nil;self.pendingSeam=nil;self.seamPendingObserve=nil;self.inBattle=nil;self.battleReturn=nil
    B:cancel();self.ballArrival=nil;self.ballArrivalStable=nil
    self:detach();self.wilds={};self.followers={};self.lineRejoining=nil;T:clear();W:clear()
  end
  function C:clearWilds()
    self:detach();self.wilds={};W:clear()
  end
  function C:ecosystemSpawn(area,kind,hit,actors)
    return E:spawn(area,kind,hit,actors)
  end
  function C:battleStarted()
    self.inBattle=true
    self.battleReturn={map=self.map,save=self.save}
    self:clearWilds()
  end
  function C:battleEnded()
    self.inBattle=nil
    self.battleReturn=self.battleReturn or {map=self.map,save=self.save}
    self:clearWilds()
  end
  function C:mapReloaded()
    if self.battleReturn and self.battleReturn.map==A:mapId() and self.battleReturn.save==A:save() then
      self:clearWilds()
    else self:clear() end
  end
  function C:mapEntered(ev)
    if self.nativeConnection and ev and ev.via=='connection' then
      self.nativeConnection.event=ev;return
    end
    if self.battleReturn and self.battleReturn.map==(ev and ev.mapId or A:mapId())
        and self.battleReturn.save==A:save() then self:clearWilds();return end
    if ev and ev.via=='connection' and self.save==A:save() then
      local from=ev.fromMapId or ev.fromMap
      local to=ev.mapId or A:mapId()
      if not from or from==self.map then
        for _,neighbor in ipairs(A:adjacent(self.area or A:area(self.map))) do
          if neighbor.id==to then
            self.pendingSeam={map=to,dx=-neighbor.offsetX,dy=-neighbor.offsetY}
            self:detach();self.wilds={};W:transition(ev);return
          end
        end
      end
    end
    self.pendingSeam=nil
    B:cancel()
    self:detach();self.wilds={};self.followers={};T:clear()
    W:transition(ev);self.battlePending=false
  end
  function C:projectFollowers(dx,dy)
    local shifted={}
    local function anchor(t)
      if not t or shifted[t] then return end
      shifted[t]=true
      if t.x then t.x=t.x+dx end;if t.y then t.y=t.y+dy end
    end
    for _,e in ipairs(self.followers) do
      for _,key in ipairs({'cellX','targetX'}) do if e[key] then e[key]=e[key]+dx end end
      for _,key in ipairs({'cellY','targetY'}) do if e[key] then e[key]=e[key]+dy end end
      for _,key in ipairs({'px','startX','x'}) do if e[key] then e[key]=e[key]+dx*16 end end
      for _,key in ipairs({'py','startY','y'}) do if e[key] then e[key]=e[key]+dy*16 end end
      anchor(e.idleWander);anchor(e.joinTarget);anchor(e.rejoinGoal)
      e.mapId=A:mapId()
    end
    T:project(dx,dy)
  end
  function C:saveLoading()
    self:clear();self.loadArrival=true
  end
  function C:wrap(target,key,handler)
    if not target or type(target[key])~='function' then return end
    for _,entry in ipairs(self.wrappers) do if entry.target==target and entry.key==key and target[key]==entry.wrapped then return end end
    local old=target[key]
    local wrapped=function(...) if self.disposed then return old(...) end;return handler(old,...) end
    self.wrappers[#self.wrappers+1]={target=target,key=key,old=old,wrapped=wrapped}
    target[key]=wrapped
  end
  function C:dispose()
    self:clear();self.disposed=true
    V:dispose()
    for i=#self.wrappers,1,-1 do local e=self.wrappers[i];if e.target[e.key]==e.wrapped then e.target[e.key]=e.old end end
    self.wrappers={}
  end
  function C:install()
    if A.generation==3 then
      local warp=require('src.core.game3.warp')
      for _,key in ipairs({'startDoorEntrance','startDoorExit'}) do
        self:wrap(warp,key,function(old,...) return B:begin(self,old,...) end)
      end
      local effects=require('src.core.game3.field_effects')
      if effects._wildFollowersRewriteOwner and effects._wildFollowersRewriteOwner~=self then effects._wildFollowersRewriteOwner:dispose() end
      effects._wildFollowersRewriteOwner=self
      self:wrap(effects,'collectActors',function(old,actors)
        old(actors)
        if self.map==A:mapId() and self.save==A:save() and require('src.core.GameVersion').get()==A.version
            and option('enabled')~=false then
          for _,list in ipairs({self.followers,self.wilds}) do for _,actor in ipairs(list) do
            if not actor.hidden then
              actor.x,actor.y=actor.px,actor.py;actor.sortY=actor.py;actors[#actors+1]=actor
              G:collect(actors,actor)
            end
          end end
        end
      end)
      self:wrap(require('src.core.game3.field'),'interact',function(old,game)
        if self:interact() then return true end
        return old(game)
      end)
      self:wrap(require('src.core.game3.collision'),'canEnter',function(old,game,x,y,opts)
        local allowed,reason=old(game,x,y,opts)
        if self:wildAt(x,y) and (allowed or reason=='entity') then return false,'wildfollowers' end
        return allowed,reason
      end)
      local objects=require('src.core.game3.objects')
      -- This native grid check is used by roaming and connection-map NPCs;
      -- it is separate from player collision, which keeps companions passable.
      self:wrap(objects,'blocks',function(old,x,y,except,elevation)
        if except~=nil and self:followerAt(x,y) then return true end
        return old(x,y,except,elevation)
      end)
      self:wrap(objects,'playerBlocks',function(old,x,y,elevation)
        if self:followerAt(x,y) then return true end
        return old(x,y,elevation)
      end)
      self:wrap(objects,'scriptStep',function(old,npc,dir,...)
        self:recallStory()
        local d=delta[dir]
        if npc and npc~=A:player() and d and not self:npcRoom(npc,npc.cellX+d[1],npc.cellY+d[2]) then return false end
        return old(npc,dir,...)
      end)
      self:wrap(A:player(),'tryMove',function(old,dir,game,...)
        local moving=A:player().moving
        local result,reason=old(dir,game,...)
        if not moving and A:player().moving then Y:committed(self) end
        if result=='blocked' and reason=='wildfollowers' then
          local p=A:player();local d=delta[dir]
          local wild=d and self:wildAt(p.cellX+d[1],p.cellY+d[2])
          if wild and not A:busy() and not self.battlePending then self:battle(wild) end
        end
        return result,reason
      end)
      self:wrap(A:player(),'bikeStep',function(old,...)
        local moving=A:player().moving
        local result=old(...)
        if not moving and A:player().moving then Y:committed(self) end
        return result
      end)
    else
      local w=A:world()
      if not w then return end
      if w._wildFollowersRewriteOwner and w._wildFollowersRewriteOwner~=self then w._wildFollowersRewriteOwner:dispose() end
      w._wildFollowersRewriteOwner=self
      self:wrap(A:player(),'tryMove',function(old,...)
        if B.pending then return false end
        local moving=A:player().moving
        local result,reason=old(...)
        if not moving and A:player().moving then Y:committed(self) end
        return result,reason
      end)
      local npcModule=require(A.generation==1 and 'src.world.Collision' or 'src.world.gen2.Npc')
      local method=A.generation==1 and 'canMove' or 'canStep'
      self:wrap(npcModule,method,function(old,a,b,c,d)
        local npc,dir
        if A.generation==1 then npc,dir=c,d else npc,dir=a,d end
        local offset=delta[dir]
        if npc~=A:player() and offset and self:followerAt(npc.cellX+offset[1],npc.cellY+offset[2],npc) then return false end
        return old(a,b,c,d)
      end)
      if A.generation==2 then
        self:wrap(w,'tryConnection',function(old,world,...)
          local p=A:player();local x,y=p.cellX,p.cellY
          local map,save=A:mapId(),A:save()
          local previousArea=A:area()
          self.nativeConnection={}
          local ok,result,reason=pcall(old,world,...)
          local crossing=self.nativeConnection;self.nativeConnection=nil
          if not ok then error(result,0) end
          if result and A:mapId()~=map and A:save()==save then
            -- Gen 2 emits map.entered inside setMap, before the native
            -- connection code finishes positioning its in-flight player.
            -- Capture the completed native translation rather than rebuilding
            -- the group from a detached neighbor descriptor at event time.
            local dx,dy=p.cellX-x,p.cellY-y
            self.pendingSeam={map=A:mapId(),dx=dx,dy=dy}
            if previousArea then
              previousArea.current=false;previousArea.offsetX,previousArea.offsetY=dx,dy
              previousArea.destination=A:mapId();A.crossingArea=previousArea
            end
            self:detach();self.wilds={}
            W:transition(crossing.event or {via='connection',fromMapId=map,mapId=A:mapId()})
          elseif crossing.event then self:mapEntered(crossing.event) end
          return result,reason
        end)
        self:wrap(npcModule,'scriptStep',function(old,npc,dir,...)
          self:recallStory()
          local d=delta[dir]
          if d and not self:npcRoom(npc,npc.cellX+d[1],npc.cellY+d[2]) then return false end
          return old(npc,dir,...)
        end)
      else
        self:wrap(w,'updateScriptMoves',function(old,world,...)
          if #(world.scriptMoves or {})>0 and not A:ledgeTraversal() then self:recallStory() end
          local held={}
          for _,mv in ipairs(world.scriptMoves or {}) do
            local npc,d=mv.entity,delta[mv.dir]
            if npc~=A:player() and not npc.moving and not mv.inPlace and (mv.remaining or 0)>0
                and d and self:followerAt(npc.cellX+d[1],npc.cellY+d[2],npc) then
              self:npcRoom(npc,npc.cellX+d[1],npc.cellY+d[2])
              npc.moving=true;held[#held+1]=npc
            end
          end
          local result=old(world,...)
          for _,npc in ipairs(held) do npc.moving=false end
          return result
        end)
      end
      self:wrap(w,'takeWarp',function(old,...) return B:begin(self,old,...) end)
      self:wrap(w,'interact',function(old,world,...)
        if self:interact() then return true end
        return old(world,...)
      end)
    end
  end
  function C:actor(species,level,x,y,kind,slot,area)
    local national=A:national(species)
    if not S:get(national) then return nil end
    local sx,sy=area and area.localX or x,area and area.localY or y
    local current,draw
    if area then current,draw=A:elevations(sx,sy,area)
    else current=A:player().currentElevation or A:player().elevation or 3;draw=A:player().elevation or current end
    self.serial=self.serial+1
    local actor={_wildFollowersRewrite=true,id='wildfollowers_rewrite_'..self.serial,
      i=50000+self.serial,kind='npc',species=species,national=national,level=level,surface=kind,
      cellX=x,cellY=y,px=x*16,py=y*16,facing='down',clock=0,passable=slot~=nil,moving=false,
      elevation=draw,currentElevation=current,
      follower=slot~=nil,slot=slot,lineSlot=slot,mapId=area and area.id or self.map,
      def={index=50000+self.serial,name='WILDFOLLOWERS',x=x,y=y,movement='STAY'},
      spriteDef={width=16,height=16},inGrass=A:grass(sx,sy,area),trailStep=T:cellIndex(x,y)}
    actor.update=function() end -- native NPC scheduler never owns our movement
    actor.facePlayer=function(e,p) local d=delta[p.facing] or delta.down;e.facing=d[1]>0 and 'left' or d[1]<0 and 'right' or d[2]>0 and 'up' or 'down' end
    actor.pose=function(e)return V:pose(e) end
    actor.draw=function(e,a,b,c,row)
      if e.hidden then return end
      if A.generation==2 then S:draw(e,a,b,c,row) else S:draw(e,-a,-b,1) end
      if A.generation==2 then G:drawGB(e,a,b,c,row) elseif A.generation==1 then G:drawGB(e,-a,-b,1) end
    end
    return actor
  end
  function C:publish()
    if A.generation==3 or not self.world then return end
    self:detach()
    self.world.npcs=self.world.npcs or {};self.world.entities=self.world.entities or {}
    for _,list in ipairs({self.followers,self.wilds}) do for _,e in ipairs(list) do
      if not e.hidden then
        self.world.npcs[#self.world.npcs+1]=e
        self.world.entities[#self.world.entities+1]=e
      end
    end end
  end
  function C:occupied(x,y,ignore,followersPassable,vacatingPlayer)
    if A:occupied(x,y,ignore,nil,followersPassable,vacatingPlayer) then return true end
    for _,list in ipairs({self.followers,self.wilds}) do for _,e in ipairs(list) do
      if e~=ignore and not e.hidden and not e.storyRecall and not (followersPassable and e.follower)
          and (e.cellX==x and e.cellY==y or e.targetX==x and e.targetY==y) then return true end
    end end
    local p=A:player();return p and ((not vacatingPlayer or not p.moving) and p.cellX==x and p.cellY==y or p.targetX==x and p.targetY==y)
  end
  function C:wildAt(x,y,ignore)
    if self.disposed or option('enabled')==false or self.map~=A:mapId() or self.save~=A:save() then return nil end
    for _,e in ipairs(self.wilds) do
      if e~=ignore and not e.hidden and e.currentEligible~=false and
          (e.cellX==x and e.cellY==y or e.targetX==x and e.targetY==y) then return e end
    end
  end
  function C:followerAt(x,y,ignore)
    if self.storyRecalled then return nil end
    if self.disposed or option('enabled')==false or self.map~=A:mapId() or self.save~=A:save() then return nil end
    for _,e in ipairs(self.followers) do
      if e~=ignore and not e.hidden and not e.awaitingTile and
          (e.cellX==x and e.cellY==y or e.targetX==x and e.targetY==y) then return e end
    end
  end
  function C:npcRoom(npc,x,y)
    local e=self:followerAt(x,y,npc)
    if not e then return true end
    if e.moving then e.npcYield=true;return false end
    local dx,dy=x-npc.cellX,y-npc.cellY
    e.yielding=true
    for _,d in ipairs({{-dy,dx},{dy,-dx},{dx,dy},{-dx,-dy}}) do
      local tx,ty=e.cellX+d[1],e.cellY+d[2]
      if Y:legal(self,e,tx,ty) and self:move(e,tx,ty,Y:duration(true)) then
        e.npcYield=true;break
      end
    end
    return false
  end
  function C:collision(next_,allowed,ctx)
    local result=next_(allowed,ctx)
    if not ctx then return result end
    if ctx.mover~=A:player() and self:followerAt(ctx.toX,ctx.toY,ctx.mover) then
      ctx.reason='wildfollowers-companion';return false
    end
    local wild=self:wildAt(ctx.toX,ctx.toY,ctx.mover)
    if not wild then return result end
    if ctx.mover==A:player() and (result or ctx.reason=='entity') and not A:busy() and not self.battlePending then
      self:battle(wild)
    end
    ctx.reason='wildfollowers';return false
  end
  function C:move(e,x,y,duration,point)
    if e.moving or (not e.follower or e.yielding or e.arrivalAnchor or e.idleMode)
        and self:occupied(x,y,e,e.follower) then return false end
    if self:wildAt(x,y,e) then return false end
    local dx,dy=x-e.cellX,y-e.cellY
    local distance=math.abs(dx)+math.abs(dy)
    if distance~=1 and not (e.follower and point and point.jump and distance==2 and (dx==0 or dy==0)) then return false end
    local facing=dx>0 and 'right' or dx<0 and 'left' or dy>0 and 'down' or 'up'
    e.facing=facing
    if e.follower then
      local permissionPoint=point
      if e.yielding or e.arrivalAnchor or e.idleMode then permissionPoint=nil end
      if not A:allowed(x,y,e.surface,e,permissionPoint) then return false end
    elseif not W:allowed(e,x,y) then return false end
    e.rejoining=e.yielding or e.idleWander and true or nil
    e.targetX,e.targetY=x,y;e.startX,e.startY=e.px,e.py;e.progress=0;e.moving=true;e.spacingPaused=nil
    e.duration=duration or 1/6
    e.jumpActive=point and point.jump and true or nil
    if point then
      e.currentElevation=point.currentElevation or point.elevation or e.currentElevation
      e.elevation=point.elevation or e.elevation
    end
    return true
  end
  function C:animate(e,dt)
    e.clock=e.clock+dt
    if e.follower then e.inGrass=A:grass(e.cellX,e.cellY) else e.inGrass=W:grass(e) end
    if not e.moving then return end
    local limit=1
    if e.follower and e.targetStep and not e.jumpActive and not e.yielding then
      local gap=T:gap(e.lineSlot or e.slot)
      if math.abs(gap-math.floor(gap+.000001))>.000001 then
        limit=math.max(e.progress,math.min(1,T:eligible(e.lineSlot or e.slot,A:player())-e.targetStep+1))
      end
    end
    local previous=e.progress
    e.progress=math.min(limit,e.progress+dt/(e.duration or 1/6))
    e.spacingPaused=limit<1 and e.progress==previous or nil
    e.px=e.startX+(e.targetX*16-e.startX)*e.progress
    e.py=e.startY+(e.targetY*16-e.startY)*e.progress
    if e.follower and option('smart_spacing')==true and not e.jumpActive and not e.yielding and not e.ballPhase then
      local function overlap(a,b)
        return math.max(0,math.min(a[3],b[3])-math.max(a[1],b[1]))
          *math.max(0,math.min(a[4],b[4])-math.max(a[2],b[2]))
      end
      local oldX=e.startX+(e.targetX*16-e.startX)*previous
      local oldY=e.startY+(e.targetY*16-e.startY)*previous
      local oldBox,newBox=S:box(e,oldX,oldY),S:box(e,e.px,e.py)
      local p=A:player();local foot=A.generation==3 and 16 or 12
      local trainerBox={(p.px or p.cellX*16),(p.py or p.cellY*16)+foot-16,
        (p.px or p.cellX*16)+16,(p.py or p.cellY*16)+foot}
      local blocked=overlap(newBox,trainerBox)>overlap(oldBox,trainerBox)+.000001
      for _,other in ipairs(self.followers)do
        -- A leader must never wait for a follower behind it: that follower
        -- already depends on the leader's trail progress, creating a deadlock.
        local rank=e.lineSlot or e.slot or 1
        local otherRank=other.lineSlot or other.slot or 1
        if other~=e and otherRank<rank and not other.hidden and not other.ballPhase then
          local box=S:box(other)
          if overlap(newBox,box)>overlap(oldBox,box)+.000001 then blocked=true;break end
        end
      end
      if blocked then e.progress=previous;e.px,e.py=oldX,oldY;e.spacingPaused=true end
    end
    if e.progress==1 then
      e.cellX,e.cellY=e.targetX,e.targetY;e.targetX=nil;e.targetY=nil;e.moving=false;e.rejoining=nil;e.jumpActive=nil;e.spacingPaused=nil
      if e.follower then A:land(e) else W:land(e);W:sync(e) end
      if e.targetStep then e.trailStep=e.targetStep;e.targetStep=nil end
      if e.rejoinGoal then local goal=e.rejoinGoal;e.rejoinGoal=nil;Y:join(self,e,goal) end
      -- A fractional offset can cross a cell between native frames. Carry
      -- the unused frame time into the next step instead of losing pixels.
      local remaining=dt-(1-previous)*(e.duration or 1/6)
      local gap=e.follower and T:gap(e.lineSlot or e.slot)
      if remaining>.000001 and gap and math.abs(gap-math.floor(gap+.000001))>.000001
          and not e.yielding and not e.arrivalAnchor and not e.idleMode then
        local point,lost,duration=T:next(e,e.lineSlot or e.slot,A:player())
        if point and self:move(e,point.x,point.y,duration,point) then
          e.targetStep=point.n;e.clock=e.clock-remaining
          self:animate(e,remaining)
        end
      end
    end
  end
  function C:syncFollowers()
    local enabled=option('OW_FOLLOWERS_ENABLED')~=false
    local count=enabled and math.max(0,math.min(6,tonumber(option('follower_count')) or 1)) or 0
    local desired={}
    local stockFollower=false
    for _,npc in ipairs(self.world and self.world.npcs or {}) do
      if npc.pikachuFollower then stockFollower=true;break end
    end
    for _,mon in ipairs(A:party()) do
      local stockMon=false
      if stockFollower and A.generation==1 then
        stockMon=require('src.world.PikachuFollower').isStarterPikachu(A:save(),mon)
      end
      if #desired<count and not A:egg(mon) and (tonumber(mon.hp) or 0)>0
          and not stockMon and S:get(A:national(A:species(mon))) then desired[#desired+1]=mon end
    end
    local p=A:player()
    for i,mon in ipairs(desired) do
      local species=A:species(mon);local e=self.followers[i]
      if not e or e.mon~=mon or e.species~=species then
        e=self:actor(species,mon.level,p.cellX,p.cellY,A:water(p.cellX,p.cellY) and 'water' or 'land',i)
        if e then
          e.mon=mon
          if self.ballArrival then B:place(self,e) end
        end
        self.followers[i]=e
      end
    end
    for i=#self.followers,#desired+1,-1 do self.followers[i]=nil end
    -- Party identity stays in party order; procession positions may change.
    local used={}
    for _,e in ipairs(self.followers) do
      if e.lineSlot and e.lineSlot<=#desired and not used[e.lineSlot] then used[e.lineSlot]=true
      else e.lineSlot=nil end
    end
    for _,e in ipairs(self.followers) do
      if not e.lineSlot then
        for slot=1,#desired do if not used[slot] then e.lineSlot=slot;used[slot]=true;break end end
      end
    end
    self.ballArrival=nil
  end
  function C:battle(e)
    if not e or e.follower or e.currentEligible==false then return false end
    if A:start(e) then self:clearWilds();self.battlePending=true;return true end
    return false
  end
  function C:interact()
    if self.disposed or option('enabled')==false or A:busy() or self.battlePending then return false end
    local p=A:player();if p.moving then return false end
    local d=delta[p.facing] or delta.down;local x,y=p.cellX+d[1],p.cellY+d[2]
    for _,e in ipairs(self.wilds) do if e.currentEligible~=false and e.cellX==x and e.cellY==y then return self:battle(e) end end
    for _,e in ipairs(self.followers) do if e.cellX==x and e.cellY==y then return true end end
    return false
  end
  function C:recallStory()
    if self.storyRecalled or #self.followers==0 then return end
    self.storyRecalled=true;self.storyRecallTime=0
    for _,e in ipairs(self.followers)do
      -- Release all occupied/reserved cells before any scripted NPC step.
      e.storyRecall=true;e.moving=false;e.targetX=nil;e.targetY=nil;e.progress=nil
      e.npcYield=nil;e.idlePose=nil;e.yielding=nil
      if not e.hidden and option('OW_FOLLOWERS_POKEBALLS')~=false then
        e.ballPhase='recall';e.ballTime=0
      else e.hidden=true;e.ballPhase=nil end
    end
  end
  function C:tick(game,dt)
    if self.disposed then return end
    dt=math.max(0,math.min(tonumber(dt) or 1/60,.05))
    if self.inBattle then return end
    local w,id,save=A:world(),A:mapId(),A:save()
    if save~=self.save then self:saveLoading() end
    if w~=self.world or id~=self.map or save~=self.save then
      self:detach();self.wilds={}
      local seam=self.pendingSeam
      if seam and seam.map==id and save==self.save then self:projectFollowers(seam.dx,seam.dy);self.seamPendingObserve=true
      elseif not (self.battleReturn and self.battleReturn.map==id and self.battleReturn.save==save) then self.followers={};T:clear() end
      self.pendingSeam=nil
      self.world,self.map,self.save=w,id,save;self.battlePending=false
    end
    self.area=A:area()
    if option('enabled')==false or not id then self:clear();return end
    if self.loadArrival then
      self.ballArrival=true;self.ballArrivalStable=0;self.loadArrival=nil
    end
    self:install()
    -- Complete our own warp recall even if a script starts during its lock.
    -- Story recall must never wait on the field lock owned by this queue.
    if B.pending and B:tick(self,dt) then self:publish();return end
    if not B.pending and A:storyBusy() then self:recallStory() end
    if self.storyRecalled then
      self.storyRecallTime=math.min(.30,(self.storyRecallTime or 0)+dt)
      for _,e in ipairs(self.followers)do
        e.ballTime=self.storyRecallTime
        if self.storyRecallTime>=.30 then e.hidden=true;e.ballPhase=nil end
      end
      if A:busy() or A:storyBusy() or self.storyRecallTime<.30 then self:publish();return end
      self.storyRecalled=nil;self.storyRecallTime=nil
      for _,e in ipairs(self.followers)do e.storyRecall=nil;e.hidden=true;e.awaitingTile=true end
      self.ballArrival=true;self.ballArrivalStable=0;T:reset(A:player())
    end
    if self.battleReturn and A:busy() then self:publish();return end
    if B:tick(self,dt) then self:publish();return end
    if self.ballArrival and not B:arrivalReady(self) or A:busy() then
      -- A seam may open a script before the next gameplay frame. Project the
      -- preserved populations now, while their timers and spawning stay paused.
      -- A scripted NPC waits for its companion reservation to clear. Only
      -- that courtesy step advances while the player's field controls lock.
      for _,e in ipairs(self.followers) do
        if e.npcYield then self:animate(e,dt);if not e.moving then e.npcYield=nil end end
      end
      self.wilds=W:update(self,0)
      self:publish();return
    end
    self.battleReturn=nil
    if self.battlePending then self.battlePending=false end
    local p=A:player()
    if not T:observe(p) then
      if self.seamPendingObserve then
        T:reset(p)
        for _,e in ipairs(self.followers) do e.trailStep=0;e.yielding=true end
      else self:clear();T:reset(p);T:observe(p) end
    end
    self.seamPendingObserve=nil
    self.routeBudget=64
    self.routeAllowances={}
    self:syncFollowers()
    T:updateSpacing(self.followers,S,p)
    B:seedTrail(self,T)
    if p.moving then Y:prepare(self) end
    for i,e in ipairs(self.followers) do
      if e.awaitingTile then e.awaitingTile=nil;B:place(self,e) end
      if e.ballPhase=='release' and p.moving then e.ballPhase=nil end
      if e.ballPhase=='release' then
        e.ballTime=e.ballTime+dt
        if e.ballTime>=.30 then e.ballPhase=nil end
      end
      local target,lost,duration
      local idling=I:tick(self,e,dt)
      local yielding=Y:tick(self,e)
      if not yielding and not idling and not e.moving and not e.ballPhase and not e.awaitingTile then target,lost,duration=T:next(e,e.lineSlot or i,p) end
      if lost then
        local mon=e.mon
        self.followers[i]=self:actor(e.species,e.level,p.cellX,p.cellY,A:water(p.cellX,p.cellY) and 'water' or 'land',i)
        e=self.followers[i];e.mon=mon;B:place(self,e)
      elseif target then
        if mod.options:get('OW_FOLLOWERS_PLAYER_YIELD')~=false
          and p.moving and target.x==p.targetX and target.y==p.targetY then
          e.yielding=true;target=nil
        end
        if target and e.arrivalAnchor then
          target=B:approach(self,e,target)
          if not target then e.yielding=true end
        end
        if target then
          e.surface=A:water(target.x,target.y) and 'water' or 'land'
          if self:move(e,target.x,target.y,duration,target) then e.targetStep=target.n
          elseif e.follower and not self:followerAt(target.x,target.y,e) then
            e.yielding=true
          end
        end
      end
      self:animate(e,dt)
      if e.arrivalAnchor and not e.moving and not e.ballPhase then
        local landed=T.points[e.trailStep]
        if landed and landed.x==e.cellX and landed.y==e.cellY then e.arrivalAnchor=nil end
      end
      e.hidden=e.awaitingTile or not e.ballPhase and not p.moving and not e.moving and math.abs(e.px-(p.px or p.cellX*16))<1
        and math.abs(e.py-(p.py or p.cellY*16))<1
    end
    T:trim(self.followers)
    self.wilds=W:update(self,dt)
    E:prepare(self.wilds,dt)
    for _,e in ipairs(self.wilds) do
      if not e.retired then
        e.hidden=false;self:animate(e,dt)
        e.idle=(e.idle or 0)+dt
        if not E:step(self,e,dt) and e.idle>=2 and not e.moving then
          e.idle=0;local d=delta[({'up','down','left','right'})[math.random(1,4)]]
          if W:habitat(e,e.cellX+d[1],e.cellY+d[2]) then self:move(e,e.cellX+d[1],e.cellY+d[2]) end
        end
        if option('WE_OWE_INITIATE_BATTLES')==true and e.currentEligible and not p.moving and e.cellX==p.cellX and e.cellY==p.cellY then
          if self:battle(e) then return end
        end
      end
    end
    self:publish()
  end
  function C:canReplace(ctx)
    if self.disposed or option('enabled')==false or option('WE_VANILLA_RANDOM')~=false
        or option('WE_OW_ENCOUNTERS')==false or A:encountersBlocked() or not A:healthy() then return false end
    if ctx and ctx.kind and ctx.kind~='wild' then return false end
    local kind=ctx and ctx.terrain=='water' and 'water' or 'land'
    if kind=='water' and option('WE_OW_WATER')==false then return false end
    -- A failed asset/provider must leave the native encounter available.
    for _,e in ipairs(self.wilds) do if e.currentEligible~=false and not e.hidden and e.surface==kind then return true end end
    return false
  end
  function C:status()
    local out={version=mod.exports.version,numbering='national',game=A.version,generation=A.generation,actors={},followers={},pathStep=T.index}
    for _,e in ipairs(self.wilds) do out.actors[#out.actors+1]={national=e.national,species=e.species,level=e.level,x=e.cellX,y=e.cellY,
      kind=e.surface,sourceMap=e.sourceMap,current=e.currentEligible,preview=e.previewEligible,retired=e.retired,
      behavior=e.ecology and e.ecology.mode or 'wander'} end
    for _,e in ipairs(self.followers) do out.followers[#out.followers+1]={national=e.national,species=e.species,x=e.cellX,y=e.cellY,
        px=e.px,py=e.py,moving=e.moving,trailStep=e.trailStep,hidden=e.hidden,lineSlot=e.lineSlot,yielding=e.yielding} end
    return out
  end
  return C
end
