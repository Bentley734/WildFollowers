-- Recall on both building directions; keep exit recalls visible before fading.
return function(E,Follower)
  local M={}
  local Warp,Field=E.Warp,E.Field
  if not Warp then function M.tick()end;return M end
  local pending
  local LOCK='wildfollowers-door'
  local unpack=table.unpack or unpack

  if Warp.startDoorEntrance then
    local raw=Warp.startDoorEntrance
    Warp.startDoorEntrance=function(mod,game,destination,...)
      Follower.readOptions()
      if not Warp._busy and E.C.OW_FOLLOWERS_ENABLED then
        Follower.queueDoorArrival(destination)
        -- Untamed's entrance wrapper already recalls the shared controller.
      end
      return raw(mod,game,destination,...)
    end
  end

  if Warp.startDoorExit then
    local raw=Warp.startDoorExit
    Warp.startDoorExit=function(...)
      Follower.readOptions()
      if Warp._busy or not E.C.OW_FOLLOWERS_ENABLED then return raw(...) end
      local args={n=select('#',...),...}
      Follower.queueDoorArrival(args[3])
      if not Follower.enterBall() then return raw(...) end
      pending={args=args,raw=raw,frames=0,map=E.mapId(),
        session=E.Runtime.getSession(),ownsLock=not Field.locked}
      -- Reserve the engine gate immediately so held direction/repeated calls
      -- cannot queue a second exit while the 17-frame native recall finishes.
      Warp._busy=true
      if Field.lock then Field.lock(LOCK) end
      return true
    end
  end

  function M.tick()
    local p=pending
    if not p then return end
    if not Warp._busy or p.map~=E.mapId() or p.session~=E.Runtime.getSession() then
      pending=nil;Follower.cancelDoorArrival()
      Warp._busy=false
      if Field.unlock then Field.unlock(LOCK) end
      return
    end
    p.frames=p.frames+1
    if Follower.recalling() and p.frames<20 then return end
    pending=nil
    Warp._busy=false
    local ok,result=pcall(p.raw,unpack(p.args,1,p.args.n))
    if Field.unlock then Field.unlock(LOCK) end
    if not ok or result==false then
      Follower.cancelDoorArrival()
      if p.ownsLock and not Warp._busy and Warp.releaseField then Warp.releaseField(Field) end
      if not ok then error(result,0) end
    end
  end

  if Warp.clear then
    local raw=Warp.clear
    Warp.clear=function(...)
      local p=pending
      pending=nil;Follower.cancelDoorArrival()
      local result=raw(...)
      if p and Field.unlock then Field.unlock(LOCK) end
      return result
    end
  end
  return M
end
