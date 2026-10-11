local root,version,dexRoot=arg[1],arg[2],arg[3]
local function read(path) local f=assert(io.open(path,'rb'));local s=f:read('*a');f:close();return s end
local checks=0
local function check(v,message) checks=checks+1;assert(v,version..': '..message) end
local function eq(a,b,message) check(a==b,message..' ['..tostring(a)..' vs '..tostring(b)..']') end
love=require('tests.love_stub')
local GV=require('src.core.GameVersion');GV.set(version)
local gen=GV.generation()
local manifest=require('src.mods.Manifest').validate(require('src.link.Json').decode(read(root..'/manifest.json')),root)
check(require('src.mods.ModTargets').supports(manifest,version,gen),'native loader accepts current cartridge target')
local roster=assert(load(read(dexRoot..'/encounters/roster.lua')))()
local P=require('src.core.game3.pokemon')
P._names={};P._byName={};P._national={toSpecies={},toNational={}}
-- Read the real native mapping from the supplied FireRed cartridge. This
-- exercises the nonuniform Hoenn ordering and reserved internal slots.
local rom=read(dexRoot..'/../FireRed.gba')
for slot=1,411 do
  local pos=0x251FEE+(slot-1)*2+1
  local nat=rom:byte(pos)+256*rom:byte(pos+1)
  if nat>=1 and nat<=386 then
    P._national.toNational[slot]=nat
    if not P._national.toSpecies[nat] then P._national.toSpecies[nat]=slot end
  end
end
eq(P._national.toNational[277],252,'ROM Treecko mapping')
eq(P._national.toNational[410],386,'ROM Deoxys mapping')
eq(P._national.toNational[411],358,'ROM Chimecho mapping is not a constant offset')
local data={pokemon={},field={},constants=require('src.world.FieldDefaults').CONSTANTS}
for _,row in ipairs(roster) do
  local n=row.id
  if n>386 then P._national.toSpecies[n]=n+64;P._national.toNational[n+64]=n end
  local slot=assert(P._national.toSpecies[n],tostring(n))
  P._names[slot]=row.name;P._byName[row.name:gsub('[^A-Z0-9]','')]=slot
  data.pokemon[row.name]={dex=n,id=row.name,name=row.name,baseStats={hp=50,attack=50,defense=50,speed=50,specialAttack=50,specialDefense=50},types={'NORMAL'},growthRate='MEDIUM_FAST',learnset={}}
end
local function species(n) return gen==3 and P.speciesFromNational(n) or roster[n].name end
local player={cellX=12,cellY=12,px=192,py=192,facing='down',elevation=3,moving=false}
local session={version=version,map='TEST_ROUTE',party={},repelSteps=0,pokedex={seen={},caught={}}}
for n=1,6 do session.party[n]={species=species(n),level=12,hp=30,maxHp=30} end
local busy=false
local walls={['10:10']=true};local warpX=11
local map={id='TEST_ROUTE',widthCells=25,heightCells=25,
  def={id='TEST_ROUTE',environment='ROUTE',index=1,tileset='OVERWORLD'}}
function map:inBounds(x,y)return x>=0 and y>=0 and x<25 and y<25 end
function map:isWaterCell(x,y)return self:inBounds(x,y) and y>=15 end
function map:isWalkableCell(x,y)return self:inBounds(x,y) and not walls[x..':'..y] and not self:isWaterCell(x,y) end
function map:isGrassCell(x,y)return self:isWalkableCell(x,y) and x>=3 end
function map:warpAtCell(x,y)return x==warpX and y==11 end
map.warpAt=gen==1 and {} or map.warpAtCell
function map:cellCollision(x,y)return self:isWaterCell(x,y) and 0x29 or self:isGrassCell(x,y) and 0x18 or 0 end
local world={map=map,player=player,npcs={},entities={player},isOverworld=true,tod='NITE'}
local game={data=data,save=session,session=session,world=world,overworld=world,phase='field',stack={states={}}}
world.game=game
if gen==1 then game.stack.states={world} end
function world:busy()return busy end
function world:updateScriptMoves()
  if self.storyStepAssertion then return self.storyStepAssertion() end
end
if gen==3 then
  require('src.core.game3.objects').scriptStep=function(npc)
    if npc.storyStepAssertion then return npc.storyStepAssertion() end
    return true
  end
elseif gen==2 then
  require('src.world.gen2.Npc').scriptStep=function(npc)
    if npc.storyStepAssertion then return npc.storyStepAssertion() end
    return true
  end
end
local originalInteractions=0
function world:interact()originalInteractions=originalInteractions+1;return 'native-interaction' end
local battleCalls,exactSpecies,exactLevel,exactOpts=0
local nativeBattle=function(hit,opts)
  battleCalls=battleCalls+1;exactSpecies=hit.species;exactLevel=hit.level;exactOpts=opts
  busy=true;return true
end
function world:startBattle(opts) return nativeBattle(opts.wild,opts) end
local rawTables
local function replaceTables(nat)
  local slots={};for i=1,12 do slots[i]={species=species(nat),level=7,minLevel=7,maxLevel=9} end
  local water={};for i=1,5 do water[i]={species=species(129),level=8,minLevel=8,maxLevel=8} end
  if gen==1 then rawTables={grass={rate=50,slots=slots},water={rate=50,slots=water}};data.encounters={[map.id]=rawTables}
  elseif gen==2 then
    local day={};local night={};for i=1,7 do day[i]={species=species(16),level=6};night[i]={species=species(nat),level=9} end
    rawTables={grass={[map.id]={rates={MORN=50,DAY=50,NITE=50},slots={MORN=day,DAY=day,NITE=night}}},water={[map.id]={rate=50,slots=water}}}
    data.encounters=rawTables;data.gen2Encounters=rawTables
  else rawTables={land={rate=50,slots=slots},water={rate=50,slots=water}} end
end
replaceTables(163)
function world:wildTables()return rawTables end
local ballLocked=false
local field={running=true,isLocked=function()return busy or ballLocked end,
  lock=function()ballLocked=true end,unlock=function()ballLocked=false end,
  interact=function()originalInteractions=originalInteractions+1;return 'native-interaction' end}
local doorCalls=0
local function doorFixture()
  doorCalls=doorCalls+1;map.id='TEST_BUILDING';session.map=map.id
  return true
end
world.takeWarp=doorFixture
local effects={collectActors=function(actors) actors[#actors+1]={native=true} end}
local R={getSession=function()return session end,isActive=function()return true end,uiBusy=function()return busy end}
if gen==3 then
  package.loaded['src.core.game3.runtime']=R
  package.loaded['src.core.game3.player']=player
  package.loaded['src.core.game3.field']=field
  package.loaded['src.core.game3.field_effects']=effects
  package.loaded['src.core.game3.battle']={isActive=function()return busy end}
  package.loaded['src.core.game3.warp']={isBusy=function()return false end,startDoorEntrance=doorFixture,startDoorExit=doorFixture}
  package.loaded['src.core.game3.forced_movement']={isForced=function()return false end}
  package.loaded['src.core.game3.scripting.space']={getVm=function()end}
  package.loaded['src.core.game3.field_semantics']={getVar=function(_,key)return key=='repelSteps' and session.repelSteps or 0 end}
  package.loaded['src.core.game3.battle_bridge']={startWild=function(_,_,hit,opts)return nativeBattle(hit,opts)end}
  package.loaded['src.core.game3.collision']={
    _mapDef=map.def,_widthCells=25,_heightCells=25,
    inBounds=function(x,y)return map:inBounds(x,y)end,
    isWater=function(x,y)return map:isWaterCell(x,y)end,
    isWalkable=function(x,y)return map:isWalkableCell(x,y)end,
    warpAt=function(x,y)return map:warpAtCell(x,y)end,
    canEnter=function(_,x,y,opts)return map:inBounds(x,y) and not walls[x..':'..y] and (opts.surfing or map:isWalkableCell(x,y))end}
  -- Execute the engine's actual encounter helper code against live native tables.
  local Enc=require('src.core.game3.encounters')
  Enc.tableFor=function()return rawTables end
  Enc.terrainAt=function(x,y)return map:isWaterCell(x,y) and 'water' or map:isGrassCell(x,y) and 'land' or nil end
  P.isEgg=function(mon)return mon.egg==true end
  P.speciesOf=function(mon)return mon.species end
elseif gen==2 then
  -- Real native weighted encounter selector; battle creation is a boundary fixture.
  require('src.battle.gen2.Encounter')
  package.loaded['src.battle.gen2.Mon']={new=function(_,sp,level)return {species=sp,level=level,hp=30}end}
end
local events,hooks,values={}, {}, {}
local mod={id='wildfollowers',exports={},path=root,game=game,
  read=function(_,path)return read(root..'/'..path)end,
  options={get=function(_,key)return values[key]end,define=function(_,rows)for _,r in ipairs(rows)do if values[r.key]==nil then values[r.key]=r.default end end end},
  assets={image=function(_,path)return love.graphics.newImage(root..'/'..path)end},
  events={on=function(_,name,fn)events[name]=fn end},
  hooks={wrap=function(_,name,fn)hooks[name]=fn end},
  log={info=function()end},
  world={overworld=function()return world end,startWildBattle=function(_,sp,level)return nativeBattle({species=sp,level=level})end}}
game.mods={exports={wildfollowers=mod.exports}}
local dex={exports={}}
local dexMod={game=game,exports=dex.exports,read=function(_,name)return read(dexRoot..'/'..name)end,
  content={pokemon={get=function(_,id)return data.pokemon[id]end}}}
assert(load(read(dexRoot..'/compat/species_numbers.lua')))()(dexMod)
local numbers=dex.exports.speciesNumbers
for nat=1,1025 do
  local native=numbers.speciesFromNational(nat)
  eq(native,species(nat),'National to native '..nat)
  eq(numbers.nationalOfSpecies(native),nat,'native to National '..nat)
end
eq(numbers.speciesFromNational(0),nil,'invalid zero');eq(numbers.speciesFromNational(1026),nil,'invalid high')
eq(numbers.speciesFromNational(1.5),nil,'invalid fraction')
eq(numbers.nationalOfSpecies('UNKNOWN'),nil,'unknown name')
if gen==3 then eq(numbers.nationalOfSpecies(463),399,'Bidoof 463 is National 399') end
local dexOn=true
function mod:find(id) if dexOn and id=='1025dex' then return dex end end
local Sandbox=require('src.mods.Sandbox')
local env=Sandbox.envFor({modId='wildfollowers',permissions={engine_internals=true}})
game.writeOptions=function() end
assert(Sandbox.compile(read(root..'/main.lua'),'@wildfollowers/main.lua',env))()(mod)
eq(#mod.exports.supportedGames,11,'eleven targets')
eq(values.OW_FOLLOWERS_RUN_TO_CATCH_UP,true,'old run-to-catch-up toggle is restored and enabled by default')
local optionRows=assert(load(read(root..'/options.lua')))()
local catchUpRow
for _,row in ipairs(optionRows)do if row.key=='OW_FOLLOWERS_RUN_TO_CATCH_UP' then catchUpRow=row end end
check(catchUpRow and catchUpRow.type=='toggle' and catchUpRow.label=='Run to catch up','catch-up control is exposed in mod options')
local voxelTick
local function tick(n)
  for i=1,n do
    hooks['input.step'](function()end,game,1/60)
    if voxelTick then voxelTick() end
  end
end
-- Main-menu settings reuse the mod-manager bucket and persist immediately.
game.mods.modOptions={wildfollowers=values}
local written,emitted=0,0
local originalWrite=game.writeOptions
game.writeOptions=function()written=written+1 end
game.mods.events={emit=function(_,name,ev)
 emitted=emitted+1;if events[name]then events[name](ev)end
end}
game.options=game.options or {};session.options=session.options or {}
local mainEntry,settings
if gen<3 then
 local base={{id='mods',label='MODS'},{id='cancel',label='BACK',cancel=true}}
 local rootRows=hooks['ui.options.rows'](function(_,rows)return rows end,game,base)
 eq(rootRows[2].id,'wildfollowers','main options contains WildFollowers before BACK')
 mainEntry=rootRows[2]
 local duplicate=hooks['ui.options.rows'](function(_,rows)return rows end,game,rootRows)
 eq(#duplicate,3,'main-menu hook does not duplicate section')
 local stack=game.stack
 local page
 game.stack={push=function(_,p)page=p end,pop=function()page=nil end,top=function()return page end}
 mainEntry.activate(game)
 check(page and page.sub,'WildFollowers opens native options subpage')
 settings=page.rows
 if gen==2 then eq(page.view[#page.view].label,'BACK','Gen 2 settings include native BACK row')end
 game.stack=stack
else
 local Rows=require('src.ui.game3.option_rows')
 -- Cartridge text extraction is outside this menu integration fixture.
 local flat=Rows.build({game=game,session=session,options=game.options},
   {textSpeed=true,battleScene=true,battleStyle=true,sound=true,buttonMode=true,frameType=true})
 local pageTitle
 local rootRows=Rows.group(flat,function(title,members)pageTitle=title;settings=members end)
 for _,row in ipairs(rootRows)do if row.id=='wildfollowers' then mainEntry=row end end
 check(mainEntry~=nil,'GBA main options contains WildFollowers section')
 mainEntry.activate({game=game})
 eq(pageTitle,'WILDFOLLOWERS','GBA group opens its own titled native page')
end
eq(#settings,#optionRows,'main options exposes the complete existing schema')
local speedRow,runRow
for _,row in ipairs(settings)do
 if row.id=='wildfollowers.OW_FOLLOWERS_CATCH_UP_SPEED' then speedRow=row end
 if row.id=='wildfollowers.OW_FOLLOWERS_RUN_TO_CATCH_UP' then runRow=row end
end
check(speedRow and runRow,'main options includes catch-up toggle and speed')
local context=gen==3 and {game=game} or game
check(speedRow.step(context,1),'main option changes live mod setting')
eq(values.OW_FOLLOWERS_CATCH_UP_SPEED,3,'main speed choice shares mod manager value')
eq(speedRow.value(),'3X','native page reads updated choice label')
check(runRow.step(context,1),'main toggle changes live mod setting')
eq(values.OW_FOLLOWERS_RUN_TO_CATCH_UP,false,'main toggle shares mod manager value')
eq(runRow.value(),'OFF','native page reads updated toggle label')
eq(written,2,'main setting changes persist through engine writer')
eq(emitted,2,'main setting changes emit normal mod option events')
speedRow.step(context,-1);runRow.step(context,1)
game.writeOptions=originalWrite
-- Real Mods manager writes the save-options bucket before the engine writer.
-- Separate/stale main-option buckets used to make these edits revert on reload.
local Manager=require('src.mods.ManagerState')
local manager={game=game,persistOptions=function(self)self.game:writeOptions()end}
local Serializer=require('src.core.SaveSerializer')
for _,key in ipairs({'OW_FOLLOWERS_TRAINER_SPACING','OW_FOLLOWERS_SPACING'}) do
  local other=key=='OW_FOLLOWERS_SPACING' and 'OW_FOLLOWERS_TRAINER_SPACING' or 'OW_FOLLOWERS_SPACING'
  values[other]=2.7
  for tenth=10,40 do
    -- Simulate the engine writer replacing tables during earlier saves.
    game.options.modOptions={wildfollowers={[key]=1,[other]=1}}
    game.save.options.modOptions={wildfollowers={[key]=1,[other]=1}}
    local selected=tonumber(string.format('%.1f',tenth/10))
    Manager.setOption(manager,'wildfollowers',key,selected)
    eq(values[key],selected,'Mods edit preserves selected tenth')
    eq(values[other],2.7,'Mods edit leaves other spacing unchanged')
    eq(game.options.modOptions.wildfollowers[key],selected,'root writer sees latest Mods value')
    eq(game.save.options.modOptions.wildfollowers[key],selected,'save writer sees latest Mods value')
    local loaded=assert(Serializer.decode(Serializer.encode(game.options)))
    eq(loaded.modOptions.wildfollowers[key],selected,'spacing survives real serializer round trip')
    for _,row in ipairs(settings) do
      if row.id=='wildfollowers.'..key then
        eq(row.value(),string.format('%.1f TILES',selected),'main menu displays saved spacing')
      end
    end
  end
end
values.OW_FOLLOWERS_TRAINER_SPACING=1;values.OW_FOLLOWERS_SPACING=1


tick(1);eq(#mod.exports.status().followers,0,'initial save waits for player to settle')
tick(1)
local startupOwner=gen==3 and effects._wildFollowersRewriteOwner or world._wildFollowersRewriteOwner
for _,e in ipairs(startupOwner.followers) do
  eq(e.ballPhase,'release','initial save releases companions from balls')
  check(e.cellX~=player.cellX or e.cellY~=player.cellY,'initial save avoids player tile')
end
-- Reloading the same save object must also re-arm release, even when native
-- map entry arrives after save.loaded and while the field is still busy.
values.follower_count=6
events['save.loading']();busy=true;events['save.loaded']()
events['map.entered']({fromMap=map.id,toMap=map.id});tick(20)
eq(#mod.exports.status().followers,0,'busy save load keeps companions recalled')
busy=false;tick(2)
eq(#startupOwner.followers,6,'same-session save reload restores six companions')
local loadedCells={}
for _,e in ipairs(startupOwner.followers) do
  eq(e.ballPhase,'release','save.loaded uses door release animation')
  check(not (e.cellX==player.cellX and e.cellY==player.cellY),'save.loaded avoids player tile')
  check(not map:warpAtCell(e.cellX,e.cellY) and not walls[e.cellX..':'..e.cellY],'save.loaded avoids warps and walls')
  local key=e.cellX..':'..e.cellY;check(not loadedCells[key],'save.loaded reserves separate companion tiles');loadedCells[key]=true
  eq(e.mon,session.party[e.slot],'save release preserves exact party object')
end
tick(180)
local status=mod.exports.status()
check(#status.actors>0,'visible wilds created')
for _,e in ipairs(status.actors)do
  eq(e.national,numbers.nationalOfSpecies(e.species),'sprite/battle identity')
  check(not map:warpAtCell(e.x,e.y) and not walls[e.x..':'..e.y],'no warp or wall spawn')
  check(e.level>=6 and e.level<=9,'native encounter levels')
end
local function nativeRoll()return {species=species(16),level=5} end
check(hooks['encounter.roll'](nativeRoll,{}, {terrain=status.actors[1].kind})==nil,'ordinary replacement when visible')
local roamer={species=species(243),level=40,roamer=true}
eq(hooks['encounter.roll'](function()return roamer end,{},{}),roamer,'roamer survives')
check(hooks['encounter.roll'](nativeRoll,{}, {kind='contest'})~=nil,'contest survives')
eq(hooks['encounter.roll'](function()return nil end,{},{}),nil,'failed native roll remains nil')
values.WE_VANILLA_RANDOM=true
check(hooks['encounter.roll'](nativeRoll,{}, {})~=nil,'random battles option')
values.WE_VANILLA_RANDOM=false
-- The same assets enter each native compositor with the correct coordinate convention.
local drawn={};local graphics=love.graphics;local originalDraw=graphics.draw
graphics.draw=function(img,quad,x,y,rotation,sx,sy)drawn[#drawn+1]={x=x,y=y,sx=sx,sy=sy,quad=quad}end
local actor
if gen==3 then
  local list={};effects.collectActors(list);check(list[1].native,'native actors preserved');actor=list[2]
  local under,over=require('src.core.game3.field_view').applyDrawOrder({actor},{},{},20)
  eq(#under+#over,1,'native GBA depth compositor accepts actor')
else for _,e in ipairs(world.npcs)do if not e.follower then actor=e;break end end end
check(actor~=nil,'native renderer receives actor')
local originalSurface=actor.surface;actor.surface='land' -- standing-anchor checks use a full land frame
local originalMapY,originalSortY=actor.y,actor.sortY
check(not actor.pikachuFollower,'custom actor cannot impersonate the native story follower')
eq(actor.mapId,map.id,'actors belong to the current map')
local sprite,poseX,poseY=actor:pose()
eq(poseX,actor.px,'native pose X');eq(poseY,actor.py,'native pose Y')
local footprint=require('src.render.TileRenderer').feetStrip(poseX,poseY,sprite)
check(footprint~=nil,'native grass renderer accepts actor pose')
actor:draw(10,20,2)
check(#drawn>0,'actor draws a sprite')
local d=drawn[#drawn]
if gen==2 then
  check(math.abs(d.x-(10+(actor.px-8)*2))<1e-9,'Gen2 positive offset');eq(d.sx,1,'Gen2 output scale')
  check(math.abs(d.y-(20+(actor.py-20)*2))<1e-9,'Gen2 native foot anchor')
else
  eq(d.x,actor.px-18,'GB1/GBA camera subtraction');eq(d.sx,.5,'GB1/GBA output scale')
  eq(d.y,actor.py-20-(gen==3 and 16 or 20),'native camera and foot anchor')
end
-- Compare the custom frame origin to the installed native drawing code.
-- This catches a shared GB anchor accidentally being applied to GBA again.
local probe=setmetatable({px=160,py=224,national=actor.national,moving=false,
  hidden=false,facing='down',clock=0},{__index=actor})
probe:draw(10,20,2)
local custom=drawn[#drawn]
if gen==3 then
  local Ow=require('src.core.game3.ow_sprites');local originalGetDraw=Ow.getDraw
  local nativeFrame={width=32,height=32,frameCount=1,image={},quads={[0]={}}}
  Ow.getDraw=function()return nativeFrame end
  check(Ow.draw('PLACEMENT_FIXTURE',probe.px,probe.py,10,20,'down',0,false),'native GBA frame draws')
  Ow.getDraw=originalGetDraw
  local native=drawn[#drawn]
  eq(custom.x,native.x,'GBA custom/native horizontal origin')
  eq(custom.y,native.y,'GBA custom/native vertical origin')
  eq(custom.y+custom.quad.h*custom.sy,native.y+nativeFrame.height,'GBA custom/native feet')
  eq(actor.y,originalMapY,'GBA anchor leaves map Y unchanged')
  eq(actor.sortY,originalSortY,'GBA anchor leaves depth Y unchanged')
else
  local Renderer=require('src.render.SpriteRenderer')
  local geometry={anchorX=16,anchorY=32}
  local nx,ny=Renderer.getScreenOrigin(geometry,probe.px,probe.py,gen==1 and 10 or 0,gen==1 and 20 or 0)
  if gen==2 then nx,ny=10+nx*2,20+ny*2 end
  eq(custom.x,nx,'GB custom/native horizontal origin')
  eq(custom.y,ny,'GB custom/native vertical origin')
end
if gen==2 then
  local before=#drawn
  local World=require('src.world.gen2.World')
  local composite={isCrystal=function()return true end,drawGrassOver=function()end}
  actor.inGrass=true
  World.drawEntityComposite(composite,actor,10,20,2,function(row,x,y,s)actor:draw(x,y,s,row)end,false,false)
  eq(#drawn,before+2,'native Crystal split compositor')
  local bottom,top=drawn[before+1],drawn[before+2]
  eq(top.x,bottom.x,'Crystal slices share horizontal origin')
  eq(top.y,20+(actor.py-20)*2,'Crystal top starts at native full-frame origin')
  eq(top.quad.h*top.sy,24*2,'Crystal top covers first 24 output pixels')
  eq(bottom.quad.h*bottom.sy,8*2,'Crystal bottom covers final 8 output pixels')
  eq(top.y+top.quad.h*top.sy,bottom.y,'Crystal slices join without a gap')
  eq(bottom.quad.y,top.quad.y+top.quad.h,'Crystal source crops join without a gap')
  local _,feetTop,_,feetBottom=require('src.world.gen2.OamFootprint').feetStrip(actor)
  eq(bottom.y,20+feetTop*2,'Crystal bottom starts at native grass footprint')
  eq(bottom.y+bottom.quad.h*bottom.sy,20+feetBottom*2,'Crystal bottom ends at native grass footprint')
end
actor.surface=originalSurface
graphics.draw=originalDraw
local waterModules={}
local function waterInclude(name)
  if not waterModules[name] then waterModules[name]=assert(Sandbox.compile(read(root..'/src/'..name..'.lua'),'@water-test/'..name,env))()(mod,waterInclude) end
  return waterModules[name]
end
assert(load(read(root..'/tests/water_rendering.lua')))()(waterInclude,mod,values,world,player,gen,root,check,eq)
local verifyVoxelDispose
verifyVoxelDispose,voxelTick=assert(load(read(root..'/tests/voxel.lua')))()(mod,events,actor,values,gen,root,check,eq)
if gen==1 then
  local A=waterInclude('adapter');local oldTables,oldField=data.encounters,data.field
  local oldFishingGroups=oldField.superRod
  local shared={grass={rate=25,slots={{species='NIDORAN_M',level=12}}},water={rate=25,slots={{species='TENTACOOL',level=12}}}}
  data.encounters={NATIVE_SURF_ROUTE=shared}
  local area={id='NATIVE_SURF_ROUTE'}
  eq(A:tables('water',area),shared.water,'Gen 1 uses separate native water table')
  local hit=A:choose('water',function(lo)return lo end,area)
  eq(hit.species,'TENTACOOL','mixed map selects water species rather than Nidoran')
  local native=require('src.world.Encounter').roll({grass=shared.water},function()return 0 end)
  eq(native.species,hit.species,'matches native surfing caller table conversion')
  shared.water.rate=0
  eq(A:tables('water',area),shared.water,'disabled water table remains separate')
  eq(A:choose('water',function(lo)return lo end,area),nil,'disabled explicit water table stays disabled')
  shared.water=nil
  eq(A:tables('water',area),nil,'missing water table cannot use grass')
  eq(A:choose('water',function(lo)return lo end,area),nil,'grass-only map cannot create water wild')
  eq(A:choose('land',function(lo)return lo end,area).species,'NIDORAN_M','land table remains available')
  data.field.superRod={NATIVE_SURF_ROUTE={{species='POLIWAG',level=15},{species='GOLDEEN',level=15}}}
  eq(A:choose('water',function(lo)return lo end,area).species,'POLIWAG','pond uses its native fishing pool')
  eq(A:choose('water',function(lo,hi)return hi end,area).species,'GOLDEEN','fishing fallback samples all native slots')
  shared.water={rate=0,slots={{species='TENTACOOL',level=12}}}
  eq(A:choose('water',function(lo)return lo end,area),nil,'disabled surf table suppresses fishing fallback')
  shared.water=nil
  -- Read each cartridge's imported tables, rather than inventing their shape.
  local imported=assert(load(read(os.getenv('APPDATA')..'/pokemon-love2d/'..version..'/data/generated/encounters.lua')))()
  data.field=assert(load(read(os.getenv('APPDATA')..'/pokemon-love2d/'..version..'/data/generated/field.lua')))()
  data.encounters=imported
  local wet,dry=0,0
  for id,entry in pairs(imported) do
    local source={id=id}
    local fish=data.field.superRod[id]
    local expectedTable=entry.water or fish and {slots=fish}
    eq(A:tables('water',source) and A:tables('water',source).slots,expectedTable and expectedTable.slots,'actual imported water/fishing slots '..id)
    eq(A:tables('land',source),entry.grass,'actual imported land table '..id)
    if not entry.water and not fish then
      dry=dry+1
      eq(A:choose('water',function(lo)return lo end,source),nil,'actual grass-only map rejects water spawn '..id)
    elseif entry.water and entry.water.rate>0 then
      wet=wet+1
      local chosen=A:choose('water',function(lo)return lo end,source)
      local expected=require('src.world.Encounter').roll({grass=entry.water},function()return 0 end)
      eq(chosen.species,expected.species,'actual surfing species '..id)
      eq(chosen.level,expected.level,'actual surfing level '..id)
    end
  end
  check(wet>0 and dry>0,'imported dataset covers surfing and grass-only maps')
  oldField.superRod=oldFishingGroups
  data.encounters,data.field=oldTables,oldField
end

-- A press uses the visible native species and level, then removes the actor.
local target=status.actors[1]
player.cellX,player.cellY=target.x,target.y-1;player.px,player.py=player.cellX*16,player.cellY*16;player.facing='down'
local interact=gen==3 and function()return field.interact(game)end or function()return world:interact()end
check(interact()==true,'visible interaction starts battle')
eq(battleCalls,1,'one battle only');eq(exactSpecies,target.species,'visible species enters battle');eq(exactLevel,target.level,'visible level enters battle')
if gen==3 then check(exactOpts.__completeDexExact,'1025Dex cannot reroll a visible species') end
eq(#mod.exports.status().actors,0,'battle clears actors')
interact();eq(battleCalls,1,'no duplicate battle while busy')
busy=false;events['battle.ended']();values.WE_OW_ENCOUNTERS=false
values.follower_count=6;events['mod.options_changed']({mod='wildfollowers'});player.cellX=8;player.cellY=8;player.px=128;player.py=128
tick(1)
for step=1,10 do player.cellX=8+step;player.px=player.cellX*16;tick(18) end
status=mod.exports.status();eq(#status.followers,6,'six followers')
if gen<3 then
  local nativeFollower=require(gen==1 and 'src.world.PikachuFollower' or 'src.world.gen2.Follower')
  eq(nativeFollower.current(world),nil,'native follower manager ignores custom followers')
  local stock={pikachuFollower=true}
  table.insert(world.npcs,stock)
  eq(nativeFollower.current(world),stock,'native follower remains discoverable')
  table.remove(world.npcs)
end
check(status.followers[1].x>8,'leader follows actual trail')
check(status.followers[6].x>=8,'last follower keeps trail')
-- Eggs and fainted mons never become followers; party reorder is observed live.
session.party[1].egg=true;session.party[2].hp=0;tick(1)
eq(#mod.exports.status().followers,4,'egg/fainted filter')
session.party[1].egg=false;session.party[2].hp=30
local previous=mod.exports.status().followers[1].species
session.party[1],session.party[6]=session.party[6],session.party[1];tick(1)
check(mod.exports.status().followers[1].species~=previous,'party reorder takes effect')
-- Busy UI freezes actors and leaves the rendered world intact.
local before=mod.exports.status().followers[1].x;busy=true;tick(30)
eq(mod.exports.status().followers[1].x,before,'no movement through dialog');busy=false
-- Travel/new save resets all transient state, even when map ID is unchanged.
local oldSession=session;session={version=version,map=map.id,party={},repelSteps=0};game.save=session;game.session=session
tick(1);eq(#mod.exports.status().followers,0,'new campaign session has no stale followers')
session=oldSession;game.save=session;game.session=session
events['save.loading']();eq(#mod.exports.status().actors,0,'loading clears wilds')
values.WE_OW_ENCOUNTERS=true;values.OW_FOLLOWERS_ENABLED=false;values.WE_OW_WATER=false
events['mod.options_changed']({mod='wildfollowers'});player.cellX=12;player.cellY=12;tick(180)
for _,e in ipairs(mod.exports.status().actors)do eq(e.kind,'land','water off') end
-- Live Dex provider can replace species without hard-coded native ID arithmetic.
local transforms=0
if gen==3 then dex.exports.chooseWildEncounter=function(_,kind,level)transforms=transforms+1;return {},species(399),level end
else dex.exports.chooseGBWildEncounter=function(hit)transforms=transforms+1;return {species=species(399),level=hit.level}end end
events['mod.options_changed']({mod='1025dex'});tick(180)
check(transforms>0,'Dex public encounter API used')
check(#mod.exports.status().actors>0,'expanded visible roster')
for _,e in ipairs(mod.exports.status().actors)do eq(e.national,399,'Bidoof canonical sprite') end
-- Species rarity is specific to visible selection and uses National identity
-- after the live Dex provider has mapped the cartridge's species numbering.
local rarityAdapter=assert(Sandbox.compile(read(root..'/src/adapter.lua'),'@wildfollowers/rarity-adapter',env))()(mod)
local providerKey=gen==3 and 'chooseWildEncounter' or 'chooseGBWildEncounter'
local originalProvider=dex.exports[providerKey]
local forcedNational=924
if gen==3 then dex.exports[providerKey]=function(_,_,level)return {},species(forcedNational),level end
else dex.exports[providerKey]=function(hit)return {species=species(forcedNational),level=hit.level}end end
local passes,rarityRolls=0,0
for roll=1,1000 do
  local hit=rarityAdapter:choose('land',function(lo,hi)
    if lo==1 and hi==1000 then rarityRolls=rarityRolls+1;return roll end
    return lo
  end)
  if hit then passes=passes+1;eq(rarityAdapter:national(hit.species),924,'rare visible selection preserves Tandemaus identity') end
end
eq(rarityRolls,1000,'every Tandemaus selection uses visible rarity gate')
eq(passes,1,'only one in 1000 eligible Tandemaus selections becomes a visible spawn')
forcedNational=399;local unexpectedRarityRoll=false
local ordinaryHit=rarityAdapter:choose('land',function(lo,hi)
  if lo==1 and hi==1000 then unexpectedRarityRoll=true end
  return lo
end)
check(ordinaryHit and rarityAdapter:national(ordinaryHit.species)==399,'other overworld species remain available')
check(not unexpectedRarityRoll,'other species bypass Tandemaus rarity gate')
replaceTables(163)
forcedNational=399
check(rarityAdapter:choose('water',function(lo)return lo end)~=nil,'water fixture samples an eligible species')
forcedNational=278
for _,habitat in ipairs({'land','water'})do
  eq(rarityAdapter:choose(habitat,function(lo)return lo end),nil,'Wingull excluded from visible '..habitat..' wilds')
end
forcedNational=279
for _,habitat in ipairs({'land','water'})do
  local hit=rarityAdapter:choose(habitat,function(lo)return lo end)
  check(hit and rarityAdapter:national(hit.species)==279,'Pelipper remains eligible for '..habitat)
end
dex.exports[providerKey]=originalProvider
session.repelSteps=100;for _,mon in ipairs(session.party)do mon.level=100 end
mod.exports.clearAll();tick(180)
eq(#mod.exports.status().actors,0,'repel blocks weaker visible mons')
check(hooks['encounter.roll'](nativeRoll,{}, {})~=nil,'empty visible pool preserves native encounter path')
session.repelSteps=0
-- Door animations run through the installed runtime wrappers for every game.
values.OW_FOLLOWERS_ENABLED=true;values.follower_count=6;values.WE_OW_ENCOUNTERS=false
mod.exports.clearAll();tick(1)
local owner=gen==3 and effects._wildFollowersRewriteOwner or world._wildFollowersRewriteOwner
local door=gen==3 and package.loaded['src.core.game3.warp'].startDoorEntrance or world.takeWarp
door(world,{destMap='TEST_BUILDING'})
eq(doorCalls,0,'door waits for visible recall')
eq(owner.followers[1].ballPhase,'recall','door starts shrink animation')
local animated=owner.followers[1];local oldScale,oldCircle,oldArc=graphics.scale,graphics.circle,graphics.arc
graphics.arc=oldArc or function()end
local scales,circles={},{}
graphics.scale=function(x,y)scales[#scales+1]=x;if oldScale then oldScale(x,y) end end
graphics.circle=function(mode,x,y,r)circles[#circles+1]={x=x,y=y,r=r};if oldCircle then oldCircle(mode,x,y,r) end end
animated.ballTime=.10;animated:draw(10,20,2)
local shrink=scales[#scales];local ball=circles[#circles]
check(shrink<1 and shrink>0 and ball~=nil,'recall shrinks body and draws ball')
animated.ballPhase='release';animated.ballTime=.20;animated:draw(10,20,2)
check(math.abs(scales[#scales]-shrink)<.00001,'release exactly reverses body scale')
eq(circles[#circles].x,ball.x,'reverse ball preserves horizontal anchor')
eq(circles[#circles].y,ball.y,'reverse ball preserves vertical anchor')
-- The ball starts closed, separates into two shells, and emits cyan rays
-- around a white flash. Its effect is drawn once in Crystal's split pass.
local oldPolygon,oldColor=graphics.polygon,graphics.setColor
local polygons,cyan,white=0,false,false
local function resetBurst()polygons=0;cyan=false;white=false end
 graphics.polygon=function(...)polygons=polygons+1;if oldPolygon then oldPolygon(...)end end
 graphics.setColor=function(r,g,b,a)
   if r==.35 and g==.95 and b==1 and a>0 then cyan=true end
   if r==1 and g==1 and b==1 and a>0 then white=true end
   if oldColor then oldColor(r,g,b,a)end
 end
animated.ballPhase='release';animated.ballTime=0;resetBurst();animated:draw(10,20,2)
check(polygons==4 and not cyan,'closed release ball is visible before flash')
animated.ballTime=.081;resetBurst();animated:draw(10,20,2)
check(polygons==13 and cyan and white,'opening ball emits cyan rays and white starburst')
animated.ballPhase='recall';animated.ballTime=.219;resetBurst();animated:draw(10,20,2)
check(polygons==13 and cyan and white,'recall reverses the opening flash')
if gen==2 then
 resetBurst();animated:draw(10,20,2,'top')
 check(polygons==0,'Crystal top OAM pass does not duplicate burst')
end
 graphics.polygon,graphics.setColor=oldPolygon,oldColor
graphics.scale,graphics.circle,graphics.arc=oldScale,oldCircle,oldArc
animated.ballPhase='recall';animated.ballTime=0
door(world,{destMap='TEST_BUILDING'});tick(8)
eq(doorCalls,0,'repeat door request is suppressed while recalling')
check(owner.followers[1].ballTime>0,'recall advances before warp')
while doorCalls==0 do tick(1) end
eq(doorCalls,1,'native doorway runs exactly once after recall')
events['map.entered']({fromMap='TEST_ROUTE',toMap='TEST_BUILDING'})
-- The map event precedes the scheduled door walk-out. No companion should
-- release in that gap or while the player is interpolating onto the doorstep.
tick(1)
eq(#owner.followers,0,'arrival waits through the pre-step map-entry frame')
world.scriptMoves={{entity=player,remaining=1}};tick(2)
eq(#owner.followers,0,'arrival waits for queued door step')
world.scriptMoves={};player.moving=true;player.targetX=player.cellX;player.targetY=player.cellY+1
tick(12);eq(#owner.followers,0,'arrival stays recalled during door walk-out')
player.cellY=player.targetY;player.py=player.cellY*16;player.moving=false;player.targetX=nil;player.targetY=nil
tick(1);eq(#owner.followers,0,'arrival lets native movement settle after landing')
tick(1)
local placed={}
for _,e in ipairs(owner.followers) do
  eq(e.ballPhase,'release','arrival reverses ball animation')
  check(not (e.cellX==player.cellX and e.cellY==player.cellY),'release never overlaps player')
  check(map:isWalkableCell(e.cellX,e.cellY) and not map:warpAtCell(e.cellX,e.cellY),'release uses legal floor away from warps')
  local key=e.cellX..':'..e.cellY;check(not placed[key],'each follower gets a separate tile');placed[key]=true
end
eq(math.abs(owner.followers[1].cellX-player.cellX)+math.abs(owner.followers[1].cellY-player.cellY),1,'lead releases next to player')
tick(20)
for _,e in ipairs(owner.followers) do check(not e.ballPhase and not e.hidden,'release finishes visibly while stationary') end
for step=1,4 do
  player.cellX=player.cellX+1;player.px=player.cellX*16;player.facing='right';tick(30)
end
local rejoined=false
for _,e in ipairs(owner.followers) do if not e.arrivalAnchor and e.trailStep>0 then rejoined=true end end
check(rejoined,'released companions rejoin recorded trail in flexible order')
player.cellX=12;player.px=192
-- No legal floor keeps companions hidden until space becomes available.
mod.exports.clearAll();owner.ballArrival=true
local walkable=map.isWalkableCell;map.isWalkableCell=function()return false end
tick(2)
for _,e in ipairs(owner.followers) do check(e.hidden and e.awaitingTile,'no legal placement remains hidden') end
map.isWalkableCell=walkable;tick(1)
for _,e in ipairs(owner.followers) do check(not e.hidden and e.ballPhase=='release','placement retries when floor becomes available') end
-- Save/session teardown cancels a queued doorway and releases its input lock.
door(world,{destMap='TEST_BUILDING'});mod.exports.clearAll();tick(20)
eq(doorCalls,1,'clear cancels queued native warp');check(not ballLocked and not player.inputLocked,'clear releases recall input gate')
if gen==1 then
  -- Gen 1's tile numbers are tileset-local: 0x14 is also an indoor door and
  -- 0x32 is a bookshelf, despite Map's raw water/shore lookup matching both.
  local NativeMap=require('src.world.Map')
  local def={id='INDOOR_WATER_ID_FIXTURE',width=2,height=2,tileset='REDS_HOUSE_1',
    blocks={0,0,0,1},warps={{x=2,y=3,destMap='TEST_ROUTE'}}}
  local floor,door={},{};for i=1,16 do floor[i]=1;door[i]=1 end
  floor[5]=0x32;door[13]=0x14
  local nativeIndoor=NativeMap.new(def,{walkable={1,0x14},blocks={floor,door}})
  local previousMap,previousWaterSets=world.map,data.field.waterTilesets
  world.map=nativeIndoor;data.field.waterTilesets={'OVERWORLD'}
  player.cellX,player.cellY,player.px,player.py=2,3,32,48
  owner:saveLoading();tick(2)
  check(nativeIndoor:isWaterCell(2,3),'native raw lookup demonstrates door/water ID reuse')
  check(nativeIndoor:isWaterCell(0,0),'native raw lookup demonstrates bookshelf/shore ID reuse')
  check(not rarityAdapter:water(2,3),'adapter rejects water classification on house door')
  check(not rarityAdapter:water(0,0,rarityAdapter:area()),'area water query rejects house bookshelf')
  eq(#owner.followers,6,'house entrance releases six companions on floor')
  for _,e in ipairs(owner.followers) do
    eq(e.surface,'land','house release uses land surface')
    check(nativeIndoor:isWalkableCell(e.cellX,e.cellY),'house release uses native walkable floor')
    check(not nativeIndoor:warpAtCell(e.cellX,e.cellY),'house release excludes door warp')
  end
  -- Missing tileset metadata uses the native vanilla allowlist, while explicit
  -- custom water tilesets are supported through the imported field table.
  data.field.waterTilesets=nil
  check(not rarityAdapter:water(0,0),'stale-cache fallback excludes indoor shelf tileset')
  nativeIndoor.def.tileset='CUSTOM_WATER';data.field.waterTilesets={'CUSTOM_WATER'}
  check(rarityAdapter:water(0,0),'explicit custom water tileset is honored')
  world.map=previousMap;data.field.waterTilesets=previousWaterSets
  player.cellX,player.cellY,player.px,player.py=12,12,192,192
  mod.exports.clearAll()
end
-- Gen 1 population creation/publishing/drawing from the actual Route 19 table.
if gen==1 then
  local waterFn,grassFn,oldTables,oldWaterSets=map.isWaterCell,map.isGrassCell,data.encounters,data.field.waterTilesets
  local previousDex=dexOn;dexOn=false
  map.isWaterCell=function(self,x,y)return self:inBounds(x,y)end
  map.isGrassCell=function()return false end
  data.field.waterTilesets={'OVERWORLD'}
  local imported=assert(load(read(os.getenv('APPDATA')..'/pokemon-love2d/'..version..'/data/generated/encounters.lua')))()
  data.encounters={[map.id]=imported.ROUTE_19}
  values.OW_FOLLOWERS_ENABLED=false;values.WE_OW_ENCOUNTERS=true;values.WE_OW_WATER=true
  player.moving=false;player.targetX=nil;player.targetY=nil;busy=false
  mod.exports.clearAll();tick(180)
  local population=mod.exports.status().actors
  check(#population>0,'actual Gen 1 Route 19 water table spawns visible water wilds')
  for _,e in ipairs(population) do
    eq(e.kind,'water','Gen 1 surf population stays on water')
    eq(e.species,'TENTACOOL','Gen 1 surf population uses native aquatic species')
  end
  local bodies=0;local renderFrames={}
  local restoreDraw=graphics.draw
  graphics.draw=function(img,q) bodies=bodies+1;renderFrames[q.x]=true end
  for _,e in ipairs(world.npcs) do if not e.follower then e:draw(0,0,1) end end
  check(bodies>0,'Gen 1 published water wilds actually draw their bodies')
  local wild=owner.wilds[1];wild.moving=false;wild.targetX=nil;wild.targetY=nil
  local committed=false
  for _,d in ipairs({{1,0},{-1,0},{0,1},{0,-1}}) do
    if owner:move(wild,wild.cellX+d[1],wild.cellY+d[2]) then committed=true;break end
  end
  check(committed,'Gen 1 water wild commits a legal native-runtime roaming step')
  renderFrames={}
  for _=1,9 do owner:animate(wild,1/60);wild:draw(0,0,1) end
  local poses=0;for _ in pairs(renderFrames)do poses=poses+1 end
  eq(poses,4,'short real Gen 1 water step renders every walking pose')
  graphics.draw=restoreDraw
  data.encounters={[map.id]={grass={rate=25,slots={{species='NIDORAN_M',level=12}}}}}
  mod.exports.clearAll();tick(180)
  eq(#mod.exports.status().actors,0,'grass-only Nidoran table cannot publish actors on water')
  map.isWaterCell,map.isGrassCell,data.encounters,data.field.waterTilesets=waterFn,grassFn,oldTables,oldWaterSets
  dexOn=previousDex
  values.WE_OW_WATER=false;mod.exports.clearAll()
end
assert(load(read(root..'/tests/story_events.lua')))()(mod,values,world,player,owner,gen,tick,check,eq)
assert(load(read(root..'/tests/mega_sprites.lua')))()(mod,values,data,P,gen,Sandbox,env,check,eq,function(expected)
  eq(exactSpecies,expected,'native battle receives exact alternate-form species');busy=false
end)
-- Failed assets cannot suppress random encounters.
assert(load(read(root..'/tests/spawn_amounts.lua')))()(mod,values,player,owner,tick,replaceTables,check,eq)
if gen==1 then
  assert(load(read(root..'/tests/native_pond.lua')))()(mod,values,world,player,data,owner,dex,root,dexRoot,version,tick,check,eq)
end
local oldImage=mod.assets.image;mod.assets.image=function()error('asset unavailable')end
mod.exports.dispose()
assert(Sandbox.compile(read(root..'/main.lua'),'@wildfollowers/reload.lua',env))()(mod)
tick(90);eq(#mod.exports.status().actors,0,'missing assets create no false visible actors')
check(hooks['encounter.roll'](nativeRoll,{}, {})~=nil,'missing assets preserve native battles')
mod.assets.image=oldImage;mod.exports.dispose()
if verifyVoxelDispose then verifyVoxelDispose() end
eq(#world.npcs,0,'dispose removes owned NPCs')
check(world.entities[1]==player,'dispose preserves player')
print(('PASS %s rewrite: %d assertions (sandbox/native samplers/identity/field fixtures)'):format(version,checks))
