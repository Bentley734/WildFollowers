-- Exercise the supplied renderers' actual SpriteBillboards and VoxelScene code.
-- GPU calls record geometry; this does not claim an interactive visual test.
return function(mod,events,actor,values,gen,root,check,eq)
  local sprite=actor:pose()
  check(sprite and sprite.def and sprite:resolveImage(),'native pose supplies an actual sprite')
  if gen>2 then return end -- Terrarium also supplies a Gen 2 bridge
  local function read(path) local f=assert(io.open(path,'rb'));local s=f:read('*a');f:close();return s end
  local peers={
    TERRARIUM=root..'/../.work/voxel-reference/TERRARIUM-1.30.1/TERRARIUM',
  }
  if gen==1 then peers.BATTLE_ART_VOXEL_FORK=root..'/../.work/voxel-reference/BATTLE_ART_VOXEL_FORK-1.11.1' end
  local oldFind=mod.find
  function mod:find(id)
    if peers[id] and self.game.mods.exports[id] then return {exports=self.game.mods.exports[id]} end
    return oldFind and oldFind(self,id)
  end
  local original={}
  local scenes={}
  local draws=0
  for id,path in pairs(peers) do
    local gpu={}
    function gpu.pushQuad(indices) for _,v in ipairs({1,2,3,1,3,4}) do indices[#indices+1]=v end end
    function gpu.newMesh(vertices,indices)
      return {vertices=vertices,indices=indices,release=function(m)m.released=true end}
    end
    function gpu.draw(mesh,tex) check(mesh and not mesh.released and tex,'voxel GPU receives a live mesh and texture');draws=draws+1 end
    function gpu.casterMatrix()return {}end
    local modules={Voxel3D=gpu,VoxelState={angle=1},ShadowMap={snug=function(m)return m end},
      FirstPerson={cardBlend=function()return 0 end},MarioCam={relativeFacing=function(f)return f end},
      TileShape={forMap=function()return {}end,at=function()return nil end},
      SafariAccess={support=function()return nil end},GameCorner={support=function()return nil end},
      Wind={leanAt=function()return 0,0,0 end}}
    local lib={}
    function lib.require(name)
      if modules[name] then return modules[name] end
      if name=='SpriteBillboards' or name=='Mat4' or name=='VoxelScene' then
        local source=read(path..'/lib/'..name..'.lua')
        if name=='VoxelScene' then source=source:gsub('return VoxelScene%s*$','VoxelScene._testPoses=posesOf;return VoxelScene') end
        modules[name]=assert(load(source,'@'..id..'/'..name))(lib)
      else modules[name]={} end
      return modules[name]
    end
    local cards=lib.require('SpriteBillboards')
    original[id]={cards=cards,mesh=cards.mesh,shadow=cards.shadowQuad}
    mod.game.mods.exports[id]={lib=lib}
    scenes[id]=lib.require('VoxelScene')
  end
  events['mods.loaded']()
  for id,scene in pairs(scenes) do
    local cards=original[id].cards
    local wrapped=cards.mesh;events['mods.loaded']();eq(cards.mesh,wrapped,'mods.loaded is idempotent')
    for _,set in ipairs({'g9','ee'}) do
      values.wild_sprites,values.follower_sprites=set,set
      for _,follower in ipairs({false,true}) do
        actor.follower=follower;actor.hidden=false;actor.ballPhase=nil;actor.idlePose=nil;actor.surface='land'
        for _,facing in ipairs({'down','left','right','up'}) do
          actor.facing=facing;actor.moving=true;actor.spacingPaused=false
          for frame=0,3 do
            actor.clock=frame/8;actor.progress=(frame==0 and .76 or (frame-1)/4)
            local s,x,y,d,p,f=actor:pose()
            check(scene.drawEntity(s,x,y,d,p,f,0,nil,0,0),'actual '..id..' entity renderer remains in voxel mode')
            local mesh=cards.mesh(s.def,0)
            eq(cards.shadowQuad(s.def,0),mesh,'solid and shadow passes share geometry')
            eq(cards.mesh(s.def,0),mesh,'unchanged pose reuses mesh')
            local art=s.def._wildFollowers
            eq(art.frame,frame,'all four native walk frames reach voxel pipeline')
            local v=mesh.vertices
            eq(v[2][1]-v[1][1],s.frameWidth,'larger sprite is not clipped to a native 16px card')
            eq(v[1][2],-4,'native GB foot anchor retained')
            check(v[1][4]>=0 and v[2][4]<=1 and v[1][5]<=1 and v[3][5]>=0,'sprite UV stays within the sheet')
          end
        end
        actor.moving=false;actor.idlePose={facing='left',frame=2,jumping=true,hop=-10,sx=1.1,sy=.9}
        local s=actor:pose();local mesh=cards.mesh(s.def,0)
        eq(s.def._wildFollowers.jump,-10,'idle jump reaches voxel pose')
        eq(mesh.vertices[1][2],6,'voxel body rises with idle jump')
        actor.idlePose=nil;actor.follower=false;actor.surface='water'
        for crop=0,3 do
          values.water_sprite_crop=crop
          local s=actor:pose();local mesh=cards.mesh(s.def,0)
          check(mesh~=nil,'water crop leaves a visible voxel body')
          if crop>0 then check(s.def._wildFollowers.retained<s.record.h,'selected crop is applied to voxel art') end
        end
        actor.ballPhase='recall';actor.ballTime=.29
        local s=actor:pose();eq(cards.mesh(s.def,0),nil,'fully recalled body disappears in voxel mode')
        actor.ballPhase='release';actor.ballTime=.29
        local s,x,y,d,p,f=actor:pose()
        check(scene.drawEntity(s,x,y,d,p,f,0,nil,0,0),'door release restores the voxel body')
      end
    end
    -- Vanilla definitions continue through the supplied renderer unchanged.
    local def={id='NPC',image=actor:pose().def.image,frames=1}
    eq(cards.mesh(def,0),original[id].mesh(def,0),'ordinary NPC billboard delegates unchanged')
  end
  check(draws>(gen==1 and 128 or 64),'supported voxel renderers exercised across animation frames')
  actor.follower=false;actor.surface='land';actor.ballPhase=nil;actor.idlePose=nil;actor.moving=false
  values.wild_sprites='g9';values.follower_sprites='g9';values.water_sprite_crop=0
  -- Keep integrations installed to cover subsequent warp/story fixtures;
  -- controller disposal at the end must restore their original methods.
  local function disposed()
    for _,entry in pairs(original) do
      eq(entry.cards.mesh,entry.mesh,'dispose restores peer mesh API')
      eq(entry.cards.shadowQuad,entry.shadow,'dispose restores peer shadow API')
    end
  end
  local function tick()
    local world=mod.world:overworld()
    local entities={}
    for _,e in ipairs(world.entities or {}) do if e._wildFollowersRewrite then entities[#entities+1]=e end end
    local terrain=setmetatable({cellTile=function()return 0 end,tileAt=function()return 0 end},{__index=world.map})
    for id,scene in pairs(scenes) do
      local posed=scene._testPoses({map=terrain,entities=entities},function()return nil end)
      eq(#posed,#entities,'actual '..id..' pose assembly accepts current transition population')
      for _,p in ipairs(posed) do
        check(p.sprite and p.sprite.def,'no nil sprite during transitions, warps or story recall')
        -- A completely recalled body correctly returns false, without throwing.
        scene.drawEntity(p.sprite,p.px,p.py,p.facing,p.phase,p.flip,p.gh,p.colors,p.lift,p.waterline or p.visualAnchorY)
      end
    end
  end
  return disposed,tick
end
