-- Production ecology and controller movement loaded through the native sandbox.
-- Geometry is authored; no ROM assets or full graphical gameplay are simulated.
local root,version=arg[1],arg[2]
love=require('tests.love_stub')
local GV=require('src.core.GameVersion');GV.set(version)
local Sandbox=require('src.mods.Sandbox')
local checks=0
local function check(v,m)checks=checks+1;assert(v,version..': '..m)end
local function read(path)local f=assert(io.open(path,'rb'));local s=f:read('*a');f:close();return s end
local function fixture()
  local F={values={},walls={},npcs={},actors={},serial=0}
  local p={cellX=40,cellY=40,px=640,py=640,currentElevation=3,elevation=3}
  local A={generation=GV.generation(),player=function()return p end,
    occupied=function(_,x,y)return F.npcs[x..':'..y] or false end,
    mapId=function()return 'A' end,save=function()return F end}
  function A:national(species)
    return type(species)=='number' and species-64 or tonumber(tostring(species):match('SPECIES_(%d+)'))
  end
  function A:repelled(level)return F.repelLevel and level<F.repelLevel or false end
  function A:choose(kind,_,area)
    F.sampleCalls=(F.sampleCalls or 0)+1;F.sampleSource=area;F.sampleKind=kind
    return table.remove(F.samples or {},1)
  end
  F.player=p
  local W={}
  function W:habitat(e,x,y)
    local lx=x-(e.areaOffsetX or 0);local ly=y-(e.areaOffsetY or 0)
    return lx>=0 and lx<30 and ly>=0 and ly<30 and (e.surface=='water' and ly>=20 or e.surface=='land' and ly<20)
  end
  function W:allowed(e,x,y)return self:habitat(e,x,y) and not F.walls[x..':'..y] end
  function W:grass(e)return e.surface=='land' end
  function W:land()end
  function W:sync(e)e.sourceX=e.cellX-(e.areaOffsetX or 0);e.sourceY=e.cellY-(e.areaOffsetY or 0)end
  local mod={options={get=function(_,k)return F.values[k]end}}
  local env=Sandbox.envFor({modId='wildfollowers',permissions={engine_internals=true}})
  local modules={adapter=A,areas=W}
  local include
  include=function(name)
    if not modules[name] then
      if name=='ecology' or name=='ecology_data' or name=='controller' then
        modules[name]=assert(Sandbox.compile(read(root..'/src/'..name..'.lua'),'@wildfollowers/'..name,env))()(mod,include)
      else modules[name]={} end
    end
    return modules[name]
  end
  F.E=include('ecology');F.C=include('controller');F.C.map='A';F.C.save=F
  function F:actor(n,x,y,kind,level)
    self.serial=self.serial+1
    local e={id='wild-'..self.serial,national=n,species=GV.generation()==3 and n+64 or 'SPECIES_'..n,
      level=level or 10,cellX=x,cellY=y,px=x*16,py=y*16,clock=0,moving=false,
      surface=kind or 'land',sourceMap='A',currentEligible=true,currentElevation=3,elevation=3}
    self.actors[#self.actors+1]=e;self.C.wilds=self.actors;return e
  end
  function F:step(dt)
    self.E:prepare(self.actors)
    for _,e in ipairs(self.actors)do
      if not e.retired then self.C:animate(e,dt);self.E:step(self.C,e,dt) end
    end
  end
  function F:decide(e)
    self.E:prepare(self.actors);self.E:step(self.C,e,0)
    e.ecology.next=0;self.E:step(self.C,e,0)
  end
  return F
end
math.randomseed(781)
local f=fixture();local a=f:actor(1,5,5);local b=f:actor(3,9,5,'land',30)
f:decide(a);check(a.ecology.mode=='shelter' and a.moving,'juvenile follows evolved family leader')
check(a.national==1 and a.level==10,'behavior preserves sampled identity and level')
f=fixture();a=f:actor(1025,5,5,'land',2);b=f:actor(1025,9,5,'land',20)
f:decide(a);check(a.ecology.mode=='group','unlisted expanded species flock with same species')
f=fixture();a=f:actor(19,5,5);b=f:actor(24,8,5)
f:decide(a);check(a.ecology.mode=='flee' and a.moving and math.abs(a.targetX-b.cellX)+math.abs(a.targetY-b.cellY)>3,'prey flees a nearby predator')
f:decide(b);check(b.ecology.mode=='stalk','predator stalks existing prey')
f=fixture();a=f:actor(10,8,5);b=f:actor(12,8,8,'land',30);local danger=f:actor(21,12,5)
f:decide(b);check(b.ecology.mode=='protect' and b.moving,'evolved guardian intercepts danger near juvenile')
f=fixture();a=f:actor(19,5,5);f.player.cellX=7;f.player.cellY=5
f:decide(a);check(a.ecology.mode=='flee' and a.moving and math.abs(a.targetX-7)+math.abs(a.targetY-5)>2,'timid species react to player')
f=fixture();a=f:actor(19,5,5);a.currentEligible=false;f.player.cellX=7;f.player.cellY=5
f:decide(a);check(a.ecology.mode~='flee','preview actors do not flee projected live player')
f=fixture();a=f:actor(19,5,5);f.player.cellX=7;f.player.cellY=5;f.player.currentElevation=1
f:decide(a);check(a.ecology.mode~='flee','different bridge layer does not cause player flight')
f=fixture();a=f:actor(1,5,5);b=f:actor(3,9,5);b.sourceMap='B'
f:decide(a);check(a.ecology.mode~='shelter','groups stay within their source map')
b.sourceMap='A';b.currentElevation=1;a.ecology.next=0;f:decide(a)
check(a.ecology.mode~='shelter','groups do not join across bridge layers')
f=fixture();a=f:actor(118,5,22,'water');b=f:actor(130,8,22,'water')
f:decide(a);check(a.ecology.mode=='flee' and a.moving,'aquatic predator/prey works')
f=fixture();a=f:actor(1,5,5);f:decide(a);f.C:animate(a,1);a.ecology.sleepLeft=4;a.ecology.next=0
f:decide(a);check(a.ecology.mode=='rest' and a.idlePose.sleep,'wilds rest with a sleep pose')
f:step(.1);check(a.idlePose.sx~=1,'resting pose breathes')
f.player.cellX=a.cellX+2;f.player.cellY=a.cellY;a.ecology.next=0
f:step(.1);check(not a.ecology.sleepLeft and not a.idlePose,'approaching player wakes a resting wild')
f.player.cellX=40;f.player.cellY=40
f.C:animate(a,1);a.ecology.sleepLeft=4;a.idlePose={sleep=true}
local prey=f:actor(19,7,5);a.ecology.sleepLeft=2
f.values.ecosystem_rest=false;f:step(.1)
check(not a.ecology.sleepLeft and not a.idlePose,'rest toggle clears sleeping pose immediately')
f.values.living_ecosystems=false;f:step(.1)
check(not a.ecology and not a.idlePose and not prey.ecology,'master toggle releases old wandering state')
f=fixture();a=f:actor(19,5,5);b=f:actor(24,8,5);f.values.ecosystem_chases=false
f:decide(a);check(a.ecology.mode~='flee','chase toggle disables predator reactions')
f:decide(b);check(b.ecology.mode~='stalk','chase toggle disables stalking')
f=fixture();a=f:actor(19,5,5);b=f:actor(24,8,5);f:decide(b)
b.ecology.chaseLeft=.01;f:step(.02)
check(not b.ecology.chasing and b.ecology.cooldown>0,'chase episodes expire into cooldown')
f=fixture();a=f:actor(1,5,5);f:decide(a)
f.walls['6:5']=true;f.npcs['5:6']=true;local blocker=f:actor(25,4,5);blocker.targetX=5;blocker.targetY=4
check(not f.E:travel(f.C,a,8,5,false),'blocked terrain cannot be entered')
check(not f.E:room(f.C,a,5,6),'native NPC cell is reserved')
check(not f.E:room(f.C,a,5,4),'moving actor destination is reserved')
check(not f.E:room(f.C,a,14,5),'activity has bounded home radius')
f=fixture();a=f:actor(1,5,5);f:decide(a)
a.areaOffsetX=100;a.areaOffsetY=-50;a.cellX=a.cellX+100;a.cellY=a.cellY-50;a.px=a.cellX*16;a.py=a.cellY*16
check(f.E:room(f.C,a,a.cellX+1,a.cellY),'source-local home survives map projection')
check(not f.E:room(f.C,a,a.cellX+9,a.cellY),'projected home remains bounded')
f=fixture();a=f:actor(1,5,5)
local function hit(n,level)return {species=GV.generation()==3 and n+64 or 'SPECIES_'..n,level=level or 10}end
local unrelated=hit(25);local relative=hit(3,18);local area={id='A'}
f.samples={hit(129),relative,hit(24)}
local selected,anchor=f.E:spawn(area,'land',unrelated,f.actors)
check(selected==relative and anchor==a,'social spawn chooses a sampled valid relative')
check(f.sampleSource==area and f.sampleKind=='land' and f.sampleCalls<=4,'spawn sampling is bounded and source-specific')
f.values.living_ecosystems=false;local count=f.sampleCalls
check(f.E:spawn(area,'land',unrelated,f.actors)==unrelated and f.sampleCalls==count,'ecosystem OFF preserves original encounter selection')
f=fixture();a=f:actor(1,5,5);f.samples={};selected=f.E:spawn(area,'land',unrelated,f.actors)
check(selected==unrelated,'unavailable relatives are never invented')
f=fixture();a=f:actor(1,5,5);f.repelLevel=15;f.samples={relative,hit(3,2)}
selected=f.E:spawn(area,'land',hit(25,20),f.actors)
check(selected==relative,'social candidate preserves its provider level and repel rule')
f=fixture();a=f:actor(1,5,5);b=f:actor(7,8,5)
f:decide(a);check(a.ecology.band and a.ecology.band==b.ecology.band,'peaceful mixed species form a local group')
f=fixture();a=f:actor(129,5,23,'water');b=f:actor(130,8,23,'water')
f:decide(a);f:decide(b)
check(a.ecology.mode~='flee' and b.ecology.mode~='stalk','evolved members protect rather than hunt their own family')
f=fixture();a=f:actor(19,5,5);b=f:actor(24,8,5);f:decide(b)
f.actors={b};f.C.wilds=f.actors;f:step(.3)
check(not b.ecology.chasing,'removing prey immediately cancels stale chase reference')
f=fixture();a=f:actor(19,6,6);b=f:actor(24,10,6);f:actor(1000,7,11);f:actor(1001,10,11)
local chased=false;local moved=0;local oldX,oldY=b.cellX,b.cellY
for _=1,300 do
  f:step(1/60)
  if b.ecology.mode=='stalk' then chased=true end
  if b.cellX~=oldX or b.cellY~=oldY then moved=moved+1;oldX,oldY=b.cellX,b.cellY end
end
check(chased and moved>=2,'normal four-wild population produces an actual moving chase within five seconds')
-- Measure actual activity, not just state-entry code. Spawned actors receive
-- no forced behavior timers in these population simulations.
local seenModes={}
-- Continuous production interpolation with mixed roles and aquatic actors.
for seed=1,8 do
  math.randomseed(seed);f=fixture()
  for _,row in ipairs({{10,6,6},{12,6,9},{21,11,6},{19,15,8},{24,19,8},
    {1,8,14},{2,10,14},{3,12,14},{1025,21,14},{1025,24,14},
    {129,7,23,'water'},{130,11,23,'water'}})do f:actor(row[1],row[2],row[3],row[4])end
  local snapshots={}
  for _,e in ipairs(f.actors)do snapshots[e]={e.national,e.species,e.level,e.surface,e.sourceMap} end
  for frame=1,2400 do
    f:step(1/60)
    local occupied={}
    for _,e in ipairs(f.actors)do
      check(f.E:room(f.C,e,e.cellX,e.cellY),'simulation remains on legal local habitat')
      local s=snapshots[e]
      seenModes[e.ecology.mode]=true
      check(e.national==s[1] and e.species==s[2] and e.level==s[3] and e.surface==s[4] and e.sourceMap==s[5],
        'ecosystem leaves encounter provider identity intact')
      for _,cell in ipairs({{e.cellX,e.cellY},{e.targetX,e.targetY}})do
        if cell[1] then
          local key=cell[1]..':'..cell[2]
          check(not occupied[key] or occupied[key]==e,'actors never overlap committed cells')
          occupied[key]=e
        end
      end
    end
  end
end
for _,mode in ipairs({'stalk','protect','shelter','play_chase','play_run','forage','look'})do
  check(seenModes[mode],'natural simulation visibly exercises '..mode)
end
-- Four minutes with groups disabled gives solitary wilds a fair opportunity
-- to nap. Resting remains a small minority, with at most one per habitat.
math.randomseed(314);f=fixture();f.values.ecosystem_groups=false;f.values.ecosystem_chases=false
for i=1,8 do f:actor(1000+i,3+i*3,10)end
local restFrames,total=0,0
for frame=1,7200 do
  f:step(1/30);local asleep=0
  for _,e in ipairs(f.actors)do total=total+1;if e.ecology.sleepLeft then asleep=asleep+1;restFrames=restFrames+1 end end
  check(asleep<=1,'no more than one local sleeper')
end
check(restFrames>0,'infrequent natural resting still occurs')
check(restFrames/total<.03,'less than three percent of actor time is spent sleeping')
print('PASS '..version..' living ecosystems: '..checks..' checks; solitary sleep '..string.format('%.2f',restFrames/total*100)..'%')
