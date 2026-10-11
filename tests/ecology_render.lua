local root,version=arg[1],arg[2]
love=require('tests.love_stub')
local GV=require('src.core.GameVersion');GV.set(version)
local checks=0
local function check(v,m)checks=checks+1;assert(v,version..': '..m)end
local options={wild_sprites='g9',water_sprite_crop=0}
local mod={options={get=function(_,k)return options[k]end},
  assets={image=function(_,p)return love.graphics.newImage(root..'/'..p)end}}
local modules={jumps={pose=function()return 0 end,shadow=function()end}}
local include
include=function(n)
  if not modules[n] then modules[n]=assert(loadfile(root..'/src/'..n..'.lua'))()(mod,include) end
  return modules[n]
end
local S=include('sprites')
local lines,draws=0,0
local oldLine,oldDraw=love.graphics.line,love.graphics.draw
love.graphics.line=function(...)lines=lines+1;return oldLine(...)end
love.graphics.draw=function(...)draws=draws+1;return oldDraw(...)end
local e={national=1,species='BULBASAUR',surface='land',px=32,py=48,facing='down',clock=1,idlePose={sleep=true,sx=1.02,sy=.97}}
for _,set in ipairs({'g9','ee'})do
  options.wild_sprites=set
  for _,scale in ipairs({1,2,3})do
    for _,row in ipairs({'full','bottom','top'})do
      lines=0;draws=0
      S:draw(e,7,9,scale,row=='full' and nil or row)
      check(draws==1,'sleep pose retains one Pokemon body')
      check(lines==(row=='bottom' and 0 or 6),'Z overlay draws once in full or Crystal upper pass')
      local r,g,b,a=love.graphics.getColor()
      check(r==1 and g==1 and b==1 and a==1,'sleep overlay restores graphics color')
    end
  end
end
lines=0;e.hidden=true;S:draw(e,0,0,1);check(lines==0,'hidden sleeping wild has no overlay')
e.hidden=false;e.moving=true;S:draw(e,0,0,1);check(lines==0,'moving wild has no sleeping overlay')
e.moving=false;e.idlePose=nil;S:draw(e,0,0,1);check(lines==0,'awake wild has no sleeping overlay')
print('PASS '..version..' ecology rendering: '..checks..' checks')
