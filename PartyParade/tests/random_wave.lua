local checks=0
local function eq(a,b,msg)checks=checks+1;assert(a==b,msg..': '..tostring(a)..' ~= '..tostring(b))end
local E={C={OW_FOLLOWERS_ENABLED=true,OW_FOLLOWERS_RANDOM_WAVE=true,OW_FOLLOWERS_IDLE_TIME=0},
 Player={},controlsLocked=function()return false end,followerVisible=function()return true end}
local M=assert(loadfile('lib/idle.lua'))()(E,{});E.Idle=M
local function actor(i)return {active=true,emote=-1,act=0,species=i,facing='down',followSlot=i,
 cellX=i,cellY=0,px=i*16,py=0,nativeCore={A={NONE=0,IN_PLACE=1},talking=function()return false end}}end
local names={'jump_wave','bounce_wave','spin_wave','pulse_wave'}
local keys={'OW_FOLLOWERS_JUMP_WAVE','OW_FOLLOWERS_BOUNCE_WAVE','OW_FOLLOWERS_SPIN_WAVE','OW_FOLLOWERS_PULSE_WAVE'}
local random=math.random;local roll,choice
math.random=function(n)eq(n,4,'only four wave effects');roll=roll+1;return choice end
for count=1,6 do
 local line={};for i=1,count do line[i]=actor(i)end
 for k,name in ipairs(names)do
  E.Player.moving=true;M.beginTick(line);E.Player.moving=false;roll=0;choice=k
  for _=1,480 do
   M.beginTick(line)
   for _,a in ipairs(line)do
    M.tick(a);eq(M.modeFor(a),name,'entire line shares selected wave')
    eq(select(2,M.age(a)),name,'selected choreography has live clock')
    for j,key in ipairs(keys)do eq(M.enabled(key,a),j==k,'only selected wave enabled')end
    eq(M.enabled('OW_FOLLOWERS_WANDER',a),false,'random wave cannot wander')
    eq(M.enabled('OW_FOLLOWERS_DOZE',a),false,'random wave cannot doze')
    eq(M.enabled('OW_FOLLOWERS_PLAY',a),false,'random wave cannot play tag')
   end
  end
  eq(roll,1,'stable one roll per stop')
 end
end
-- Switching from unrestricted random must discard a non-wave shared choice.
math.random=function()return 6 end
E.C.OW_FOLLOWERS_RANDOM_WAVE=false;E.C.OW_FOLLOWERS_RANDOM=true
local line={actor(1),actor(2)};M.beginTick(line);eq(M.modeFor(line[1]),'doze','broad random supports doze')
E.C.OW_FOLLOWERS_RANDOM=false;E.C.OW_FOLLOWERS_RANDOM_WAVE=true;choice=4;roll=0
math.random=function(n)eq(n,4,'switch narrows choices');roll=roll+1;return choice end
M.beginTick(line);eq(M.modeFor(line[1]),'pulse_wave','live switch immediately rerolls wave pool')
line[2].invisible=true;M.beginTick(line);line[2].invisible=false;M.beginTick(line)
eq(M.modeFor(line[2]),'pulse_wave','late participant joins same effect');eq(roll,1,'visibility does not reroll choice')
math.random=random
local Rows={GROUPS={},ORDER={},build=function()return {}end,group=function(r)return r end}
package.loaded['src.ui.game3.option_rows']=Rows
package.loaded['src.core.game3.options']={block=function(o)o.game3=o.game3 or {};return o.game3 end}
assert(loadfile('lib/native_menu.lua'))()(E,{},{{key='OW_FOLLOWERS_RANDOM_WAVE',label='Random wave',type='toggle',default=false}})
for _,game in ipairs({'firered','leafgreen','emerald'})do
 local ctx={options={game3={wildsG3FollowerRandom=true,wildsG3FollowerMixed=true,wildsG3FollowerBounceWave=true}}}
 local row=Rows.build(ctx)[1];eq(row.value(ctx),'OFF',game..' default off');row.step(ctx,1)
 eq(ctx.options.game3.wildsG3FollowerRandomWave,true,game..' selection saved')
 for _,key in ipairs({'wildsG3FollowerRandom','wildsG3FollowerMixed','wildsG3FollowerBounceWave'})do eq(ctx.options.game3[key],false,'random wave exclusive')end
 local children;Rows.group({row},function(_,r)children=r end)[1].activate()
 eq(children[1].id,'wildsG3FollowerRandomWave','nested idle option')
 M.select(ctx.options.game3,'OW_FOLLOWERS_RANDOM');eq(ctx.options.game3.wildsG3FollowerRandomWave,false,'broad random deselects wave random')
end
print('PASS: '..checks..' random wave / shared effect / stable timing / saved menu assertions')
