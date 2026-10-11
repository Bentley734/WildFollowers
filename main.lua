-- New runtime. No legacy follower or overworld-spawner implementation is loaded.
return function(mod)
  local modules={}
  local function include(name)
    if not modules[name] then
      modules[name]=assert(load(assert(mod:read('src/'..name..'.lua')), '@wildfollowers/'..name))()(mod,include)
    end
    return modules[name]
  end
  local schema=assert(load(assert(mod:read('options.lua'))))()
  mod.options:define(schema)
  local controller=include('controller')
  include('menu'):install(controller,schema)
  mod.exports.version='3.3.9'
  mod.exports.numbering='national'
  mod.exports.supportedGames={'red','blue','yellow','gold','silver','crystal','ruby','sapphire','firered','leafgreen','emerald'}
  mod.exports.status=function() return controller:status() end
  mod.exports.clearAll=function() controller:clear() end
  mod.exports.dispose=function() controller:dispose() end
  include('voxel'):install()
  mod.events:on('mods.loaded',function() include('voxel'):install() end)
  mod.hooks:wrap('input.step',function(next_,game,dt)
    controller:tick(game,dt or 1/60)
    return next_(game,dt)
  end)
  -- Suppress only ordinary step battles, only with a working visible provider.
  mod.hooks:wrap('encounter.roll',function(next_,tables,ctx)
    local hit=next_(tables,ctx)
    if hit and not (hit.roamer or hit.roaming or hit.wildScripted) and controller:canReplace(ctx) then return nil end
    return hit
  end,1000)
  mod.hooks:wrap('movement.collision',function(next_,allowed,ctx)
    return controller:collision(next_,allowed,ctx)
  end,1000)
  mod.events:on('map.entered',function(ev) controller:mapEntered(ev) end)
  for _,event in ipairs({'save.loading','save.loaded'}) do
    mod.events:on(event,function() controller:saveLoading() end)
  end
  mod.events:on('map.reloaded',function() controller:mapReloaded() end)
  mod.events:on('battle.started',function() controller:battleStarted() end)
  mod.events:on('battle.ended',function() controller:battleEnded() end)
  mod.events:on('mod.options_changed',function(ev)
    if not ev or ev.mod=='1025dex' or ev.mod=='kanto_hoenn'
        or ev.mod==mod.id and mod.options:get('enabled')==false then controller:clear() end
  end)
  mod.log:info('WildFollowers 3 rewrite loaded; National identity, native cartridge battles.')
end
