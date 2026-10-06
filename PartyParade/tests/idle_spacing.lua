math.randomseed(42)
local checks=0
local function eq(a,b,msg)checks=checks+1;assert(a==b,msg..': '..tostring(a)..' ~= '..tostring(b))end
local E={FOLLOWER_SLOTS=6,actors={},C={OW_FOLLOWERS_ENABLED=true,OW_FOLLOWERS_MIXED=true,OW_FOLLOWERS_IDLE_TIME=0,
 follower_spacing=7,follower_trainer_spacing=7,OW_FOLLOWERS_WANDER_RANGE=2},
 Player={cellX=10,cellY=10,px=160,py=160,facing='down'},Field={},
 Runtime={getSession=function()end},Pokemon={isEgg=function()return false end,speciesOf=function(m)return m.species end},
 controlsLocked=function()return false end,followerVisible=function()return true end,random=function()return 1 end,
 Collision={inBounds=function(x,y)return x>=0 and y>=0 and x<30 and y<30 end,
 warpAt=function()return false end,ledgeLanding=function()return false end},
 Objects={at=function()end,blocks=function()return false end},canMove=function()return true end}
E.playerCur=function()return E.Player.cellX,E.Player.cellY end;E.playerPrev=E.playerCur
local party={};for i=1,6 do party[i]={hp=20,species=i};E.actors[i]={act=0,emote=-1,species=i,facing='down'}end
E.party=function()return party end
E.actorAt=function(x,y,except)for _,a in ipairs(E.actors)do if a~=except and a.active and
 ((a.cellX==x and a.cellY==y) or (a.moving and a.targetX==x and a.targetY==y)) then return a end end end
local contexts={};local chase=0;local walkCount=0
local function core()
 local c={A={NONE=0,IN_PLACE=1,WALK=2,JUMP=3},talking=function()return false end}
 local ctx,a
 function c.init(e)ctx=e;a=e.FOLLOWER;contexts[#contexts+1]=e end
 function c.update()a.active=ctx.party()[1]~=nil end
 function c.place(x,y,visible)a.cellX,a.cellY=x,y;a.px,a.py=x*16,y*16;a.targetX,a.targetY=x,y;a.invisible=not visible;a.moving=false;a.independent=false end
 function c.reset()a.active=false end
 function c.stopIndependent()a.independent=false;a.wander=nil end
 function c.independentStep(dir,frames)
  local dx={up=0,right=1,down=0,left=-1};local dy={up=-1,right=0,down=1,left=0}
  local x,y=a.cellX+dx[dir],a.cellY+dy[dir]
  eq(E.actorAt(x,y,a),nil,'idle steps avoid other actors and reserved targets')
  a.targetX,a.targetY=x,y;a.moving=true;a.act=2;a.actDur=frames;a.facing=dir;walkCount=walkCount+1;return true
 end
 function c.tick()
  if not a.independent and ctx.Player.moving and not E.Player.moving then chase=chase+1 end
  if a.moving then
   local function move(v,to)local d=to-v;return v+math.max(-2,math.min(2,d))end
   a.px=move(a.px,a.targetX*16);a.py=move(a.py,a.targetY*16)
   if a.px==a.targetX*16 and a.py==a.targetY*16 then a.cellX,a.cellY=a.targetX,a.targetY;a.moving=false;a.act=0 end
  end
  E.Idle.tick(a);E.Doze.tick(a)
 end
 return c
end
package.loaded['src.core.game3.options']={block=function(o)return o end}
local function include(path)
 if path=='follower.lua' then return core() end
 if path=='lib/terrain.lua' then return {followerCellAllowed=function()return true end} end
 if path=='lib/map_offset.lua' then return {} end
 return assert(loadfile((arg[1] or '.')..'/'..path))()
end
E.Idle=include('lib/idle.lua')(E,{});E.Doze=include('lib/doze.lua')(E,{})
local F=include('lib/native_followers.lua')(E,include,{id='wildfollowers',options={get=function()return 6 end},events={on=function()end}});E.Follower=F
F.update();F.seed()
local random=math.random
math.random=function(n)return n==15 and 13 or 1 end
E.Idle.beginTick(F.order)
math.random=random
local modes={'zoomies','zoomies','copycat','sleepy_buddy','sleepy_buddy','copycat'}
for i,a in ipairs(F.order)do a.mixedIdle=modes[i] end
local offsets={};for i,a in ipairs(F.order)do local v=E.Spacing.view(a);offsets[i]={v.px-a.px,v.py-a.py};eq(math.abs(offsets[i][2]),7*i,'configured formation gap')end
local homes={}
for i,a in ipairs(F.order)do local v=E.Spacing.view(a);homes[i]={a.cellX,a.cellY,v.px,v.py}end
local saw={}
for t=1,420 do
 F.tick()
 for i,a in ipairs(F.order)do
  local v=E.Spacing.view(a)
  for j=i+1,#F.order do
   local b=E.Spacing.view(F.order[j])
   eq(math.abs(v.px-b.px)>=16 or math.abs(v.py-b.py)>=16,true,'visible followers never overlap during mixed idle movement')
  end
 end
 for i,a in ipairs(F.order)do
  if a.independent then
   saw[a.mixedIdle]=true
   local v=E.Spacing.view(a)
   eq(math.abs(v.px-a.px)+math.abs(v.py-a.py),7*i,'idle retains configured spacing magnitude')
   eq(v.nativeActor,a,'idle render view keeps native identity')
  end
 end
end
eq(chase,0,'stationary followers never chase independent leaders')
eq(walkCount>0,true,'walking behaviors actually run')
eq(saw.zoomies,true,'mixed zoomies runs');eq(saw.sleepy_buddy,true,'mixed sleepy buddy runs')
-- Stop starting activities without moving the player; drain every controller.
E.C.OW_FOLLOWERS_MIXED=false
for t=1,600 do F.tick()end
for _,a in ipairs(F.order)do eq(a.independent,false,'all behaviors return without deadlock');eq(a.social,nil,'social state released');eq(a.play,nil,'play state released')end
for _,i in ipairs({4,5})do
 local a=F.order[i];local v=E.Spacing.view(a);local h=homes[i]
 eq(a.cellX,h[1],'sleepy pair returns to exact native X');eq(a.cellY,h[2],'sleepy pair returns to exact native Y')
 eq(v.px,h[3],'sleepy pair returns to exact visible X');eq(v.py,h[4],'sleepy pair returns to exact visible Y')
end
F.reset();eq(E.idleReturning,false,'reset clears recovery state')
print('PASS: '..checks..' integrated six-follower spacing / mixed-controller assertions')
