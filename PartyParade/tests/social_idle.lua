local checks=0
local function eq(a,b,msg)checks=checks+1;assert(a==b,msg..': '..tostring(a)..' ~= '..tostring(b))end
local E={FOLLOWER_SLOTS=6,C={OW_FOLLOWERS_ENABLED=true,OW_FOLLOWERS_IDLE_TIME=0,OW_FOLLOWERS_ZOOMIES=true},
 Player={cellX=3,cellY=4,px=48,py=64,facing='down'},Field={},
 controlsLocked=function()return false end,followerVisible=function()return true end,
 Objects={at=function()end},canMove=function()return true end}
local blocked,actors={},{}
E.Collision={inBounds=function(x,y)return x>=0 and x<12 and y>=0 and y<12 end,
 warpAt=function(x,y)return blocked[x..','..y] end,ledgeLanding=function()return false end}
E.actorAt=function(x,y,except)for _,a in ipairs(actors)do if a~=except and a.cellX==x and a.cellY==y then return a end end end
local Idle=assert(loadfile('lib/idle.lua'))()(E,{});E.Idle=Idle
E.Doze=assert(loadfile('lib/doze.lua'))()(E,{})
local W=assert(loadfile('lib/wander.lua'))()(E,{followerCellAllowed=function()return true end})
local S=assert(loadfile('lib/social_idle.lua'))()(E,W);E.Social=S
local dx={up=0,right=1,down=0,left=-1};local dy={up=-1,right=0,down=1,left=0}
local steps={}
local function actor(i,x,y)
 local a={active=true,emote=-1,act=0,followSlot=i,cellX=x,cellY=y,px=x*16,py=y*16,facing='down',species=i}
 a.nativeCore={A={NONE=0,IN_PLACE=1,WALK=2},talking=function()return false end,
 stopIndependent=function()a.independent=false end,
 independentStep=function(dir,frames)
  local x,y=a.cellX+dx[dir],a.cellY+dy[dir]
  eq(W.free(a,x,y,dir),true,'every issued step is legal')
  steps[#steps+1]={dir,frames};a.cellX,a.cellY=x,y;a.px,a.py=x*16,y*16;return true
 end}
 return a
end
local function tick(n)
 for _=1,n do W.beginTick();Idle.beginTick(actors);S.beginTick(actors)
  for i,a in ipairs(actors)do S.tick(a,i==1 and E.Player or actors[i-1]);Idle.tick(a) end
 end
end
local random=math.random;math.random=function()return 1 end
actors={actor(1,4,4)};tick(70)
eq(#steps,4,'zoomies completes four-step loop');eq(actors[1].cellX,4,'loop closes X');eq(actors[1].cellY,4,'loop closes Y')
eq(actors[1].social,nil,'zoomies returns to line');eq(actors[1].independent,false,'native following resumes')
for _,step in ipairs(steps)do eq(step[2],8,'zoomies uses fast native gait')end
S.reset();W.reset();steps={};blocked['4,3']=true;actors={actor(1,4,4)};tick(40)
eq(#steps,0,'blocked loop never steps into warp');eq(actors[1].social,nil,'blocked loop safely abandons')
blocked={};S.reset();W.reset();steps={};actors={actor(1,4,4)};tick(20)
E.Player.moving=true;tick(60);eq(actors[1].social,nil,'moving player interrupts and returns zoomies');E.Player.moving=false
S.reset();W.reset();steps={};E.C.OW_FOLLOWERS_ZOOMIES=false;E.C.OW_FOLLOWERS_SLEEPY_BUDDY=true
actors={actor(1,4,4),actor(2,6,4)};tick(40)
eq(E.Doze.sleeping(actors[1]),true,'first follower sleeps');eq(E.Doze.sleeping(actors[2]),false,'buddy stays awake')
tick(110);eq(actors[2].cellX,5,'buddy walks beside sleeper');eq(E.Doze.sleeping(actors[1]),false,'buddy wakes sleeper')
local _,hopY=S.pose(actors[1]);eq(type(hopY),'number','waking follower has hop pose')
tick(130);eq(actors[1].social,nil,'sleeper rejoins');eq(actors[2].social,nil,'buddy rejoins');eq(#steps,2,'buddy approaches then returns to its original slot');eq(actors[2].cellX,6,'buddy fully restores original formation X');eq(actors[2].cellY,4,'buddy fully restores original formation Y')
-- A buddy ahead of its sleeper must also restore its own slot, leader first.
S.reset();W.reset();steps={};actors={actor(1,6,4),actor(2,4,4)};tick(150)
eq(actors[2].cellX,5,'reverse-order buddy approaches sleeper')
blocked['4,4']=true;tick(130)
eq(actors[2].social~=nil,true,'blocked original slot retains return state')
eq(actors[2].social.returning,true,'blocked buddy keeps returning')
blocked={};tick(80)
eq(actors[2].cellX,4,'unblocked buddy restores original slot')
eq(actors[2].social,nil,'reverse-order buddy releases after exact return')
-- Once the trainer moves, stale homes must not pull followers backwards.
S.reset();W.reset();actors={actor(1,4,4),actor(2,6,4)};tick(40)
eq(actors[2].social.home.cellX,6,'home captured before approach')
E.Player.moving=true;S.beginTick(actors)
for _,a in ipairs(actors)do eq(a.social.home,nil,'trainer movement invalidates stationary home')end
E.Player.moving=false;S.reset()
S.reset();W.reset();actors={actor(1,4,4)};tick(220);eq(E.Doze.sleeping(actors[1]),false,'single follower wakes itself');tick(80);eq(actors[1].social,nil,'single follower returns')
-- Copycat shares its leader clock but renders each imitation 24 frames later.
E.C.OW_FOLLOWERS_SLEEPY_BUDDY=false;E.C.OW_FOLLOWERS_COPYCAT=true
actors={actor(1,4,4),actor(2,5,4)};W.reset();tick(12)
local face1=Idle.pose(actors[1]);eq(face1,'right','leader makes first turn');eq(Idle.pose(actors[2]),nil,'second waits to imitate')
tick(24);eq(Idle.pose(actors[2]),'right','second copies the leader turn')
tick(24);local _,y=Idle.pose(actors[1]);eq(y<0,true,'leader hops');tick(24);local _,y2=Idle.pose(actors[2]);eq(y2<0,true,'second copies hop')
E.Player.moving=true;tick(1);eq(Idle.pose(actors[1]),nil,'movement cancels copycat')
math.random=random
print('PASS: '..checks..' social idle checks; legal zoomies, blockage, interruption, paired/single sleep wake, clean return and copycat timing')
