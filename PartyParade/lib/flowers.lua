-- Reuse each map's animated flower pixels, without repainting its ground.
return function(E)
  local Native=require('src.core.game3.tileset_native')
  local Anim=require('src.core.game3.tileset_anim')
  local caches=setmetatable({},{__mode='k'})
  local M={}
  local frame=0
  local footQuad
  function M.beginFrame()frame=frame+1 end
  local function flowerMid(pair,mid)
    local entry=Anim._pairs and Anim._pairs[pair]
    if not entry or type(entry)~='table' then return false end
    if not entry.rse then
      local b=entry.banks and entry.banks.flower
      return b and b.midIndex and b.midIndex[mid]~=nil
    end
    for _,bank in ipairs(entry.banks or {})do
      local row=bank and bank.row
      if row and tostring(row.name):lower():find('flower',1,true) then
        for _,id in ipairs(row.mids or {})do if id==mid then return true end end
      end
    end
    return false
  end
  local function pixels(ts,mid)
    if not ts.imageData or not ts.imageData.getPixel or not ts.midToSlot[1] then return end
    local slot=ts.midToSlot[mid];if slot==nil then return end
    local cache=caches[ts]
    if not cache then cache={};caches[ts]=cache end
    local item=cache[mid]
    if not item then item={frames={}};cache[mid]=item end
    if frame>0 and item.serial==frame then return item.current end
    local x,y=slot%ts.cols*16,math.floor(slot/ts.cols)*16
    local ground=ts.midToSlot[1]
    local bx,by=ground%ts.cols*16,math.floor(ground/ts.cols)*16
    local bytes={}
    for yy=10,15 do for xx=0,15 do
      local r,g,b,a=ts.imageData:getPixel(x+xx,y+yy)
      local br,bg,bb=ts.imageData:getPixel(bx+xx,by+yy)
      -- Matching base grass is background, not a flower or leaf.
      if r==br and g==bg and b==bb then a=0 end
      bytes[#bytes+1]=string.char(math.floor(r*255+.5),math.floor(g*255+.5),math.floor(b*255+.5),math.floor((a or 1)*255+.5))
    end end
    local signature=table.concat(bytes)
    local image=item.frames[signature]
    if not image then
      -- A small cache follows native animation frames and palette changes.
      if (item.count or 0)>=16 then
        for _,old in pairs(item.frames)do if old.release then old:release() end end
        item.frames={};item.count=0
      end
      image=love.graphics.newImage(love.image.newImageData(16,6,'rgba8',signature))
      if image.setFilter then image:setFilter('nearest','nearest') end
      item.frames[signature]=image;item.count=(item.count or 0)+1
    end
    item.serial,item.current=frame,image
    return image
  end
  function M.drawAt(px,py,camX,camY)
    local def=E.Collision._mapDef
    if not def or not def.midLayout then return end
    -- Only repaint the intersection with this actor's bottom six pixels.
    -- Whole tile strips can cover heads while crossing a tile, and can also
    -- repaint neighbouring actors outside this actor's footprint.
    local feetTop,feetBottom=py+10,py+16
    for y=math.floor(feetTop/16),math.ceil(feetBottom/16)-1 do
      for x=math.floor(px/16),math.ceil((px+16)/16)-1 do
        local left,right=math.max(px,x*16),math.min(px+16,x*16+16)
        local top,bottom=math.max(feetTop,y*16+10),math.min(feetBottom,y*16+16)
        if right>left and bottom>top then
          local mid,pair,void
          if E.Map.worldMidAt then mid,pair,void=E.Map.worldMidAt(x,y,def)
          else mid=def.midLayout:midAt(x,y) end
          pair=pair or def.pair or def.midLayout.pair
          if not void and pair and flowerMid(pair,mid) then
            local ts=Native.get(pair)
            local image=ts and pixels(ts,mid)
            if image then
              local lg=love.graphics
              local shader=lg.getShader();local r,g,b,a=lg.getColor()
              lg.setShader();lg.setColor(1,1,1,1)
              if not footQuad then footQuad=lg.newQuad(0,0,16,6,16,6) end
              footQuad:setViewport(left-x*16,top-y*16-10,right-left,bottom-top,16,6)
              lg.draw(image,footQuad,left-camX,top-camY)
              lg.setShader(shader);lg.setColor(r,g,b,a)
            end
          end
        end
      end
    end
  end
  return M
end
