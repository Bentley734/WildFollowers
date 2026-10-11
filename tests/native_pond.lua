-- Actual imported Route 22 geometry, fishing data and the live 1025Dex GB API.
return function(mod,values,world,player,data,owner,dex,root,dexRoot,version,tick,check,eq)
  local function read(path)local f=assert(io.open(path,'rb'));local s=f:read('*a');f:close();return s end
  local function imported(name)return assert(load(read(os.getenv('APPDATA')..'/pokemon-love2d/'..version..'/data/generated/'..name..'.lua')))()end
  local oldMap,oldMaps,oldSets,oldField,oldEncounters=world.map,data.maps,data.tilesets,data.field,data.encounters
  local oldX,oldY,oldPx,oldPy=player.cellX,player.cellY,player.px,player.py
  local oldProvider=dex.exports.chooseGBWildEncounter
  mod.exports.clearAll()
  data.maps,data.tilesets,data.field,data.encounters=imported('maps'),imported('tilesets'),imported('field'),imported('encounters')
  local def=data.maps.ROUTE_22
  world.map=require('src.world.Map').new(def,data.tilesets[def.tileset])
  local pond=world.map;local waterCount=0
  for y=0,pond.heightCells-1 do for x=0,pond.widthCells-1 do
    if pond:isWaterCell(x,y) then waterCount=waterCount+1 end
  end end
  check(waterCount>0,'actual Route 22 geometry contains a pond')
  eq(data.encounters.ROUTE_22.water,nil,'actual Route 22 has no surfing encounters')
  check(data.field.superRod.ROUTE_22[1]~=nil,'actual Route 22 has a native fishing group')
  local peer={game=mod.game,exports={},options={get=function()return '17'end,define=function()end},
    read=function(_,path)return read(dexRoot..'/encounters/'..path)end,
    rootRead=function(_,path)return read(dexRoot..'/'..path)end,
    hooks={wrap=function()end},log={info=function()end}}
  assert(load(read(dexRoot..'/encounters/gb.lua')))()(peer)
  dex.exports.chooseGBWildEncounter=peer.exports.chooseGBWildEncounter
  values.OW_FOLLOWERS_ENABLED=false;values.WE_OW_ENCOUNTERS=true;values.WE_OW_WATER=true
  values.spawn_density='low';values.spawn_range='very_wide'
  -- Position from the reported Route 22 save, with the small pond in range.
  player.cellX,player.cellY,player.px,player.py=37,10,37*16,10*16
  player.moving=false;player.targetX=nil;player.targetY=nil
  local appeared=0
  for seed=1,20 do
    math.randomseed(seed);mod.exports.clearAll();tick(180)
    local count=0
    for _,e in ipairs(owner.wilds)do
      if e.surface=='water' and e.sourceMap=='ROUTE_22' then
        count=count+1;check(pond:isWaterCell(e.cellX,e.cellY),'published pond actor stands on real water')
        local native=false
        for _,row in ipairs(data.field.superRod.ROUTE_22)do if row.species==e.species then native=true end end
        if not native then
          local aquatic={}
          for _,row in ipairs(peer.exports.gbEncounterAdditions('ROUTE_22','water'))do aquatic[row.name or row.species]=true end
          check(aquatic[e.species],'pond additions come from actual 1025Dex aquatic pool')
        end
        check(e.species~='NIDORAN_M' and e.species~='NIDORAN_F','pond cannot spawn Nidoran')
        local draws=0;local G=love.graphics;local oldDraw=G.draw
        G.draw=function()draws=draws+1 end;e:draw(0,0,1);G.draw=oldDraw
        check(draws>0,'actual Route 22 water actor draws')
      end
    end
    if count>0 then appeared=appeared+1 end
  end
  eq(appeared,20,'small Route 22 pond consistently receives a water wild at low density')
  print(('Route 22 %s: pond cells=%d, seeds with water wilds=%d/20'):format(version,waterCount,appeared))
  values.WE_OW_WATER=false;mod.exports.clearAll();tick(180)
  for _,e in ipairs(owner.wilds)do check(e.surface~='water','water toggle suppresses fishing-based pond wilds')end
  values.WE_OW_WATER=true
  local originalEntities=world.entities;world.entities={player}
  for y=0,pond.heightCells-1 do for x=0,pond.widthCells-1 do
    if pond:isWaterCell(x,y) then world.entities[#world.entities+1]={cellX=x,cellY=y} end
  end end
  mod.exports.clearAll();tick(180)
  local land=0
  for _,e in ipairs(owner.wilds)do
    if e.sourceMap=='ROUTE_22' then check(e.surface~='water','occupied pond rejects aquatic spawn');land=land+1 end
  end
  check(land>0,'occupied pond does not starve land spawning')
  world.entities=originalEntities
  mod.exports.clearAll()
  world.map,data.maps,data.tilesets,data.field,data.encounters=oldMap,oldMaps,oldSets,oldField,oldEncounters
  player.cellX,player.cellY,player.px,player.py=oldX,oldY,oldPx,oldPy
  dex.exports.chooseGBWildEncounter=oldProvider
end
