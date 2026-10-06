local checks=0
local function eq(a,b,msg)checks=checks+1;assert(a==b,msg..': '..tostring(a)..' ~= '..tostring(b))end
local E={C={OW_FOLLOWERS_ENABLED=true,OW_FOLLOWERS_RANDOM=true,OW_FOLLOWERS_IDLE_TIME=0},
 Player={cellX=0,cellY=0,px=0,py=0},controlsLocked=function()return false end,followerVisible=function()return true end}
local M=assert(loadfile('lib/idle.lua'))()(E,{});E.Idle=M
local function actor(i)
 return {active=true,emote=-1,act=0,followSlot=i,cellX=i,cellY=1,px=i*16,py=16,
 nativeCore={A={NONE=0,IN_PLACE=1},talking=function()return false end}}
end
local modes={'look','jump','jump_wave','cheer','stretch','doze','wander','play','zoomies','copycat','bounce_wave','spin_wave','pulse_wave'}
local keys={'OW_FOLLOWERS_LOOK_AROUND','OW_FOLLOWERS_JUMP','OW_FOLLOWERS_JUMP_WAVE','OW_FOLLOWERS_CHEER','OW_FOLLOWERS_STRETCH',
 'OW_FOLLOWERS_DOZE','OW_FOLLOWERS_WANDER','OW_FOLLOWERS_PLAY','OW_FOLLOWERS_ZOOMIES','OW_FOLLOWERS_COPYCAT','OW_FOLLOWERS_BOUNCE_WAVE','OW_FOLLOWERS_SPIN_WAVE','OW_FOLLOWERS_PULSE_WAVE'}
local random=math.random;local chosen,rolls
math.random=function(n)eq(n,13,'full behavior pool');rolls=rolls+1;return chosen end
for count=1,6 do
 local line={};for i=1,count do line[i]=actor(i)end
 for choice,name in ipairs(modes)do
  E.Player.moving=true;M.beginTick(line)
  for _,a in ipairs(line)do eq(M.modeFor(a),nil,'moving clears shared choice')end
  E.Player.moving=false;chosen=choice;rolls=0
  for _=1,120 do
   M.beginTick(line)
   for _,a in ipairs(line)do
    M.tick(a);eq(M.modeFor(a),name,'every follower shares stable random mode')
    eq(M.enabled('OW_FOLLOWERS_SLEEPY_BUDDY',a),false,'sleepy buddy excluded from Random')
    for k,key in ipairs(keys)do eq(M.enabled(key,a),k==choice,'only chosen controller enabled')end
   end
  end
  eq(rolls,1,'one roll for entire stop')
  line[1].independent=true;M.beginTick(line);eq(M.modeFor(line[1]),name,'independent activity keeps shared selection');line[1].independent=false
 end
end
local line={actor(1),actor(2)}
E.Player.moving=true;M.beginTick(line);E.Player.moving=false
for _,a in ipairs(line)do a.invisible=true end
rolls=0;M.beginTick(line);eq(rolls,0,'no hidden-only roll')
line[1].invisible=false;chosen=10;M.beginTick(line)
line[2].invisible=false;M.beginTick(line);eq(M.modeFor(line[2]),'copycat','late arrival joins same choice');eq(rolls,1,'late arrival does not reroll')
E.C.OW_FOLLOWERS_RANDOM=false;M.beginTick(line);eq(M.modeFor(line[1]),nil,'disabled random clears choice')
math.random=random
local block={wildsG3FollowerMixed=true,wildsG3FollowerDoze=true};M.select(block,'OW_FOLLOWERS_RANDOM')
eq(block.wildsG3FollowerMixed,false,'random excludes mixed');eq(block.wildsG3FollowerDoze,false,'random excludes standalone')
block.wildsG3FollowerRandom=true;M.select(block,'OW_FOLLOWERS_MIXED');eq(block.wildsG3FollowerRandom,false,'mixed excludes random')
local Rows={GROUPS={},ORDER={},build=function()return {}end,group=function(rows)return rows end}
package.loaded['src.ui.game3.option_rows']=Rows
package.loaded['src.core.game3.options']={block=function(o)o.game3=o.game3 or {};return o.game3 end}
assert(loadfile('lib/native_menu.lua'))()(E,{},{{key='OW_FOLLOWERS_RANDOM',label='Random',type='toggle',default=false}})
for _,game in ipairs({'firered','leafgreen','emerald'})do
 local ctx={options={game3={wildsG3FollowerMixed=true}}}
 local row=Rows.build(ctx)[1];eq(row.id,'wildsG3FollowerRandom',game..' persisted key')
 row.step(ctx,1);eq(ctx.options.game3.wildsG3FollowerRandom,true,game..' toggle saved')
 eq(ctx.options.game3.wildsG3FollowerMixed,false,game..' mixed disabled')
 local child;Rows.group({row},function(_,rows)child=rows end)[1].activate()
 eq(child[1].id,'wildsG3FollowerRandom',game..' nested idle menu')
 row.step(ctx,1);eq(ctx.options.game3.wildsG3FollowerRandom,false,game..' toggle off')
end
print('PASS: '..checks..' shared random idle / stable selection / controller / menu assertions')
