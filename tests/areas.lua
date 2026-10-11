-- Area lifecycle regression fixture. Source maps and encounter pools are
-- deliberately distinct; the real mod sandbox loads the production manager.
-- The controller boundary only creates actors, so it cannot alter retention.
local root,version=arg[1],arg[2]
local function read(path)local f=assert(io.open(path,'rb'));local s=f:read('*a');f:close();return s end
local checks=0
local function check(ok,message)checks=checks+1;assert(ok,version..': '..message)end
local function eq(a,b,message)check(a==b,message..' ['..tostring(a)..' vs '..tostring(b)..']')end
local function near(a,b,message)check(math.abs(a-b)<.001,message..' ['..tostring(a)..' vs '..tostring(b)..']')end
love=require('tests.love_stub')
local GV=require('src.core.GameVersion');GV.set(version)
local Sandbox=require('src.mods.Sandbox')
local code=read(root..'/src/areas.lua')

local function fixture(configuration)
  configuration=configuration or {}
  local F={id='A',save={},busy=false,blocked=false,healthy=true,actors={},choices={},serial=0}
  F.player={cellX=85,cellY=40,px=85*16,py=40*16,currentElevation=3,elevation=3}
  F.values={enabled=true,WE_OW_ENCOUNTERS=true,WE_OW_WATER=true,
    spawn_density='normal',spawn_range='normal'}
  local pools={A='BULBASAUR',B='CHARMANDER',C='SQUIRTLE',D='PIKACHU'}
  local maps={}
  for id in pairs(pools)do
    local m={id=id,widthCells=96,heightCells=96,def={id=id,width=48,height=48,environment='ROUTE'}}
    function m:inBounds(x,y)return x>=0 and y>=0 and x<self.widthCells and y<self.heightCells end
    function m:isWaterCell()return false end
    function m:isGrassCell(x,y)return self:inBounds(x,y)end
    function m:isWalkableCell(x,y)return self:inBounds(x,y)end
    function m:warpAtCell()end
    m.warpAt={}
    maps[id]=m
  end
  F.maps=maps
  F.world={map=maps.A,player=F.player,entities={F.player}}
  local function descriptor(id)
    local m=maps[id]
    return m and {id=id,map=m,def=m.def,width=m.widthCells,height=m.heightCells}
  end
  local function neighbor(id,x,y)
    local area=descriptor(id);area.offsetX=x;area.offsetY=y;return area
  end
  local A={generation=GV.generation(),version=version}
  function A:mapId()return F.id end
  function A:save()return F.save end
  function A:world()return F.world end
  function A:player()return F.player end
  function A:busy()return F.busy end
  function A:healthy()return F.healthy end
  function A:encountersBlocked()return F.busy or F.blocked end
  function A:area(id)return descriptor(id)end
  function A:adjacent(area)
    if configuration.disconnected then return {}end
    if area.id=='A' then return {neighbor('B',96,0),neighbor('C',0,96)}end
    if area.id=='B' then return {neighbor('A',-96,0)}end
    if area.id=='C' then return {neighbor('A',0,-96)}end
    return {}
  end
  function A:water(x,y,area)return false end
  function A:tables()return nil end -- authored routes have no native water pool
  function A:grass(x,y,area)return area and area.map:isGrassCell(x,y)or false end
  function A:habitat(x,y,kind,area)
    return kind=='land' and area and area.map:inBounds(x,y)or false
  end
  function A:allowed(x,y,kind,from,point,area)
    return kind=='land' and area and area.map:inBounds(x,y)or false
  end
  function A:elevations()return 3,3 end
  function A:land(actor,area)
    F.landing={x=actor.cellX,y=actor.cellY,id=area and area.id}
    actor.currentElevation,actor.elevation=5,5
  end
  function A:repelled()return false end
  function A:choose(kind,rng,area)
    F.choices[#F.choices+1]={id=area and area.id,kind=kind}
    if F.emptyPool and area.id==F.emptyPool then return nil end
    return {species=pools[area.id],level=area.id=='A' and 10 or area.id=='B' and 20 or 30}
  end
  local mod={id='wildfollowers',exports={},options={get=function(_,key)return F.values[key]end}}
  local env=Sandbox.envFor({modId='wildfollowers',permissions={engine_internals=true}})
  if configuration.cornerFirst then
    local calls=0
    env.math.random=function(a,b)
      calls=calls+1
      if calls<=2 then return b or a end
      if a==nil then return math.random()end
      if b==nil then return math.random(a)end
      return math.random(a,b)
    end
  end
  F.manager=assert(Sandbox.compile(code,'@wildfollowers/areas',env))()(mod,function(name)
    assert(name=='adapter','area manager requests only adapter');return A
  end)
  F.controller={followers={}}
  function F.controller:actor(species,level,x,y,kind,slot,area)
    F.serial=F.serial+1
    local actor={id=F.serial,species=species,level=level,cellX=x,cellY=y,
      px=x*16,py=y*16,surface=kind,moving=false,clock=0,
      elevation=3,currentElevation=3,_wildFollowersRewrite=true}
    F.actors[#F.actors+1]=actor
    return actor
  end
  function F:update(dt)
    self.list=self.manager:update(self.controller,dt or 1/60)
    assert(type(self.list)=='table','areas:update returns a population list')
    return self.list
  end
  function F:advance(seconds)
    local whole=math.floor(seconds*60+.00001)
    for _=1,whole do self:update(1/60)end
    local remainder=seconds-whole/60
    if remainder>.000001 then self:update(remainder)end
    return self.list
  end
  function F:source(id)
    local out={};for _,e in ipairs(self.list or {})do if e.sourceMap==id then out[#out+1]=e end end;return out
  end
  function F:has(actor)
    for _,e in ipairs(self.list or {})do if e==actor then return true end end;return false
  end
  function F:movePlayer(x,y)
    self.player.cellX,self.player.cellY=x,y;self.player.px,self.player.py=x*16,y*16
  end
  function F:enter(id,x,y,via)
    local previous=self.id
    self.manager:transition({fromMapId=previous,mapId=id,via=via or 'connection'})
    self.id=id;self.world.map=maps[id];self:movePlayer(x,y);return self:update(0)
  end
  return F
end

math.randomseed(938117)
local F=fixture();F:advance(1)
eq(#F:source('A'),4,'active source fills restored normal density')
eq(#F:source('B'),4,'closest connected source prepopulates before entry')
eq(#F:source('C'),0,'only the nearest connected source prepopulates')
for _,e in ipairs(F:source('A'))do
  eq(e.species,'BULBASAUR','active population samples own encounter pool')
  check(e.currentEligible and not e.retired,'active actors are currently eligible')
end
local preview=F:source('B')[1]
check(preview~=nil,'preview exists while source map is unloaded')
for _,e in ipairs(F:source('B'))do
  eq(e.species,'CHARMANDER','unloaded neighbor samples its own encounter pool')
  eq(e.level,20,'neighbor preserves its own encounter levels')
  check(e.previewEligible and not e.currentEligible,'preview cannot be interacted with as current map')
  eq(e.mapId,'B','actor map ownership remains source map')
  eq(e.areaOffsetX,96,'east preview has source-to-current cell offset')
  near(e.cellX,e.sourceX+96,'preview source X projects into current map')
  near(e.cellY,e.sourceY,'preview source Y projects into current map')
  check(math.abs(e.cellX-F.player.cellX)<=12 and math.abs(e.cellY-F.player.cellY)<=12,
    'normal range creates actors inside a12cell square')
end

-- Distance and offscreen movement cannot age an active area's population.
local active=F:source('A')[1];F:movePlayer(12,12);F:advance(16)
check(F:has(active),'active-map actor survives outside spawn range for over15seconds')
check(active.currentEligible and not active.retired,'offscreen current actor stays active')
check(not F:has(preview),'unvisited former preview expires after its full grace')
-- Returning within range activates the same preview instead of replacing it.
F:movePlayer(85,40);F:advance(.3)
preview=F:source('B')[1]
check(preview~=nil,'expired preview can repopulate when it is closest again')
F:movePlayer(12,12);F:advance(5)
F:movePlayer(85,40);F:advance(.3)
check(F:has(preview),'returning to a preview cancels its retirement')
check(preview.previewEligible and not preview.retired,'nearest preview reactivation is eligible')

-- A seamless crossing reprojections source anchors and keeps identities.
F:enter('B',1,40)
check(F:has(preview),'preloaded neighbor actor survives entry')
check(preview.currentEligible and not preview.retired,'preview becomes current upon entry')
near(preview.cellX,preview.sourceX,'entering source map removes prior east projection')
near(preview.px,preview.sourceX*16,'entering source map removes prior pixel projection')
check(F:has(active),'departed active actor remains during grace period')
near(active.cellX,active.sourceX-96,'departed source projects across west connection')
-- Get well away from the old seam so its population is no longer the preview.
F:movePlayer(48,40);F:update(0)
check(active.retired and not active.currentEligible,'departed area enters retirement')
F:advance(7)
F.busy=true;F:advance(60);F.busy=false
check(F:has(active),'menus and battle busy time do not consume departure grace')
F:advance(7.9)
check(F:has(active),'departed actor survives14.9seconds of field time')
F:advance(.2)
check(not F:has(active),'departed actor retires after15seconds of field time')
check(F:has(preview),'current map population survives old source retirement')

-- Return during grace preserves the old population and resets retirement.
F=fixture();F:advance(1);active=F:source('A')[1]
F:enter('B',48,40);F:advance(10)
check(F:has(active),'first departure stays alive during grace')
F:enter('A',85,40)
check(F:has(active)and active.currentEligible and not active.retired,
  'returning before15seconds preserves and reactivates same actor')
F:enter('B',48,40);F:advance(10)
check(F:has(active),'second departure receives a fresh full grace period')
F:advance(5.1)
check(not F:has(active),'fresh departure grace eventually expires')

-- Moving from east to south switches the nearest prepopulation pool.
F=fixture();F:advance(1);preview=F:source('B')[1]
F:movePlayer(40,85);F:advance(1)
eq(#F:source('C'),4,'new nearest connected source prepopulates')
check(F:has(preview)and preview.retired,'former nearest preview receives departure grace')
for _,e in ipairs(F:source('C'))do
  eq(e.species,'SQUIRTLE','second neighbor never borrows first neighbor pool')
  eq(e.areaOffsetY,96,'south preview uses Y connection offset')
  near(e.cellY,e.sourceY+96,'south preview transforms source Y correctly')
end
F:advance(14.1)
check(not F:has(preview),'former preview retires after15seconds')

-- A disconnected warp must never render actors in stale map coordinates.
F=fixture();F:advance(1);active=F:source('A')[1];preview=F:source('B')[1]
F:enter('D',48,48,'warp');F:advance(1)
for _,e in ipairs(F.list)do
  if e.sourceMap~='D' then
    check(e.hidden and not e.currentEligible and not e.previewEligible,
      'disconnected actor is hidden and interaction-ineligible')
  else eq(e.species,'PIKACHU','warp destination samples its own source')end
end
check(not F:has(active)or active.hidden,'active actor cannot leak into disconnected map')
check(not F:has(preview)or preview.hidden,'preview cannot leak into disconnected map')

-- Replacing a save starts a distinct population even with unchanged map ID.
F=fixture();F:advance(1);active=F:source('A')[1];F.save={};F:advance(1)
check(not F:has(active),'session identity replacement removes old-save actors')
eq(#F:source('A'),4,'new save repopulates current map')

-- Area-aware movement uses source geometry, and projection preserves native
-- interpolation pixels when a preview becomes the current route.
F=fixture();F:advance(1);preview=F:source('B')[1]
local localX,localY=preview.sourceX,preview.sourceY
check(F.manager:allowed(preview,preview.cellX+1,preview.cellY),
  'preview movement checks source map instead of current out-of-bounds cell')
check(F.manager:habitat(preview,preview.cellX+1,preview.cellY),
  'preview habitat checks source encounter geometry')
check(F.manager:grass(preview),'preview grass flag comes from source map')
preview.cellX=preview.cellX+1;preview.px=preview.cellX*16+4
preview.startX=preview.px;preview.startY=preview.py
preview.targetX=preview.cellX+1;preview.targetY=preview.cellY;preview.moving=true
F.manager:sync(preview)
eq(preview.sourceX,localX+1,'sync commits new cell to source anchor')
F:enter('B',1,40)
near(preview.cellX,localX+1,'in-flight source cell survives seam projection')
near(preview.px,(localX+1)*16+4,'in-flight pixel interpolation survives seam projection')
near(preview.targetX,localX+2,'in-flight destination converts from preview to source')
near(preview.startX,(localX+1)*16+4,'in-flight start converts from preview to source')
F.manager:land(preview)
check(F.landing~=nil,'area-aware landing delegates to adapter')
eq(F.landing.id,'B','landing retains source geometry descriptor')
eq(F.landing.x,localX+1,'landing converts actor X to source coordinates')
eq(preview.currentElevation,5,'landing applies source elevation result')

-- All restored option choices have independent source caps and geometry.
for _,density in ipairs({{'low',2},{'normal',4},{'high',6},{'very_high',8}})do
  F=fixture();F.values.spawn_density=density[1];F:advance(2)
  eq(#F:source('A'),density[2],'restored density '..density[1]..' caps current source')
  eq(#F:source('B'),density[2],'restored density '..density[1]..' caps preview source')
  check(#F.list<=16,'current plus preview remain inside global cap16')
end
for _,range in ipairs({{'normal',12},{'far',20},{'wide',32},{'very_wide',48},{'ultra_wide',64}})do
  F=fixture({disconnected=true,cornerFirst=true});F:movePlayer(80,80)
  F.maps.A.widthCells,F.maps.A.heightCells=200,200
  F.maps.A.def.width,F.maps.A.def.height=100,100
  F.values.spawn_range=range[1];F:advance(1)
  eq(#F:source('A'),4,'restored range '..range[1]..' fills current source')
  local extreme=false
  for _,e in ipairs(F:source('A'))do
    local dx,dy=math.abs(e.cellX-F.player.cellX),math.abs(e.cellY-F.player.cellY)
    check(dx<=range[2]and dy<=range[2],'range '..range[1]..' bounds are inclusive square')
    if dx==range[2]and dy==range[2]then extreme=true end
  end
  check(extreme,'range '..range[1]..' supports its far corner without Manhattan clipping')
end

-- Retired populations consume the global cap. A new preview waits for grace
-- expiry so cap pressure never shortens the user's15second retention.
F=fixture();F.values.spawn_density='very_high';F:advance(2)
eq(#F.list,16,'highest density fills exactly two sources within global cap')
local before={};for _,e in ipairs(F:source('A'))do before[e]=true end
F:movePlayer(40,85);F:advance(2)
check(#F.list<=16,'preview switch does not exceed cap despite retired population')
eq(#F:source('A'),8,'cap pressure does not remove active source actors')
eq(#F:source('B'),8,'cap pressure preserves every unexpired retired actor')
eq(#F:source('C'),0,'full cap delays a new preview while grace population is retained')
for _,e in ipairs(F:source('A'))do check(before[e],'cap pressure preserves current source identity')end
F:advance(14)
eq(#F:source('B'),0,'retired preview eventually releases global capacity')
eq(#F:source('C'),8,'new eligible preview fills after grace releases capacity')

-- Failed neighbor tables never fall back to current area's encounter pool.
F=fixture();F.emptyPool='B';F:advance(1)
eq(#F:source('A'),4,'empty neighbor pool leaves current source functioning')
eq(#F:source('B'),0,'empty neighbor encounter pool creates no borrowed wilds')
for _,call in ipairs(F.choices)do check(call.id=='A'or call.id=='B','only requested source pools are sampled')end
F.values.WE_OW_ENCOUNTERS=false;F:update(0)
eq(#F.list,0,'visible-wilds toggle clears all source populations')
F.values.WE_OW_ENCOUNTERS=true;F:advance(1)
eq(#F:source('A'),4,'visible-wilds toggle can repopulate')
F.manager:clear();F.list={};F:update(0)
check(#F.list<=1,'explicit clear removes all old populations before fresh fill')

print('PASS '..version..': '..checks..' connected-area lifecycle checks')
