local root,version=arg[1],arg[2]
love=require('tests.love_stub');local V=require('src.core.GameVersion');V.set(version)
local settings={wild_sprites='g9',follower_sprites='ee'}
local mod={options={get=function(_,k)return settings[k]end},assets={image=function(_,path)return love.graphics.newImage(root..'/'..path)end}}
local P=require('src.core.game3.pokemon');P._names={[25]='PIKACHU'}
local originalShiny,originalGender=P.isShiny,P.gender
P.isShiny=function(m)return m.shiny==true end;P.gender=function(_,pid)return pid==1 and 'F' or 'M' end
local catalog=assert(loadfile(root..'/src/ee_data.lua'))()(mod)
local S=assert(loadfile(root..'/src/sprites.lua'))()(mod,function(n)
 if n=='ee_data' then return catalog end
 return {pose=function()return 0 end,shadow=function()end}
end)
local checks=0
local function check(v,m)checks=checks+1;assert(v,version..': '..m)end
local f={national=25,species=V.generation()==3 and 25 or 'PIKACHU',follower=true,mon={species=25,shiny=true,gender='female',personality=1},px=16,py=32,facing='right'}
local w={national=25,species=f.species,px=16,py=32,facing='up'}
local r=S:get(25,f);check(r.ee and r.image.path:find('PIKACHU_female_shiny',1,true),'female shiny EE follower')
check(not S:get(25,w).ee,'wild stays G9 independently')
settings.wild_sprites='ee';settings.follower_sprites='g9'
check(S:get(25,w).ee and not S:get(25,f).ee,'reverse mixed settings live without rebuilding actors')
settings.follower_sprites='ee';f.mon.shiny=false;f.mon.gender='male';f.mon.personality=0
check(S:get(25,f).image.path:find('/PIKACHU.png',1,true),'normal palette and gender')
local saved=catalog.species.PIKACHU;catalog.species.PIKACHU=nil
check(not S:get(25,w).ee,'missing catalog artwork falls back to G9');catalog.species.PIKACHU=saved
local old=mod.assets.image;mod.assets.image=function(_,p)if p:find('assets/ee/',1,true)then error('missing EE')end;return old(mod.assets,p)end
S.cache={};check(not S:get(25,w).ee,'missing EE file falls back');check(not S:get(25,w).ee,'cached missing file still falls back');mod.assets.image=old;S.cache={}
local draws={};love.graphics.draw=function(img,q,x,y,_,sx,sy)draws[#draws+1]={q=q,x=x,y=y,sx=sx,sy=sy}end
for _,dir in ipairs({'down','left','right','up'})do
 w.facing=dir;w.moving=true
 for frame=0,3 do w.clock=frame/8;S:draw(w,0,0,1);local d=draws[#draws]
 check(d.q.x==frame*32,'all walk frames');check(d.sx==1,'EE native pixel size')
 check(d.y==w.py+(V.generation()==3 and 16 or 12)-32,'native foot baseline')
 end
end
w.moving=false;S:draw(w,0,0,1,'bottom');local bottom=draws[#draws];S:draw(w,0,0,1,'top');local top=draws[#draws]
check(bottom.q.h==8 and top.q.h==24,'Crystal split rows keep native eight pixel mask')
local large={national=321,species='WAILORD',px=16,py=32,facing='down'}
local lr=S:get(321,large);check(lr.w==64 and lr.ee,'large EE species retain 64 pixel frame')
S:draw(large,0,0,1);check(draws[#draws].sx==1,'large species remain native size')
check(draws[#draws].y==large.py+(V.generation()==3 and 16 or 12)-64,'large species foot placement')
large.ballPhase='recall';large.ballTime=.05;S:draw(large,0,0,1)
large.ballPhase='release';large.ballTime=.05;S:draw(large,0,0,1)
local schema=assert(loadfile(root..'/options.lua'))();local found=0
for _,def in ipairs(schema)do
 if def.key=='wild_sprites' or def.key=='follower_sprites' then
  found=found+1;check(def.default=='g9' and def.choices[2][2]=='ee','persisted choices preserve G9 defaults')
 end
end
check(found==2,'separate schema entries')
local hip={national=450,species='HIPPOWDON',follower=true,mon={shiny=true,gender='female',personality=1}}
check(S:get(450,hip).image.path:find('HIPPOWDON_female_shiny',1,true),'palette-only female variant')
P.isShiny,P.gender=originalShiny,originalGender
print('PASS '..version..' EE sprite selection/rendering: '..checks)
