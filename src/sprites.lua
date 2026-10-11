return function(mod,include)
  local J=include('jumps')
  local waterBounds=include('water_bounds')
  local visibleBounds=include('sprite_bounds')
  local S={cache={}}
  local EE=include('ee_data')
  local Forms=include('forms')
  local rows={down=0,left=1,right=2,up=3}
  -- Native GB feet end at cell Y + 12; GBA feet end at cell Y + 16.
  local footY=require('src.core.GameVersion').generation()==3 and 16 or 12
  function S:get(national,actor)
    local form
    if actor then form=Forms:resolve(actor.species) end
    if form then national=form.national end
    if type(national)~='number' or national%1~=0 or national<1 or national>1025 then return nil end
    local paths,seen={},{}
    local function add(path)
      if path and not seen[path] then paths[#paths+1]=path;seen[path]=true end
    end
    local useEE=actor and mod.options:get(actor.follower and 'follower_sprites' or 'wild_sprites')=='ee'
    local shiny,female=false,false
    if actor then
      local mon=actor.mon
      if mon and (useEE or form) then
        shiny=mon.shiny==true;female=mon.gender=='F' or mon.gender=='female'
        if require('src.core.GameVersion').generation()==3 then
          local P=require('src.core.game3.pokemon')
          shiny=P.isShiny(mon);female=P.gender(actor.species,mon.personality)=='F'
        end
      end
    end
    local function variants(art)
      if shiny and female then add(art.female_shiny) end
      if shiny then add(art.shiny) end
      if female then add(art.female) end
      add(art.normal)
    end
    if form then
      variants(useEE and form.ee or form.g9)
      variants(useEE and form.g9 or form.ee)
    end
    local base=EE.national[national]
    if form and form.mega then
      -- Keep the requested shiny-base fallback only when true Mega art is
      -- missing. This is a display choice, never a mutation of the Pokemon.
      add(EE.species[base..'_shiny'])
    end
    if useEE then
      variants({normal=EE.species[base],shiny=EE.species[base..'_shiny'],
        female=EE.species[base..'_female'],female_shiny=EE.species[base..'_female_shiny']})
    end
    add(('assets/g9rpsprites/%03d-normal.png'):format(national))
    for _,path in ipairs(paths)do
      local record=self:load(path)
      if record then return record end
    end
    return nil
  end
  function S:load(path)
    if self.cache[path]~=nil then return self.cache[path] or nil end
    local ee=path:find('assets/ee/',1,true)~=nil
    local ok,img=pcall(mod.assets.image,mod.assets,path)
    if not ok or not img then
      self.cache[path]=false
      return nil
    end
    img:setFilter('nearest','nearest')
    local w,h=img:getDimensions()
    if w%4~=0 or h%4~=0 then
      self.cache[path]=false
      return nil
    end
    local record={path=path,image=img,w=w/4,h=h/4,quads={},ee=ee,bottoms=waterBounds[path]}
    for facing,row in pairs(rows) do
      record.quads[facing]={}
      for frame=0,3 do
        record.quads[facing][frame]=love.graphics.newQuad(frame*record.w,row*record.h,record.w,record.h,w,h)
      end
    end
    self.cache[path]=record
    return record
  end
  function S:extent(actor)
    local r=self:get(actor.national,actor)
    if not r then return {left=8,right=8,top=16,bottom=0} end
    local bounds=visibleBounds[r.path]
    local b=bounds and (bounds[actor.facing or 'down'] or bounds) or {0,0,r.w,r.h}
    local size=r.ee and 1 or 32/r.w
    return {left=math.max(0,(r.w/2-b[1])*size),right=math.max(0,(b[3]-r.w/2)*size),
      top=math.max(0,(r.h-b[2])*size),bottom=(b[4]-r.h)*size}
  end
  function S:box(actor,x,y)
    local b=self:extent(actor)
    local pose=actor.idlePose;local sx=pose and pose.sx or 1;local sy=pose and pose.sy or 1
    x=(x or actor.px)+8;y=(y or actor.py)+footY
    return {x-b.left*sx,y-b.top*sy,x+b.right*sx,y+b.bottom*sy}
  end
  function S:frame(actor)
    local march=mod.options:get(actor.follower and 'followers_march' or 'wilds_march')==true
    local speed=march and math.max(.1,math.min(3,tonumber(mod.options:get(actor.follower and 'followers_march_speed' or 'wilds_march_speed')) or 1)) or 1
    local pose=actor.idlePose
    local frame=((actor.moving and not actor.spacingPaused) or march) and math.floor((actor.clock or 0)*8*speed)%4 or (pose and pose.frame or 0)
    -- Moving wilds keep their complete step cycle; march speed controls their
    -- standing animation without changing walking speed or movement progress.
    if not actor.follower and actor.moving and not actor.spacingPaused and actor.progress~=nil then
      frame=(1+math.floor(math.max(0,math.min(1,actor.progress))*4))%4
    end
    return frame
  end
  function S:draw(actor,ox,oy,scale,oamRow)
    local r=self:get(actor.national,actor);if not r or actor.hidden then return end
    local G=love.graphics;scale=scale or 1
    -- Supplied 64px frames include padding; a 32px frame puts the body in one cell.
    local size=r.ee and 1 or 32/r.w
    local pose=actor.idlePose
    local facing=pose and pose.facing or actor.facing or 'down'
    local frame=self:frame(actor)
    local x=ox+(actor.px+8)*scale-r.w*size*scale/2
    local jumpY=J:pose(actor)
    local y=oy+(actor.py+footY+jumpY)*scale-r.h*size*scale
    local water=actor.surface=='water' and not actor.follower
    local bottom=r.h
    if water and r.bottoms then bottom=r.bottoms[(rows[facing] or 0)+1][frame+1] end
    local crop=water and math.max(0,math.min(3,math.floor(tonumber(mod.options:get('water_sprite_crop')) or 0))) or 0
    local retained=crop>0 and math.max(0,bottom-crop/size) or r.h
    J:shadow(actor,ox,oy,scale,oamRow)
    G.push('all');G.setColor(1,1,1,1)
    if pose and (not actor.moving or actor.spacingPaused) and not actor.ballPhase then
      local cx,cy=ox+(actor.px+8)*scale,oy+(actor.py+footY)*scale
      G.translate(cx,cy);G.scale(pose.sx or 1,pose.sy or 1);G.translate(-cx,-cy)
    end
    local t
    if actor.ballPhase then
      t=math.min(1,(actor.ballTime or 0)/.30)
      if actor.ballPhase=='release' then t=1-t end
      local cx,cy=ox+(actor.px+8)*scale,oy+(actor.py+footY)*scale
      local shrink=math.max(.01,1-t/.72)
      G.translate(cx,cy);G.scale(shrink,shrink);G.translate(-cx,-cy)
    end
    -- Crystal asks for the bottom and top OAM rows separately.
    if t and t>=.72 then
      -- The body has fully entered the ball.
    elseif oamRow or water then
      local qx=(frame*r.w);local qy=(rows[facing] or 0)*r.h
      local cut=r.h-8/size
      local height=oamRow and math.min(cut,retained) or retained
      if oamRow=='bottom' then qy=qy+cut;y=y+cut*size*scale;height=retained-cut end
      if height>0 then
        local q
        if water then
          r.waterQuads=r.waterQuads or {}
          local key=facing..':'..frame..':'..crop..':'..(oamRow or 'full')
          q=r.waterQuads[key]
          if not q then q=G.newQuad(qx,qy,r.w,height,r.image:getDimensions());r.waterQuads[key]=q end
        else q=G.newQuad(qx,qy,r.w,height,r.image:getDimensions()) end
        G.draw(r.image,q,x,y,0,size*scale,size*scale)
      end
    else
      G.draw(r.image,r.quads[facing][frame],x,y,0,size*scale,size*scale)
    end
    G.pop()
    if pose and pose.sleep and not actor.moving and not actor.hidden and oamRow~='bottom' then
      -- Draw once above the body, including Crystal's split OAM compositor.
      local cx=ox+(actor.px+8)*scale
      local cy=oy+(actor.py+footY-r.h*size-2)*scale
      G.push('all')
      for z=0,2 do
        local phase=((actor.clock or 0)*.35+z/3)%1
        local alpha=math.sin(phase*math.pi)*.75
        local x=cx+(z%2==0 and 3 or -3)*scale
        local y=cy-phase*9*scale
        G.setColor(.08,.14,.25,alpha);G.setLineWidth(3*scale)
        G.line(x-2*scale,y,x+2*scale,y,x-2*scale,y+3*scale,x+2*scale,y+3*scale)
        G.setColor(1,1,1,alpha);G.setLineWidth(scale)
        G.line(x-2*scale,y,x+2*scale,y,x-2*scale,y+3*scale,x+2*scale,y+3*scale)
      end
      G.pop()
    end
    if t and oamRow~='top' then
      local cx,cy=ox+(actor.px+8)*scale,oy+(actor.py+footY-4)*scale
      -- t runs closed -> Pokemon for release, and backwards for recall.
      local progress=1-t
      local opacity=math.min(1,t*4)
      local open=math.sin(math.pi*math.min(1,progress/.70))
      local radius=4*scale
      local gap=open*3*scale
      local flash=math.max(0,1-math.abs(progress-.27)/.23)
      G.push('all')
      local function shell(top)
        local centerY=cy+(top and -gap or gap*.35)
        local points={cx,centerY}
        for i=0,12 do
          local angle=(top and math.pi or 0)+i*math.pi/12
          points[#points+1]=cx+math.cos(angle)*radius
          points[#points+1]=centerY+math.sin(angle)*radius*(top and 1 or .72)
        end
        G.setColor(top and .92 or .94,top and .12 or .96,top and .16 or 1,opacity)
        G.polygon('fill',points)
        G.setColor(.10,.13,.16,opacity);G.setLineWidth(scale)
        G.polygon('line',points)
        -- The dark interior lip makes the separated halves read as open.
        G.line(cx-radius,centerY,cx+radius,centerY)
      end
      shell(false);shell(true)
      G.setColor(.12,.15,.18,opacity);G.circle('fill',cx,cy-gap,1.6*scale)
      G.setColor(.95,.98,1,opacity);G.circle('fill',cx,cy-gap,scale)
      if flash>0 then
        -- Long cyan-edged rays surround an opaque white energy burst.
        -- Deterministic angles avoid flicker when Crystal draws OAM rows.
        local burst=(3+10*flash)*scale
        for i=0,7 do
          local angle=i*math.pi/4-.15
          local length=burst*(i%2==0 and 1.25 or .85)
          local ax,ay=math.cos(angle),math.sin(angle)
          local width=(.8+flash)*scale
          G.setColor(.35,.95,1,flash*.8)
          G.polygon('fill',cx-ay*width,cy+ax*width,
            cx+ax*length,cy+ay*length,cx+ay*width,cy-ax*width)
        end
        local star={}
        for i=0,15 do
          local angle=i*math.pi/8
          local length=(i%2==0 and burst*.72 or burst*.25)
          star[#star+1]=cx+math.cos(angle)*length
          star[#star+1]=cy+math.sin(angle)*length
        end
        G.setColor(1,1,1,flash);G.polygon('fill',star)
      end
      -- White core remains anchored to the ball throughout opening/closing.
      G.setColor(1,1,1,flash);G.circle('fill',cx,cy,(1+3*flash)*scale)
      G.pop()
    end
  end
  return S
end
