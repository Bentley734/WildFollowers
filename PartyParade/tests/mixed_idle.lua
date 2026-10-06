bit=bit or bit32 or require('bit')
local checks=0
local function eq(a,b,msg)checks=checks+1;assert(a==b,(msg or '')..': '..tostring(a)..' ~= '..tostring(b))end
local function include(p)return assert(loadfile(p))()end
local E={FOLLOWER_SLOTS=6,C={OW_FOLLOWERS_ENABLED=true,OW_FOLLOWERS_JUMP_WAVE=true,OW_FOLLOWERS_IDLE_TIME=0},
 Player={moving=false,jumping=false,cellX=0,cellY=0,px=0,py=0,facing='down'},
 controlsLocked=function()return false end,followerVisible=function()return true end,
 Collision={inBounds=function()return true end,warpAt=function()return false end,
  ledgeLanding=function()return false end},Objects={at=function()end,blocks=function()return false end},
 actorAt=function()end,canMove=function()return true end,Field={}}
local function actor(i)
 local a={active=true,emote=-1,act=0,followSlot=i,facing='down',species=i,
  cellX=i,cellY=2,px=i*16,py=32}
 a.nativeCore={A={NONE=0,IN_PLACE=1,WALK=1},talking=function()return false end,
  stopIndependent=function()a.independent=false end,
  independentStep=function()a.moving=true end}
 return a
end
local M=include('lib/idle.lua')(E,{})
local line={actor(1),actor(2),actor(3)}
local function step(n)
 for _=1,n do M.beginTick(line);for _,a in ipairs(line)do M.tick(a)end end
end
local function height(a)local _,y=M.pose(a);return y end
-- Regression: native order includes active followers still hidden in balls.
line[3].invisible=true
step(12);eq(height(line[1]),-8,'visible first hops with hidden tail')
step(24);eq(height(line[2]),-8,'visible second hops with hidden tail')
line[2].moving=true
step(12);eq(height(line[1]),-8,'busy member does not stall ready member')
line[2].moving=false;line[3].invisible=false
step(12);eq(height(line[1]),-8,'ready lineup restarts forward')
local Terrain={followerCellAllowed=function()return true end}
local Spacing=include('lib/spacing.lua')(E,Terrain)
for _,a in ipairs(line)do Spacing.track(a,E.Player) end
local view=Spacing.view(line[1])
eq(view~=line[1],true,'production renderer passes a spacing view')
eq(view.nativeActor,line[1],'spacing view keeps native identity')
eq(height(view),-8,'wave visible through production spacing view')
-- Demonstrate that the previous release loses its wave on that same view.
local old=loadfile('../reference/wildfollowers/lib/idle.lua')
if old then
 local baseline=old()(E,{})
 for _=1,12 do baseline.beginTick(line);for _,a in ipairs(line)do baseline.tick(a)end end
 local _,y=baseline.pose(view)
 eq(y,nil,'2.21.7 reproduces missing wave in render view')
end
-- Mixed selects one stable nearby pair and excludes solo legacy activities.
E.C.OW_FOLLOWERS_JUMP_WAVE=false;E.C.OW_FOLLOWERS_MIXED=true
local random=math.random
math.randomseed(42)
local allowed={look=true,jump=true,jump_wave=true,cheer=true,stretch=true,zoomies=true,copycat=true,bounce_wave=true,spin_wave=true,pulse_wave=true,sleepy_buddy=true}
for count=1,6 do
 for stop=1,100 do
  E.Player.moving=true;M.beginTick(line);E.Player.moving=false
  line={};for i=1,count do line[i]=actor(i)end
  step(1)
  local sleepy=0;local chosen={}
  for i,a in ipairs(line)do
   eq(allowed[a.mixedIdle],true,'only allowed mixed choices')
   chosen[i]=a.mixedIdle
   if a.mixedIdle=='sleepy_buddy' then sleepy=sleepy+1 end
   for _,key in ipairs({'OW_FOLLOWERS_DOZE','OW_FOLLOWERS_WANDER','OW_FOLLOWERS_PLAY'})do
    eq(M.enabled(key,a),false,'excluded mixed behavior cannot start')
   end
  end
  eq(sleepy,count>=2 and 2 or 0,'exactly one sleepy pair, no solo selection')
  step(10)
  for i,a in ipairs(line)do eq(a.mixedIdle,chosen[i],'stable assignment while stopped')end
 end
end
-- Pair stays selected through its independent animation and repairs removals.
line={actor(1),actor(2),actor(3)}
E.Player.moving=true;M.beginTick(line);E.Player.moving=false;step(1)
local pair={};for _,a in ipairs(line)do if a.mixedIdle=='sleepy_buddy' then pair[#pair+1]=a end end
pair[1].independent=true;pair[2].independent=true;step(5)
for _,a in ipairs(pair)do eq(a.mixedIdle,'sleepy_buddy','active social pair retained')end
pair[1].invisible=true;pair[2].independent=false;step(1)
local sleepy=0;for _,a in ipairs(line)do if a.mixedIdle=='sleepy_buddy' then sleepy=sleepy+1 end end
eq(sleepy,2,'visible replacement gets a complete pair')
line={actor(1),actor(2)};E.Player.moving=true;M.beginTick(line);E.Player.moving=false;step(1)
line[2].moving=true
E.Idle=M;E.Doze=include('lib/doze.lua')(E,{})
local W=include('lib/wander.lua')(E,Terrain);W.time=120;W.idle=120
local S=include('lib/social_idle.lua')(E,W)
S.beginTick(line);eq(line[1].social,nil,'mixed sleeper waits for busy partner')
line[2].moving=false;S.beginTick(line)
eq(line[1].social.partner,line[2],'sleeper claims its assigned partner')
eq(line[2].social.partner,line[1],'buddy reciprocates')
E.Player.moving=true;M.beginTick(line)
for _,a in ipairs(line)do eq(a.mixedIdle,nil,'movement clears selections')end
E.Player.moving=false;math.random=random
-- Standalone modes remain available; busy/hidden followers do not create solos.
E.C.OW_FOLLOWERS_MIXED=false
for _,key in ipairs({'OW_FOLLOWERS_DOZE','OW_FOLLOWERS_WANDER','OW_FOLLOWERS_PLAY'})do
 E.C[key]=true;eq(M.enabled(key,line[1]),true,'standalone behavior preserved');E.C[key]=false
end
E.C.OW_FOLLOWERS_MIXED=true
line={actor(1),actor(2)};line[2].invisible=true
M.beginTick(line);eq(line[1].mixedIdle~='sleepy_buddy',true,'hidden partner does not create solo sleeper')
E.Player.moving=true;M.beginTick(line);E.Player.moving=false
line[2].invisible=false;line[2].moving=true;M.beginTick(line)
eq(line[1].mixedIdle~='sleepy_buddy',true,'moving partner excluded until ready')
line[2].moving=false;M.beginTick(line)
for _,a in ipairs(line)do eq(a.mixedIdle,'sleepy_buddy','late-ready follower completes exactly one pair')end
-- Native menu mode exclusivity and persistence for all three games.
local Rows={GROUPS={},ORDER={},build=function()return {}end,group=function(rows)return rows end}
package.loaded['src.ui.game3.option_rows']=Rows
package.loaded['src.core.game3.options']={block=function(o)o.game3=o.game3 or {};return o.game3 end}
local schema={{key='OW_FOLLOWERS_ZOOMIES',label='Zoomies',type='toggle',default=false},
 {key='OW_FOLLOWERS_COPYCAT',label='Copycat',type='toggle',default=false},
 {key='OW_FOLLOWERS_SLEEPY_BUDDY',label='Sleepy buddy',type='toggle',default=false},
 {key='OW_FOLLOWERS_MIXED',label='Mixed',type='toggle',default=false},
 {key='OW_FOLLOWERS_JUMP_WAVE',label='Jump wave',type='toggle',default=false}}
include('lib/native_menu.lua')(E,{},schema)
for _,version in ipairs({'firered','leafgreen','emerald'})do
 local ctx={options={game3={wildsG3FollowerJumpWave=true,wildsG3FollowerDoze=true}}}
 local rows=Rows.build(ctx)
 rows[4].step(ctx,1)
 eq(ctx.options.game3.wildsG3FollowerMixed,true,version..' native mixed saved')
 eq(ctx.options.game3.wildsG3FollowerJumpWave,false,version..' wave deselected')
 eq(ctx.options.game3.wildsG3FollowerDoze,false,version..' doze deselected')
 rows[5].step(ctx,1)
 eq(ctx.options.game3.wildsG3FollowerMixed,false,version..' mixed deselected')
 for _,id in ipairs({'wildsG3FollowerZoomies','wildsG3FollowerCopycat','wildsG3FollowerSleepyBuddy'})do
  local rows=Rows.build(ctx);local selected
  for _,r in ipairs(rows)do if r.id==id then selected=r end end
  eq(selected~=nil,true,version..' new idle option exists')
  selected.step(ctx,1)
  eq(ctx.options.game3[id],true,version..' new behavior persists')
  eq(ctx.options.game3.wildsG3FollowerJumpWave,false,version..' new selection disables previous mode')
 end
 eq(ctx.options.game3.wildsG3FollowerZoomies,false,version..' modes remain exclusive')
 eq(ctx.options.game3.wildsG3FollowerCopycat,false,version..' sleepy selection disables copycat')

 eq(ctx.options.game3.wildsG3FollowerSleepyBuddy,true,version..' final selection retained')
end
print('PASS: '..checks..' mixed idle / stalled-wave checks; independent random choices, mode controllers, movement rerolls and native menu')
