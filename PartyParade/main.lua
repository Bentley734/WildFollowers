-- Party Parade extends the running Untamed Advanced engine, never its wilds.
return function(mod)
  if mod.generation~=3 then return end
  local function include(path)
    return assert(load(assert(mod:read(path),'Missing '..path),'@'..mod.path..'/'..path))()
  end
  local dependency=mod:find('untamed_advanced')
  local base=dependency and dependency.exports and dependency.exports.engine
  assert(base and base.Follower and base.FOLLOWER and base.actors,
    'Party Parade requires enabled Untamed Advanced 1.0.0-beta.7 or a compatible engine export.')
  assert(not base.partyParade,'Party Parade is already installed in this session.')
  local facade=base.Follower -- dependency callbacks retain this table by identity
  facade.reset()
  local E=include('adapter.lua')(base,mod,include)
  local schema,flags=include('schema.lua')(E,mod,include)
  local function readOptions()
    for _,row in ipairs(schema)do
      local value=mod.options:get(row.key)
      if value==nil then value=row.default end
      E.C[row.key]=value
    end
    for _,flag in ipairs(flags)do
      if not flag[3] then E.C[flag[1]]=flag[2] end
    end
    E.C.OW_FOLLOWERS_ENABLED=E.C.OW_FOLLOWERS_ENABLED and base.C.OW_FOLLOWERS_ENABLED
  end
  readOptions()
  E.Idle=include('lib/idle.lua')(E,include('lib/sprite_heads.lua'))
  E.Doze=include('lib/doze.lua')(E,include('lib/sprite_heads.lua'))
  E.SpriteSets=include('lib/sprite_sets.lua')(E,mod,include('lib/sprite_sets_data.lua'))
  E.Flowers=include('lib/flowers.lua')(E)
  local controller=include('lib/native_followers.lua')(E,include,mod)
  E.Follower=controller
  for key in pairs(facade)do facade[key]=nil end
  setmetatable(facade,{__index=controller})
  local nativeTick=controller.tick
  local doors=include('lib/door_transitions.lua')(E,controller)
  local serviced=false
  facade.tick=function()
    serviced=true
    readOptions();doors.tick()
    if E.C.OW_FOLLOWERS_ENABLED then nativeTick();E.tickExtraGrass() else controller.reset() end
  end
  -- UA owns the normal field tick. Only fill menu frames it did not service.
  include('lib/live_field.lua')(E,function()
    if not serviced and E.C.OW_FOLLOWERS_ENABLED then facade.tick() end
    serviced=false
  end)
  E.onSettingsChanged=function()
    readOptions();controller.readOptions();controller.update()
    if not E.C.OW_FOLLOWERS_ENABLED then controller.reset() end
  end
  include('lib/native_menu.lua')(E,mod,schema)
  include('lib/shared_options.lua')(E,mod,schema)
  include('lib/session_options.lua')(function()return E.Runtime.getSession()end)
  include('presentation.lua')(E,base,controller)
  mod.events:on('mod.options_changed',function(ev)
    if ev.mod==mod.id then
      local s=E.Runtime.getSession()
      for _,row in ipairs(schema)do
        if row.key==ev.key and s and s.options then s.options[row.nativeKey]=mod.options:get(row.key) end
      end
      E.captureSharedSettings()
      E.onSettingsChanged()
    elseif ev.mod=='untamed_advanced' then E.onSettingsChanged() end
  end,1000)
  -- A mod enabled on an already-loaded field still uses the safe arrival gate.
  if E.Runtime.getSession() and E.Field.running then controller.onMapEntered({via='load'}) end
  base.partyParade=E
  mod.exports.engine=E
  mod.exports.version='3.0.0'
  mod.exports.followerAddon=true
end
