local root,version=arg[1],arg[2]
love=require('tests.love_stub')
require('src.core.GameVersion').set(version)
local checks=0
local function check(ok,why)checks=checks+1;assert(ok,version..': '..why)end
local function eq(a,b,why)check(a==b,why..' ['..tostring(a)..' vs '..tostring(b)..']')end
local F=require('src.core.game3.field_effects')
-- Exercise the installed loader and crop creation with an authored RGBA
-- fixture. No cartridge artwork is distributed with this test.
local newImage=love.graphics.newImage
love.graphics.newImage=function(data)
  local image=newImage(data)
  if type(data)=='table'and data.getDimensions then image.w,image.h=data:getDimensions()end
  return image
end
F._manifest=false;F._sheets={}
F._cache={read=function(_,path)
  if path:match('tall_grass%.rgba$')or path:match('long_grass%.rgba$')then return string.rep('\0',16*80*4)end
end}
local tall=assert(F.loadSheet('tall_grass',16,16,5))
eq(tall.quadsFront[4].h,8,'actual native loader creates grass feet crop')
eq(tall.quadsFront[4].y,72,'actual native crop selects bottom of resting frame')
local MB=require('src.core.game3.mb')
local C=require('src.core.game3.collision')
local beforeMap=C._mapDef
local originalBehavior=C.behaviorOn
C.behaviorOn=function(def,x,y)return def.long and MB.id('LONG_GRASS')or MB.id('TALL_GRASS')end
local area={id='SOURCE',def={long=false},width=10,height=10}
local visited={}
local A={generation=3,area=function()return area end,grass=function(_,x,y,source)
  visited[#visited+1]={x=x,y=y,source=source}
  return x>=0 and y>=0 and x<10 and y<10 and x~=4
end}
local W={source=function()return area end}
local Sandbox=require('src.mods.Sandbox')
local env=Sandbox.envFor({modId='wildfollowers',permissions={engine_internals=true}})
local file=assert(io.open(root..'/src/grass.lua','rb'));local code=file:read('*a');file:close()
local grass=assert(Sandbox.compile(code,'@wildfollowers/grass',env))()({},function(name)return name=='adapter'and A or W end)
local actor={i=50001,px=32,py=32,elevation=4,surface='land',follower=true}
local function collect()local out={};grass:collect(out,actor);return out end
local out=collect()
eq(#out,1,'standing follower gets exactly one grass cover')
eq(out[1].x,32,'cover anchors to native grass tile X')
eq(out[1].grassY,40,'cover anchors to native grass tile feet Y')
eq(out[1].y,actor.py,'cover uses owner position for native subpriority')
eq(out[1].elevation,4,'bridge draw elevation is retained')
eq(out[1].sortY,32.5,'cover sorts immediately above owner')
local oldColor={love.graphics.getColor()};love.graphics.setColor(.2,.3,.4,.5)
local draw=love.graphics.draw;local drawn
love.graphics.draw=function(image,q,x,y)drawn={image=image,q=q,x=x,y=y}end
out[1]:draw(5,7)
eq(drawn.image,tall.image,'cover uses installed native grass artwork')
eq(drawn.q,tall.quadsFront[4],'cover uses native front quad')
eq(drawn.x,27,'camera X applied')
eq(drawn.y,33,'camera Y applied')
local r,g,b,a=love.graphics.getColor();eq(r,.2,'drawing restores graphics color');eq(a,.5,'drawing restores graphics alpha')
love.graphics.draw=draw;love.graphics.setColor(unpack(oldColor))
actor.hidden=true;eq(#collect(),0,'hidden follower has no orphan cover');actor.hidden=false
actor.surface='water';eq(#collect(),0,'swimming actor has no grass cover');actor.surface='land'
actor.px=64;eq(#collect(),0,'plain ground gets no cover')
actor.px=56;out=collect();eq(#out,1,'horizontal grass boundary covers only grass portion');eq(out[1].grassX,48,'cover stays on source grass tile')
actor.px=32;actor.py=40;out=collect();eq(#out,1,'first half of vertical step keeps one feet row')
actor.py=36;out=collect();eq(#out,2,'feet spanning two grass rows cover both')
actor.py=48;out=collect();eq(#out,1,'landing has no stale origin cover');eq(out[1].grassY,56,'landed cover matches destination grass row')
actor.follower=false;actor.areaOffsetX,actor.areaOffsetY=10,-3;actor.px,actor.py=12*16,-16
out=collect();eq(#out,1,'wild in projected neighbor gets source terrain cover')
eq(visited[#visited].x,2,'terrain query removes neighbor X offset');eq(visited[#visited].y,2,'terrain query removes neighbor Y offset')
eq(out[1].grassX,192,'cover retains projected render X');eq(out[1].grassY,-8,'cover retains projected render Y')
actor.retired=true;eq(#collect(),1,'departed wild retains cover during grace')
area.def.long=true;out=collect();check(out[1].draw~=nil,'long grass cover is drawable')
eq(F._sheets.long_grass.frames,5,'long grass uses its native sheet')
local View=require('src.core.game3.field_view')
for _,py in ipairs({32,36,40,44,48})do
  actor.areaOffsetX,actor.areaOffsetY=nil,nil;actor.px,actor.py=32,py
  actor.x,actor.y=actor.px,actor.py;actor.sortY=py
  for _,elevation in ipairs({3,4,6})do
    actor.elevation=elevation
    for _,camY in ipairs({0,7,16,39})do
      local covers=collect();local all={actor};for _,cover in ipairs(covers)do all[#all+1]=cover end
      local under,over=View.applyDrawOrder(all,{},{},camY)
      local sorted=actor.priority<2 and over or under
      eq(sorted[1],actor,'native compositor draws owner before its covers throughout movement')
      for _,cover in ipairs(covers)do
        eq(cover.priority,actor.priority,'native cover shares owner bridge priority')
        eq(cover.subpriority,actor.subpriority,'camera scrolling cannot sort cover below owner')
      end
    end
  end
end
local loadSheet=F.loadSheet;F.loadSheet=function()return nil end
eq(#collect(),0,'unavailable artwork leaves actor drawing intact');F.loadSheet=loadSheet
eq(C._mapDef,beforeMap,'covers never replace native active collision map')
C.behaviorOn=originalBehavior
print('PASS '..version..': '..checks..' native grass cover checks')
