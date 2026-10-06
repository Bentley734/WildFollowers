local checks=0
local function eq(a,b,msg)checks=checks+1;assert(a==b,msg..': '..tostring(a)..' ~= '..tostring(b))end
local E={C={OW_FOLLOWERS_ENABLED=true,OW_FOLLOWERS_IDLE_TIME=0,follower_spacing=7,follower_trainer_spacing=7},
 Player={px=0,py=0},controlsLocked=function()return false end,followerVisible=function()return true end,
 Collision={inBounds=function()return true end},Objects={blocks=function()return false end}}
local M=assert(loadfile('lib/idle.lua'))()(E,{});E.Idle=M
local Spacing=assert(loadfile('lib/spacing.lua'))()(E,{followerCellAllowed=function()return true end})
local defs={{'OW_FOLLOWERS_BOUNCE_WAVE','bounce_wave','wildsG3FollowerBounceWave'},
 {'OW_FOLLOWERS_SPIN_WAVE','spin_wave','wildsG3FollowerSpinWave'},
 {'OW_FOLLOWERS_PULSE_WAVE','pulse_wave','wildsG3FollowerPulseWave'}}
local function actor(i)return {active=true,emote=-1,act=0,species=i,facing='down',followSlot=i,
 cellX=i,cellY=0,px=i*16,py=0,nativeCore={A={NONE=0,IN_PLACE=1,JUMP=3},talking=function()return false end}}end
for _,def in ipairs(defs)do
 E.C[def[1]]=true
 for count=1,6 do
  local line={};for i=1,count do line[i]=actor(i);Spacing.track(line[i],E.Player)end
  local seenHop,seenTurn,seenScale=false,false,false
  for tick=1,720 do
   M.beginTick(line)
   for i,a in ipairs(line)do
    M.tick(a);local v=Spacing.view(a)
    local phase,name=M.age(v);local rank=math.floor(tick/240)%2==0 and i-1 or count-i
    local expected=tick%240-rank*18;if expected<0 then expected=239 end
    eq(name,def[2],'view retains shared dance');eq(phase,expected,'alternating choreography rank')
    local face,y=M.pose(v);local sx,sy=M.scale(v)
    eq(y>=-9 and y<=0,true,'hop remains bounded')
    eq(sx>=.8 and sx<=1.2 and sy>=.8 and sy<=1.2,true,'scale remains bounded')
    eq(a.px,i*16,'dance never moves ground X');eq(a.py,0,'dance never moves ground Y');eq(a.facing,'down','render turns preserve native facing')
    seenHop=seenHop or y<0;seenTurn=seenTurn or face~='down';seenScale=seenScale or sx~=1 or sy~=1
   end
  end
  eq(seenHop,def[2]~='pulse_wave','hop visible in hop routines')
  eq(seenTurn,def[2]=='spin_wave','spin produces directional sequence')
  eq(seenScale,def[2]=='pulse_wave','pulse produces squash and stretch')
  E.Player.moving=true;M.beginTick(line);eq(M.pose(line[1]),nil,'movement stops dance');E.Player.moving=false
  line[count].invisible=true;M.beginTick(line)
  for i=1,count-1 do M.tick(line[i]);local phase=M.age(line[i]);eq(phase,i==1 and 1 or 239,'hidden tail cannot stall ready dancers')end
 end
 E.C[def[1]]=false;M.beginTick({})
end
local Rows={GROUPS={},ORDER={},build=function()return {}end,group=function(r)return r end}
package.loaded['src.ui.game3.option_rows']=Rows
package.loaded['src.core.game3.options']={block=function(o)o.game3=o.game3 or {};return o.game3 end}
local schema={};for _,d in ipairs(defs)do schema[#schema+1]={key=d[1],label=d[2],type='toggle',default=false}end
assert(loadfile('lib/native_menu.lua'))()(E,{},schema)
for _,game in ipairs({'firered','leafgreen','emerald'})do
 local ctx={options={game3={wildsG3FollowerRandom=true,wildsG3FollowerMixed=true}}}
 for i,def in ipairs(defs)do
  local row=Rows.build(ctx)[i];row.step(ctx,1)
  eq(ctx.options.game3[def[3]],true,game..' dance persists')
  eq(ctx.options.game3.wildsG3FollowerRandom,false,'dance excludes random')
  eq(ctx.options.game3.wildsG3FollowerMixed,false,'dance excludes mixed')
  for j,other in ipairs(defs)do if j~=i then eq(ctx.options.game3[other[3]],false,'only one dance selected')end end
 end
 local children;local launch=Rows.group(Rows.build(ctx),function(_,r)children=r end)[1];launch.activate()
 eq(#children,3,'all dances in idle submenu')
end
print('PASS: '..checks..' coordinated dance / spacing view / repeat direction / saved menu assertions')
