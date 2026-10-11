-- Integration fixture: the engine's real Player implementations own every
-- commitment and interpolation. Only world geometry and UI boundaries are fake.
local root,version=arg[1],arg[2]
local function read(path)local f=assert(io.open(path,'rb'));local s=f:read('*a');f:close();return s end
local checks=0
local function check(ok,message)checks=checks+1;assert(ok,version..': '..message)end
local function eq(a,b,message)check(a==b,message..' ['..tostring(a)..' vs '..tostring(b)..']')end
local function near(a,b,message)check(math.abs(a-b)<0.001,message..' ['..tostring(a)..' vs '..tostring(b)..']')end
love=require('tests.love_stub')
local GV=require('src.core.GameVersion');GV.set(version)
local gen=GV.generation()
local names={'BULBASAUR','IVYSAUR','VENUSAUR','CHARMANDER','CHARMELEON','CHARIZARD'}
local data={pokemon={},sprites={SPRITE_RED={image=root..'/assets/g9rpsprites/001-normal.png',frames=6}},
  field={playerSprites={walk='SPRITE_RED'}},constants={world={stepFrames=16,bikeStepFrames=8}}}
local session={version=version,map='NATIVE_MOVEMENT_ROUTE',party={},flags={},inventory={}}
for i,name in ipairs(names)do
  data.pokemon[name]={id=name,dex=i}
  session.party[i]={species=gen==3 and i or name,hp=30,maxHp=30,level=12}
end
local menu=false
local forcedState=false
local ledgeX,ledgeY
local map={id=session.map,def={id=session.map,tileset='OVERWORLD',environment='ROUTE'},
  widthCells=96,heightCells=96}
function map:inBounds(x,y)return x>=0 and y>=0 and x<self.widthCells and y<self.heightCells end
function map:isWaterCell()return false end
function map:isWalkableCell(x,y)return self:inBounds(x,y) and not (x==ledgeX and y==ledgeY)end
map.isWalkable=map.isWalkableCell
function map:isGrassCell()return false end
function map:cellCollision()return 0 end
function map:cellTile(x,y)return x==ledgeX and y==ledgeY and 2 or 1 end
-- Native Gen 1 stores warpAt as a TABLE. Its callable API is warpAtCell.
-- Gen 2 uses a separate lookup table and exposes both callable spellings.
if gen==1 then
  local Map=require('src.world.Map')
  map.warpAt={};map.warpAtCell=Map.warpAtCell
else
  local Map=require('src.world.gen2.Map')
  map._warpAt={};map.warpAt=Map.warpAt;map.warpAtCell=Map.warpAtCell
end
local world={map=map,npcs={},entities={},isOverworld=true,scriptMoves={}}
local game={data=data,save=session,session=session,world=world,overworld=world,
  phase=gen==2 and 'play' or 'field',stack={states={}}}
world.game=game
if gen==1 then game.stack.states={world}end
function game.stack:top()return self.states[#self.states]end
function world:busy()return menu end
function world:interact()return false end
local effects={collectActors=function()end,tallGrassAt=function()end,leaveTallGrass=function()end}
local field={running=true,isLocked=function()return menu end,interact=function()end,
  locked=false,tryCoordEvents=function()end}
local function no()return false end
local player
if gen==3 then
  local Collision={_grid={1},_mapDef={},_widthCells=96,_heightCells=96,
    inBounds=function(x,y)return map:inBounds(x,y)end,
    nextElevation=function()return 3,3 end,elevationAt=function()return 3 end,
    isWater=no,isGrass=no,isSurfDismount=no,isStairWarpBehavior=no,isWarpDoor=no,behavior=function()return 0 end,
    isWalkable=function(x,y)return map:isWalkableCell(x,y)end,
    arrowWarpDir=function()end,warpAt=function(x,y)return map:warpAtCell(x,y)end,tryWarpAt=no,
    ledgeLanding=function(_,x,y,dir)
      if dir=='right' and x+1==ledgeX and y==ledgeY then return x+2,y end
    end,
    canEnter=function(_,x,y)
      if not map:isWalkableCell(x,y)then return false,'tile' end
      for _,e in ipairs(world.entities)do
        if e~=world.player and not e.passable and
            (e.cellX==x and e.cellY==y or e.targetX==x and e.targetY==y)then
          return false,'entity'
        end
      end
      return true
    end}
  package.loaded['src.core.game3.collision']=Collision
  package.loaded['src.core.game3.runtime']={getSession=function()return session end,isActive=function()return true end,uiBusy=function()return menu end}
  package.loaded['src.core.game3.field']=field
  package.loaded['src.core.game3.field_effects']=effects
  package.loaded['src.core.game3.battle']={isActive=no}
  package.loaded['src.core.game3.warp']={isBusy=no,ownsPlayerSprite=no}
  package.loaded['src.core.game3.forced_movement']={
    isForced=function()return forcedState end,isForcedMovementTile=no,onStepFinished=no}
  package.loaded['src.core.game3.scripting.space']={getVm=function()end}
  package.loaded['src.core.game3.bike']={rse=function()end}
  package.loaded['src.core.game3.field_moves']={isRse=no}
  package.loaded['src.core.game3.step_events']={onStepTaken=function()end}
  package.loaded['src.core.game3.trainer_sight']={check=function()end}
  package.loaded['src.core.game3.encounters']={onStep=function()end,noteGrass=function()end,
    terrainAt=function()end,tableFor=function()end}
  package.loaded['src.core.game3.audio']={playSe=function()end}
  package.loaded['src.core.game3.profile']={forSession=function()return {map={scriptStepEvents=false}}end}
  local P=require('src.core.game3.pokemon')
  P._names={};P._byName={};P._national={toNational={},toSpecies={}}
  for i,name in ipairs(names)do P._names[i]=name;P._byName[name]=i;P._national.toNational[i]=i;P._national.toSpecies[i]=i end
  player=require('src.core.game3.player');player.reset(12,12,'right')
elseif gen==2 then
  player=require('src.world.gen2.Player').new(12,12,'right')
else
  -- Player:stepLength reads the service owner dynamically, exactly as it does
  -- during native overworld walking and movement.speed hooks.
  package.loaded['src.core.Game']=game
  player=require('src.world.Player').new(data,12,12,'right')
end
world.player=player;world.entities={player}
local values={enabled=true,OW_FOLLOWERS_ENABLED=true,follower_count=6,
  WE_OW_ENCOUNTERS=false,WE_OW_WATER=true}
local mod={id='wildfollowers',game=game,exports={},
  read=function(_,name)return read(root..'/'..name)end,
  options={get=function(_,key)return values[key]end},
  assets={image=function(_,name)return love.graphics.newImage(root..'/'..name)end},
  world={overworld=function()return world end},find=function()end}
game.mods={exports={wildfollowers=mod.exports}}
local Sandbox=require('src.mods.Sandbox')
local env=Sandbox.envFor({modId='wildfollowers',permissions={engine_internals=true}})
local modules={}
local function include(name)
  if not modules[name]then
    local chunk=assert(Sandbox.compile(read(root..'/src/'..name..'.lua'),'@wildfollowers/'..name,env))
    modules[name]=chunk()(mod,include)
  end
  return modules[name]
end
local C=include('controller')
local function tick(n)
  for _=1,n or 1 do C:tick(game,1/60)end
end
local function advance(n)
  for _=1,n do
    if gen==3 then player.tick(game)else player:update()end
    tick()
  end
end
local function frames()return player.stepFramesCur or player.stepFrames or 16 end
local function start(dir,run)
  local result
  for _=1,8 do
    result=gen==3 and player.tryMove(dir,game,run)or player:tryMove(dir,map,world.entities)
    if player.moving then break end
    advance(1)
  end
  check(player.moving,'native player commits '..dir..' ('..tostring(result)..')')
  tick()
  return result
end
local route={{x=12,y=12}}
local function step(dir,run)
  start(dir,run);local duration=frames();advance(duration)
  check(not player.moving,'native player completes '..dir)
  route[#route+1]={x=player.cellX,y=player.cellY}
end
local delta={right={1,0},down={0,1},left={-1,0},up={0,-1}}
tick()
eq(#C.followers,0,'startup waits for loaded player to settle')
tick()
eq(#C.followers,6,'six party followers exist at startup')
local occupied={}
for _,e in ipairs(C.followers)do
  check(not e.hidden and e.ballPhase=='release','startup follower releases from ball')
  check(e.cellX~=player.cellX or e.cellY~=player.cellY,'startup follower avoids player cell')
  local key=e.cellX..':'..e.cellY;check(not occupied[key],'startup followers use distinct cells');occupied[key]=true
end
tick(20)
-- A released side row is already a valid procession, not a rejoin puzzle.
local savedWalkable=map.isWalkableCell
for _,side in ipairs({'left','right'}) do
  for _,dir in ipairs({'up','down','right'}) do
    player.cellX,player.cellY,player.px,player.py=12,12,192,192
    player.moving=false;player.targetX=nil;player.targetY=nil;player.facing='down'
    map.isWalkableCell=function(self,x,y)
      return savedWalkable(self,x,y) and not (side=='right' and x==11 and y==12)
    end
    -- A right-side procession can follow up/down immediately. Walking into
    -- its occupied side still uses the normal safety detour.
    if side~='right' or dir~='right' then
      C:saveLoading();tick(2)
      for slot,e in ipairs(C.followers) do
        eq(e.lineSlot,slot,'arrival preserves assigned party order')
        eq(e.cellX,12+(side=='left' and -slot or slot),'arrival forms a side row')
      end
      tick(2)
      for slot,e in ipairs(C.followers) do
        check(not e.moving,'arrival row stays still until trainer walks')
        eq(e.cellX,12+(side=='left' and -slot or slot),'arrival does not pre-rearrange')
      end
      start(dir)
      for slot,e in ipairs(C.followers) do
        check(e.moving,'every side-row follower starts on first native commitment '..side..' '..dir..' slot='..slot..' step='..tostring(e.trailStep)..' anchor='..tostring(e.arrivalAnchor)..' yield='..tostring(e.yielding))
        check(not e.yielding and not e.arrivalAnchor,'side row enters normal replay without rearranging')
        check(not e.ballPhase,'walking ends outstanding release effect')
        eq(e.lineSlot,slot,'first step retains assigned party order')
      end
      advance(frames())
      for slot,e in ipairs(C.followers) do
        eq(e.cellX,12+(side=='left' and -(slot-1) or slot-1),'first step advances the row normally')
        eq(e.cellY,12,'first step remains on the seeded row')
      end
      for _=1,8 do step(dir) end
      tick(80)
      for slot,e in ipairs(C.followers) do eq(e.lineSlot,slot,'unobstructed following keeps assigned order') end
    end
  end
end
map.isWalkableCell=savedWalkable
player.cellX,player.cellY,player.px,player.py=12,12,192,192
player.moving=false;player.targetX=nil;player.targetY=nil
C:saveLoading();tick(20)
-- Walk directly toward an idle follower using actual cartridge commitments.
-- It must sidestep without snapping, then route behind the landed player.
values.follower_count=1
C:saveLoading();player.facing='up';tick(2)
local released=C.followers[1];local saveX,saveY=player.cellX,player.cellY
eq(released.ballPhase,'release','save-loading fixture uses actual ball release')
eq(released.cellX,saveX-1,'saved companion releases on left side')
eq(released.cellY,saveY,'saved companion releases on player row')
start('left')
check(released.yielding and released.moving,'freshly released companion yields before animation finishes')
advance(frames());tick(120)
eq(released.cellX,saveX,'freshly released companion reaches rear X')
eq(released.cellY,saveY,'freshly released companion reaches rear Y')
step('down');tick(120)
for _,dir in ipairs({'up','down','left','right'}) do
  C:clear();tick()
  local d=delta[dir];local f=C.followers[1]
  local x,y=player.cellX,player.cellY
  f.cellX,f.cellY=x+d[1],y+d[2];f.px,f.py=f.cellX*16,f.cellY*16;f.hidden=false
  player.facing=dir;player.turnTimer=0;player.turnArmed=false
  local px,py=f.px,f.py
  local result=gen==3 and player.tryMove(dir,game) or player:tryMove(dir,map,world.entities)
  check(player.moving,'native approach commits '..dir..' ('..tostring(result)..')')
  check(f.moving and f.yielding,'approached follower sidesteps for '..dir)
  check(not (f.targetX==player.cellX and f.targetY==player.cellY),'sidestep avoids player source for '..dir)
  check(not (f.targetX==player.targetX and f.targetY==player.targetY),'sidestep avoids player destination for '..dir)
  near(f.px,px,'sidestep does not teleport X for '..dir);near(f.py,py,'sidestep does not teleport Y for '..dir)
  tick();advance(frames());tick(120)
  eq(f.cellX,x,'yielding follower routes behind player X for '..dir)
  eq(f.cellY,y,'yielding follower routes behind player Y for '..dir)
  check(not f.yielding,'yielding follower rejoins trail for '..dir)
end
-- Walk-through mode uses real native movement in all four directions.
values.OW_FOLLOWERS_PLAYER_YIELD=false
for _,dir in ipairs({'up','down','left','right'}) do
  C:clear();tick()
  local d=delta[dir];local f=C.followers[1]
  local x,y=player.cellX,player.cellY
  f.cellX,f.cellY=x+d[1],y+d[2];f.px,f.py=f.cellX*16,f.cellY*16
  f.hidden=false;f.arrivalAnchor=nil;f.ballPhase=nil;f.yielding=nil
  player.facing=dir;player.turnTimer=0;player.turnArmed=false
  start(dir)
  check(player.moving,'walk-through native player commits '..dir)
  check(not f.yielding and not f.moving,'walk-through does not trigger sidestep '..dir)
  tick()
  check(not f.yielding,'walk-through tick does not trigger avoidance '..dir)
  advance(frames())
  eq(player.cellX,x+d[1],'walk-through player lands X '..dir)
  eq(player.cellY,y+d[2],'walk-through player lands Y '..dir)
  tick(120)
end
values.OW_FOLLOWERS_PLAYER_YIELD=true
-- Reserved NPC cells and warp tiles force the sidestep onto the opposite side.
C:clear();tick()
local yielding=C.followers[1];local x,y=player.cellX,player.cellY
yielding.cellX,yielding.cellY=x+1,y;yielding.px,yielding.py=(x+1)*16,y*16;yielding.hidden=false
local sideNpc={cellX=x+2,cellY=y+1,targetX=x+1,targetY=y+1,passable=false}
world.entities[#world.entities+1]=sideNpc
player.facing='right';player.turnTimer=0;player.turnArmed=false
start('right')
eq(yielding.targetX,x+1,'sidestep keeps forward column beside NPC')
eq(yielding.targetY,y-1,'sidestep avoids NPC reserved destination')
advance(frames());tick(120)
eq(yielding.cellX,x,'follower goes around NPC to rear X');eq(yielding.cellY,y,'follower goes around NPC to rear Y')
table.remove(world.entities)
-- Side tiles forbidden by geometry/warp policy must never become detour cells.
local originalWarp=map.warpAtCell
for _,obstacle in ipairs({'wall','warp','follower','wild'}) do
  C:clear();tick()
  local f=C.followers[1];local ox,oy=player.cellX,player.cellY
  f.cellX,f.cellY=ox+1,oy;f.px,f.py=(ox+1)*16,oy*16;f.hidden=false
  if obstacle=='wall' then ledgeX,ledgeY=ox+1,oy+1
  elseif obstacle=='warp' then
    map.warpAtCell=function(self,cx,cy)return cx==ox+1 and cy==oy+1 or originalWarp(self,cx,cy)end
  elseif obstacle=='follower' then
    values.follower_count=2;tick()
    local other=C.followers[2];other.cellX,other.cellY=ox+1,oy+1
    other.px,other.py=other.cellX*16,other.cellY*16;other.hidden=false
  else
    local wild=assert(C:actor(session.party[1].species,7,ox+1,oy+2,'land'))
    wild.targetX,wild.targetY=ox+1,oy+1;wild.currentEligible=true;C.wilds={wild};C:publish()
  end
  player.facing='right';player.turnTimer=0;player.turnArmed=false;start('right')
  eq(f.targetX,ox+1,'sidestep preserves column near '..obstacle)
  if obstacle=='follower' then
    check(math.abs(f.targetY-oy)==1,'sidestep may cross a passable companion')
  else eq(f.targetY,oy-1,'sidestep avoids '..obstacle..' cell') end
  advance(frames())
  ledgeX,ledgeY=nil,nil;map.warpAtCell=originalWarp
  values.follower_count=1;C.wilds={};tick(120)
  eq(f.cellX,ox,'detour around '..obstacle..' reaches rear X')
  eq(f.cellY,oy,'detour around '..obstacle..' reaches rear Y')
  step('left');tick(120)
end
-- A moving companion backs away from the player's destination smoothly.
C:clear();tick()
yielding=C.followers[1];x,y=player.cellX,player.cellY
yielding.cellX,yielding.cellY=x+1,y-1;yielding.px,yielding.py=(x+1)*16,(y-1)*16;yielding.hidden=false
check(C:move(yielding,x+1,y,16/60),'fixture companion commits toward next player cell')
tick(4);local retreatX,retreatY=yielding.px,yielding.py
player.facing='right';player.turnTimer=0;player.turnArmed=false
local retreatResult=gen==3 and player.tryMove('right',game) or player:tryMove('right',map,world.entities)
check(player.moving,'native player commits toward in-flight follower '..tostring(retreatResult))
eq(yielding.targetY,y-1,'in-flight companion retreats to safe source')
near(yielding.px,retreatX,'in-flight retreat keeps pixel X');near(yielding.py,retreatY,'in-flight retreat keeps pixel Y')
tick();advance(frames());tick(120)
eq(yielding.cellX,x,'in-flight companion rejoins rear X');eq(yielding.cellY,y,'in-flight companion rejoins rear Y')
step('left');step('left');tick(120)
values.follower_count=6
route={{x=player.cellX,y=player.cellY}}
-- Isolate the command-history checks below from the new arrival formation.
player.cellX,player.cellY,player.px,player.py=12,12,192,192
player.moving=false;player.targetX=nil;player.targetY=nil
C:clear();tick()
eq(type(gen==1 and map.warpAt or map.warpAtCell),gen==1 and 'table' or 'function','map preserves native warp API shape')
start('right')
eq(player.cellX,12,'player source remains until native landing')
eq(player.targetX,13,'first native destination is committed')
check(not C.followers[1].hidden,'first follower reveals on commitment before landing')
advance(frames());route[#route+1]={x=player.cellX,y=player.cellY}
start('right')
local e=C.followers[1]
check(e.moving,'second commitment starts follower while player is in flight')
advance(4)
check(player.moving,'player remains in flight during follower motion')
check(e.px>12*16 and e.px<13*16,'follower pixels interpolate before native landing')
advance(frames()-4);route[#route+1]={x=player.cellX,y=player.cellY}
eq(e.cellX,13,'walking follower reaches vacated source at native pace')
for _=1,8 do step('right')end
for i,follower in ipairs(C.followers)do
  eq(follower.cellX,player.cellX-i,'all six trail one cell apart after native walking')
  check(not follower.moving,'walking follower lands by native step end')
end
-- Turning, reversals, and revisiting cells preserve the command history.
-- A follower yielding around the player may take longer than one player step.
for _,dir in ipairs({'down','down','left','left','up','up','right','left','left','left','down','right'})do step(dir)end
for i,follower in ipairs(C.followers)do
  check(map:isWalkableCell(follower.cellX,follower.cellY),'turn/reversal keeps follower '..i..' on legal floor')
end
tick(120)
for _=1,12 do step('right')end
tick(120)
for i,follower in ipairs(C.followers)do
  eq(follower.cellX,player.cellX-follower.lineSlot,'followers regroup behind player after yielding '..i)
  eq(follower.cellY,player.cellY,'followers rejoin the straight trail after yielding '..i)
end
local old=session.party[1];session.party[1]=session.party[2];session.party[2]=old
tick();eq(C.followers[1].species,session.party[1].species,'party reorder changes first follower identity')
for _=1,8 do step('right')end
check(C.followers[1].cellX>=player.cellX-2,'reordered follower resumes following')
-- A native menu freezes movement without spending queued follower time.
start('right');advance(3);local frozenX,frozenY=C.followers[1].px,C.followers[1].py
menu=true
if gen<3 then game.stack.states[#game.stack.states+1]={isMenu=true}end
tick(20)
near(C.followers[1].px,frozenX,'menu freezes follower X');near(C.followers[1].py,frozenY,'menu freezes follower Y')
menu=false
if gen<3 then table.remove(game.stack.states)end
advance(frames()-3)
check(not C.followers[1].moving,'follower resumes queued step after menu')
-- Real native durations, including an eight-frame pace. Gen 1 uses its
-- configurable stepLength; Gen 2 uses the same stepFrames World sets for bike.
values.follower_count=1;C:clear();tick()
if gen<3 then player.stepFrames=8 end
step('right',true)
start('right',true);eq(frames(),8,'native faster pace is eight frames')
local speedy=C.followers[1];advance(3)
check(speedy.moving,'faster follower interpolates while native player moves')
advance(5)
eq(speedy.cellX,player.cellX-1,'faster follower keeps native eight-frame pace')
-- A sustained native bicycle procession crosses the bounded history trim
-- threshold. Every commitment still comes from the cartridge player API.
values.follower_count=6;C:clear();tick()
local fastFrames=gen==3 and 4 or 8
session.onBike=true
if gen==3 then player.biking=true else player.stepFrames=8 end
local fastRoute={{x=player.cellX,y=player.cellY}}
local function fastStart(dir)
  if gen==3 then
    local d=delta[dir]
    check(player.bikeStep(player.cellX+d[1],player.cellY+d[2],dir,4),
      'real native bike API commits '..dir)
    tick()
  else start(dir)end
  eq(frames(),fastFrames,'native bicycle duration')
end
local function fastFinish()
  advance(fastFrames)
  check(not player.moving,'native bicycle landing')
  fastRoute[#fastRoute+1]={x=player.cellX,y=player.cellY}
end
fastStart('right');fastFinish()
values.WE_OW_ENCOUNTERS=false
for commitment=1,340 do
  local dir=({'right','down','left','up'})[math.floor((commitment-1)%16/4)+1]
  fastStart(dir);fastFinish()
  if commitment>=8 then
    for slot,follower in ipairs(C.followers)do
      local point=fastRoute[#fastRoute-slot]
      eq(follower.cellX,point.x,'sustained fast path X '..commitment..' slot '..slot)
      eq(follower.cellY,point.y,'sustained fast path Y '..commitment..' slot '..slot)
    end
  end
end
check(#fastRoute>256,'native fast route crosses history trim boundary')
session.onBike=false
if gen==3 then player.biking=false end
if gen==3 then
  -- Forced tile movement is still overworld movement. The real native
  -- forcedStep API supplies all destinations and interpolated pixels while
  -- the controlled service reports the current/ice/spinner sequence active.
  C:clear();tick()
  local companions={}
  for slot,follower in ipairs(C.followers)do companions[slot]=follower end
  local forcedRoute={{x=player.cellX,y=player.cellY}}
  forcedState=true
  for commitment=1,10 do
    check(player.forcedStep('right',8,{}),'native forced step commits '..commitment)
    tick()
    if commitment>=2 then
      check(C.followers[1].moving,'follower advances while forced service is active '..commitment)
    end
    advance(8)
    forcedRoute[#forcedRoute+1]={x=player.cellX,y=player.cellY}
    if commitment>=6 then
      for slot,follower in ipairs(C.followers)do
        local point=forcedRoute[math.max(1,#forcedRoute-slot)]
        eq(follower.cellX,point.x,'forced path X '..commitment..' slot '..slot)
        eq(follower.cellY,point.y,'forced path Y '..commitment..' slot '..slot)
      end
    end
  end
  local forcedIndex=C:status().pathStep
  check(forcedIndex>=10,'forced commitments are recorded throughout the sequence')
  forcedState=false;tick()
  eq(C:status().pathStep,forcedIndex,'ending forced movement retains the command history')
  for slot,follower in ipairs(C.followers)do
    eq(follower,companions[slot],'ending forced movement retains companion '..slot)
  end
  step('right')
  eq(C:status().pathStep,forcedIndex+1,'ordinary step continues the existing forced path')
  eq(C.followers[1].cellX,player.cellX-1,'ordinary step preserves the forced procession gap')
end
-- Native NPCs can enter the route after the player's commitment. Following
-- replays that valid route through the NPC, while ordinary wild movement and
-- solid geometry keep their collision vetoes.
if gen<3 then player.stepFrames=16 end
values.follower_count=1;C:clear();tick();step('right')
local npcX,npcY=player.cellX,player.cellY
local commit=gen==3 and player.tryMove('right',game,false)or player:tryMove('right',map,world.entities)
check(player.moving,'native player commits before NPC enters the vacated route '..tostring(commit))
local ordinary
if gen==1 then
  ordinary=require('src.world.NPC').new(data,map.id,
    {index=70,name='NATIVE_TRAIL_NPC',sprite='SPRITE_RED',x=npcX,y=npcY-1,movement='STAY',range='NONE'})
  ordinary.passable=false
  world.npcs[#world.npcs+1]=ordinary;world.entities[#world.entities+1]=ordinary
  local OW=require('src.world.OverworldController')
  OW.scriptMove(world,ordinary,'down',1)
  for _=1,32 do OW.updateScriptMoves(world);ordinary:update(map,world.entities)end
  OW.updateScriptMoves(world)
elseif gen==2 then
  ordinary=require('src.world.gen2.Npc').new(map.id,
    {index=70,name='NATIVE_TRAIL_NPC',sprite='SPRITE_RED',x=npcX,y=npcY-1,movement='STAY'},data.sprites.SPRITE_RED)
  ordinary.passable=false
  world.npcs[#world.npcs+1]=ordinary;world.entities[#world.entities+1]=ordinary
  ordinary:stepNow('down')
  check(ordinary.moving,'real native Gen 2 roaming NPC commits onto route')
  for _=1,32 do ordinary:update(map,world.entities)end
else
  -- Game3 event-object collision is a controlled boundary. Its canEnter
  -- fixture above returns the same entity reason as the native object grid.
  ordinary={cellX=npcX,cellY=npcY,px=npcX*16,py=npcY*16,passable=false}
  world.entities[#world.entities+1]=ordinary
end
eq(ordinary.cellX,npcX,'ordinary NPC reaches recorded path X')
eq(ordinary.cellY,npcY,'ordinary NPC reaches recorded path Y')
tick()
check(C.followers[1].targetX==npcX and C.followers[1].targetY==npcY,
  'follower can replay the recorded trail through a native NPC')
advance(frames());step('right');tick(120)
eq(C.followers[1].cellX,player.cellX-1,'follower routes around NPC and rejoins X')
eq(C.followers[1].cellY,player.cellY,'follower routes around NPC and rejoins Y')
check(not ordinary.passable,'ordinary NPC retains native nonpassable flag')
local A=include('adapter')
local ordinaryWild=C:actor(session.party[1].species,7,npcX-1,npcY,'land')
check(not A:allowed(npcX,npcY,'land',ordinaryWild),'ordinary wild movement remains blocked by native NPC')
check(not C:move(ordinaryWild,npcX,npcY),'ordinary wild cannot move onto NPC and follower')
ledgeX,ledgeY=npcX+1,npcY
check(not A:allowed(ledgeX,ledgeY,'land',C.followers[1],
  {x=ledgeX,y=ledgeY,elevation=3,currentElevation=3}),
  'recorded follower exemption cannot bypass solid geometry')
check(not C:move(C.followers[1],ledgeX,ledgeY,16/60,
  {x=ledgeX,y=ledgeY,elevation=3,currentElevation=3}),
  'follower cannot start walking through a wall')
ledgeX,ledgeY=nil,nil
for i=#world.npcs,1,-1 do if world.npcs[i]==ordinary then table.remove(world.npcs,i)end end
for i=#world.entities,1,-1 do if world.entities[i]==ordinary then table.remove(world.entities,i)end end
-- Native ledge commitments: Gen 1's script mover supplies two successive
-- one-tile steps; Gen 2 and Gen 3 supply a single two-tile jump destination.
if gen<3 then player.stepFrames=16 end
C:clear();tick();step('right')
ledgeX,ledgeY=player.cellX+1,player.cellY
local landX=player.cellX+2
local jumps=include('jumps');local sawFollowerJump=false
local savedAnimate=C.animate
C.animate=function(self,e,dt)
  savedAnimate(self,e,dt)
  if e.follower and e.jumpActive and e.moving then
    local offset,active=jumps:pose(e)
    check(active,'ledge follower keeps jump active during flight')
    if offset<0 then sawFollowerJump=true end
  end
end
if gen==1 then
  local OW=require('src.world.OverworldController')
  world.scriptMove=OW.scriptMove;world.updateScriptMoves=OW.updateScriptMoves
  player.ledgeHop=true
  world:scriptMove(player,'right',2,function()player.ledgeHop=nil end)
  for _=1,33 do world:updateScriptMoves();player:update();tick()end
elseif gen==2 then
  check(player:scriptJump('right'),'native Gen 2 jump commits');tick();advance(frames())
else
  eq(start('right'),'ledge','native Gen 3 collision commits ledge jump');advance(frames())
end
eq(player.cellX,landX,'native ledge lands beyond blocked middle cell')
for _=1,3 do step('right')end
tick(40)
 C.animate=savedAnimate
check(sawFollowerJump,'native ledge follower visibly rises above its ground anchor')
check(not C.followers[1].jumpActive,'landing clears follower jump state')
eq(C.followers[1].cellX,player.cellX-1,'follower completes native ledge without becoming stranded')
check(C.followers[1].cellX~=ledgeX,'follower does not rest on an impassable ledge')
-- Solid wild occupancy and player bump battles through real native movement.
ledgeX,ledgeY=nil,nil;C:clear();tick()
local Runtime=require('src.mods.Runtime')
local Hooks=require('src.mods.Hooks').new()
Hooks:wrap('movement.collision',function(next_,allowed,ctx)return C:collision(next_,allowed,ctx)end,1000,'wildfollowers')
Runtime.install({emit=function()end},Hooks,{})
local encounters=0;local exactWild
A.start=function(_,wild)encounters=encounters+1;exactWild=wild;return true end
local function putWild(x,y)
  local wild=assert(C:actor(session.party[1].species,7,x,y,'land'))
  wild.currentEligible=true;C.wilds={wild};C:publish();return wild
end
local x,y=player.cellX,player.cellY
local function attempt(dir)
  if gen==3 then return player.tryMove(dir,game)end
  return player:tryMove(dir,map,world.entities)
end
local solid=putWild(x+1,y)
check(not solid.passable,'wild is nonpassable')
local follower=assert(C:actor(session.party[1].species,7,x,y,'land',1))
check(not C:move(follower,x+1,y,16/60,{x=x+1,y=y,elevation=3}),'follower cannot replay onto wild')
local other=assert(C:actor(session.party[1].species,7,x+2,y,'land'))
check(not C:move(other,x+1,y),'another wild cannot move onto wild')
if gen==1 then
  check(not require('src.world.Collision').canMove(map,world.entities,other,'left'),'native NPC collision sees solid wild')
elseif gen==2 then
  check(not require('src.world.gen2.Npc').canStep(other,map,world.entities,'left'),'native Gen2 NPC collision sees solid wild')
else
  check(not require('src.core.game3.collision').canEnter(game,x+1,y,{fromX=x+2,fromY=y,dir='left'}),'native GBA NPC collision sees solid wild')
end
eq(encounters,0,'NPC and follower checks never start battles')
player.facing='right';player.turnTimer=0;player.turnArmed=false
eq(attempt('right'),'blocked','native player refuses wild destination')
eq(player.cellX,x,'bump battle leaves player source cell')
check(not player.moving,'bump battle never commits overlapping movement')
eq(encounters,1,'player bump initiates exactly one battle')
eq(exactWild,solid,'bump battle uses the visible wild identity')
eq(#C.wilds,0,'battle clears solid occupancy')
-- A moving wild reserves its destination before it lands.
C.battlePending=false;solid=putWild(x+2,y);solid.moving=true;solid.targetX,solid.targetY=x+1,y
check(not C:move(follower,x+1,y,16/60,{x=x+1,y=y,elevation=3}),'followers cannot enter reserved wild destination')
eq(attempt('right'),'blocked','player cannot enter reserved wild destination')
eq(encounters,2,'player bump can battle a moving visible wild')
Runtime.reset()
-- Rejoining is about physical line positions, not the original party order.
values.follower_count=6;C:clear();tick()
if gen<3 then player.stepFrames=16 end
for _=1,8 do step('right')end
tick(60)
local returning,front=C.followers[1],C.followers[2]
local lineX,lineY=player.cellX,player.cellY
front.cellX,front.cellY=returning.cellX,returning.cellY
front.px,front.py=front.cellX*16,front.cellY*16
returning.cellY=returning.cellY+1;returning.py=returning.cellY*16;returning.yielding=true
local firstMon,secondMon=returning.mon,front.mon
tick(120)
eq(returning.lineSlot,2,'returning companion takes the available second position')
eq(front.lineSlot,1,'front companion keeps its physical first position')
check(not returning.yielding,'occupied original slot no longer strands returning companion')
eq(returning.mon,firstMon,'changing line order preserves first party identity')
eq(front.mon,secondMon,'changing line order preserves second party identity')
-- A one-cell corridor occupied by teammates must not trap a displaced member.
local corridorWalkable=map.isWalkableCell
returning.cellX,returning.cellY=lineX-7,lineY+1
returning.px,returning.py=returning.cellX*16,returning.cellY*16;returning.yielding=true
map.isWalkableCell=function(self,cx,cy)
  return corridorWalkable(self,cx,cy) and (cy==lineY or cx==lineX-7 and cy==lineY+1)
end
for _=1,240 do
  tick()
  for _,one in ipairs(C.followers) do
    if one.moving then
      check(map:isWalkableCell(one.targetX,one.targetY),'return reserves a legal tile')
      -- Transit through teammates is allowed; final distinct slots are
      -- checked below once the formation has settled.
    end
  end
end
local lineCells,lineSlots={},{}
for _,f in ipairs(C.followers)do
  check(not f.yielding and not f.moving,'crowded corridor returns every companion to line')
  eq(f.cellY,lineY,'crowded corridor companion stays on legal line')
  eq(f.cellX,lineX-f.lineSlot,'crowded corridor fills physical line slot')
  check(not lineCells[f.cellX] and not lineSlots[f.lineSlot],'corridor rejoining uses distinct positions')
  lineCells[f.cellX]=true;lineSlots[f.lineSlot]=true
end
map.isWalkableCell=corridorWalkable
-- Two simultaneous returns can exchange positions without waiting for one another.
local a,b=C.followers[3],C.followers[4]
local ax,bx=a.cellX,b.cellX
a.cellX,a.cellY=bx,lineY+1;a.px,a.py=bx*16,(lineY+1)*16;a.yielding=true
b.cellX,b.cellY=ax,lineY+1;b.px,b.py=ax*16,(lineY+1)*16;b.yielding=true
tick(120)
check(not a.yielding and not b.yielding,'simultaneous returns finish without fixed-order deadlock')
check(a.lineSlot~=b.lineSlot and a.cellX~=b.cellX,'simultaneous returns reserve separate line cells')
eq(a.cellX,lineX-a.lineSlot,'first simultaneous return rejoins line')
eq(b.cellX,lineX-b.lineSlot,'second simultaneous return rejoins line')
-- Catch-up is a live toggle for return routing, and changing it never restarts
-- a step already in flight. Urgent sidesteps remain quick in both modes.
values.follower_count=1;C:clear();tick()
for _=1,3 do step('right')end
for _,run in ipairs({false,true}) do
  values.OW_FOLLOWERS_RUN_TO_CATCH_UP=run
  local f=C.followers[1];f.cellX,f.cellY=player.cellX-1,player.cellY+2
  f.px,f.py=f.cellX*16,f.cellY*16;f.yielding=true;f.moving=false;f.targetX=nil;f.targetY=nil
  tick()
  local nativeDuration=(player.stepFramesCur or player.stepFrames or 16)/60
  near(f.duration,run and nativeDuration/2 or nativeDuration,'return routing respects catch-up toggle')
  local stepDuration=f.duration
  values.OW_FOLLOWERS_RUN_TO_CATCH_UP=not run;tick(2)
  near(f.duration,stepDuration,'live toggle preserves current step duration')
  tick(120)
  check(not f.yielding,'either catch-up mode returns companion to line')
  eq(f.cellX,player.cellX-1,'catch-up mode reaches trailing cell X')
  eq(f.cellY,player.cellY,'catch-up mode reaches trailing cell Y')
end
-- The ordinary recorded trail uses the same toggle only when actually behind.
local trail=include('trail');local savedStep=trail.index
local f=C.followers[1];f.trailStep=savedStep-3;f.cellX,f.cellY=trail.points[savedStep-3].x,trail.points[savedStep-3].y
values.OW_FOLLOWERS_RUN_TO_CATCH_UP=false
local point,_,walkDuration=trail:next(f,1)
check(point~=nil,'lagging normal follower has a recorded next step')
values.OW_FOLLOWERS_RUN_TO_CATCH_UP=true
local _,_,runDuration=trail:next(f,1)
near(runDuration,walkDuration/2,'ordinary trail catch-up respects restored toggle')
-- Speed choices affect both return routing and recorded catch-up.
for _,speed in ipairs({2,3,4,6}) do
  values.OW_FOLLOWERS_CATCH_UP_SPEED=speed
  local _,_,duration=trail:next(f,1)
  near(duration,walkDuration/speed,'selected catch-up multiplier applies to trail')
  near(include('avoidance'):duration(),(player.stepFramesCur or player.stepFrames or 16)/60/speed,'selected multiplier applies to return')
end
values.OW_FOLLOWERS_CATCH_UP_SPEED=2
-- Idle behavior starts after its delay and cancels when movement resumes.
local idle=include('idle')
values.OW_FOLLOWERS_IDLE_TIME=1
f.yielding=nil;f.moving=false;f.ballPhase=nil;f.awaitingTile=nil;f.idleAge=0
for _,mode in ipairs({'look','walk','jump','wave','spin','bounce','pulse','copycat','dance','stretch','doze','cheer'}) do
  values.OW_FOLLOWERS_IDLE_MODE=mode;f.idleAge=0;f.idleEpoch=nil
  check(not idle:tick(C,f,.1),'idle delay keeps formation still')
  check(idle:tick(C,f,1),'idle starts after delay')
  check(f.idlePose and f.idleMode==mode,'selected idle pose is active')
  if mode=='jump' or mode=='wave' or mode=='bounce' or mode=='cheer' then
    f.idleAge=1.2;f.lineSlot=1;f.idleMode=mode;idle.groupTime=1.2;idle:tick(C,f,0)
    check(f.idlePose.jumping,'idle hop uses shared jump state')
    eq(f.idlePose.hop,jumps:offset(.2/jumps.duration,jumps.duration),'idle hop uses player jump curve')
  end
  player.moving=true;idle:tick(C,f,.1);player.moving=false
  check(not f.idlePose and not f.idleMode,'walking cancels idle immediately')
end
-- Group choices are selected once per stop, including late participants.
local cohort={followers={}}
for slot=1,6 do cohort.followers[slot]={slot=slot,lineSlot=slot,facing='down',idleAge=0,cellX=player.cellX-slot,cellY=player.cellY} end
for _,mode in ipairs({'random','random_wave'}) do
  values.OW_FOLLOWERS_IDLE_MODE=mode
  player.moving=true;idle:tick(cohort,cohort.followers[1],0);player.moving=false
  local chosen
  for frame=1,600 do
    for _,e in ipairs(cohort.followers) do
      idle:tick(cohort,e,1/60)
      if e.idleMode then
        chosen=chosen or e.idleMode
        eq(e.idleMode,chosen,'group random choice stays shared and stable while stopped')
        if mode=='random_wave' then
          check(e.idleMode=='wave' or e.idleMode=='spin' or e.idleMode=='bounce' or e.idleMode=='pulse','random wave uses only wave effects')
        end
      end
    end
  end
  local late={slot=7,lineSlot=7,idleAge=2,facing='down',cellX=player.cellX-7,cellY=player.cellY}
  idle:tick(cohort,late,0);eq(late.idleMode,chosen,'late participant joins current group choice')
  player.moving=true
  for _,e in ipairs(cohort.followers) do idle:tick(cohort,e,0);check(not e.idlePose,'walking cancels group idle pose') end
  player.moving=false
end
values.OW_FOLLOWERS_IDLE_MODE='copycat'
local mimic=cohort.followers[1];mimic.idleAge=2;mimic.idleEpoch=nil;mimic.idleSelection='copycat'
for _,dir in ipairs({'up','down','left','right'}) do
  player.facing=dir;idle:tick(cohort,mimic,0);eq(mimic.idlePose.facing,dir,'copycat tracks stationary trainer turns')
end
values.OW_FOLLOWERS_IDLE_MODE='dance';mimic.idleSelection='dance';mimic.idleMode=nil;mimic.idleAge=2;idle:tick(cohort,mimic,0)
check(mimic.idlePose.sx>=.95 and mimic.idlePose.sx<=1.05,'dance keeps scaling bounded')
values.OW_FOLLOWERS_IDLE_MODE='pulse';mimic.idleSelection='pulse';mimic.idleMode=nil;mimic.idleAge=1.35;idle:tick(cohort,mimic,0);idle.groupTime=1.35;idle:tick(cohort,mimic,0)
check(mimic.idlePose.sx>1 and mimic.idlePose.sy<1,'pulse wave uses anchored stretch pose')
values.OW_FOLLOWERS_IDLE_MODE='wander';f.idleSelection='wander';f.idleMode=nil;f.idleAge=2
idle:tick(C,f,.1);check(f.idleWander~=nil,'wander records its home')
player.moving=true;idle:tick(C,f,.1);player.moving=false
check(f.yielding and not f.idleWander,'wander resumes legal return when player moves')
assert(load(read(root..'/tests/idle_behaviors.lua')))()(include,values,player,check,eq,near,assert(load(read(root..'/options.lua')))())
-- A delayed Gen 2 automatic door step cannot race companion placement.
if gen==2 then
  local oldCollision=map.cellCollision
  map.cellCollision=function()return 0x71 end
  local balls=include('balls');C.ballArrivalStable=0
  for _=1,30 do check(not balls:arrivalReady(C),'forced door tile waits for native exit') end
  map.cellCollision=oldCollision
  check(not balls:arrivalReady(C),'first settled update waits')
  check(balls:arrivalReady(C),'cleared door releases after settled update')
end
-- NPCs reserve neither the companion's cell nor its committed destination.
values.OW_FOLLOWERS_IDLE_MODE='none';values.follower_count=1
C:clear();tick()
local companion=C.followers[1]
companion.cellX,companion.cellY=player.cellX-2,player.cellY
companion.px,companion.py=companion.cellX*16,companion.cellY*16;companion.hidden=false
local npc={cellX=companion.cellX,cellY=companion.cellY-1,passable=false,facing='down',localId=70}
local function npcCanMove()
  if gen==1 then return require('src.world.Collision').canMove(map,world.entities,npc,'down') end
  if gen==2 then return require('src.world.gen2.Npc').canStep(npc,map,world.entities,'down') end
  return not require('src.core.game3.objects').blocks(companion.cellX,companion.cellY,70,3)
end
check(not npcCanMove(),'native roaming NPC cannot enter stationary follower tile')
companion.moving=true;companion.targetX,companion.targetY=companion.cellX+1,companion.cellY
npc.cellX=companion.targetX
check(not C:collision(function(v)return v end,true,{mover=npc,toX=companion.targetX,toY=companion.targetY}),
  'NPC collision veto protects a moving companion destination')
if gen==2 then
 require('src.world.gen2.Npc').scriptStep(npc,'down')
 check(C.storyRecalled and companion.storyRecall,'Gen 2 story step recalls companions before native NPC movement')
elseif gen==3 then
 require('src.core.game3.objects').scriptStep(npc,'down')
 check(C.storyRecalled and companion.storyRecall,'GBA story step recalls companions before native NPC movement')
else
 local OW=require('src.world.OverworldController')
 world.updateScriptMoves=OW.updateScriptMoves;C:install()
 world.scriptMoves={{entity=npc,dir='down',remaining=1}}
 world:updateScriptMoves()
 check(C.storyRecalled and companion.storyRecall and npc.moving and world.scriptMoves[1].remaining==0,'Gen 1 script recalls companions and proceeds without a blocked move')
 world.scriptMoves={}
end
-- Gen 1 scripted movement must not softlock while controls are locked: the
-- companion's courtesy step advances, then the NPC's original step resumes.
if gen==1 then
 C:clear();tick();companion=C.followers[1]
 companion.cellX,companion.cellY=player.cellX-2,player.cellY
 companion.px,companion.py=companion.cellX*16,companion.cellY*16;companion.hidden=false
 npc.cellX,npc.cellY=companion.cellX,companion.cellY-1;npc.moving=false
 world.scriptMoves={{entity=npc,dir='down',remaining=1}}
 world:updateScriptMoves()
 check(companion.storyRecall and not C:followerAt(companion.cellX,companion.cellY),'scripted NPC clears companion reservations by recall')
 menu=true;tick(20);menu=false
 check(companion.hidden and not companion.moving,'story recall completes with player controls locked')
 world:updateScriptMoves()
 check(npc.moving and world.scriptMoves[1].remaining==0,'scripted NPC resumes after companion clears tile')
 check(not C:followerAt(npc.targetX,npc.targetY),'recalled companion cannot obstruct resumed script')
 world.scriptMoves={}
end
-- Continuously walking leader: displaced companions join before the leader
-- stops, keep one position while catching up, and reserve distinct legal steps.
player.moving=false;player.targetX=nil;player.targetY=nil
player.cellX,player.cellY,player.px,player.py=12,12,192,192
values.follower_count=6;values.OW_FOLLOWERS_RUN_TO_CATCH_UP=true
C:clear();tick()
for _=1,8 do step('right')end
tick(60)
local displaced={C.followers[2],C.followers[4],C.followers[6]}
for i,e in ipairs(displaced) do
 e.cellY=e.cellY+2+i;e.py=e.cellY*16;e.yielding=true;e.joinSlot=nil;e.joinTarget=nil
end
local joinedMoving=false
for command=1,28 do
 local direction=command<=12 and 'right' or command<=20 and 'down' or 'left'
 start(direction)
 for frame=1,frames() do
   advance(1)
   for _,e in ipairs(displaced) do
     if not e.yielding and player.moving then joinedMoving=true end
   end
   local returning=false
   for _,e in ipairs(C.followers) do returning=returning or e.yielding or e.rejoining end
   if returning then
     for _,e in ipairs(C.followers) do
       if e.moving then
         check(map:isWalkableCell(e.targetX,e.targetY),'moving return step stays on legal floor')
         -- Rejoining companions may now cross teammates. Geometry remains
         -- authoritative; temporary shared reservations are intentional.
       end
     end
   end
 end
 if command==12 then
   for _,e in ipairs(displaced) do check(not e.yielding,'displaced companion rejoins while leader keeps walking') end
 end
end
check(joinedMoving,'return completes during native player movement')
for _,e in ipairs(displaced) do check(not e.yielding,'turning moving line retains rejoined companions') end
-- Expanded spacing settles behind the player without skipping trail cells.
for _,gap in ipairs({2,3,4}) do
  player.cellX,player.cellY,player.px,player.py=12,12,192,192
  player.moving=false;player.targetX=nil;player.targetY=nil
  C:clear();tick()
  values.OW_FOLLOWERS_TRAINER_SPACING=gap;values.OW_FOLLOWERS_SPACING=gap
  for _=1,28 do step('right') end
  tick(120)
  for rank=1,6 do
    local e
    for _,candidate in ipairs(C.followers) do if candidate.lineSlot==rank then e=candidate end end
    check(e~=nil,'expanded formation retains each procession position')
    eq(player.cellX-e.cellX,gap*rank,'expanded spacing applies to trainer and all teammates')
    eq(e.cellY,player.cellY,'expanded procession remains on recorded route')
  end
  for _=1,28 do step('down') end
  tick(120)
  for _,e in ipairs(C.followers) do
    eq(e.cellX,player.cellX,'expanded procession follows a corner')
    eq(player.cellY-e.cellY,gap*e.lineSlot,'corner retains configured spacing')
  end
  local displaced=C.followers[3]
  displaced.cellX=displaced.cellX+2;displaced.px=displaced.cellX*16;displaced.yielding=true
  for _=1,12 do step('left') end
  tick(240)
  check(not displaced.yielding,'expanded formation rejoins after displacement and continued walking')
end
values.OW_FOLLOWERS_TRAINER_SPACING=1;values.OW_FOLLOWERS_SPACING=1
-- Tenths are real pixel gaps, including accumulated party spacing and turns.
for _,gaps in ipairs({{1.1,1.1},{1.5,1.2},{2.3,1.7},{3.9,4}}) do
  player.cellX,player.cellY,player.px,player.py=12,12,192,192
  player.moving=false;player.targetX=nil;player.targetY=nil
  C:clear();tick()
  values.OW_FOLLOWERS_TRAINER_SPACING=gaps[1];values.OW_FOLLOWERS_SPACING=gaps[2]
  for _=1,32 do step('right') end
  tick(180)
  for _,e in ipairs(C.followers) do
    near(player.px-e.px,16*(gaps[1]+(e.lineSlot-1)*gaps[2]),'fractional spacing settles at exact pixels')
    near(e.py,player.py,'fractional spacing stays on route')
    if e.moving then check(e.spacingPaused,'fractional settled step stops walk animation') end
  end
  -- Check each native interpolation frame, rather than only landed positions.
  for command=1,4 do
    start('right')
    for frame=1,frames() do
      advance(1)
      for _,e in ipairs(C.followers) do
        local gap=gaps[1]+(e.lineSlot-1)*gaps[2]
        if math.abs(gap-math.floor(gap+.000001))>.000001 then
          near(player.px-e.px,16*gap,'fractional walking gap stays stable every frame')
        end
      end
    end
  end
  for _=1,32 do step('down') end
  tick(180)
  for _,e in ipairs(C.followers) do
    near(player.py-e.py,16*(gaps[1]+(e.lineSlot-1)*gaps[2]),'fractional spacing follows turns')
    near(e.px,player.px,'fractional corner stays on route')
  end
end
values.OW_FOLLOWERS_IDLE_MODE='look';values.OW_FOLLOWERS_IDLE_TIME=1
tick(120)
for _,e in ipairs(C.followers) do check(e.idlePose~=nil,'fractional resting formation supports idle poses') end
-- Confirm actual interpolated companions visibly hop, including middle slots.
for _,mode in ipairs({'wave','wave_single'}) do
  values.OW_FOLLOWERS_IDLE_MODE=mode
  local hopPeaks={}
  for n=1,8*60 do
    tick()
    for slot,e in ipairs(C.followers) do
      local height=jumps:pose(e)
      hopPeaks[slot]=math.min(hopPeaks[slot] or 0,height)
    end
  end
  for slot=1,6 do check(hopPeaks[slot]<=-8,'real fractional formation jumps visibly in every slot '..slot..' for '..mode) end
end
values.OW_FOLLOWERS_IDLE_MODE='none'
values.OW_FOLLOWERS_TRAINER_SPACING=1;values.OW_FOLLOWERS_SPACING=1
local schema=assert(load(read(root..'/options.lua')))()
for _,entry in ipairs(schema) do
  if entry.key=='OW_FOLLOWERS_TRAINER_SPACING' or entry.key=='OW_FOLLOWERS_SPACING' then
    eq(#entry.choices,31,'spacing menu provides every tenth from 1.0 to 4.0')
    for i,choice in ipairs(entry.choices) do near(choice[2],1+(i-1)/10,'spacing menu value is exact tenth') end
  end
end
-- Deterministic release geometry checks through the actual placement module.
local A=include('adapter');local B=include('balls');local oldAllowed=A.allowed
local reservations={};local blocked={}
A.allowed=function(_,x,y)return map:inBounds(x,y) and not blocked[x..':'..y] end
local placement={occupied=function(_,x,y)return reservations[x..':'..y] end}
for _,dir in ipairs({'up','down','left','right'}) do
  player.facing=dir;reservations={};blocked={}
  for slot=1,6 do
    local e={};check(B:place(placement,e),'release has side floor')
    local d=delta[dir]
    check(e.cellX~=player.cellX+d[1] or e.cellY~=player.cellY+d[2],'release excludes facing tile for every direction')
    eq(e.cellY,player.cellY,'release stays on side row')
    eq(e.cellX,player.cellX-slot-(dir=='left' and 1 or 0),'release preserves party order along left row')
    reservations[e.cellX..':'..e.cellY]=true
  end
end
player.facing='down';reservations={};blocked={[player.cellX-1 ..':'..player.cellY]=true}
local e={};check(B:place(placement,e),'blocked left permits right');eq(e.cellX,player.cellX+1,'right fallback starts next to player')
A.allowed=function()return false end
check(not B:place(placement,{}),'no safe floor leaves companion recalled')
A.allowed=oldAllowed
-- Disabling visuals must retain safe placement and native transition results.
values.OW_FOLLOWERS_POKEBALLS=false
C:saveLoading();tick(2)
for _,follower in ipairs(C.followers) do
  check(not follower.ballPhase,'animation toggle removes only the release effect')
  local d=delta[player.facing]
  check(follower.cellX~=player.cellX+d[1] or follower.cellY~=player.cellY+d[2],'animation-off arrival still avoids forward tile')
end
local calls=0
local result=B:begin(C,function()calls=calls+1;return true end)
check(result and calls==1 and not B.pending,'animation-off doorway calls native transition immediately')
C.ballArrival=nil
result=B:begin(C,function()calls=calls+1;return false end)
check(result==false and not C.ballArrival,'failed animation-off transition does not arm arrival')
values.OW_FOLLOWERS_POKEBALLS=true
-- Compare each animation frame with the engine's actual player implementation.
local savedProgress,savedJump,savedType=player.progress,player.jumping,player.jumpType
for frame=1,32 do
  local expected
  if gen==1 then
    local view=setmetatable({py=0,hopFrames=32-frame+1,hopTotal=32},{__index=player})
    local _,_,y=view:pose();expected=y
  elseif gen==2 then expected=require('src.script.gen2.Movement').jumpYOffset(frame,32)
  else
    player.progress=frame;player.jumping=true;player.jumpType=nil
    expected=player.jumpSpriteY()
  end
  eq(jumps:offset((frame-1)/32,32/60),expected,'follower matches native player jump frame')
end
player.progress,player.jumping,player.jumpType=savedProgress,savedJump,savedType
local draws={};local oldDraw=love.graphics.draw
love.graphics.draw=function(...)draws[#draws+1]={...}end
local shadow={};local oldShadow=player.shadowImg;player.shadowImg=shadow
local oldWorldShadow=world.drawJumpShadow;local shadowCalls=0
world.drawJumpShadow=function(_,e,ox,oy,s)
  shadowCalls=shadowCalls+1
  check(e.jumping and e.px==64 and e.py==80,'Gen 2 native shadow retains ground anchor')
end
local fx=gen==3 and require('src.core.game3.field_effects')
local oldLoad=fx and fx.loadSheet
if fx then fx.loadSheet=function(name)
  eq(name,'shadow_medium','same shadow sheet as native GBA player')
  return {image=shadow,quads={[0]={}},fh=8,fw=16}
end end
local actor={national=1,px=64,py=80,facing='down',clock=0,moving=true,jumpActive=true,progress=.5,duration=32/60}
local sprites=include('sprites');sprites:draw(actor,3,5,2)
local r=sprites:get(1);local body=draws[#draws]
near(body[4],5+(80+(gen==3 and 16 or 12)+jumps:offset(.5,32/60))*2-r.h*32/r.w*2,'body rises while shadow remains grounded')
if gen==2 then eq(shadowCalls,1,'one native Gen 2 shadow draw')
else
  eq(#draws,gen==3 and 2 or version=='yellow' and 3 or 5,'native shadow pieces drawn once before body')
  local first=draws[1];eq(first[1],shadow,'native player shadow image reused')
  near(first[gen==3 and 4 or 3],5+(80+(gen==3 and 8 or version=='yellow' and 8 or 4))*2,'shadow stays at ground height')
end
-- The actual renderer must lift a paused fractional follower, for both sets.
actor.jumpActive=nil;actor.follower=true;actor.spacingPaused=true
actor.idlePose={facing='down',frame=1,hop=jumps:offset(.5,32/60),jumping=true,sx=1,sy=1}
for _,set in ipairs({'g9','ee'}) do
  values.follower_sprites=set;draws={};shadowCalls=0
  sprites:draw(actor,3,5,2)
  local record=sprites:get(1,actor);local rendered=draws[#draws]
  local size=record.ee and 1 or 32/record.w
  near(rendered[4],5+(80+(gen==3 and 16 or 12)+actor.idlePose.hop)*2-record.h*size*2,'fractional idle jump reaches sprite renderer for '..set)
  eq(rendered[2],record.quads.down[1],'fractional idle jump chooses pose frame for '..set)
end
values.follower_sprites='g9'
draws={};shadowCalls=0;jumps:shadow(actor,3,5,2,'top')
eq(#draws+shadowCalls,0,'Crystal top OAM pass does not duplicate shadow')
actor.ballPhase='release';jumps:shadow(actor,3,5,2)
eq(#draws+shadowCalls,0,'Pokeball animation suppresses jump shadow')
love.graphics.draw=oldDraw;player.shadowImg=oldShadow;world.drawJumpShadow=oldWorldShadow
if fx then fx.loadSheet=oldLoad end
C:dispose()
print(('PASS %s: %d native movement integration checks'):format(version,checks))

