-- One-cell native walks. Bounded return searches run only at step boundaries.
return function(E,Terrain)
  local M={idle=0,time=0}
  local speeds={slowest=48,slower=32,slow=24,normal=16,fast=12,fastest=8}
  local dirs={'up','right','down','left'}
  local dx={up=0,right=1,down=0,left=-1}
  local dy={up=-1,right=0,down=1,left=0}
  local lastX,lastY
  function M.reset()M.idle=0;lastX,lastY=nil,nil end
  function M.beginTick()
    M.time=M.time+1
    local p=E.Player
    if p.moving or p.cellX~=lastX or p.cellY~=lastY or E.controlsLocked() then M.idle=0
    else M.idle=M.idle+1 end
    lastX,lastY=p.cellX,p.cellY
  end
  local function free(a,x,y,dir)
    if E.Spacing and not E.Spacing.allowedAt(a,x,y) then return false end
    if E.Spacing and E.Spacing.blocksIdleStep and E.Spacing.blocksIdleStep(a,x,y) then return false end
    if not E.Collision.inBounds(x,y) or E.Collision.warpAt(x,y)
        or not Terrain.followerCellAllowed(E.Player,E.Collision,x,y)
        or E.Objects.at(x,y) or E.actorAt(x,y,a.nativeActor or a) then return false end
    local p=E.Player
    if (x==p.cellX and y==p.cellY) or (p.moving and x==p.targetX and y==p.targetY) then return false end
    if E.Collision.ledgeLanding(E.Field._game,a.cellX,a.cellY,dir) then return false end
    return E.canMove(a,x,y,dir,false)
  end
  -- Reuse scratch arrays across followers; no per-node table allocation.
  local xs,ys,first,seen={},{},{},{}
  local epoch=0;local current
  local probe=setmetatable({},{__index=function(_,k)return current[k]end})
  local function returnDirection(a,leader,exact)
    local tx,ty=leader.cellX,leader.cellY
    local layout=E.Collision._mapDef and E.Collision._mapDef.midLayout
    local width=layout and layout.width or 65536
    epoch=epoch+1
    if epoch>1000000 then seen={};epoch=1 end
    current=a;probe.nativeActor=a.nativeActor or a
    xs[1],ys[1],first[1]=a.cellX,a.cellY,false
    seen[a.cellY*width+a.cellX]=epoch
    local head,tail=1,1
    local bestDistance=math.abs(a.cellX-tx)+math.abs(a.cellY-ty)
    local bestDirection
    while head<=tail and head<=512 do
      local x,y=xs[head],ys[head]
      local distance=math.abs(x-tx)+math.abs(y-ty)
      if distance<bestDistance then bestDistance=distance;bestDirection=first[head] end
      if head>1 and ((exact and distance==0) or (not exact and distance==1)) then return first[head] end
      probe.cellX,probe.cellY=x,y
      -- Try directions towards the leader first, preserving bounded work.
      local offset=math.abs(tx-x)>math.abs(ty-y) and (tx>x and 2 or 4) or (ty>y and 3 or 1)
      for k=0,3 do
        local d=dirs[(offset+k-1)%4+1];local nx,ny=x+dx[d],y+dy[d]
        local key=ny*width+nx
        if seen[key]~=epoch and math.abs(nx-a.cellX)<=12 and math.abs(ny-a.cellY)<=12
            and free(probe,nx,ny,d) and not E.actorAt(nx,ny,a) then
          seen[key]=epoch;tail=tail+1
          xs[tail],ys[tail],first[tail]=nx,ny,first[head] or d
        end
      end
      head=head+1
    end
    return bestDirection
  end
  -- Shared return controller: legal shortest route, leader-first settling,
  -- and no extra pause after a completed native step. Only blocked paths wait.
  function M.returnFrames(a,leader)
    local gap=math.abs(a.cellX-leader.cellX)+math.abs(a.cellY-leader.cellY)
    return (E.Player.running or (E.C.OW_FOLLOWERS_RUN_TO_CATCH_UP~=false and gap>1)) and 8 or 16
  end
  function M.returnStep(a,leader,home)
    if a.moving or leader.independent then return false end
    local target=home or leader
    if math.abs(a.cellX-target.cellX)+math.abs(a.cellY-target.cellY)==(home and 0 or 1) then
      a.returnRetry=nil;return true
    end
    if M.time<(a.returnRetry or 0) then return false end
    local dir=returnDirection(a,target,home~=nil)
    if dir and free(a,a.cellX+dx[dir],a.cellY+dy[dir],dir)
        and a.nativeCore.independentStep(dir,M.returnFrames(a,leader))~=false then
      a.returnRetry=M.time+1
    else a.returnRetry=M.time+4 end
    return false
  end
  function M.tick(a,leader)
    if a.play or a.social then return end
    local core=a.nativeCore
    if not a.active or a.invisible or a.ballGfx or a.affine or core.talking()
        or not E.followerVisible() or E.controlsLocked()
        or (a.act~=core.A.NONE and a.act~=core.A.IN_PLACE and a.act~=core.A.WALK) then
      core.stopIndependent();return
    end
    local w=a.wander
    local range=math.max(1,math.min(8,tonumber(E.C.OW_FOLLOWERS_WANDER_RANGE) or 2))
    local paused=E.Player.moving or E.idleReturning or M.time<(E.idleRecoveryUntil or 0) or M.idle<E.Idle.delay()
    if w and w.range~=range then w.returning=true end
    local enabled=E.Idle.enabled('OW_FOLLOWERS_WANDER',a)
    if w and (not enabled or paused) then w.returning=true end
    if not w then
      if not enabled or paused or a.moving then return end
      w={x=a.cellX,y=a.cellY,range=range,next=M.time+(a.followSlot or 1)*12}
      if E.Spacing then E.Spacing.beginIndependent(a) end
      a.wander=w;a.independent=true;E.Doze.cancel(a)
    end
    if a.moving then return end
    if w.returning then
      if M.returnStep(a,leader) then core.stopIndependent();return end
      return
    end
    if M.time<w.next then return end
    local frames=speeds[E.C.OW_FOLLOWERS_WANDER_SPEED] or 16
    local offset=E.random()%4
    for k=0,3 do
      local dir=dirs[(offset+k)%4+1];local x,y=a.cellX+dx[dir],a.cellY+dy[dir]
      if math.abs(x-w.x)<=range and math.abs(y-w.y)<=range and free(a,x,y,dir) then
        core.independentStep(dir,frames);break
      end
    end
    w.next=M.time+frames*2+30+E.random()%31
  end
  M.free=free;M.directionTo=returnDirection
  return M
end
