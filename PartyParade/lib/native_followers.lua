-- Six independent native follower state machines with optional idle wandering.
return function(E,include,mod)
  E.arrivalBlocked=include('lib/arrival.lua')(E)
  local M={cores={},followers={},order={},selected={},ticks=0}
  local MapOffset=include('lib/map_offset.lua')
  local Terrain=include('lib/terrain.lua')
  E.Spacing=include('lib/spacing.lua')(E,Terrain)
  local Wander=include('lib/wander.lua')(E,Terrain)
  M.Wander=Wander
  local Play=include('lib/play.lua')(E,Wander)
  M.Play=Play;E.Play=Play
  local Social=include('lib/social_idle.lua')(E,Wander);E.Social=Social;M.Social=Social
  local Options=require('src.core.game3.options')
  local savedCount=tonumber(mod.options:get('follower_count')) or 1
  function M.readOptions()
    if E.applySharedSettings then E.applySharedSettings() end
    local s=E.Runtime.getSession()
    local block=s and s.engineOptions and Options.block(s.engineOptions)
    local count=block and block.wildsG3FollowerCount
    M.follower_count=math.max(0,math.min(6,tonumber(count) or savedCount))
    if block then
      for _,key in ipairs({'wildsG3FollowerSpriteSet'}) do
        if block[key]~=nil and block[key]~='g9rp' then block[key]='untamed' end
      end
      E.Idle.normalize(block)
      for _,row in ipairs(E.nativeOptionSchema or {}) do
        if block[row.nativeKey]~=nil and E.C[row.key]~=nil then
          E.C[row.key]=block[row.nativeKey]
        end
      end
    end
    E.Idle.normalize()
    if M.wasEnabled and not E.C.OW_FOLLOWERS_ENABLED and M.reset then M.reset() end
    M.wasEnabled=E.C.OW_FOLLOWERS_ENABLED
  end
  mod.events:on('mod.options_changed',function(ev)
    if ev.mod~=mod.id then return end
    savedCount=tonumber(mod.options:get('follower_count')) or 1
    M.readOptions()
  end)
  local dx={up=0,down=0,left=-1,right=1}
  local dy={up=-1,down=1,left=0,right=0}
  local function staticFree(x,y)
    return E.Collision.inBounds(x,y)
      and not (E.Collision.warpAt and E.Collision.warpAt(x,y))
      and Terrain.followerCellAllowed(E.Player,E.Collision,x,y)
      and not E.Objects.blocks(x,y,nil,E.Player.currentElevation or 3)
  end
  local function leader(a)
    local slot=a.followSlot or a.index
    return slot==1 and E.Player or M.order[slot-1] or E.Player
  end
  local anchors={}
  local function followTarget(a)
    local b=leader(a)
    if b~=E.Player and b.independent and not E.Player.moving and anchors[b] then return anchors[b] end
    return b
  end
  for i=1,6 do
    local a=E.actors[i]
    a.index=i;a.followSlot=i;a.nativeCore=include('follower.lua')
    local proxy=setmetatable({},{__index=function(_,k)return followTarget(a)[k] end})
    local child=setmetatable({FOLLOWER=a,Player=proxy},{__index=E})
    child.party=function()return {M.selected[i]} end
    child.playerCur=function()
      local b=followTarget(a)
      return b.moving and b.targetX or b.cellX,b.moving and b.targetY or b.cellY
    end
    child.playerPrev=function()
      local b=followTarget(a)
      if b==E.Player then return E.playerPrev() end
      return b.cellX,b.cellY
    end
    child.followerVisible=E.followerVisible
    a.nativeCore.init(child);M.cores[i]=a.nativeCore
  end
  M.ANIMS=M.cores[1].ANIMS;M.animFrame=M.cores[1].animFrame;M.A=M.cores[1].A
  function M.update()
    M.readOptions()
    local party=E.party() or {};local selected={}
    if M.follower_count>0 then
      for _,mon in ipairs(party) do
        if (tonumber(mon.hp) or 0)>0 and not E.Pokemon.isEgg(mon)
            and E.Pokemon.speciesOf(mon)~=0 then
          selected[#selected+1]=mon
          if #selected>=M.follower_count then break end
        end
      end
    end
    M.selected=selected;M.followers={};M.order={}
    for i,c in ipairs(M.cores) do
      c.update()
      local a=E.actors[i]
      if a.active then
        M.followers[#M.followers+1]=a;M.order[#M.order+1]=a
        a.followSlot=#M.order
      end
    end
  end
  local function seed(release)
    if E.arrivalBlocked() or not E.followerVisible() then
      local px,py=E.playerCur()
      for _,a in ipairs(M.order)do a.nativeCore.place(px,py,false)end
      M.arrivalPending=true;M.arrivalUseBalls=release or false
      return
    end
    Social.reset();Play.reset()
    anchors={};E.idleReturning=false;E.idleRecoveryUntil=0
    E.Spacing.reset()
    local px,py=E.playerCur();local seen={[px..':'..py]=true};local x,y=px,py
    local p=E.Player
    local function reserve(tx,ty)
      if type(tx)=='number' and type(ty)=='number' then seen[tx..':'..ty]=true end
    end
    reserve(p.cellX,p.cellY);reserve(p.targetX,p.targetY)
    if type(p.px)=='number' and type(p.py)=='number' then
      for ty=math.floor(p.py/16),math.floor((p.py+15)/16) do
        for tx=math.floor(p.px/16),math.floor((p.px+15)/16) do reserve(tx,ty) end
      end
    end
    local back=E.Player.facing or 'down'
    local candidates={{-dx[back],-dy[back]},{-dy[back],dx[back]},
      {dy[back],-dx[back]},{dx[back],dy[back]}}
    for _,a in ipairs(M.order) do
      local placed=false
      for _,d in ipairs(candidates) do
        local tx,ty=x+d[1],y+d[2]
        if not seen[tx..':'..ty] and staticFree(tx,ty) then
          seen[tx..':'..ty]=true;x,y=tx,ty
          a.nativeCore.place(x,y,true)
          if release then a.nativeCore.exitBall() end
          placed=true;break
        end
      end
      if not placed then a.nativeCore.place(px,py,false) end
    end
    for _,a in ipairs(M.order) do E.Spacing.track(a,leader(a)) end
  end
  function M.tick()
    M.ticks=M.ticks+1
    Wander.beginTick()
    if M.arrivalPending then
      -- Entry dialogue can retain the VM lock long after the fade/step ends.
      if E.arrivalBlocked() then return end
      if not E.followerVisible() then return end
      M.arrivalPending=false
      M.update()
      seed(M.arrivalUseBalls)
    end
    if M.ticks%30==0 then M.update() end
    if #M.order==0 then M.update();if #M.order>0 then seed() end end
    if M.arrivalPending then return end
    -- A downstream follower follows its leader's stationary formation anchor
    -- while that leader is doing its own idle activity, not its wandering path.
    for _,a in ipairs(M.order)do
      if not a.independent then
        anchors[a]={cellX=a.cellX,cellY=a.cellY,targetX=a.cellX,targetY=a.cellY,
          px=a.px,py=a.py,facing=a.facing,moving=false,running=false}
      end
    end
    local returning=E.Player.moving or E.Player.jumping
    for _,a in ipairs(M.order)do
      if a.wander and a.wander.returning or a.social and a.social.returning
          or a.play and a.play.returning then returning=true end
    end
    if E.idleReturning and not returning then E.idleRecoveryUntil=Wander.time+180 end
    E.idleReturning=returning
    E.Idle.beginTick(M.order)
    Social.beginTick(M.order)
    Play.beginTick(M.order)
    -- Drain all moving activities together. Otherwise an endless wander ahead
    -- can prevent a returning follower from ever rejoining its leader.
    if E.idleReturning then
      Play.returnToLine()
      for _,a in ipairs(M.order)do
        if a.wander then a.wander.returning=true end
        if a.social then a.social.returning=true end
      end
    end
    for _,a in ipairs(M.order) do
      Social.tick(a,leader(a));Play.tick(a,leader(a));Wander.tick(a,leader(a));a.nativeCore.tick();E.Spacing.track(a,leader(a))
    end
  end
  function M.onMapEntered(ev)
    E.Spacing.reset()
    Social.reset();Play.reset();Wander.reset()
    local from=M.mapId;local to=E.mapId();M.update()
    local doorArrival=M.doorDestination==to and ev and ev.via=='warp'
    M.doorDestination=nil;M.arrivalPending=false
    local Map=E.Map or require('src.core.game3.map');local game=E.Field._game
    local x,y
    if from and from~=to and ev and ev.via=='connection' then
      x,y=MapOffset.offset(from,to,Map.world,game and game.data.maps,Map._worldRoot)
    end
    if x then
      for _,a in ipairs(M.followers) do a.nativeCore.translate(x,y) end
    else
      for _,c in ipairs(M.cores) do c.onMapEntered(ev) end
      M.update()
      -- Every map rebuild stays hidden until the player is visible and settled.
      -- Do not seed a visible formation at the doorway before the entry step.
      M.arrivalPending=true
      M.arrivalUseBalls=doorArrival and E.C.OW_FOLLOWERS_ARRIVAL_BALLS or false
      local px,py=E.playerCur()
      for _,a in ipairs(M.order) do a.nativeCore.place(px,py,false) end
    end
    M.mapId=to
  end
  function M.onStep(ev)M.update();for _,c in ipairs(M.cores) do c.onStep(ev) end end
  function M.reset()
    anchors={};E.idleReturning=false;E.idleRecoveryUntil=0
    E.Spacing.reset()
    Social.reset();Play.reset();Wander.reset()
    for _,a in ipairs(M.followers) do a.nativeCore.stopIndependent() end
    for _,c in ipairs(M.cores) do c.reset() end
    M.followers={};M.order={}
    M.arrivalPending=false;M.doorDestination=nil
  end
  function M.queueDoorArrival(destination)M.doorDestination=destination end
  function M.cancelDoorArrival()M.doorDestination=nil;M.arrivalPending=false end
  function M.enterBall(...)
    Social.reset();Play.reset()
    local started=false
    for _,c in ipairs(M.cores) do if c.enterBall(...) then started=true end end
    return started
  end
  function M.recalling()
    for _,a in ipairs(M.followers) do
      if a.act==a.nativeCore.A.ENTER then return true end
    end
    return false
  end
  function M.face(dir)M.cores[1].face(dir)end
  function M.talking()
    for _,c in ipairs(M.cores) do if c.talking() then return true end end
    return false
  end
  function M.talk(a)return (a or E.FOLLOWER).nativeCore.talk() end
  function M.onBattleStarted(ev)
    Social.reset();Play.reset();Wander.reset()
    for _,c in ipairs(M.cores) do c.stopIndependent();c.onBattleStarted(ev) end
  end
  function M.onBattleEnded(ev)
    M.update();for _,c in ipairs(M.cores) do c.onBattleEnded(ev) end
  end
  function M.appearNow()for _,c in ipairs(M.cores) do c.appearNow() end end
  M.seed=seed
  M.readOptions()
  return M
end
