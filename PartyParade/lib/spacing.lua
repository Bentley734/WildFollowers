-- Pixel gaps are sampled along each native follower's travelled path. Tile
-- movement/collision stays native; a persistent draw view supplies positioning,
-- sorting and terrain cover at the visible position rather than cutting corners.
return function(E,Terrain)
  local M={}
  local states={}
  local floor,abs=math.floor,math.abs
  local function setting(key)
    return math.max(1,math.min(7,floor(tonumber(E.C[key]) or 1)))
  end
  local function distance(a)
    return setting('follower_trainer_spacing')+((a.followSlot or 1)-1)*setting('follower_spacing')
  end
  local function free(x,y)
    return E.Collision.inBounds(x,y)
      and not (E.Collision.warpAt and E.Collision.warpAt(x,y))
      and Terrain.followerCellAllowed(E.Player,E.Collision,x,y)
      and not E.Objects.blocks(x,y,nil,E.Player.currentElevation or 3)
  end
  local function legal(px,py)
    -- The native actor's ground footprint is one 16px tile. Check both sides
    -- while crossing a boundary; never extend an initial gap into a wall.
    for y=floor(py/16),floor((py+15)/16) do
      for x=floor(px/16),floor((px+15)/16) do
        if not free(x,y) then return false end
      end
    end
    return true
  end
  local function fresh(a,leader)
    local x,y=a.px,a.py
    local points={{x,y}}
    -- Seed a straight legal continuation of the initial formation. Narrow
    -- entrances may temporarily have less space until a longer trail exists.
    if leader and not a.independent and not a.invisible then
      local dx,dy=x-leader.px,y-leader.py
      if abs(dx)>abs(dy) then dx=dx<0 and -1 or 1;dy=0
      elseif dy~=0 then dy=dy<0 and -1 or 1;dx=0
      else dx,dy=0,0 end
      if dx~=0 or dy~=0 then
        for n=1,64 do
          local px,py=x+dx*n,y+dy*n
          if not legal(px,py) then break end
          points[#points+1]={px,py}
        end
      end
    end
    local view=setmetatable({}, {__index=a,__newindex=function(_,k,v)a[k]=v end})
    rawset(view,'nativeActor',a)
    rawset(view,'graphicsId',view)
    local s={points=points,lastX=x,lastY=y,view=view}
    states[a]=s
    return s
  end
  function M.reset()states={} end
  function M.beginIndependent(a)
    local v=M.view(a);local s=states[a] or fresh(a)
    s.idleOffset={v.px-a.px,v.py-a.py}
  end
  function M.allowedAt(a,x,y)
    local s=states[a.nativeActor or a];local off=s and s.idleOffset
    return not off or legal(x*16+off[1],y*16+off[2])
  end
  function M.blocksIdleStep(a,x,y)
    local owner=a.nativeActor or a
    local s=states[owner];local off=s and s.idleOffset
    local v=M.view(owner)
    local ox,oy=off and off[1] or v.px-owner.px,off and off[2] or v.py-owner.py
    -- Use the probe's source cell during route searches, not the real actor's
    -- position. Reserve the whole visible ground footprint along each step.
    local sx,sy=a.cellX*16+ox,a.cellY*16+oy
    local tx,ty=x*16+ox,y*16+oy
    local left,top=math.min(sx,tx),math.min(sy,ty)
    local right,bottom=math.max(sx,tx)+16,math.max(sy,ty)+16
    local function overlaps(l,t,r,b,px,py,qx,qy)
      return l<math.max(px,qx)+16 and r>math.min(px,qx)
        and t<math.max(py,qy)+16 and b>math.min(py,qy)
    end
    for _,other in ipairs(E.Follower and E.Follower.order or {}) do
      if other~=owner and other.active and not other.invisible then
        local ov=M.view(other);local px,py=ov.px,ov.py
        local qx,qy=px,py
        if other.moving then
          -- Independent walks retain their spacing offset. Native walks may
          -- turn along their trail, so conservatively reserve the remaining
          -- displacement as well as the current visible footprint.
          qx=px+(other.targetX or other.cellX)*16-other.px
          qy=py+(other.targetY or other.cellY)*16-other.py
        end
        if overlaps(left,top,right,bottom,px,py,qx,qy) then
          -- A formation can already overlap after a cramped entrance. Permit
          -- only a separating step, never crossing through the other actor.
          local escaping=not other.moving
            and overlaps(sx,sy,sx+16,sy+16,px,py,px,py)
            and not overlaps(tx,ty,tx+16,ty+16,px,py,px,py)
            and (tx-sx)*(sx-px)+(ty-sy)*(sy-py)>=0
          if not escaping then return true end
        end
      end
    end
    return false
  end
  function M.track(a,leader)
    if not a.nativeCore or not a.active then states[a]=nil;return end
    local s=states[a]
    local delta=s and abs(a.px-s.lastX)+abs(a.py-s.lastY) or 0
    if a.independent and not a.invisible and s and s.idleOffset then
      s.lastX,s.lastY=a.px,a.py;return
    end
    if s and s.idleOffset and not a.independent then
      fresh(a,leader);return
    end
    -- Native jumps/teleports, independent wandering and hidden arrivals do
    -- not invent a walkable route through the skipped tiles.
    if not s or delta>8 or a.independent or a.invisible
        or a.act==a.nativeCore.A.JUMP then
      fresh(a,not a.independent and leader or nil);return
    end
    if delta>0 then
      table.insert(s.points,1,{a.px,a.py})
      while #s.points>96 do table.remove(s.points) end
      s.lastX,s.lastY=a.px,a.py
    end
  end
  function M.view(a)
    if not a.nativeCore or not a.active or a.invisible
        or a.act==a.nativeCore.A.JUMP then return a end
    local s=states[a]
    if not s then return a end
    -- Event-driven placement can happen between simulation ticks. Refresh
    -- before rendering so it never draws a stale location after placement.
    if a.px~=s.lastX or a.py~=s.lastY then
      M.track(a);s=states[a]
    end
    if a.independent then
      local off=s.idleOffset
      if not off then return a end
      local v=s.view;local x,y=a.px+off[1],a.py+off[2]
      rawset(v,'px',x);rawset(v,'py',y)
      rawset(v,'cellX',floor((x+8)/16));rawset(v,'cellY',floor((y+8)/16))
      rawset(v,'targetX',floor(((a.targetX or a.cellX)*16+off[1]+8)/16))
      rawset(v,'targetY',floor(((a.targetY or a.cellY)*16+off[2]+8)/16))
      rawset(v,'facing',a.facing);rawset(v,'anim',a.anim)
      return v
    end
    local remain=distance(a)
    local points=s.points
    local x,y=points[1][1],points[1][2]
    local facing=a.facing
    for i=2,#points do
      local p=points[i];local dx,dy=p[1]-x,p[2]-y
      local length=abs(dx)+abs(dy)
      if length>0 then
        local fraction=math.min(remain,length)/length
        facing=abs(dx)>abs(dy) and (dx>0 and 'left' or 'right') or (dy>0 and 'up' or 'down')
        x,y=x+dx*fraction,y+dy*fraction
        remain=remain-length
        if remain<=0 then break end
      end
    end
    x,y=floor(x+.5),floor(y+.5)
    local v=s.view
    rawset(v,'px',x);rawset(v,'py',y)
    local cx,cy=floor((x+8)/16),floor((y+8)/16)
    rawset(v,'cellX',cx);rawset(v,'cellY',cy)
    rawset(v,'targetX',cx);rawset(v,'targetY',cy)
    rawset(v,'facing',a.moving and facing or a.facing)
    rawset(v,'anim',a.anim)
    if a.moving and a.act==a.nativeCore.A.WALK and not a.ballGfx and not a.affine then
      local anims=a.nativeCore.ANIMS[a.asym==true]
      rawset(v,'anim',(a.actDur<=8 and anims.goFast or anims.go)[facing])
    end
    return v
  end
  function M.at(x,y)
    for _,a in ipairs(E.Follower and E.Follower.order or {}) do
      if a.active and not a.invisible then
        local v=M.view(a)
        if v.cellX==x and v.cellY==y then return a end
      end
    end
  end
  M.distance=distance
  return M
end
