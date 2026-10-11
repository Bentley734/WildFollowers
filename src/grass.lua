-- Native grass artwork stays in the engine. These covers belong to our actors
-- and follow their source map without registering them as native NPCs.
return function(mod,include)
  local A,W=include('adapter'),include('areas')
  local M={}
  function M:drawGB(e,screenX,screenY,scale,row)
    if A.generation==3 or e.hidden or e.surface=='water' or row=='top' then return end
    local area=e.follower and A:area() or W:source(e)
    if not area or not area.map then return end
    local dx,dy=(e.areaOffsetX or 0)*16,(e.areaOffsetY or 0)*16
    local px,py=e.px-dx,e.py-dy
    local grass=false
    for y=math.floor((py+4)/16),math.floor((py+11)/16) do
      for x=math.floor(px/16),math.floor((px+15.999)/16) do
        if A:grass(x,y,area) then grass=true end
      end
    end
    if not grass then return end
    local G=love.graphics;G.push('all')
    if A.generation==1 then
      local renderer=area.map.renderer
      if not renderer and area.map.tileset and area.map.tileset.image then
        renderer=require('src.render.TileRenderer').new(area.map,mod.game.data)
        area.map.renderer=renderer
      end
      if renderer and renderer.drawStrip then
        G.translate(screenX+dx*(scale or 1),screenY+dy*(scale or 1));G.scale(scale or 1)
        renderer:drawStrip(px,py+4,px+16,py+12,0,0)
      end
    else
      local world=A:world()
      if world and world.drawGrassOver then
        local view=setmetatable({map=area.map},{__index=world})
        local feet={px=px,py=py,cellX=math.floor(px/16),cellY=math.floor(py/16),
          spriteDef=e.spriteDef,inGrass=true}
        world.drawGrassOver(view,feet,screenX+dx*(scale or 1),screenY+dy*(scale or 1),scale or 1)
      end
    end
    G.pop()
  end
  function M:collect(out,e)
    if A.generation~=3 or e.hidden or e.surface=='water' then return end
    local F=require('src.core.game3.field_effects')
    if type(F.loadSheet)~='function' then return end
    local area=e.follower and A:area() or W:source(e)
    if not area then return end
    local ox,oy=e.areaOffsetX or 0,e.areaOffsetY or 0
    local C=require('src.core.game3.collision')
    local MB=require('src.core.game3.mb')
    -- Test the interpolated sixteen-pixel foot footprint, including both
    -- sides of a tile boundary. Only terrain under the feet gets a cover.
    local feet=e.py+16
    for y=math.floor((feet-8)/16),math.floor((feet-1)/16) do
      for x=math.floor(e.px/16),math.floor((e.px+15.999)/16) do
        local sx,sy=x-ox,y-oy
        if A:grass(sx,sy,area) then
          local behavior=C.behaviorOn and C.behaviorOn(area.def,sx,sy)
          local name=behavior~=nil and behavior==MB.id('LONG_GRASS') and 'long_grass' or 'tall_grass'
          local sheet=F.loadSheet(name,16,16,5)
          if not sheet and name~='tall_grass' then sheet=F.loadSheet('tall_grass',16,16,5) end
          local q=sheet and sheet.quadsFront and (sheet.quadsFront[4] or sheet.quadsFront[(sheet.frames or 1)-1])
          if q then
            local gx,gy=x*16,y*16+8
            out[#out+1]={kind='wildfollowers_grass',_wildFollowersGrass=true,
              owner=e,elevation=e.elevation,sortY=e.py+.5,x=e.px,y=e.py,
              grassX=gx,grassY=gy,i=90000+e.i,
              draw=function(_,camX,camY)
                local G=love.graphics
                G.push('all');G.setColor(1,1,1,1)
                G.draw(sheet.image,q,gx-camX,gy-camY);G.pop()
              end}
          end
        end
      end
    end
  end
  return M
end
