-- Installed native map/collision code and actual Sandbox own all geometry.
-- Only authored route data, render services, UI state and battle boundaries
-- are fixtures. Detached queries must never rebind the live map or save.
local root,version=arg[1],arg[2]
local function read(path)local f=assert(io.open(path,'rb'));local s=f:read('*a');f:close();return s end
local checks=0
local function check(ok,message)checks=checks+1;assert(ok,version..': '..message)end
local function eq(a,b,message)check(a==b,message..' ['..tostring(a)..' vs '..tostring(b)..']')end
local function near(a,b,message)check(math.abs(a-b)<.001,message..' ['..tostring(a)..' vs '..tostring(b)..']')end
love=require('tests.love_stub')
local GV=require('src.core.GameVersion');GV.set(version)
local gen=GV.generation()
local Sandbox=require('src.mods.Sandbox')
local data={pokemon={},maps={},tilesets={},field={},constants=require('src.world.FieldDefaults').CONSTANTS}
local names={[1]='BULBASAUR',[4]='CHARMANDER',[7]='SQUIRTLE',[25]='PIKACHU'}
for nat,name in pairs(names)do data.pokemon[name]={id=name,dex=nat}end
local function species(nat)return gen==3 and nat or names[nat]end
local player={cellX=14,cellY=8,px=224,py=128,currentElevation=3,elevation=3,facing='right',moving=false}
local session={map='NATIVE_A',version=version,party={{species=species(1),level=12,hp=30}},inventory={},flags={},repelSteps=0}
local busy=false
local nativeCalls=0
local dexCalls={}
local dexOn=false
local nativePools={NATIVE_A=1,NATIVE_B=4,NATIVE_C=7}
local function collAt(x,y)
  if y==0 then
    if x==0 then return gen==1 and 0x00 or 0x00 end
    if x==2 then return gen==1 and 0x14 or 0x29 end
    if x==3 then return 0x07 end
    if x==6 then return gen==1 and 0x07 or 0xa1 end
  end
  return gen==1 and 0x52 or 0x18
end
local function midAt(x,y)
  if y==0 and x==2 then return 2 end
  if y==0 and x==7 then return 3 end
  if y==0 and x==0 then return 0 end
  return 1
end
local function elevationAt(x,y)return y==0 and x==8 and 5 or 3 end
local mapDefs={}
local sets={}
-- Authored tilesets containing water must declare native Gen 1 membership.
data.field.waterTilesets={}
for _,id in ipairs({'NATIVE_A','NATIVE_B','NATIVE_C'})do
  local setId='FIXTURE_'..id
  data.field.waterTilesets[#data.field.waterTilesets+1]=setId
  local ts={walkable={0x00,0x52},grassTile=0x52,grassTiles={0x52},waterTiles={0x14},shoreTiles={},blocks={},collision={}}
  local def={id=id,width=8,height=8,index=1,tileset=setId,environment='ROUTE',pair=setId,
    blocks={},warps={{x=4,y=0,map='NATIVE_A',warp=1}},objects={{x=5,y=0,sprite='SPRITE_RED'}}}
  for by=0,7 do for bx=0,7 do
    local blockIndex=by*8+bx+1
    -- Gen 1 block indices are0based; Gen2 index0 is its impassable sentinel.
    local blockId=gen==1 and blockIndex-1 or blockIndex
    def.blocks[blockIndex]=blockId
    local pixels={};for n=1,16 do pixels[n]=0x52 end
    local quad={}
    for cy=0,1 do for cx=0,1 do
      local collision=collAt(bx*2+cx,by*2+cy)
      pixels[(cy*2+1)*4+cx*2+1]=collision
      quad[cy*2+cx+1]=collision
    end end
    ts.blocks[blockId+1]=pixels;ts.collision[blockId+1]=quad
  end end
  if gen==3 then
    local layout={width=16,height=16,pair=setId}
    function layout:collAt(x,y)return collAt(x,y)end
    function layout:midAt(x,y)return midAt(x,y)end
    function layout:elevAt(x,y)return elevationAt(x,y)end
    function layout:collArray()
      local grid={};for y=0,15 do for x=0,15 do grid[y*16+x+1]=self:collAt(x,y)end end;return grid
    end
    def.midLayout=layout
  end
  mapDefs[id]=def;sets[setId]=ts
end
mapDefs.NATIVE_A.connections={right={map='NATIVE_B',offset=3},up={map='NATIVE_C',offset=-2}}
mapDefs.NATIVE_B.connections={left={map='NATIVE_A',offset=-3}}
mapDefs.NATIVE_C.connections={down={map='NATIVE_A',offset=2}}
data.maps=mapDefs;data.tilesets=sets
local Map=gen==1 and require('src.world.Map')or gen==2 and require('src.world.gen2.Map')
local liveMap=Map and Map.new(mapDefs.NATIVE_A,sets[mapDefs.NATIVE_A.tileset])
  or {id='NATIVE_A',def=mapDefs.NATIVE_A,widthCells=16,heightCells=16}
local world={map=liveMap,player=player,maps=mapDefs,tilesets=sets,npcs={},entities={player},neighbors={},isOverworld=true,tod='DAY'}
local game={data=data,save=session,session=session,world=world,overworld=world,phase='field',stack={states={}}}
world.game=game
if gen==1 then game.stack.states={world}end
function world:busy()return busy end
function world:interact()nativeCalls=nativeCalls+1;return false end
local battleCount=0
local function boundaryBattle()battleCount=battleCount+1;return true end
function world:startBattle()return boundaryBattle()end
local tables={}
for id,nat in pairs(nativePools)do
  local slots={};for n=1,12 do slots[n]={species=species(nat),level=nat+10,minLevel=nat+10,maxLevel=nat+10}end
  tables[id]={land={rate=50,slots=slots},grass={rate=50,slots=slots},water={rate=50,slots={{species=species(nat),level=nat+20}}}}
end
if gen==1 then data.encounters=tables
elseif gen==2 then
  local nativeTables={grass={},water={}}
  for id,nat in pairs(nativePools)do
    local slots={};for n=1,7 do slots[n]={species=species(nat),level=nat+10}end
    nativeTables.grass[id]={rates={MORN=50,DAY=50,NITE=50},slots={MORN=slots,DAY=slots,NITE=slots}}
    nativeTables.water[id]=tables[id].water
  end
  data.gen2Encounters=nativeTables;data.encounters=nativeTables
  function world:wildTables()return nativeTables end
  package.loaded['src.battle.gen2.Mon']={new=function(_,sp,level)return {species=sp,level=level,hp=30}end}
end
local effects={collectActors=function()end}
local field={running=true,isLocked=function()return busy end,interact=function()nativeCalls=nativeCalls+1;return false end}
function field.metatileOverrideAt(id,x,y)
  if id=='NATIVE_B'and x==12 and y==0 then return {impassable=true}end
end
local Collision,Enc
if gen==3 then
  package.loaded['src.core.game3.runtime']={getSession=function()return session end,isActive=function()return true end,uiBusy=function()return busy end}
  package.loaded['src.core.game3.player']=player
  package.loaded['src.core.game3.field']=field
  package.loaded['src.core.game3.field_effects']=effects
  package.loaded['src.core.game3.battle']={isActive=function()return busy end}
  package.loaded['src.core.game3.warp']={isBusy=function()return false end}
  package.loaded['src.core.game3.forced_movement']={isForced=function()return false end}
  package.loaded['src.core.game3.objects']={hasMap=function()return false end}
  package.loaded['src.core.game3.scripting.space']={getVm=function()end,
    bundle={events={NATIVE_B={objects={{x=5,y=0}}}}}}
  package.loaded['src.core.game3.field_semantics']={getVar=function()return 0 end}
  package.loaded['src.core.game3.battle_bridge']={startWild=boundaryBattle}
  local P=require('src.core.game3.pokemon')
  P._names={};P._byName={};P._national={toNational={},toSpecies={}}
  for nat,name in pairs(names)do
    P._names[nat]=name;P._byName[name]=nat;P._national.toNational[nat]=nat;P._national.toSpecies[nat]=nat
  end
  P.isEgg=function()return false end
  local scripts=require('src.core.game3.scripting.interaction_scripts')
  for _,def in pairs(mapDefs)do scripts.behaviors[def.pair]={[0]=0,[1]=2,[2]=0x10,[3]=0x31}end
  Collision=require('src.core.game3.collision')
  check(Collision.bindMap(game,'NATIVE_A',mapDefs.NATIVE_A),'real native GBA grid binds initial authored map')
  Enc=require('src.core.game3.encounters')
  Enc._loaded=true;Enc._tables=tables
  local types={};for _,def in pairs(mapDefs)do types[def.pair]={[0]=0,[1]=1,[2]=2,[3]=1}end
  Enc.installEncounterTypes(types)
end
local values,events,hooks={}, {},{}
local dex={exports={}}
function dex.exports.chooseGBWildEncounter(hit,id,kind,rng)
  dexCalls[#dexCalls+1]={id=id,kind=kind,native=hit.species}
  return {species=species(id=='NATIVE_B'and 7 or 25),level=22}
end
function dex.exports.chooseWildEncounter(id,kind,level)
  dexCalls[#dexCalls+1]={id=id,kind=kind,nativeLevel=level}
  local nat=id=='NATIVE_B'and 7 or 25;return nat,species(nat),22
end
local mod={id='wildfollowers',game=game,exports={},read=function(_,name)return read(root..'/'..name)end,
  options={get=function(_,key)return values[key]end,define=function(_,rows)for _,row in ipairs(rows)do values[row.key]=row.default end end},
  assets={image=function(_,name)return love.graphics.newImage(root..'/'..name)end},
  world={overworld=function()return world end,startWildBattle=boundaryBattle},
  events={on=function(_,name,fn)events[name]=fn end},hooks={wrap=function(_,name,fn)hooks[name]=fn end},log={info=function()end}}
function mod:find(id)if dexOn and id=='1025dex'then return dex end end
game.mods={exports={wildfollowers=mod.exports}}
local env=Sandbox.envFor({modId='wildfollowers',permissions={engine_internals=true}})
local A=assert(Sandbox.compile(read(root..'/src/adapter.lua'),'@wildfollowers/adapter',env))()(mod)
local nativeGrid=Collision and Collision._grid
local nativeDef=Collision and Collision._mapDef
local nativeMap=world.map
local nativeSessionMap=session.map
local current=A:area();local neighbors=A:adjacent(current)
eq(#neighbors,2,'native connection descriptors expose both connected maps')
local B,C
for _,n in ipairs(neighbors)do if n.id=='NATIVE_B'then B=n elseif n.id=='NATIVE_C'then C=n end end
check(B and C,'native neighbor lookup finds east and north source')
eq(B.width,16,'native neighbor width uses16pixel cells')
eq(B.height,16,'native neighbor height uses16pixel cells')
eq(B.offsetX,16,'east source starts at current width')
eq(B.offsetY,gen==3 and 3 or 6,'offset units follow native generation semantics')
eq(C.offsetX,gen==3 and -2 or -4,'negative offsets preserve native units')
eq(C.offsetY,-16,'north source origin uses destination height')
if gen<3 then
  eq(getmetatable(B.map),Map,'detached neighbor uses actual native Map constructor')
  check(B.map~=world.map,'detached native Map leaves live map untouched')
  if gen==1 then eq(type(B.map.warpAt),'table','native Gen1 warp table shape preserved')end
end
check(A:grass(1,0,B),'detached native grass cell recognized')
check(not A:grass(0,0,B),'detached plain floor is not grass')
check(A:water(2,0,B),'detached native water cell recognized')
check(not A:water(1,0,B),'detached grass is dry')
check(not A:water(-1,0,B),'detached water check rejects out-of-bounds source')
check(A:habitat(1,0,'land',B),'detached source native grass supports land encounters')
check(A:habitat(2,0,'water',B),'detached source water supports water encounters')
check(not A:habitat(0,0,'land',B),'detached plain floor is not a route encounter habitat')
check(A:allowed(1,0,'land',nil,nil,B),'detached grass placement uses native permissions')
check(A:allowed(2,0,'water',nil,nil,B),'detached water placement uses native permissions')
check(not A:allowed(2,0,'land',nil,nil,B),'land wild cannot be placed on native water')
check(not A:allowed(3,0,'land',nil,nil,B),'detached native wall rejects placement')
check(not A:allowed(4,0,'land',nil,nil,B),'detached native warp rejects placement')
check(not A:allowed(5,0,'land',nil,nil,B),'detached map object rejects placement')
check(not A:allowed(-1,0,'land',nil,nil,B),'negative source coordinate rejects placement')
check(not A:allowed(16,0,'land',nil,nil,B),'source width boundary rejects placement')
if gen==2 then
  world.noWildEncounters=true
  check(not A:habitat(1,0,'land',current),'current Gen2 habitat honors native wildoff flag')
  check(A:habitat(1,0,'land',B),'current wildoff flag does not mutate unloaded source habitat')
  world.noWildEncounters=false
end
if gen==3 then
  check(not A:allowed(6,0,'land',nil,nil,B),'native GBA ledge is not a standing wild cell')
  check(not A:allowed(7,0,'land',{cellX=6,cellY=0,facing='right',currentElevation=3},nil,B),
    'detached movement honors native directional impassable behavior')
  check(not A:allowed(8,0,'land',{cellX=7,cellY=0,facing='right',currentElevation=3},nil,B),
    'detached movement honors native bridge elevation mismatch')
  check(not A:allowed(12,0,'land',nil,nil,B),'detached source honors native metatile overrides')
  local elevation,draw=A:elevations(8,0,B)
  eq(elevation,5,'detached source reads native elevation')
  eq(draw,5,'detached source draw elevation matches standing layer')
end
local rng=function(a,b)return a end
local hit=A:choose('land',rng,B)
check(hit~=nil,'detached source has valid native encounter pool')
eq(hit.species,species(4),'detached choice samples own native source species')
eq(hit.level,14,'detached choice samples own native source level')
dexOn=true;hit=A:choose('land',rng,B)
eq(hit.species,species(7),'detached source choice accepts provider replacement')
eq(hit.level,22,'detached source choice accepts provider level')
eq(dexCalls[#dexCalls].id,'NATIVE_B','Dex receives source map rather than active map')
eq(dexCalls[#dexCalls].kind,'land','Dex receives correct source encounter kind')
dexOn=false
eq(world.map,nativeMap,'detached map queries never replace live world map')
eq(session.map,nativeSessionMap,'detached map queries never change session map')
if gen==3 then
  eq(Collision._grid,nativeGrid,'detached native collision queries never rebind live grid')
  eq(Collision._mapDef,nativeDef,'detached native collision queries never replace active map definition')
  eq(Collision._mapId,'NATIVE_A','detached native collision queries retain active grid map ID')
end

-- Load actual main/controller/areas/sprites through the native sandbox. The
-- real map.entered event preserves prepopulated identities through a seam.
assert(Sandbox.compile(read(root..'/main.lua'),'@wildfollowers/main',env))()(mod)
local grassDraws={}
if gen==3 then
  -- Actual native loader, with extracted artwork represented by a cached
  -- image/quad fixture. Current and detached terrain remain native above.
  local nativeEffects=assert(loadfile('src/core/game3/field_effects.lua'))()
  local image=love.graphics.newImage('grass-cover-fixture')
  local q=love.graphics.newQuad(0,72,16,8,16,80)
  nativeEffects._sheets.tall_grass={image=image,quadsFront={[4]=q},frames=5}
  effects.loadSheet=nativeEffects.loadSheet
  local draw=love.graphics.draw
  love.graphics.draw=function(img,quad,x,y,...)
    grassDraws[#grassDraws+1]={image=img,quad=quad,x=x,y=y}
    return draw(img,quad,x,y,...)
  end
end
values.OW_FOLLOWERS_ENABLED=false
values.spawn_density='normal';values.spawn_range='normal'
local function tick(n)for _=1,n or 1 do hooks['input.step'](function()end,game,1/60)end end
local function actors()
  if gen==3 then
    local all,out={},{};effects.collectActors(all)
    for _,e in ipairs(all)do if not e._wildFollowersGrass then out[#out+1]=e end end
    return out
  end
  return world.npcs
end
tick(60)
local sourceCounts={}
local landCounts,waterCounts={},{}
local preview,currentActor
for _,e in ipairs(actors())do
  sourceCounts[e.sourceMap]=(sourceCounts[e.sourceMap]or 0)+1
  local counts=e.surface=='water' and waterCounts or landCounts
  counts[e.sourceMap]=(counts[e.sourceMap]or 0)+1
  if e.sourceMap=='NATIVE_B'and e.surface=='land'then preview=preview or e end
  if e.sourceMap=='NATIVE_A'and e.surface=='land'then currentActor=currentActor or e end
end
eq(landCounts.NATIVE_A,4,'actual controller fills current land source population independently')
eq(landCounts.NATIVE_B,4,'actual controller fills closest detached land source before entry')
check((waterCounts.NATIVE_A or 0)<=4 and (waterCounts.NATIVE_B or 0)<=4,'connected water populations obey their own source caps')
eq(sourceCounts.NATIVE_C,nil,'actual controller restricts prepopulation to nearest source')
check(preview and not preview.currentEligible and preview.previewEligible,'renderer publishes an interaction-ineligible preview')
check(currentActor.ecology and preview.ecology,'actual main hook activates ecosystem on current and preview wilds')
local ecologyAge=currentActor.ecology.next
local ecologyRest=currentActor.ecology.restIn
busy=true;tick(120)
eq(currentActor.ecology.next,ecologyAge,'busy main hook freezes ecosystem decision time')
eq(currentActor.ecology.restIn,ecologyRest,'busy main hook freezes wild resting time')
busy=false
values.living_ecosystems=false;tick()
check(not currentActor.ecology and not preview.ecology,'actual main hook applies ecosystem OFF')
values.living_ecosystems=true;tick()
check(currentActor.ecology and preview.ecology,'actual main hook reapplies ecosystem ON')
if gen==3 then
  local all={};effects.collectActors(all)
  local cover
  for _,e in ipairs(all)do if e._wildFollowersGrass and e.owner==preview then cover=e;break end end
  check(cover~=nil,'actual main renderer covers prepared wild feet using detached source grass')
  eq(cover.elevation,preview.elevation,'grass shares source actor native draw layer')
  check(cover.sortY>preview.sortY,'grass sorts above its owner')
  cover:draw(7,11)
  local drawn=grassDraws[#grassDraws]
  eq(drawn.x,cover.grassX-7,'native grass cover follows camera X')
  eq(drawn.y,cover.grassY-11,'native grass cover follows camera Y')
  eq(drawn.quad.h,8,'native grass covers eight-pixel feet strip')
end
local priorX,priorY=player.cellX,player.cellY
player.cellX,player.cellY=preview.cellX-1,preview.cellY;player.facing='right'
local beforeBattle=battleCount
if gen==3 then field.interact(game)else world:interact()end
eq(battleCount,beforeBattle,'main interaction cannot initiate battle in preview source')
player.cellX,player.cellY=priorX,priorY;player.px,player.py=priorX*16,priorY*16
local localX,localY=preview.sourceX,preview.sourceY
local beforeSeamCount=#actors()
session.map='NATIVE_B'
world.map=Map and Map.new(mapDefs.NATIVE_B,sets[mapDefs.NATIVE_B.tileset])
  or {id='NATIVE_B',def=mapDefs.NATIVE_B,widthCells=16,heightCells=16}
if gen==3 then check(Collision.bindMap(game,'NATIVE_B',mapDefs.NATIVE_B),'native engine binds destination upon actual seam entry')end
player.cellX,player.cellY=1,8-(gen==3 and 3 or 6);player.px,player.py=player.cellX*16,player.cellY*16
busy=true
events['map.entered']({fromMapId='NATIVE_A',mapId='NATIVE_B',via='connection'})
eq(#mod.exports.status().actors,0,'main map-entered event detaches old flat list before next tick')
tick()
eq(#actors(),beforeSeamCount,'busy seam tick republishes every preserved source actor')
check(preview.currentEligible and not preview.previewEligible,
  'busy seam still activates preserved preview in destination source')
check(currentActor.retired and not currentActor.currentEligible,
  'busy seam still marks departed source interaction-ineligible')
near(preview.cellX,localX,'busy seam reprojects current source without waiting for script/menu')
near(preview.cellY,localY,'busy seam reprojects current source Y while locked')
near(currentActor.areaLinger,15,'busy seam starts departure grace at full15field seconds')
tick(120)
eq(#actors(),beforeSeamCount,'busy field cannot spawn or discard source actors')
near(currentActor.areaLinger,15,'busy field time cannot consume departure grace')
-- Isolate seam projection from a pre-existing random wandering step.
preview.moving=false;preview.targetX=nil;preview.targetY=nil;preview.idle=0
values.living_ecosystems=false
busy=false;tick()
local found=false
for _,e in ipairs(actors())do if e==preview then found=true end end
check(found,'main event and actual controller preserve preview actor identity on entry')
check(preview.currentEligible and not preview.previewEligible,'entered preview becomes battle eligible')
near(preview.cellX,localX,'main seam removes preview X cell offset')
near(preview.cellY,localY,'main seam removes preview Y cell offset')
check(currentActor.retired,'main seam gives departed source a grace population')
localX,localY=player.cellX,player.cellY
player.cellX,player.cellY=preview.cellX-1,preview.cellY;player.facing='right'
if gen==3 then field.interact(game)else world:interact()end
eq(battleCount,beforeBattle+1,'entered source can initiate its native wild battle')
eq(#mod.exports.status().actors,0,'successful native battle clears area populations')
player.cellX,player.cellY=localX,localY
-- Connected seams retain the actual follower object and a committed step.
values.OW_FOLLOWERS_ENABLED=true;values.follower_count=1;values.WE_OW_ENCOUNTERS=false
player.cellX,player.cellY,player.px,player.py=0,4,0,64;player.moving=false
events['save.loaded']()
tick(60)
local follower
for _,e in ipairs(actors()) do if e.follower then follower=e end end
check(follower~=nil,'follower initializes before connected return seam')
follower.cellX,follower.cellY=1,4;follower.px,follower.py=20,64
follower.startX,follower.startY=16,64;follower.targetX,follower.targetY=2,4
follower.progress=.25;follower.duration=32/60;follower.moving=true;follower.ballPhase=nil
local slot=follower.lineSlot
session.map='NATIVE_A'
world.map=Map and Map.new(mapDefs.NATIVE_A,sets[mapDefs.NATIVE_A.tileset])
  or {id='NATIVE_A',def=mapDefs.NATIVE_A,widthCells=16,heightCells=16}
if gen==3 then Collision.bindMap(game,'NATIVE_A',mapDefs.NATIVE_A) end
local offset=gen==3 and 3 or 6
player.cellX,player.cellY,player.px,player.py=15,4+offset,240,(4+offset)*16
busy=true
events['map.entered']({fromMapId='NATIVE_B',mapId='NATIVE_A',via='connection'})
tick()
local retained=false
for _,e in ipairs(actors()) do if e==follower then retained=true end end
check(retained,'connected transition keeps exact follower identity')
eq(follower.cellX,17,'follower cell translates without moving to player')
eq(follower.cellY,4+offset,'connection offset preserves relative Y')
eq(follower.px,276,'in-flight pixel position translates exactly')
eq(follower.targetX,18,'committed destination survives connected transition')
eq(follower.progress,.25,'locked seam preserves movement progress')
eq(follower.lineSlot,slot,'seam retains procession order')
check(not follower.ballPhase,'connected seam does not replay Pokeball release')
check(A:allowed(18,4+offset,'land',follower),'follower can finish on legal previous-map tile')
events['battle.started']()
tick(60)
eq(follower.progress,.25,'combat freezes committed follower movement')
eq(follower.px,276,'combat retains exact follower pixel position')
eq(follower.lineSlot,slot,'combat preserves line assignment')
events['map.reloaded']()
events['battle.ended']()
tick()
local battleRetained=false
for _,e in ipairs(actors()) do if e==follower then battleRetained=true end end
check(battleRetained,'battle return republishes the same follower object')
eq(follower.progress,.25,'battle closing field lock preserves progress')
check(not follower.ballPhase,'battle return does not replay release animation')
busy=false;tick(18)
check(follower.progress>=.25,'retained follower resumes its committed animation')
events['map.entered']({fromMapId='NATIVE_A',mapId='NATIVE_B',via='warp'})
eq(#mod.exports.status().followers,0,'door or warp still resets followers for arrival release')
if gen==2 then
  local NativeWorld=require('src.world.gen2.World')
  local savedA,savedB=mapDefs.NATIVE_A.connections,mapDefs.NATIVE_B.connections
  mapDefs.NATIVE_A.connections={east={mapId='NATIVE_B',offset=3}}
  mapDefs.NATIVE_B.connections={west={mapId='NATIVE_A',offset=-3}}
  world.playerState=0
  world.connectionMap=function(_,id)return Map.new(mapDefs[id],sets[mapDefs[id].tileset])end
  world.setMap=function(self,id,x,y,facing,opts)
    local previous=self.map.id
    session.map=id;self.map=self:connectionMap(id)
    player.cellX,player.cellY,player.px,player.py=x,y,x*16,y*16
    player.facing=facing;self.entities={player};self.npcs={}
    -- The native engine emits before tryConnection restores the source and
    -- committed destination for the step crossing the seam.
    events['map.entered']({fromMapId=previous,mapId=id,via=opts.seamless and 'connection' or 'warp'})
    return true
  end
  world.tryConnection=NativeWorld.tryConnection
  for _,direction in ipairs({'right','left','up','down'}) do
  local names={right='east',left='west',up='north',down='south'}
  local opposite={right='west',left='east',up='south',down='north'}
  mapDefs.NATIVE_A.connections={[names[direction]]={mapId='NATIVE_B',offset=3}}
  mapDefs.NATIVE_B.connections={[opposite[direction]]={mapId='NATIVE_A',offset=-3}}
  for _,coordinate in ipairs({0,7,15}) do
    local sourceX=direction=='right' and 15 or direction=='left' and 0 or coordinate
    local sourceY=direction=='up' and 0 or direction=='down' and 15 or coordinate
    session.map='NATIVE_A';world.map=world:connectionMap('NATIVE_A')
    player.cellX,player.cellY,player.px,player.py=sourceX,sourceY,sourceX*16,sourceY*16
    player.moving=false;player.targetX=nil;player.targetY=nil
    events['save.loaded']();busy=false;tick(60)
    local companion
    for _,e in ipairs(actors())do if e.follower then companion=e end end
    check(companion~=nil,'Gen 2 native seam fixture has follower')
    local d=({right={1,0},left={-1,0},up={0,-1},down={0,1}})[direction]
    local fx,fy=sourceX-d[1],sourceY-d[2]
    companion.cellX,companion.cellY=fx,fy
    companion.startX,companion.startY=fx*16,fy*16
    companion.px,companion.py=fx*16+d[1]*4,fy*16+d[2]*4
    companion.targetX,companion.targetY=sourceX,sourceY
    companion.moving=true;companion.progress=.25;companion.duration=32/60;companion.ballPhase=nil
    local rank,trailStep=companion.lineSlot,companion.trailStep
    check(world:tryConnection(direction),'real Gen 2 native connection succeeds')
    local dx,dy=player.cellX-sourceX,player.cellY-sourceY
    busy=true;tick()
    local same=false
    for _,e in ipairs(actors())do if e==companion then same=true end end
    check(same,'native Gen 2 seam retains identity, including clamped landing')
    eq(companion.cellX,fx+dx,'native Gen 2 seam translates source exactly')
    eq(companion.cellY,fy+dy,'native Gen 2 seam uses actual clamped vertical offset')
    eq(companion.px,fx*16+d[1]*4+dx*16,'native Gen 2 seam retains exact interpolated pixels')
    eq(companion.py,fy*16+d[2]*4+dy*16,'native Gen 2 seam retains exact vertical pixels')
    eq(companion.targetY,sourceY+dy,'native Gen 2 seam preserves vertical destination')
    eq(companion.targetX,sourceX+dx,'native Gen 2 seam preserves committed destination')
    eq(companion.progress,.25,'native Gen 2 seam preserves movement progress')
    eq(companion.trailStep,trailStep,'native Gen 2 seam preserves trail cursor')
    eq(companion.lineSlot,rank,'native Gen 2 seam preserves order')
    check(not companion.ballPhase,'native Gen 2 seam avoids release replay')
    busy=false;tick()
    local resumed=false
    for _,e in ipairs(actors())do if e==companion then resumed=true end end
    check(resumed and companion.progress>=.25,'native Gen 2 seam resumes original committed movement')
    local missing=(direction=='up' or direction=='down') and 'right' or 'up'
    check(not world:tryConnection(missing),'unconnected Gen 2 edge refuses crossing')
    check(not world._wildFollowersRewriteOwner.nativeConnection,'failed connection clears temporary interception')
  end
  end
  values.follower_count=6
  session.party={}
  for i=1,6 do session.party[i]={species=species(1),level=12,hp=30} end
  -- Real trailing history, with the player continuing well into the new map.
  for _,direction in ipairs({'right','left','up','down'}) do
    local d=({right={1,0},left={-1,0},up={0,-1},down={0,1}})[direction]
    local names={right='east',left='west',up='north',down='south'}
    local opposite={right='west',left='east',up='south',down='north'}
    mapDefs.NATIVE_A.connections={[names[direction]]={mapId='NATIVE_B',offset=-3}}
    mapDefs.NATIVE_B.connections={[opposite[direction]]={mapId='NATIVE_A',offset=3}}
    session.map='NATIVE_A';world.map=world:connectionMap('NATIVE_A')
    local edgeX=direction=='right' and 15 or direction=='left' and 0 or 15
    local edgeY=direction=='down' and 15 or direction=='up' and 0 or 15
    player.cellX,player.cellY=edgeX-d[1]*8,edgeY-d[2]*8
    player.px,player.py=player.cellX*16,player.cellY*16
    player.moving=false;player.targetX=nil;player.targetY=nil
    mapDefs.NATIVE_A.objects={{x=edgeX-d[1]*2-(d[2]~=0 and 6 or 0),y=edgeY-d[2]*2-(d[1]~=0 and 6 or 0)}}
    events['save.loaded']();busy=false;tick(60)
    local function walk(x,y)
      player.targetX,player.targetY=x,y;player.moving=true;player.facing=direction
      local sx,sy=player.cellX,player.cellY
      for frame=1,16 do
        player.px,player.py=(sx+(x-sx)*frame/16)*16,(sy+(y-sy)*frame/16)*16
        tick()
      end
      player.cellX,player.cellY=x,y;player.moving=false;player.targetX=nil;player.targetY=nil;tick()
    end
    for step=1,8 do walk(player.cellX+d[1],player.cellY+d[2]) end
    local group=world._wildFollowersRewriteOwner.followers
    local retained={};for i,e in ipairs(group)do retained[i]=e end
    local beforeX,beforeY=player.cellX,player.cellY
    check(world:tryConnection(direction),'continued native crossing succeeds')
    local shiftX,shiftY=player.cellX-beforeX,player.cellY-beforeY
    local owner=world._wildFollowersRewriteOwner
    local probe=owner:actor(species(1),12,beforeX-d[1]*3+shiftX,beforeY-d[2]*3+shiftY,'land',6)
    check(owner:move(probe,probe.cellX+d[1],probe.cellY+d[2]),'trailing companion can take the next old-area step after clamped crossing '..direction)
    walk(player.targetX,player.targetY)
    for step=1,8 do walk(player.cellX+d[1],player.cellY+d[2]) end
    tick(60)
    for i,e in ipairs(retained)do
      eq(world._wildFollowersRewriteOwner.followers[i],e,'continued crossing retains companion')
      check(world.map:inBounds(e.cellX,e.cellY),'continued crossing brings companion into destination')
      check(math.abs(e.cellX-player.cellX)+math.abs(e.cellY-player.cellY)<=(e.lineSlot or i)+1,'continued crossing retains normal following distance '..direction..' slot '..i..' at '..e.cellX..','..e.cellY..' player '..player.cellX..','..player.cellY)
    end
  end
  mapDefs.NATIVE_A.connections=savedA;mapDefs.NATIVE_B.connections=savedB
end
print('PASS '..version..': '..checks..' native detached-area adapter checks')
