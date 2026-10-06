-- Load the supplied UA entry and add-on in the real mod sandbox.
local engineRoot,uaRoot,addonRoot=arg[1],arg[2],arg[3]
package.path=engineRoot..'/?.lua;'..package.path
local Sandbox=require('src.mods.Sandbox')
local session={version='firered',options={},party={},map='FR_PALLET_TOWN',flags={},vars={}}
for i=1,6 do session.party[i]={species=i,hp=20,personality=0,friendship=200}end
local callbacks={};local schemas={};local mods={};local checks=0
local function eq(a,b,why)checks=checks+1;assert(a==b,why..': '..tostring(a)..' ~= '..tostring(b))end
local function noop()end
local function no()return false end
local function zero()return 0 end
local player={cellX=10,cellY=10,targetX=10,targetY=10,px=160,py=160,
 facing='down',visible=true,currentElevation=3,isVisible=function()return player.visible end}
player.isVisible=function()return player.visible end
local map={id='FR_PALLET_TOWN',world={},_mapId='FR_PALLET_TOWN'}
local menuOpen=false;local runtimeRunsField=false
local runtime={active=true,getSession=function()return session end,uiBusy=no,
 update=function(dt)if runtimeRunsField then modulesField.update(dt)end end}
local field={running=true,locked=false,_game={session=session,options={firered=session.options},data={maps={}}},update=noop,interact=function()return 'native'end}
field.interact=function()return 'native'end
local objects={forDraw=function()return {}end,at=function()end,blocks=no,playerBlocks=no,elevationsCompatible=function()return true end,_byId={}}
local collision={_mapDef={mapType=1},canEnter=function()return true end,behavior=zero,isSurfable=no,ledgeLanding=function()end,
 nextElevation=function()return 3 end,inBounds=function(x,y)return x>=0 and y>=0 and x<40 and y<40 end,
 elevationAt=function()return 3 end,isWalkable=function()return true end,isWater=no,isGrass=no,warpAt=no}
local pokemon={speciesOf=function(m)return m.species end,national=function(id)return id end,isEgg=no,isShiny=no,unownLetter=zero,
 friendship=function(m)return m.friendship end,typesOf=function()return {0}end,abilityId=zero,knowsMove=no,
 displayName=function(m)return 'MON'..m.species end,keyName=function(id)return 'SPECIES_'..id end}
local nativeRows={GROUPS={},ORDER={},build=function()return {}end,group=function(r)return r end}
local engineOptions={firered=session.options}
session.engineOptions=engineOptions
modulesField=field
local options={block=function(o,id)id=id or 'firered';o[id]=o[id]or{};return o[id]end,
 ensure=function(s)return s.options end}
local modules={
 ['src.core.GameVersion']={get=function()return 'firered'end},
 ['src.core.game3.field']=field,['src.core.game3.field_view']={draw=function()return objects.forDraw()end},
 ['src.core.game3.objects']=objects,['src.core.game3.collision']=collision,
 ['src.core.game3.forced_movement']={isForced=no,isForcedMovementTile=no,fieldControlsLocked=function()return field.locked end},
 ['src.core.game3.runtime']=runtime,['src.core.game3.pokemon']=pokemon,
 ['src.core.game3.ow_sprites']={draw=noop},
 ['src.core.game3.player']=player,['src.core.game3.encounters']={terrainAt=function()return 'land'end,tableFor=function()return {}end},
 ['src.core.game3.battle_bridge']={startWild=noop},['src.core.game3.map']=map,
 ['src.core.game3.scripting.flags']={getFlag=no},['src.core.game3.scripting.space']={vm={ctx={activeMoves={}}}},
 ['src.ui.game3.fade']={isActive=no},['src.ui.game3.map_preview_screen']={isActive=no},['src.core.game3.battle']={isActive=no},
 ['src.ui.game3.hud']={isMenuOpen=function()return menuOpen end},['src.ui.game3.choice']={},['src.ui.game3.option_rows']=nativeRows,
 ['src.core.game3.tileset_native']={},['src.core.game3.tileset_anim']={},
 ['src.core.game3.options']=options,['src.core.game3.rng']={next=function()return 1 end},
 ['src.core.game3.audio']={playCry=noop,playSe=noop},['src.ui.game3.message']={show=noop},
 ['src.core.game3.field_effects']={drawFront=noop,drawBehind=noop,_sheets={}},
 ['src.core.game3.warp']={isBusy=no,startDoorEntrance=function()return true end,startDoorExit=function()return true end},
}
for path,value in pairs(modules)do package.loaded[path]=value end
local function read(path)local f=assert(io.open(path,'rb'));local value=f:read('*a');f:close();return value end
local function loadMod(id,root,values)
 local mod={id=id,path=root,generation=3,exports={},game=field._game,
   read=function(_,path)return read(root..'/'..path)end,
   find=function(_,name)return mods[name]end,log={error=function(_,fmt,...)error(string.format(fmt,...))end,warn=noop,info=noop},
   options={define=function(_,s)schemas[id]=s;for _,r in ipairs(s)do if values[r.key]==nil then values[r.key]=r.default end end end,
     get=function(_,key)return values[key]end},
   events={on=function(_,name,fn)callbacks[name]=callbacks[name]or{};table.insert(callbacks[name],fn)end},
   hooks={wrap=function()end}}
 mods[id]=mod
 local env=Sandbox.envFor({modId=id,permissions={engine_internals=true}})
 assert(load(read(root..'/main.lua'),'@'..root..'/main.lua','t',env))()(mod)
 return mod
end
-- A missing dependency must fail before any engine hooks or schemas change.
local ok=pcall(loadMod,'wildfollowers',addonRoot,{})
eq(ok,false,'missing dependency refused');eq(schemas.wildfollowers,nil,'no schema installed without dependency')
local ua=loadMod('untamed_advanced',uaRoot,{})
local base=assert(ua.exports.engine,'UA must export its actual engine')
local pool=base.actors;local poolSize=#pool;local wild=base.Owe
local tick=wild.tick;local step=wild.onStep;local sourceCanMove=base.canMove
local wildConfig={};for key,value in pairs(base.C)do if key:match('^WE_') or key:match('^OWE_')then wildConfig[key]=value end end
local originalFacade=base.Follower
local addonValues={follower_count=6}
local addon=loadMod('wildfollowers',addonRoot,addonValues)
local E=addon.exports.engine
eq(base.Follower,originalFacade,'dependency controller table preserved')
eq(base.actors,pool,'dependency pool identity preserved');eq(#pool,poolSize,'wild capacity preserved')
eq(base.Owe,wild,'one native wild engine');eq(wild.tick,tick,'wild tick unmodified');eq(wild.onStep,step,'wild step unmodified')
eq(base.canMove,sourceCanMove,'wild movement untouched')
for key,value in pairs(wildConfig)do eq(base.C[key],value,'wild option '..key..' unchanged')end
for _,row in ipairs(schemas.wildfollowers)do
 eq(row.key:match('^WE_')~=nil,false,'no encounter schema');eq(row.key:match('^OWE_')~=nil,false,'no wild schema')
end
eq(#E.actors,6,'six follower slots');eq(E.actors[1],base.FOLLOWER,'native slot one reused')
for i=2,6 do eq(E.actors[i].localId<-1000,true,'extra IDs separate');eq(base.isOwe(E.actors[i]),false,'extras never classified as wild')end
-- Actual follower state machines, actual dependency event callbacks.
for _,fn in ipairs(callbacks['map.entered']or{})do fn({via='warp'})end
eq(#E.Follower.order,6,'healthy party selected')
for _,a in ipairs(E.Follower.order)do eq(a.invisible,true,'hidden before arrival')end
field.update(1/60)
eq(E.Follower.ticks,1,'one normal follower tick')
local cells={}
for _,a in ipairs(E.Follower.order)do
 eq(a.invisible,false,'visible after safe arrival')
 local key=a.cellX..':'..a.cellY;eq(key=='10:10',false,'not on avatar');eq(cells[key],nil,'no stack');cells[key]=true
end
local list=E.FieldView.draw();local displayed=0
for _,a in ipairs(list)do if a.nativeCore then displayed=displayed+1 end end
eq(displayed,6,'renderer presents six followers')
eq(#objects.forDraw(),0,'draw injection does not leak outside render')
-- Both option surfaces change the same count.
local rows=nativeRows.build({options=engineOptions})
local countRow;for _,row in ipairs(rows)do if row.id=='wildsG3FollowerCount'then countRow=row end end
assert(countRow,'native follower count row missing')
session.options.wildsG3FollowerCount=3;countRow.step({options=engineOptions},1)
eq(E.Follower.follower_count,4,'native count edit immediately applied')
menuOpen=true
local before=E.Follower.ticks;runtime.update(1/60)
eq(E.Follower.ticks,before+1,'menu frame receives one follower tick')
runtimeRunsField=true;before=E.Follower.ticks;runtime.update(1/60)
eq(E.Follower.ticks,before+1,'runtime field frame never double ticks')
menuOpen=false;runtimeRunsField=false
session.options.wildsG3LandSpriteSet='custom-wild';session.options.wildsG3WaterSpriteSet='custom-water'
addonValues.follower_count=2
for _,fn in ipairs(callbacks['mod.options_changed']or{})do fn({mod='wildfollowers',key='follower_count'})end
eq(E.Follower.follower_count,2,'manager count overrides previous native selection')
addonValues.follower_count=0
for _,fn in ipairs(callbacks['mod.options_changed']or{})do fn({mod='wildfollowers',key='follower_count'})end
eq(#E.Follower.order,0,'zero disables followers')
eq(base.Owe.tick,tick,'count edits never replace wild engine')
eq(session.options.wildsG3LandSpriteSet,'custom-wild','land wild preference untouched')
eq(session.options.wildsG3WaterSpriteSet,'custom-water','water wild preference untouched')
for count=0,6 do
 addonValues.follower_count=count
 for _,fn in ipairs(callbacks['mod.options_changed']or{})do fn({mod='wildfollowers',key='follower_count'})end
 eq(#E.Follower.order,count,'all supported follower counts')
end
local originalOptions=session.options
engineOptions.emerald={wildsG3FollowerCount=1,wildsG3LandSpriteSet='emerald-wild'}
session={version='emerald',engineOptions=engineOptions,options=engineOptions.emerald,party=session.party,map=session.map,flags={},vars={}}
E.Follower.readOptions()
eq(E.Follower.follower_count,6,'count carries over to Emerald')
eq(session.options.wildsG3LandSpriteSet,'emerald-wild','migration leaves Emerald wild settings alone')
session.options={};engineOptions.emerald=session.options
E.Follower.readOptions()
eq(E.Follower.follower_count,6,'new game options retain shared count')
print('Party Parade / real UA sandbox integration checks',checks)
