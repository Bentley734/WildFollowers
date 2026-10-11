-- Native entity poses also feed third-party 3D pipelines. Keep the same art,
-- four-direction walk frame and ground anchor as our 2D compositor.
return function(mod,include)
  local S,J=include('sprites'),include('jumps')
  local rows={down=0,left=1,right=2,up=3}
  local bridge={wrappers={},disposed=false}
  function bridge:pose(actor)
    local r=S:get(actor.national,actor)
    -- Actors are only published after their artwork has loaded successfully.
    assert(r,'WildFollowers actor artwork unavailable')
    local sprite=actor._wfSprite
    if not sprite then
      sprite={def={id='WILDFOLLOWERS',frames=1,trueColor=true}}
      function sprite:resolveImage() return self.record.image end
      actor._wfSprite=sprite
    end
    local pose=actor.idlePose
    local facing=pose and pose.facing or actor.facing or 'down'
    local march=mod.options:get(actor.follower and 'followers_march' or 'wilds_march')==true
    local frame=((actor.moving and not actor.spacingPaused) or march) and math.floor((actor.clock or 0)*8)%4 or (pose and pose.frame or 0)
    if not actor.follower and actor.moving and not actor.spacingPaused and actor.progress~=nil then
      frame=(1+math.floor(math.max(0,math.min(1,actor.progress))*4))%4
    end
    local size=r.ee and 1 or 32/r.w
    local water=actor.surface=='water' and not actor.follower
    local crop=water and math.max(0,math.min(3,math.floor(tonumber(mod.options:get('water_sprite_crop')) or 0))) or 0
    local bottom=water and r.bottoms and r.bottoms[(rows[facing] or 0)+1][frame+1] or r.h
    local retained=crop>0 and math.max(0,bottom-crop/size) or r.h
    local sx,sy=1,1
    if pose and (not actor.moving or actor.spacingPaused) then sx,sy=pose.sx or 1,pose.sy or 1 end
    if actor.ballPhase then
      local t=math.min(1,(actor.ballTime or 0)/.30)
      if actor.ballPhase=='release' then t=1-t end
      sx= t>=.72 and 0 or math.max(.01,1-t/.72);sy=sx
    end
    local def=sprite.def
    sprite.record=r
    def.image=mod.path..'/'..r.path
    def._wildFollowers={record=r,frame=frame,row=rows[facing] or 0,size=size,
      retained=retained,sx=sx,sy=sy,jump=J:pose(actor)}
    -- SpriteRenderer-compatible metadata; our own 2D draw remains in charge.
    sprite.frameWidth=r.w*size;sprite.frameHeight=r.h*size
    sprite.anchorX=sprite.frameWidth/2;sprite.anchorY=sprite.frameHeight
    def.frameWidth,def.frameHeight=sprite.frameWidth,sprite.frameHeight
    def.anchorX,def.anchorY=sprite.anchorX,sprite.anchorY
    return sprite,actor.px,actor.py,facing,0,false,false
  end
  function bridge:install()
    if self.disposed then return end
    local exports=mod.game.mods and mod.game.mods.exports or {}
    for _,id in ipairs({'BATTLE_ART_VOXEL_FORK','TERRARIUM'}) do
      local found=mod.find and mod:find(id)
      local peer=mod.find and found and found.exports or not mod.find and exports[id]
      local lib=peer and peer.lib
      if lib and type(lib.require)=='function' then
        local cards=lib.require('SpriteBillboards')
        local already=false
        for _,entry in ipairs(self.wrappers) do if entry.cards==cards then already=true end end
        if not already then
          local gpu=lib.require('Voxel3D')
          local cache=setmetatable({},{__mode='k'})
          local function custom(def)
            local d=def._wildFollowers
            local r=d.record
            local key=table.concat({d.frame,d.row,d.size,d.retained,d.sx,d.sy,d.jump},':')
            local held=cache[def]
            if held and held.key==key then return held.mesh end
            if held and held.mesh and held.mesh.release then held.mesh:release() end
            local mesh
            if d.sx~=0 and d.retained>0 then
              local iw,ih=r.image:getDimensions()
              local fx,fy=d.frame*r.w,d.row*r.h
              local u0,u1=(fx+.02)/iw,(fx+r.w-.02)/iw
              local v0,v1=(fy+.05)/ih,(fy+d.retained-.05)/ih
              local x0,x1=8-r.w*d.size*d.sx/2,8+r.w*d.size*d.sx/2
              -- Native voxel cards pivot at py+8; GB bodies end at py+12.
              local y0=(r.h-d.retained)*d.size*d.sy-4-d.jump
              local y1=r.h*d.size*d.sy-4-d.jump
              local vertices={{x0,y0,0,u0,v1,1},{x1,y0,0,u1,v1,1},
                {x1,y1,0,u1,v0,1},{x0,y1,0,u0,v0,1}}
              local indices={};gpu.pushQuad(indices,0);mesh=gpu.newMesh(vertices,indices)
            end
            cache[def]={key=key,mesh=mesh}
            return mesh
          end
          local oldMesh,oldShadow=cards.mesh,cards.shadowQuad
          local function wrap(old)
            return function(def,...)
              if not bridge.disposed and def and def._wildFollowers then return custom(def) end
              return old(def,...)
            end
          end
          local mesh,shadow=wrap(oldMesh),wrap(oldShadow)
          cards.mesh,cards.shadowQuad=mesh,shadow
          self.wrappers[#self.wrappers+1]={cards=cards,oldMesh=oldMesh,oldShadow=oldShadow,
            mesh=mesh,shadow=shadow,cache=cache}
        end
      end
    end
  end
  function bridge:dispose()
    self.disposed=true
    for _,entry in ipairs(self.wrappers) do
      if entry.cards.mesh==entry.mesh then entry.cards.mesh=entry.oldMesh end
      if entry.cards.shadowQuad==entry.shadow then entry.cards.shadowQuad=entry.oldShadow end
      for _,held in pairs(entry.cache) do if held.mesh and held.mesh.release then held.mesh:release() end end
    end
    self.wrappers={}
  end
  return bridge
end
