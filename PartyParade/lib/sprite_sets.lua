-- True-color sprite choices share native movement, animation clocks and effects.
return function(E,mod,data)
 local M={};local images,quads={},{};local failed={};local shader;local clock=0;local used={};local g9count=0
 local walkers={}
 for _,id in ipairs({7,8,9,54,55,60,61,62,79,80,98,99,134,158,159,160,183,184,186,194,195,199,211,258,259,260,270,271,272,283,339,340,341,342,393,394,395,400,422,423,501,502,503,515,516,535,536,537,564,565,656,657,658,688,689,728,729,730,751,752,833,834,912,913,914,960,961})do walkers[id]=true end
 local directions={down=0,left=1,right=2,up=3}
 function M.selection(a)
  local style=a.nativeCore and E.C.follower_sprite_set
   or a.water and E.C.water_sprite_set or E.C.land_sprite_set
  if style~='g9rp' or not data[style] or a.shiny or a.ballGfx then return end
  local nat=a.owSpecies or a.species
  local A=E.Data.ATLAS
  -- Preserve shiny palettes, gender-specific art and alternate forms when
  -- the old normal-only packs cannot represent them.
  if a.female and A.female[nat] and A.female[nat]~=A.species[nat] then return end
  if a.water and not walkers[nat] and data.swim.species[nat] then style='swim' end
  local pack=data[style];local entry=pack.species[nat]
  if entry then return style,pack,entry end
 end
 local function imageFor(style)
  clock=clock+1;used[style]=clock
  if failed[style] then return end
  local image=images[style]
  if image and image.isReleased and image:isReleased() then
   images[style]=nil;image=nil;quads[style]=nil
   if style:match('^g9rp:') then g9count=g9count-1 end
  end
  if not image then
   local ok,result=pcall(function()
    local path=style:match('^g9rp:') and string.format('assets/g9rpsprites/%03d-normal.png',tonumber(style:sub(6))) or 'assets/'..style..'.png'
    local bytes=assert(mod:read(path),'missing '..path)
    local img=love.graphics.newImage(love.image.newImageData(love.filesystem.newFileData(bytes,path)))
    img:setFilter('nearest','nearest');return img
   end)
   if not ok then failed[style]=true;mod.log:error('sprite set %s unavailable: %s',style,tostring(result));return end
   if style:match('^g9rp:') then
    if g9count>=64 then
     local oldest,stamp
     for key,img in pairs(images)do
      if key:match('^g9rp:') and (not stamp or used[key]<stamp) then oldest,stamp=key,used[key] end
     end
     if oldest then
      local old=images[oldest];if old.release then old:release() end
      images[oldest]=nil;quads[oldest]=nil;used[oldest]=nil;g9count=g9count-1
     end
    end
    g9count=g9count+1
   end
   image=result;images[style]=image;quads[style]={}
  end
  return image
 end
 local function pose(a,frame,flip,style,entry)
  local dir=a.facing or 'down'
  local idleDir=E.Idle.pose(a)
  if idleDir then dir=idleDir end
  local held=idleDir or E.Doze.sleeping(a)
  if style=='g9rp' then
   local column=0
   if not held and a.anim and #a.anim>3 and not a.affine then
    column=math.floor((a.animT or 0)/(a.anim[2] or 6))%4
   end
   local row=directions[dir] or 0
   local offset=2+row*6
   return row*4+column,false,entry[offset],entry[offset+1],8+(entry[offset+2+column]-entry[offset+1])*32/entry[1]
  end
  local step=not held and frame%2==1
  local base=dir=='down' and 0 or dir=='up' and 1 or 2
  local f=base+(step and 3 or 0)
  return f,dir=='right' or (step and (dir=='up' or dir=='down') and flip),8,0,entry[f+2]
 end
 function M.head(a,frame)
  local style,pack,entry=M.selection(a)
  if not style or failed[style] or failed['g9rp:'..tostring(a.owSpecies or a.species)] then return end
  local _,_,_,_,head=pose(a,frame or 0,false,style,entry)
  return math.floor(head+.5)
 end
 function M.draw(a,frame,flip,sx,sy,white,alpha,xscale,mosaic,yscale)
  local style,pack,entry=M.selection(a)
  if not style then return false end
  local f,mirror,ox,oy=pose(a,frame,flip,style,entry)
  local slot=style=='g9rp' and f or entry[1]+f
  local texture=style=='g9rp' and 'g9rp:'..tostring(a.owSpecies or a.species) or style
  local image=imageFor(texture)
  if not image then return false end
  local q=quads[texture][slot]
  if not q then
   local cell=style=='g9rp' and entry[1] or pack.cell
   local columns=style=='g9rp' and 4 or pack.cols
   q=love.graphics.newQuad(slot%columns*cell,math.floor(slot/columns)*cell,cell,cell,image:getDimensions())
   quads[texture][slot]=q
  end
  local lg=love.graphics;local oldShader=lg.getShader();local r,g,b,opacity=lg.getColor()
  if (white or 0)>0 or (mosaic or 1)>1 then
   shader=shader or lg.newShader([[
    uniform float white; uniform float mosaic; uniform vec2 size;
    vec4 effect(vec4 color, Image tex, vec2 texcoord, vec2 sc) {
      highp vec2 uv=VaryingTexCoord.st;
      if(mosaic>1.0) uv=(floor(uv*size/mosaic)*mosaic+0.5)/size;
      vec4 c=Texel(tex,uv); c.rgb=mix(c.rgb,vec3(1.0),white);
      return vec4(c.rgb,c.a*color.a);
    }
   ]])
   shader:send('white',white or 0);shader:send('mosaic',mosaic or 1);shader:send('size',{image:getDimensions()});lg.setShader(shader)
  else lg.setShader() end
  lg.setColor(1,1,1,alpha or 1)
  local scale=(xscale or 1)*(mirror and -1 or 1)
  if style=='g9rp' then lg.draw(image,q,sx+8,sy+16-8*(yscale or 1),0,scale*32/entry[1],(yscale or 1)*32/entry[1],ox,oy)
  else lg.draw(image,q,sx+8,sy+16-16*(yscale or 1),0,scale,yscale or 1,8,0) end
  lg.setShader(oldShader);lg.setColor(r,g,b,opacity)
  return true
 end
 M.data=data
 return M
end
