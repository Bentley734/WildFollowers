-- Real imported artwork and resolver/rendering contracts. GPU calls are
-- recorded; conversion pixel fidelity is checked by the separate import audit.
local root,version=arg[1],arg[2]
love=require('tests.love_stub')
local V=require('src.core.GameVersion');V.set(version)
local gen=V.generation()
local checks=0
local function check(value,message)
  checks=checks+1;assert(value,version..': '..message)
end
local function eq(a,b,message)
  check(a==b,message..' ['..tostring(a)..' vs '..tostring(b)..']')
end
local function near(a,b,message)
  check(math.abs(a-b)<.00001,message..' ['..tostring(a)..' vs '..tostring(b)..']')
end
local settings={wild_sprites='companion',follower_sprites='g9',water_sprite_crop=0}
local game={options={},save={options={}},mods={modOptions={},events={emit=function()end}}}
local mod={id='wildfollowers',path=root,game=game,
  options={get=function(_,key)return settings[key]end},assets={}}
function mod.assets:image(path)
  local file=assert(io.open(root..'/'..path,'rb'),'missing artwork '..path);file:close()
  return love.graphics.newImage(root..'/'..path)
end
-- Use actual engine species-name and palette helpers with controlled identities.
local P=require('src.core.game3.pokemon')
local oldNames,oldShiny,oldGender=P._names,P.isShiny,P.gender
P._names={[25]='PIKACHU'}
P._names[201]='UNOWN';P._names[386]='DEOXYS'
P.isShiny=function(mon)return mon.shiny==true end
P.gender=function(_,personality)return personality==1 and 'F' or 'M' end
local modules={}
local function include(name)
  if not modules[name] then
    modules[name]=assert(loadfile(root..'/src/'..name..'.lua'))()(mod,include)
  end
  return modules[name]
end
local data,S,Forms=include('companion_data'),include('sprites'),include('forms')
local faces={'down','left','right','up'}
local baseCount,formCount,sheetCount=0,0,0
local basePaths,formPaths={},{}
local largePath,longPath
for national,path in pairs(data.national) do
  baseCount=baseCount+1
  basePaths[path]=true
  check(national>=1 and national<=1025 and national%1==0,'valid National index')
  local actor={national=national,species='COMPANION_BASE_'..national}
  eq(S:get(national,actor).path,path,'selected base artwork '..national)
end
eq(baseCount,387,'all 386 Gen 1-3 species and Munchlax are imported')
for national=1,386 do check(data.national[national]~=nil,'complete base roster '..national) end
check(data.national[446]~=nil,'Munchlax bonus artwork')
for name,path in pairs(data.forms) do
  if not basePaths[path] and not formPaths[path] then formCount=formCount+1 end
  formPaths[path]=true
  local form=Forms.catalog[name]
  local actor={national=form and form.national or 1,species=name}
  eq(S:get(actor.national,actor).path,path,'exact Companion form '..name)
  eq(actor.species,name,'drawing keeps form identity '..name)
end
eq(formCount,33,'all 33 alternate forms are imported')
local unown={national=201,species=gen==3 and 201 or 'UNOWN',mon={}}
if gen==3 then
  for letter=0,27 do
    local personality=letter%4+math.floor(letter/4)%4*256+math.floor(letter/16)%4*65536
    eq(P.unownLetter(personality),letter,'engine personality fixture selects intended Unown')
    unown.mon.personality=personality
    local name=letter==26 and 'EMARK' or letter==27 and 'QMARK' or string.char(65+letter)
    eq(S:get(201,unown).path,data.forms['UNOWN_'..name],'native personality selects Unown '..name)
    eq(unown.mon.personality,personality,'rendering preserves personality')
  end
else
  local U=require('src.core.gen2.Unown')
  for letter=1,26 do
    local packed=(letter-1)*10
    local dvs={attack=math.floor(packed/64)*2,defense=math.floor(packed/16)%4*2,
      speed=math.floor(packed/4)%4*2,special=packed%4*2}
    eq(U.letterFromDVs(dvs),letter,'engine DV fixture selects intended Unown')
    unown.mon.dvs=dvs
    eq(S:get(201,unown).path,data.forms['UNOWN_'..string.char(64+letter)],'native DVs select correct Unown')
  end
  unown.mon.unownLetter='B'
  eq(S:get(201,unown).path,data.forms.UNOWN_B,'stored letter takes priority over DVs')
  unown.mon.unownLetter=26
  eq(S:get(201,unown).path,data.forms.UNOWN_Z,'stored numeric letter is supported')
end
unown.species='UNOWN_QMARK'
eq(S:get(201,unown).path,data.forms.UNOWN_QMARK,'explicit question form takes priority over native identity')
unown.species='UNOWN_EXCLAMATION_MARK'
eq(S:get(201,unown).path,data.forms.UNOWN_EMARK,'explicit punctuation alias is supported')
local deoxys={national=386,species=gen==3 and 386 or 'DEOXYS'}
local nativeDeoxys=version=='firered' and 'ATTACK' or version=='leafgreen' and 'DEFENSE'
  or version=='emerald' and 'SPEED' or 'NORMAL'
eq(S:get(386,deoxys).path,data.forms['DEOXYS_'..nativeDeoxys],'native cartridge selects Deoxys form')
deoxys.species='DEOXYS_NORMAL'
eq(S:get(386,deoxys).path,data.forms.DEOXYS_NORMAL,'explicit Deoxys form overrides cartridge default')
for path,meta in pairs(data.sheets) do
  sheetCount=sheetCount+1
  local record=assert(S:load(path))
  check(record.companion and not record.ee,'Companion source is explicit '..path)
  eq(record.scale,1,'source pixels are not resampled '..path)
  eq(record.w,meta.frameWidth,'declared frame width '..path)
  eq(record.h,meta.frameHeight,'declared frame height '..path)
  eq(record.anchorX,meta.anchorX,'source horizontal anchor '..path)
  eq(record.anchorY,meta.anchorY,'source ground anchor '..path)
  eq(record.image:getWidth(),record.w*meta.columns,'atlas column contract '..path)
  eq(record.image:getHeight(),record.h*4,'atlas direction contract '..path)
  check(record.bottoms~=nil,'per-frame visible water bounds '..path)
  check(include('sprite_bounds')[path]~=nil,'visible collision bounds '..path)
  eq(record.image:getFilter(),'nearest','nearest pixel filtering '..path)
  if not largePath or record.w>S:load(largePath).w then largePath=path end
  if not longPath or meta.columns>data.sheets[longPath].columns then longPath=path end
  for row,face in ipairs(faces) do
    local durations=meta.durations[face]
    check(#durations>0 and #durations<=meta.columns,'valid direction sequence '..path..' '..face)
    local total=0
    for _,duration in ipairs(durations) do
      check(duration>0,'positive source timing')
      near(duration*60,math.floor(duration*60+.5),'original 60Hz timing')
      total=total+duration
    end
    local time=0
    for index,duration in ipairs(durations) do
      local frame=index-1;local q=record.quads[face][frame]
      eq(q.x,frame*record.w,'frame source x '..path)
      eq(q.y,(row-1)*record.h,'direction source y '..path)
      eq(q.w,record.w,'unscaled quad width')
      eq(q.h,record.h,'unscaled quad height')
      local actor={follower=true,facing=face,moving=true,clock=time+duration/2}
      eq(S:frame(actor,record,face),frame,'full timed follower sequence '..path..' '..face)
      actor.clock=actor.clock+total*3
      eq(S:frame(actor,record,face),frame,'timed animation loops without dropping frames')
      actor.follower=false;actor.clock=1000;actor.progress=(time+duration/2)/total
      eq(S:frame(actor,record,face),frame,'wild step visits every source pose')
      local bottom=record.bottoms[row][index]
      check(bottom>0 and bottom<=record.h,'water bounds stay inside populated frame')
      time=time+duration
    end
  end
end
eq(sheetCount,420,'all unique imported sets load')
check(data.sheets[longPath].columns>4,'test includes longer-than-four-frame source animation')
check(S:load(largePath).w>32,'test includes large native sprite canvases')
local actor={national=25,species=gen==3 and 25 or 'PIKACHU',px=16,py=32,
  facing='down',clock=0,mon={shiny=true,gender='female',personality=1}}
local companionPath=data.national[25]
eq(S:get(25,actor).path,companionPath,'Companion retains its original palette for shiny/female actor')
actor.follower=true
eq(S:get(25,actor).path,'assets/g9rpsprites/025-normal.png','follower stays on independent G9 choice')
settings.follower_sprites='companion';settings.wild_sprites='ee'
eq(S:get(25,actor).path,companionPath,'follower switches source live')
actor.follower=false
check(S:get(25,actor).path:find('/PIKACHU_female_shiny.png',1,true)~=nil,'wild EE palette remains independent')
settings.wild_sprites='companion';settings.follower_sprites='companion'
eq(S:get(1025,{species='PECHARUNT'}).path,'assets/g9rpsprites/1025-normal.png','later species keep existing G9 fallback')
eq(S:get(0,actor),nil,'invalid National zero')
eq(S:get(1026,actor),nil,'invalid National upper bound')
local image=mod.assets.image
mod.assets.image=function(self,path)
  if path==companionPath then error('fixture missing Companion image') end
  return image(self,path)
end
S.cache={}
for _=1,2 do
  eq(S:get(25,actor).path,'assets/g9rpsprites/025-normal.png','missing and cached missing Companion art falls back')
end
mod.assets.image=image;S.cache={}
local exactName,exactForm
for name in pairs(data.forms) do
  local form=Forms.catalog[name]
  if form and form.g9.normal and form.ee.normal then exactName,exactForm=name,form;break end
end
check(exactForm~=nil,'exact-form fallback fixture exists')
local formActor={national=exactForm.national,species=exactName}
mod.assets.image=function(self,path)
  if path==data.forms[exactName] then error('fixture missing Companion form') end
  return image(self,path)
end
S.cache={}
eq(S:get(formActor.national,formActor).path,exactForm.g9.normal,'missing Companion form uses exact G9 form')
mod.assets.image=function(self,path)
  if path==data.forms[exactName] or path==exactForm.g9.normal then error('fixture missing preferred forms') end
  return image(self,path)
end
S.cache={}
eq(S:get(formActor.national,formActor).path,exactForm.ee.normal,'exact EE form is retained when G9 form is missing')
mod.assets.image=image;S.cache={}
-- Test the actual drawing coordinates with native source anchors, zoom and
-- visible water cropping, including Crystal's split OAM compositor.
local draws={}
local oldDraw=love.graphics.draw
love.graphics.draw=function(img,q,x,y,rotation,sx,sy)
  draws[#draws+1]={image=img,q=q,x=x,y=y,sx=sx,sy=sy}
end
local record=S:load(longPath)
local savedGet=S.get
S.get=function()return record end
actor.follower=false;actor.mon=nil;actor.moving=true;actor.progress=nil
for row,face in ipairs(faces) do
  actor.facing=face
  local time=0
  for index,duration in ipairs(record.durations[face]) do
    actor.clock=time+duration/2
    for zoom=1,3 do
      actor.surface='land';draws={};S:draw(actor,3,5,zoom)
      eq(#draws,1,'land body draws once')
      local d=draws[1]
      eq(d.q,record.quads[face][index-1],'renderer uses complete source timing')
      eq(d.sx,zoom,'native source pixel scale follows viewport zoom')
      near(d.x+record.anchorX*d.sx,3+(actor.px+8)*zoom,'horizontal ground anchor')
      near(d.y+record.anchorY*d.sy,5+(actor.py+(gen==3 and 16 or 12))*zoom,'native ground anchor')
      for crop=0,3 do
        settings.water_sprite_crop=crop;actor.surface='water';draws={};S:draw(actor,3,5,zoom)
        local water=draws[1]
        local retained=crop>0 and math.max(0,record.bottoms[row][index]-crop) or record.h
        eq(water.q.h,retained,'crop measured from each source pose visible bottom')
        eq(water.y,d.y,'cropping preserves source ground anchor')
      end
    end
    time=time+duration
  end
end
actor.surface='land';actor.moving=false;actor.facing='down';settings.water_sprite_crop=0
draws={};S:draw(actor,0,0,1,'top');S:draw(actor,0,0,1,'bottom')
eq(#draws,2,'both Crystal compositor passes remain visible')
near(draws[1].q.h,record.anchorY-8,'top pass ends eight native pixels before source anchor')
near(draws[1].q.h+draws[2].q.h,record.h,'Crystal passes cover entire canvas exactly once')
near(draws[1].y+draws[1].q.h,draws[2].y,'Crystal split has no gap or overlap')
actor.follower=true;actor.surface='water';settings.water_sprite_crop=3
draws={};S:draw(actor,0,0,1)
eq(draws[1].q.h,record.h,'followers are not cropped on water')
actor.hidden=true;draws={};S:draw(actor,0,0,1);eq(#draws,0,'hidden actors do not draw');actor.hidden=nil
actor.ballPhase='recall';actor.ballTime=.30;draws={};S:draw(actor,0,0,1)
eq(#draws,0,'fully recalled Companion body disappears')
actor.ballPhase=nil;actor.surface='land';actor.follower=false
settings.water_sprite_crop=0
-- The bridge's actual custom mesh must share the 2D source frame and anchor.
local fallback={}
local cards={mesh=function()return fallback end,shadowQuad=function()return fallback end}
local gpu={pushQuad=function(indices)for _,v in ipairs({1,2,3,1,3,4})do indices[#indices+1]=v end end,
  newMesh=function(vertices,indices)return {vertices=vertices,indices=indices,release=function(m)m.released=true end}end}
local lib={require=function(name)return name=='SpriteBillboards' and cards or gpu end}
mod.find=function(_,name)if name=='TERRARIUM' then return {exports={lib=lib}} end end
local bridge=include('voxel');bridge:install()
actor.facing='right';actor.moving=true;actor.clock=.15
local sprite=bridge:pose(actor)
eq(sprite.record,record,'voxel shares selected source record')
eq(sprite.anchorX,record.anchorX,'voxel native horizontal anchor')
eq(sprite.anchorY,record.anchorY,'voxel native vertical anchor')
local mesh=cards.mesh(sprite.def,0)
eq(cards.mesh(sprite.def,0),mesh,'unchanged native pose reuses mesh')
eq(cards.shadowQuad(sprite.def,0),mesh,'shadow geometry shares sprite mesh')
local d=sprite.def._wildFollowers
eq(d.frame,S:frame(actor,record,'right'),'voxel selects the same timed frame')
near(mesh.vertices[1][1],8-record.anchorX,'voxel left anchor')
near(mesh.vertices[2][1],8+record.w-record.anchorX,'voxel right anchor')
near(mesh.vertices[1][2],record.anchorY-record.h-4,'voxel source ground anchor')
near(mesh.vertices[3][2],record.anchorY-4,'voxel source top anchor')
check(mesh.vertices[1][4]>=0 and mesh.vertices[2][4]<=1 and mesh.vertices[1][5]<=1 and mesh.vertices[3][5]>=0,'voxel UV stays inside atlas')
eq(cards.mesh({},0),fallback,'ordinary entities still use native renderer')
bridge:dispose();check(mesh.released,'disposing bridge frees cached source mesh')
eq(cards.mesh({},0),fallback,'disposing bridge restores native renderer')
S.get=savedGet;love.graphics.draw=oldDraw
-- The real shared menu rows expose and persist the additional choice for every
-- cartridge, without changing either original style or default choice.
local schema=assert(loadfile(root..'/options.lua'))()
local rows=include('menu'):rows(schema)
local byKey={};for _,row in ipairs(rows)do byKey[row.id]=row end
for _,definition in ipairs(schema) do
  if definition.key=='wild_sprites' or definition.key=='follower_sprites' then
    eq(definition.default,'g9','original sprite default remains G9')
    eq(definition.choices[1][2],'g9','original G9 option order')
    eq(definition.choices[2][2],'ee','original EE option order')
    eq(definition.choices[3][2],'companion','additional source follows original options')
    settings[definition.key]='ee'
    local row=assert(byKey['wildfollowers.'..definition.key])
    row.step(game,1)
    eq(game.mods.modOptions.wildfollowers[definition.key],'companion','native menu persists Companion source')
    settings[definition.key]='companion'
    eq(row.value(),definition.choices[3][1],'native menu labels Companion source')
  end
end
P._names,P.isShiny,P.gender=oldNames,oldShiny,oldGender
print(('PASS %s Companion source: %d checks, %d sheets, %d base species, %d forms'):format(version,checks,sheetCount,baseCount,formCount))
