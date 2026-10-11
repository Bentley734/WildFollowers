local root=arg[1]
local function source(n)local f=assert(io.open(root..'/src/'..n..'.lua'));local s=f:read('*a');f:close();return s end
local checks=0
local function check(v,m)checks=checks+1;assert(v,m)end
for gen=1,3 do
 local values={smart_spacing=true,OW_FOLLOWERS_TRAINER_SPACING=1,OW_FOLLOWERS_SPACING=1,OW_FOLLOWERS_IDLE_MODE='none'}
 local mod={path='test',options={get=function(_,k)return values[k]end}}
 local drawn
 local G=setmetatable({draw=function(_,quad)drawn=quad end},{__index=function()return function()end end})
 local modules={['src.core.GameVersion']={generation=function()return gen end}}
 local env=setmetatable({love={graphics=G},require=function(n)return assert(modules[n],n)end},{__index=_G})
 local function loadmod(n,include)return assert(load(source(n),'production '..n,'t',env))()(mod,include)end
 local records={
  {path='g9',w=64,h=64,ee=false,quads={down={[0]=0,1,2,3}}},
  {path='ee',w=64,h=64,ee=true,quads={down={[0]=0,1,2,3}}}}
 local J={pose=function()return 0 end,shadow=function()end}
 local S=loadmod('sprites',function(n)
  if n=='jumps'then return J elseif n=='sprite_bounds'then return {g9={down={16,16,48,64},right={20,16,44,64}},ee={2,2,62,64}} else return {} end
 end)
 S.get=function(_,n)return records[n]end
 local V=loadmod('voxel',function(n)return n=='sprites' and S or J end)
 local followers={{national=1,lineSlot=1,follower=true,px=0,py=0,clock=0,facing='down'},
  {national=2,lineSlot=2,follower=true,px=-64,py=0,clock=0,facing='down'}}
 local T=loadmod('trail')
 T:updateSpacing(followers,S)
 check(T:gap(1)==1.1,'trimmed G9 alpha size, not full canvas')
 check(T:gap(2)==3.6,'large EE follower adds independent safe distance')
 -- Horizontal lines must not inherit a tall sprite's vertical height.
 followers[1].facing='right';followers[2].facing='right'
 T:updateSpacing(followers,S,{px=64,py=0,facing='right'})
 check(T:gap(1)==1,'horizontal trainer gap uses width')
 check(T:gap(2)==3.4,'horizontal pair uses facing width')
 values.OW_FOLLOWERS_IDLE_MODE='mixed'
 T:updateSpacing(followers,S,{px=64,py=0,facing='right'})
 check(T:gap(2)==3.4,'idle mode cannot inflate smart spacing')
 check(T:joinGap(6)==6,'smart catch-up does not add two tiles per follower')
 local compact={}
 for i=1,6 do compact[i]={national=1,lineSlot=i,follower=true,px=-i*16,py=0,facing='right'}end
 T:updateSpacing(compact,S,{px=0,py=0,facing='right'})
 check(T:gap(6)==6,'six narrow followers stay one tile apart despite tall artwork')
 check(T:joinGap(6)==6,'compact catch-up uses actual six-tile line length')
 values.OW_FOLLOWERS_IDLE_MODE='none'
 values.OW_FOLLOWERS_TRAINER_SPACING=4;T:updateSpacing(followers,S)
 check(T:gap(1)==4,'manual spacing remains minimum')
 values.smart_spacing=false
 check(T:gap(2)==5,'smart OFF preserves manual gaps')
 values.smart_spacing=true
 local player={cellX=100,cellY=100,px=1600,py=1600}
 local A={generation=gen,player=function()return player end,grass=function()return false end,land=function()end}
 local C={followers={}}
 env.C=C;env.A=A;env.S=S;env.W={grass=function()return false end};env.T={gap=function()return 1 end}
 env.option=function(k)return values[k]end
 local code=source('controller');local first=assert(code:find('  function C:animate',1,true))
 local last=assert(code:find('  function C:syncFollowers',first,true))
 assert(load(code:sub(first,last-1),'production animation overlap guard','t',env))()
 local front={lineSlot=1,national=1,px=24,py=0,cellX=2,cellY=0,follower=true}
 local e={lineSlot=2,national=1,px=0,py=0,cellX=0,cellY=0,follower=true,clock=0,moving=true,
  startX=0,startY=0,targetX=1,targetY=0,progress=0,duration=.2}
 C.followers={e,front};C:animate(e,.1)
 check(e.px==8,'safe partial step reaches edge')
 C:animate(e,.1)
 check(e.px==8 and e.spacingPaused,'overlap with front follower pauses progression')
 C.followers={e};player.px=24;player.py=0
 C:animate(e,.1)
 check(e.px==8,'trainer overlap also pauses progression')
 player.px=1600;player.py=1600
 e.px=20;e.startX=20;e.progress=0;e.targetX=0
 C.followers={e,front};C:animate(e,.1)
 check(e.px==10,'existing overlap can unwind rather than trapping actor')
 -- A turn can bring the leader towards a trailing body. Checking that tail
 -- makes the leader wait for the tail, which itself waits for the leader.
 e.lineSlot=1;front.lineSlot=2;e.startX=0;e.px=0;e.py=0;e.progress=0;e.targetX=1;e.targetY=0;e.moving=true
 front.px=24;front.py=0
 C:animate(e,.1);C:animate(e,.1)
 check(e.cellX==1 and not e.moving,'leader completes turn without waiting for tail')

 -- A coarse update that crosses the safe boundary must retain its safe pixels.
 e.lineSlot=2;front.lineSlot=1;front.px=26;front.py=0
 e.startX=0;e.startY=0;e.px=0;e.py=0;e.progress=0;e.targetX=1;e.targetY=0;e.moving=true
 C.followers={e,front};C:animate(e,.15)
 check(e.px>9.99 and e.px<=10.001,'partial overlap frame advances up to safe edge instead of losing all movement')

 for _,follower in ipairs({true,false})do
  local key=follower and 'followers_march' or 'wilds_march'
  local a={national=1,follower=follower,px=100,py=200,clock=0,facing='down'}
  for _,enabled in ipairs({false,true})do
   values[key]=enabled
   for frame=0,3 do
    a.clock=frame/8
    S:draw(a,0,0,1)
    check(drawn==(enabled and frame or 0),'march cycle in 2D')
    local sprite,x,y=V:pose(a)
    check(sprite.def._wildFollowers.frame==(enabled and frame or 0),'march cycle in native/3D pose')
    check(x==100 and y==200 and not a.moving,'march cannot move actor')
   end
  end
 end
 -- Music idle frames override standing march in both compositors.
 values.followers_march=true;values.followers_march_speed=.1
 local dancing={national=1,follower=true,px=100,py=200,clock=0,facing='down',idlePose={music=true,frame=2,sx=1,sy=1}}
 S:draw(dancing,0,0,1);check(drawn==2,'music frame overrides standing march in 2D')
 local musicSprite=V:pose(dancing);check(musicSprite.def._wildFollowers.frame==2,'music frame overrides standing march in native pose')
 dancing.moving=true;dancing.clock=.13
 check(S:frame(dancing)==1,'walking interrupts music frames as well as march speed')
 -- Independent speed multipliers must match in 2D and native/3D poses.
 for _,follower in ipairs({true,false})do
  local key=follower and 'followers_march' or 'wilds_march'
  local other=follower and 'wilds_march' or 'followers_march'
  values[key]=true;values[other]=true;values[other..'_speed']=3
  local a={national=1,follower=follower,px=100,py=200,clock=0,facing='down'}
  for _,speed in ipairs({.1,.2,.25,.33,.5,.75,1,1.25,1.5,2,3})do
   values[key..'_speed']=speed
   for sample=0,95 do
    a.clock=sample*.07
    local expected=math.floor(a.clock*8*speed)%4
    S:draw(a,0,0,1);check(drawn==expected,'chosen march speed drives 2D animation independently')
    local sprite,x,y=V:pose(a)
    check(sprite.def._wildFollowers.frame==expected,'native/3D march speed matches 2D')
    check(x==100 and y==200 and not a.moving,'march speed cannot move actor')
   end
  end
  for _,speed in ipairs({.1,.2,.25,.33,.5,.75,1,1.25,1.5,2,3})do
   values[key]=true;values[key..'_speed']=speed;a.moving=true;a.spacingPaused=nil;a.progress=.5;a.clock=.13
   S:draw(a,0,0,1);local expected=follower and 1 or 3
   check(drawn==expected,'walking uses normal animation regardless of march speed')
   local sprite=V:pose(a)
   check(sprite.def._wildFollowers.frame==expected,'native walking also ignores march speed')
   a.spacingPaused=true
   check(S:frame(a)==math.floor(a.clock*8*speed)%4,'stationary paused step uses chosen march speed')
  end
  a.spacingPaused=nil
  values[key]=false;a.moving=true;a.clock=.13;a.progress=.5
  check(S:frame(a)==(follower and 1 or 3),'march OFF preserves native walking animation')
 end

end
print('PASS '..checks..' smart alpha bounds, pairwise spacing, manual minimum, march toggles and 2D/native pose checks')

