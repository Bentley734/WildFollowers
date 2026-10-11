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
  for _=1,n or 1 do C:tick(game,1/30)end
end
local function advance(n)
  for _=1,n do
    if gen==3 then player.tick(game)else player:update()end
    if _%2==0 then tick() end
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

local sprites=include('sprites');local get=sprites.get;local art={6,34,151,65,250,144};sprites.get=function(self,n,a)return get(self,art[n] or n,a)end
values.follower_sprites='ee'; if gen==3 then local P=require('src.core.game3.pokemon');P.isShiny=function()return false end;P.gender=function()return 'M' end end
values.smart_spacing=true;values.OW_FOLLOWERS_TRAINER_SPACING=1;values.OW_FOLLOWERS_SPACING=1
values.OW_FOLLOWERS_IDLE_MODE='none';values.OW_FOLLOWERS_POKEBALLS=false
values.OW_FOLLOWERS_PLAYER_YIELD=false
 tick(2)
 eq(#C.followers,6,'smart test starts all six followers')
 local worst={};local T=include('trail')
 for _,segment in ipairs({{'right',24},{'down',14},{'left',24},{'up',14},{'right',24},{'down',14},{'left',24},{'up',14},{'right',24}})do
  for i=1,segment[2] do step(segment[1]);for _,e in ipairs(C.followers)do local lag=T:eligible(e.lineSlot,player)-(e.trailStep+(e.targetStep and e.progress or 0));worst[e.slot]=math.max(worst[e.slot] or 0,lag)end end
 end
 for _,lag in ipairs(worst)do check(lag<=2.25,'moving formation stays within 2.25 trail cells of its smart target')end
 print(version..' moving lag '..table.concat(worst,','));advance(180)
 for _,e in ipairs(C.followers)do
  check(e.cellX>20,'every smart follower advances after turns, not stranded behind')
  check(math.abs(e.cellY-player.cellY)<=1,'every smart follower rejoins final straight line')
 end
 C:dispose()
 print(('PASS %s: %d smart six-follower native movement/turn checks'):format(version,checks))
