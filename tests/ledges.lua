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
      local d=({right={1,0},left={-1,0},down={0,1},up={0,-1}})[dir]
      if d and x+d[1]==ledgeX and y+d[2]==ledgeY then return x+2*d[1],y+2*d[2] end
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
local OW
if gen==1 then
  OW=require('src.world.OverworldController')
  -- Native new() binds this singleton; inject the authored service owner.
  for i=1,20 do
    local name=debug.getupvalue(OW.checkLedgeHop,i)
    if name=='Game' then debug.setupvalue(OW.checkLedgeHop,i,game);break end
  end
  world.scriptMove=OW.scriptMove;world.updateScriptMoves=OW.updateScriptMoves
  world.finishLedgeHop=OW.finishLedgeHop
  require('src.core.Sound').play=function()end
end
local delta={right={1,0},left={-1,0},down={0,1},up={0,-1}}
local monitor,identities,jumped
local J=include('jumps')
local function tick()
  C:tick(game,1/60)
  if monitor then
    check(not C.storyRecalled,'normal ledge never enters story recall')
    for i,e in ipairs(C.followers)do
      check(e==identities[i],'ledge keeps each actual follower object')
      check(not e.hidden and not e.ballPhase,'followers remain visible outside their balls')
      check(not (e.cellX==ledgeX and e.cellY==ledgeY),'follower never lands on ledge middle')
      if e.jumpActive then
        local offset,active=J:pose(e)
        check(active,'ledge hop uses native jump pose')
        if offset<0 then jumped[i]=true end
      end
    end
  end
end
local function advance(n)
  for _=1,n do
    if gen==1 then world:updateScriptMoves();player:update()
    elseif gen==2 then player:update() else player.tick(game) end
    tick()
  end
end
local function step(dir)
  local result
  for _=1,8 do
    result=gen==3 and player.tryMove(dir,game,false) or gen~=3 and player:tryMove(dir,map,world.entities)
    if player.moving then break end
    advance(1)
  end
  check(player.moving,'player commits native move '..dir..' '..tostring(result))
  tick();advance(player.stepFramesCur or player.stepFrames or 16)
end
for _,count in ipairs({1,6})do for _,spacing in ipairs({1,1.3})do for _,dir in ipairs({'down','left','right'})do
  monitor=false;ledgeX,ledgeY=nil,nil;world.scriptMoves={}
  player.cellX,player.cellY,player.px,player.py=40,40,640,640
  player.targetX=nil;player.targetY=nil;player.moving=false;player.ledgeHop=nil;player.jumping=nil;player.inputLocked=nil
  if gen<3 then player.stepFrames=16;player.stepFramesCur=nil end
  values.follower_count=count;values.OW_FOLLOWERS_IDLE_MODE='none'
  values.OW_FOLLOWERS_TRAINER_SPACING=spacing;values.OW_FOLLOWERS_SPACING=spacing
  C:clear();tick();tick();advance(24)
  for _=1,12 do step(dir)end
  local d=delta[dir];ledgeX,ledgeY=player.cellX+d[1],player.cellY+d[2]
  local lx,ly=player.cellX+2*d[1],player.cellY+2*d[2]
  identities={};jumped={}
  for i,e in ipairs(C.followers)do identities[i]=e end
  check(#identities==count,'all selected followers present before ledge')
  monitor=true
  if gen==1 then
    data.field.ledges={{tileset='OVERWORLD',facing=dir,input=dir,standingTile=1,ledgeTile=2}}
    check(OW.checkLedgeHop(world,dir),'real Gen 1 ledge detection starts native scripted hop')
    tick();advance(33)
  elseif gen==2 then
    check(player:scriptJump(dir),'native Gen 2 hop starts');tick();advance(player.stepFrames)
  else step(dir) end
  eq(player.cellX,lx,'player lands at correct ledge X');eq(player.cellY,ly,'player lands at correct ledge Y')
  for _=1,13 do step(dir) end
  advance(90)
  for i,e in ipairs(C.followers)do
    check(jumped[i],'follower '..i..' visibly jumps the ledge')
    check(not e.jumpActive,'follower '..i..' finishes jump')
  end
end end end
monitor=false
if gen==1 then
  local A=include('adapter')
  player.ledgeHop=true;world.scriptMoves={{entity=player,dir='down',remaining=2}}
  check(A:ledgeTraversal() and not A:storyBusy(),'player-only ledge script is ordinary traversal')
  world.scriptMoves[#world.scriptMoves+1]={entity={cellX=5,cellY=5},dir='left',remaining=1}
  check(not A:ledgeTraversal() and A:storyBusy(),'NPC script during a hop remains story movement')
  world.scriptMoves={{entity=player,dir='down',remaining=2}};world.textbox={}
  check(A:storyBusy(),'dialogue still recalls during a ledge')
  world.textbox=nil;player.ledgeHop=nil;player.inputLocked=true
  check(A:storyBusy(),'ordinary scripted player input lock remains story movement')
end
print('PASS '..version..' native ledges: '..checks..' checks')
