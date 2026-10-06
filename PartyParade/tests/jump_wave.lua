local checks=0
local function eq(a,b,msg)checks=checks+1;assert(a==b,(msg or '')..': '..tostring(a)..' ~= '..tostring(b))end
local locked=false
local E={C={OW_FOLLOWERS_ENABLED=true,OW_FOLLOWERS_JUMP_WAVE=true,OW_FOLLOWERS_IDLE_TIME=0},Player={moving=false,jumping=false},controlsLocked=function()return locked end,followerVisible=function()return true end}
local function actor(i)return {active=true,emote=-1,act=0,followSlot=i,facing='down',species=i,nativeCore={A={NONE=0,IN_PLACE=1},talking=function()return false end}}end
local function create()return assert(loadfile('lib/idle.lua'))()(E,{})end
for count=1,6 do
 local M=create();local order={};for i=1,count do order[i]=actor(i)end
 for frame=1,1200 do
  M.beginTick(order);for _,a in ipairs(order)do M.tick(a)end
  local round,phase=math.floor(frame/300),frame%300;local airborne=0
  for i,a in ipairs(order)do
   local dir,y,hop=M.pose(a)
   local rank=round%2==0 and i-1 or count-i;local p=phase-rank*24;local expected=0
   if p>=0 and p<24 then expected=-math.floor(8*math.sin(math.pi*p/24)+.5)end
   eq(y,expected,'height: count '..count..', frame '..frame..', follower '..i)
   eq(dir,'down','facing');eq(hop,true,'jump pose')
   if y<0 then airborne=airborne+1 end
   if phase==rank*24+12 then eq(y,-8,'alternating hop peak')end
  end
  eq(airborne<=1,true,'sequential hops')
 end
end
local M=create();local order={actor(1),actor(2),actor(3)}
local function step(n)for _=1,n do M.beginTick(order);for _,a in ipairs(order)do M.tick(a)end end end
local function height(a)local _,y=M.pose(a);return y end
E.C.OW_FOLLOWERS_IDLE_TIME=1
for frame=1,59 do step(1);eq(M.pose(order[1]),nil,'idle delay')end
step(13);eq(height(order[1]),-8,'first after delay')
E.Player.moving=true;step(1);eq(M.pose(order[1]),nil,'movement cancels');E.Player.moving=false
E.C.OW_FOLLOWERS_IDLE_TIME=0;step(12);eq(height(order[1]),-8,'movement restarts forward')
locked=true;M.beginTick(order);eq(M.pose(order[1]),nil,'script lock');locked=false
step(1);eq(height(order[3]),0,'restart from first')
order={order[3],order[1]};step(12);eq(height(order[1]),-8,'current order and count')
M.beginTick({});eq(M.pose(order[1]),nil,'empty roster clears')
local block={wildsG3FollowerJump=true,wildsG3FollowerJumpWave=true,wildsG3FollowerPlay=true}
M.select(block,'OW_FOLLOWERS_JUMP_WAVE')
eq(block.wildsG3FollowerJump,false,'regular jump deselected');eq(block.wildsG3FollowerPlay,false,'play deselected');eq(block.wildsG3FollowerJumpWave,true,'wave selected')
E.C.OW_FOLLOWERS_JUMP_WAVE=false;E.C.OW_FOLLOWERS_JUMP=true
M=create();order={actor(1),actor(2)};step(12)
eq(height(order[1]),-8,'regular timing retained');eq(height(order[2]),0,'regular stagger retained')
print('PASS: '..checks..' jump wave checks; 1–6 followers, four alternating rounds, delay, resets and regular jump')
