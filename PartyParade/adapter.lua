-- Six follower-only slots sit outside UA's fixed wild actor pool.
return function(base,mod,include)
  local function copy(value)
    if type(value)~='table' then return value end
    local result={};for key,item in pairs(value)do result[key]=copy(item)end;return result
  end
  local E=setmetatable({C=copy(base.C),Data=copy(base.Data),actors={},FOLLOWER_SLOTS=6}, {__index=base})
  E.actors[1]=base.FOLLOWER;E.FOLLOWER=base.FOLLOWER
  for i=2,6 do
    local a={uadv=true,slot=1,index=i,localId=-1000-i,active=false,
      visible=true,hidden=false,invisible=true,cellX=0,cellY=0,px=0,py=0,
      targetX=0,targetY=0,moving=false,stepFrames=16,stepFlip=false,
      facing='down',elevation=3,currentElevation=3,raiseX=0,raiseY=0}
    a.graphicsId=a;E.actors[i]=a
  end
  local atlasIds=include('lib/atlas_species.lua')
  for i=0,26 do atlasIds[2048+i]=1024+i end
  for _,name in ipairs({'species','female','shinyPal','asym','shadow','tracks'})do
    local original=base.Data.ATLAS[name]
    if original then
      local target=E.Data.ATLAS[name]
      for nat,id in pairs(atlasIds)do target[nat]=original[id]end
    end
  end
  E.Gfx=setmetatable({sheetFor=function(species,...)
    return base.Gfx.sheetFor(atlasIds[species] or species,...)
  end},{__index=base.Gfx})
  function E.Gfx.draw(sheet,frame,flip,palRow,sx,sy,white,alpha,xscale,mosaic,yscale)
    local G=base.Gfx
    if not yscale or yscale==1 then
      return G.draw(sheet,frame,flip,palRow,sx,sy,white,alpha,xscale,mosaic)
    end
    if not G.ready and not G.load() then return false end
    local A=base.Data.ATLAS;local b=(sheet-1)*6
    local fw,fh=A.sheets[b+3],A.sheets[b+4]
    frame=math.min(frame,A.sheets[b+5]-1)
    local y=A.sheets[b+2]
    G.quads[sheet]=G.quads[sheet] or {}
    local q=G.quads[sheet][frame]
    if not q then
      q=love.graphics.newQuad(A.sheets[b+1]+frame*fw,y%A.h,fw,fh,A.w,A.h)
      G.quads[sheet][frame]=q
    end
    local lg=love.graphics;local previous
    if not G.bound then previous=lg.getShader();lg.setShader(G.shader) end
    mosaic=mosaic or 1
    if mosaic~=G.mosaic then G.mosaic=mosaic;G.shader:send('mosaic',mosaic) end
    lg.setColor((palRow%256)/255,math.floor(palRow/256)/255,white or 0,alpha or 1)
    lg.draw(G.pages[math.floor(y/A.h)+1],q,sx+8,sy+16-fh*yscale,0,
      (flip and -1 or 1)*(xscale or 1),yscale,fw/2,0)
    if not G.bound then lg.setShader(previous);lg.setColor(1,1,1,1) end
    return true
  end
  function E.monInfo(mon)
    if not mon or E.Pokemon.isEgg(mon) then return end
    local nat=E.Pokemon.national(E.Pokemon.speciesOf(mon))
    if not nat then return end
    if nat==201 then
      local letter=E.Pokemon.unownLetter(mon.personality or 0)
      if letter>0 then nat=2048+letter-1 end
    end
    return nat,E.Pokemon.isShiny(mon),mon.gender=='F'
  end
  function E.drawShadow(a,...)
    local original=a.species;a.species=atlasIds[original] or original
    local ok,result=pcall(base.drawShadow,a,...);a.species=original
    if not ok then error(result,0)end;return result
  end
  function E.followerVisible()
    local p=E.Player
    return p.visible~=false and not p.hidden and (not p.isVisible or p.isVisible())
      and base.followerVisible()
  end
  function E.actorAt(x,y,except)
    for _,a in ipairs(E.actors)do
      if a~=except and a.active and not a.invisible then
        local view=E.Spacing and E.Spacing.view(a) or a
        if view.cellX==x and view.cellY==y or a.moving and a.targetX==x and a.targetY==y then return a end
      end
    end
    local result=base.actorAt(x,y,except)
    if result==base.FOLLOWER then return nil end
    return result
  end
  function E.canMove(a,tx,ty,dir,surfing)
    -- UA's movement adapter uses slot-1 identity to apply follower collision.
    if a==base.FOLLOWER then return base.canMove(a,tx,ty,dir,surfing) end
    local leader=base.FOLLOWER
    local x,y,elevation=leader.cellX,leader.cellY,leader.currentElevation
    leader.cellX,leader.cellY,leader.currentElevation=a.cellX,a.cellY,a.currentElevation
    local ok,r1,r2=pcall(base.canMove,leader,tx,ty,dir,surfing)
    leader.cellX,leader.cellY,leader.currentElevation=x,y,elevation
    if not ok then error(r1,0)end;return r1,r2
  end
  return E
end
