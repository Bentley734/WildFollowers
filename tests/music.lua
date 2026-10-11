local root=arg[1]
local checks=0
local function check(v,m)checks=checks+1;assert(v,m)end
local function read(n)local f=assert(io.open(root..'/src/'..n..'.lua'));local s=f:read('*a');f:close();return s end
local stamp=1000;local signal
local values={OW_FOLLOWERS_IDLE_MODE='music',OW_FOLLOWERS_IDLE_TIME=0,music_sensitivity=1,music_speed=1}
local mod={read=function()return signal end,options={get=function(_,key)return values[key]end}}
local env=setmetatable({os={time=function()return stamp end}},{__index=_G})
local Music=assert(load(read('music'),'music','t',env))()(mod)
local function packet(seq,beats,level,bass,state,time)
 signal=('WFMusic1 %d %d %.6f %.6f %d %s\n'):format(seq,time or stamp,level or .025,bass or .02,beats,state or 'ready')
end
packet(1,0);Music:tick(.05);check(Music.state=='ready','fresh bridge connects')
packet(2,1);Music:tick(.05);Music:tick(.09)
check(Music:pose(0,'down').hop<0,'bass onset causes head hop')
check(Music:pose(5,'down').hop==0,'tail hop waits for beat wave')
for seq=3,8 do packet(seq,1);Music:tick(.05)end
check(Music:pose(5,'down').hop<0,'bass onset reaches tail without moving cells')
local p={moving=false,cellX=10,cellY=10,facing='down'};local busy=false
local A={player=function()return p end,busy=function()return busy end}
local T={points={},index=0}
local e={cellX=9,cellY=10,px=144,py=160,facing='down',slot=1,clock=0}
local c={followers={e},move=function()error('music mode must never move cells')end}
local modules={adapter=A,trail=T,music=Music,jumps={duration=.53},avoidance={}}
local I=assert(load(read('idle')))()(mod,function(n)return assert(modules[n],n)end)
packet(9,2);check(I:tick(c,e,.05),'music uses idle pipeline')
packet(10,2);I:tick(c,e,.1)
check(e.idlePose and e.idlePose.music and e.idlePose.jumping,'music pose drives existing jump renderer')
check(e.cellX==9 and e.cellY==10 and e.px==144 and e.py==160,'dancing preserves trail coordinates')
p.moving=true;check(not I:tick(c,e,.05) and not e.idlePose,'walking immediately cancels dancing')
p.moving=false;busy=true;check(not I:tick(c,e,.05) and not e.idlePose,'menus and battles cancel dancing')
busy=false;packet(11,0);Music:tick(.05);check(#Music.events<=2,'helper restart never fabricates a huge beat wave')
for _,bad in ipairs({'garbage','return os.execute("bad")',string.rep('1',300),'WFMusic1 1 1000 99 0 0 ready','WFMusic1 1 990 0.1 0.1 1 ready','WFMusic1 1 1009 0.1 0.1 1 ready'})do
 signal=bad;Music:tick(.05);check(Music.state=='not running' and Music:pose(0,'down').hop==0,'invalid or stale input rests safely')
end
packet(12,0,0,0);Music:tick(.05)
for seq=13,70 do packet(seq,0,0,0);Music:tick(.05)end
local pose=Music:pose(0,'down');check(pose.frame==0 and pose.hop==0 and math.abs(pose.sx-1)<.00001,'silence settles without invented dancing')
Music:tick(.6);check(Music.state=='not running','frozen helper stops animation quickly')
packet(71,0,0,0,'paused');Music:tick(.05);check(Music.state=='paused' and Music.level==0,'paused helper rests')
signal=nil;Music:tick(.05);check(Music.state=='not running','missing helper is harmless')

for _,effect in ipairs({'dance','wave','bars','stretch'})do
 for _,speed in ipairs({.1,.2,.25,.33,.5,.75,1,1.25,1.5,2})do
  values.music_effect=effect;values.music_speed=speed
  local V=assert(load(read('music'),'music effects','t',env))()(mod)
  local peaks={0,0,0,0,0,0}
  packet(1,0,0,0);V:tick(.05)
  for sample=1,150 do
   packet(sample+1,1,.03*(.5+.5*math.sin(sample*.1)),.03);V:tick(.05)
   for rank=0,5 do
    local pose=V:pose(rank,'down')
    check(pose.frame>=0 and pose.frame<=3 and pose.frame%1==0,'effect frame stays valid')
    check(pose.offsetY<=0 and pose.offsetY>=-16,'bar movement stays within one tile of anchor')
    check(pose.sx>=.88 and pose.sx<=1.04 and pose.sy>=.96 and pose.sy<=1.7,'bounded stretch and dance dimensions')
    peaks[rank+1]=math.max(peaks[rank+1],-pose.hop)
    if effect=='stretch' then check(pose.offsetY==0 and pose.hop==0,'stretch effect preserves feet anchor')end
    if effect=='bars' then check(not pose.jumping and pose.sx==1 and pose.sy==1,'bar movement uses walking instead of stretching or hopping')end
   end
  end
  if effect=='wave' then for _,peak in ipairs(peaks)do check(peak>0,'wave reaches every follower even at slowest speed')end end
  signal=nil;V:tick(.05);local pose=V:pose(5,'down')
  check(pose.offsetY==0 and pose.hop==0 and pose.sy==1,'all effects reset when helper stops')
 end
end
-- A slower wave stays airborne longer, but still reaches the tail.
values.music_effect='wave'
local duration={}
for _,speed in ipairs({.25,1})do
 values.music_speed=speed;local V=assert(load(read('music'),'wave timing','t',env))()(mod)
 packet(1,0);V:tick(.05);packet(2,1);V:tick(.05)
 local active=0
 for sample=1,60 do packet(sample+2,1);V:tick(.05);if V:pose(0,'down').jumping then active=active+1 end end
 duration[#duration+1]=active
end
check(duration[1]>duration[2]*3,'speed setting lengthens jump wave instead of only changing sprite frames')
print('PASS '..checks..' local music bridge, beat wave, idle interruption, silence and malformed/stale input checks')
