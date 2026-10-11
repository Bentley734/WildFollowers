local root,version=arg[1],arg[2]
love=require('tests.love_stub')
local GV=require('src.core.GameVersion');GV.set(version)
local gen=GV.generation();local checks=0
local function check(ok,why)checks=checks+1;assert(ok,version..': '..why)end
local function eq(a,b,why)check(a==b,why..' ['..tostring(a)..' vs '..tostring(b)..']')end
local atlas=love.graphics.newImage(root..'/assets/g9rpsprites/001-normal.png')
local ts={id='GRASS_FIXTURE',image=root..'/assets/g9rpsprites/001-normal.png',tilesPerRow=32,animatedTiles={}}
local map={id='SOURCE',def={id='SOURCE',width=4,height=4,tileset=ts.id},tileset=ts}
function map:tileAt()return 1 end
local area={id=map.id,map=map,def=map.def,width=8,height=8}
local world={map={id='ACTIVE'},bgSets={}}
local strips={}
if gen==2 then
  local World=require('src.world.gen2.World')
  world.drawGrassOver=World.drawGrassOver
  world.drawGrassOverGoldSilver=World.drawGrassOverGoldSilver
  world.drawGrassOverCrystal=World.drawGrassOverCrystal
  function world:isCrystal()return version=='crystal'end
  function world:grassAtlasFor()return atlas,ts end
  function world:mapCacheKey(id)return id end
  function world:bgTileAt()return 1 end
  function world:blitBgOverRegion(def,ox,oy,s,x0,y0,x1,y1,keyed)
    strips[#strips+1]={def=def,ox=ox,oy=oy,s=s,x0=x0,y0=y0,x1=x1,y1=y1,keyed=keyed}
  end
  local newQuad=love.graphics.newQuad
  love.graphics.newQuad=function(...)
    local q=newQuad(...);function q:setViewport(x,y,w,h)self.x,self.y,self.w,self.h=x,y,w,h end;return q
  end
end
local plain=false
local A={generation=gen,area=function()return area end,world=function()return world end,
  grass=function(_,x,y,source)return not plain and source==area and x>=0 and y>=0 and x<8 and y<8 end}
local W={source=function()return area end}
local mod={game={data={}}}
local Sandbox=require('src.mods.Sandbox')
local env=Sandbox.envFor({modId='wildfollowers',permissions={engine_internals=true}})
local f=assert(io.open(root..'/src/grass.lua','rb'));local code=f:read('*a');f:close()
local grass=assert(Sandbox.compile(code,'@wildfollowers/grass',env))()(mod,function(n)return n=='adapter'and A or W end)
local drawn,transforms={},{}
love.graphics.draw=function(img,q,x,y,rotation,sx,sy)drawn[#drawn+1]={img=img,q=q,x=x,y=y,sx=sx,sy=sy}end
love.graphics.translate=function(x,y)transforms[#transforms+1]={x=x,y=y}end
local actor={px=32,py=32,surface='land',follower=true,spriteDef={width=16,height=16}}
local function count()return #drawn+#strips end
grass:drawGB(actor,10,20,2)
check(count()>0,'standing follower gets native grass overdraw')
if gen==1 then
  check(map.renderer~=nil,'source native TileRenderer is constructed on demand')
  eq(transforms[#transforms].x,10,'native strip receives screen X')
  eq(transforms[#transforms].y,20,'native strip receives screen Y')
  check(drawn[1].y>=36 and drawn[1].y<44,'native keyed strip covers py+4 through py+12')
elseif version=='crystal' then
  eq(strips[1].y0,36,'Crystal native feet strip starts py+4')
  eq(strips[1].y1,44,'Crystal native feet strip ends py+12')
  check(strips[1].keyed,'Crystal retains keyed background over OAM')
else
  check(drawn[1].y>=20+36*2 and drawn[1].y<20+44*2,'Gold/Silver native grass strip covers feet at scale')
end
local n=count();grass:drawGB(actor,10,20,2,'top');eq(count(),n,'Crystal top slice does not repaint grass over head')
actor.hidden=true;grass:drawGB(actor,10,20,2);eq(count(),n,'hidden actor has no grass');actor.hidden=false
actor.surface='water';grass:drawGB(actor,10,20,2);eq(count(),n,'swimming actor has no grass');actor.surface='land'
plain=true;grass:drawGB(actor,10,20,2);eq(count(),n,'plain ground is not painted over actor');plain=false
actor.follower=false;actor.areaOffsetX,actor.areaOffsetY=10,-3;actor.px,actor.py=192,-16
grass:drawGB(actor,10,20,2)
check(count()>n,'projected wild gets source native grass cover')
eq(world.map.id,'ACTIVE','grass does not replace live map')
if gen==1 then
  eq(transforms[#transforms].x,330,'neighbor source X projects into current view')
  eq(transforms[#transforms].y,-76,'neighbor source Y projects into current view')
elseif version=='crystal' then
  eq(strips[#strips].def,map.def,'Crystal preview samples source map definition')
  eq(strips[#strips].ox,330,'Crystal source X projection')
  eq(strips[#strips].oy,-76,'Crystal source Y projection')
end
actor.retired=true;n=count();grass:drawGB(actor,10,20,2);check(count()>n,'departed wild retains grass cover')
actor.py=actor.py+4;n=count();grass:drawGB(actor,10,20,2);check(count()>n,'moving feet retain native overdraw')
print('PASS '..version..': '..checks..' native GB grass checks')
