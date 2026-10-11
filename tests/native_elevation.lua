-- Real native elevation and collision rules, with a small walkable layout.
-- Gen 3 keeps collision elevation and rendered elevation as separate values.
local root,version=arg[1],arg[2]
local function read(path)local f=assert(io.open(path,'rb'));local s=f:read('*a');f:close();return s end
local checks=0
local function check(ok,message)checks=checks+1;assert(ok,version..': '..message)end
local function eq(a,b,message)check(a==b,message..' ['..tostring(a)..' vs '..tostring(b)..']')end
love=require('tests.love_stub')
require('src.core.GameVersion').set(version)
local elevations={[1]=4,[2]=0,[3]=15,[4]=6,[5]=6,[6]=8}
local layout={width=8,height=4,pair='NATIVE_ELEVATION_FIXTURE'}
function layout:collArray()local rows={};for _=1,self.width*self.height do rows[#rows+1]=0 end;return rows end
function layout:collAt()return 0 end
function layout:elevAt(x)return elevations[x] or 4 end
function layout:midAt()return 0 end
local mapDef={id='NATIVE_ELEVATION_ROUTE',pair=layout.pair,midLayout=layout,warps={}}
local session={version=version,map=mapDef.id,party={{species=1,hp=30,level=12}}}
local world={npcs={}}
local game={session=session,save=session,data={},world=world,overworld=world}
local nativeCollision=require('src.core.game3.collision')
check(nativeCollision.bindMap(game,mapDef.id,mapDef),'native collision binds the test layout')
local nativePlayer=require('src.core.game3.player')
nativePlayer.reset(1,1,'right')
nativePlayer.updateElevation(1,1)
eq(nativePlayer.currentElevation,4,'native collision layer starts at four')
eq(nativePlayer.elevation,4,'native rendered layer starts at four')
package.loaded['src.core.game3.runtime']={getSession=function()return session end}
local Pokemon=require('src.core.game3.pokemon')
Pokemon._names={[1]='BULBASAUR'};Pokemon._byName={BULBASAUR=1}
Pokemon._national={toNational={[1]=1},toSpecies={[1]=1}}
local mod={game=game,exports={},
  read=function(_,name)return read(root..'/'..name)end,
  options={get=function()return true end},
  assets={image=function(_,name)return love.graphics.newImage(root..'/'..name)end}}
local Sandbox=require('src.mods.Sandbox')
local env=Sandbox.envFor({modId='wildfollowers',permissions={engine_internals=true}})
local modules={}
local function include(name)
  if not modules[name]then
    modules[name]=assert(Sandbox.compile(read(root..'/src/'..name..'.lua'),'@wildfollowers/'..name,env))()(mod,include)
  end
  return modules[name]
end
local controller=include('controller')
controller.map,controller.save=mapDef.id,session
local trail=include('trail');trail:reset(nativePlayer)
local follower=assert(controller:actor(1,12,1,1,'land',1))
eq(follower.currentElevation,4,'follower collision layer starts at four')
eq(follower.elevation,4,'follower rendered layer starts at four')
local realCanEnter=nativeCollision.canEnter
local lastCollisionElevation
nativeCollision.canEnter=function(owner,x,y,opts)
  lastCollisionElevation=opts.elevation
  return realCanEnter(owner,x,y,opts)
end
local function commitPlayer(x)
  local fromX,fromY=nativePlayer.cellX,nativePlayer.cellY
  nativePlayer.updateElevation(x,1,fromX,fromY)
  nativePlayer.moving=true;nativePlayer.targetX=x;nativePlayer.targetY=1
  nativePlayer.stepFrames=16
  check(trail:observe(nativePlayer),'trail observes native commitment to '..x)
  return trail.points[trail.index]
end
local function landPlayer()
  nativePlayer.cellX,nativePlayer.cellY=nativePlayer.targetX,nativePlayer.targetY
  nativePlayer.moving=false
  -- This is the actual Player.finishStep elevation call, after cell commit.
  nativePlayer.updateElevation(nativePlayer.cellX,nativePlayer.cellY)
end
local function moveFollower(point)
  lastCollisionElevation=nil
  check(controller:move(follower,point.x,point.y,point.duration,point),'follower enters native destination '..point.x)
  eq(lastCollisionElevation,nil,'trail replay skips full native entity collision')
  eq(follower.currentElevation,point.currentElevation,'follower uses the recorded collision layer')
end
local function landFollower()
  for _=1,17 do controller:animate(follower,1/60)end
  check(not follower.moving,'follower completes the recorded native duration')
end
local function drawPriority()
  follower.x,follower.y=follower.px,follower.py
  require('src.core.game3.field_view').applyDrawOrder({follower},{},{},0)
  return follower.priority
end
local zero=commitPlayer(2)
eq(nativePlayer.currentElevation,0,'native zero tile changes collision layer')
eq(nativePlayer.elevation,4,'native zero tile retains rendered layer')
eq(zero.currentElevation,0,'trail stores zero collision layer')
eq(zero.elevation,4,'trail stores the retained rendered layer')
-- The live player can already be on another layer while this follower replays.
nativePlayer.currentElevation=8;nativePlayer.elevation=8
-- A wandering NPC can occupy the player's former tile after commitment.
-- Both visible wilds and recorded followers must respect the native NPC.
world.npcs[1]={cellX=2,cellY=1,passable=false}
local nativeAllowed,nativeReason=realCanEnter(game,2,1,
  {fromX=1,fromY=1,dir='right',surfing=false,elevation=zero.currentElevation})
eq(nativeAllowed,false,'native collision refuses the newly occupied trail cell')
eq(nativeReason,'entity','native collision identifies the NPC-only refusal')
eq(include('adapter'):allowed(2,1,'land'),false,'ordinary visible wilds cannot bypass native NPC collision')
-- Find a wall through the native permission API, rather than guessing its byte.
local permissions=require('src.world.gen2.Permissions')
local wallCode
for code=0,255 do if permissions.isWall(code) and not permissions.isWalkable(code)then wallCode=code;break end end
check(wallCode~=nil,'native permissions expose a wall collision')
local gridIndex=1*layout.width+2+1
local previousCollision=nativeCollision._grid[gridIndex]
nativeCollision._grid[gridIndex]=wallCode
eq(nativeCollision.isWalkable(2,1),false,'native grid marks the NPC-occupied tile as a wall')
nativeAllowed,nativeReason=realCanEnter(game,2,1,
  {fromX=1,fromY=1,dir='right',surfing=false,elevation=zero.currentElevation})
eq(nativeAllowed,false,'native collision refuses the NPC on a wall')
eq(nativeReason,'entity','native collision checks the entity before wall permission')
eq(controller:move(follower,zero.x,zero.y,zero.duration,zero),false,'entity refusal cannot let a follower cross a real wall')
check(not follower.moving,'wall refusal leaves follower stationary')
nativeCollision._grid[gridIndex]=previousCollision
eq(include('adapter'):allowed(zero.x,zero.y,'land',follower,zero),true,'recorded followers can pass NPCs on a valid trail tile')
-- Once the NPC vacates, the recorded bridge transition remains valid.
world.npcs={};world.entities={nativePlayer}
moveFollower(zero)
eq(follower.currentElevation,0,'follower uses its recorded layer during motion')
eq(follower.elevation,4,'follower retains bridge rendered layer during motion')
eq(drawPriority(),1,'native compositor keeps the follower above the bridge')
landFollower()
eq(follower.cellX,2,'follower arrives on zero tile')
eq(follower.currentElevation,0,'zero arrival retains native collision layer')
eq(follower.elevation,4,'zero arrival retains native rendered layer')
eq(drawPriority(),1,'zero arrival preserves native bridge priority')
nativePlayer.currentElevation,nativePlayer.elevation=0,4;landPlayer()
local transition=commitPlayer(3)
eq(transition.currentElevation,0,'elevation fifteen retains prior collision layer at commitment')
eq(transition.elevation,4,'elevation fifteen retains prior rendered layer at commitment')
moveFollower(transition);landPlayer();landFollower()
eq(follower.currentElevation,nativePlayer.currentElevation,'transition arrival matches native collision layer')
eq(follower.elevation,nativePlayer.elevation,'transition arrival matches native rendered layer')
local six=commitPlayer(4)
-- Leaving elevation fifteen defers both layer changes until native arrival.
eq(six.currentElevation,0,'fifteen-to-six commitment retains collision layer')
eq(six.elevation,4,'fifteen-to-six commitment retains rendered layer')
moveFollower(six)
eq(follower.currentElevation,0,'follower retains collision layer while leaving transition')
eq(follower.elevation,4,'follower retains rendered layer while leaving transition')
landPlayer()
eq(nativePlayer.currentElevation,6,'native player updates collision layer on transition arrival')
eq(nativePlayer.elevation,6,'native player updates rendered layer on transition arrival')
landFollower()
eq(follower.currentElevation,6,'follower updates native collision layer on transition arrival')
eq(follower.elevation,6,'follower updates native rendered layer on transition arrival')
eq(follower.cellX,4,'follower arrives beyond the elevation transition')
nativeCollision.canEnter=realCanEnter
controller:dispose()
print(('PASS %s: %d native elevation integration checks'):format(version,checks))
