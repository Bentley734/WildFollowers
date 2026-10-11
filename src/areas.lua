-- Population ownership is local to each source map. Only its projection
-- changes at a route seam; querying a neighbor never changes the live map.
return function(mod,include)
  local A=include('adapter')
  local M={populations={},views={},origins={},clock=0}
  local ranges={normal=12,far=20,wide=32,very_wide=48,ultra_wide=64,near=12}
  local amounts={none=0,low=2,normal=4,high=6,very_high=8}
  local function option(key) return mod.options:get(key) end
  local function copy(t) local out={};for k,v in pairs(t or {}) do out[k]=v end;return out end
  local function actorCount(populations,kind)
    local n=0;for _,p in pairs(populations) do for _,e in ipairs(p.actors)do
      if e.surface==kind then n=n+1 end
    end end;return n
  end
  function M:clear()
    self.populations={};self.views={};self.origins={};self.current=nil
    self.pending=nil;self.clock=0;self.nearest=nil
  end
  function M:transition(ev)
    if not ev or ev.via~='connection' then self:clear();return end
    self.pending={via=ev.via,from=ev.fromMapId or ev.fromMap,map=ev.mapId}
  end
  function M:sync(e)
    e.sourceX=e.cellX-(e.areaOffsetX or 0)
    e.sourceY=e.cellY-(e.areaOffsetY or 0)
    e.sourcePX=e.px-(e.areaOffsetX or 0)*16
    e.sourcePY=e.py-(e.areaOffsetY or 0)*16
  end
  local function project(e,x,y)
    local dx,dy=x-(e.areaOffsetX or 0),y-(e.areaOffsetY or 0)
    for _,key in ipairs({'cellX','targetX'}) do if e[key]~=nil then e[key]=e[key]+dx end end
    for _,key in ipairs({'cellY','targetY'}) do if e[key]~=nil then e[key]=e[key]+dy end end
    for _,key in ipairs({'px','startX','x'}) do if type(e[key])=='number' then e[key]=e[key]+dx*16 end end
    for _,key in ipairs({'py','startY','y'}) do if type(e[key])=='number' then e[key]=e[key]+dy*16 end end
    e.areaOffsetX,e.areaOffsetY=x,y
  end
  function M:source(e)
    local area=self.views[e.sourceMap] or e._sourceArea
    if not area then return nil end
    return area
  end
  function M:allowed(e,x,y)
    local area=self:source(e);if not area or e.retired then return false end
    local lx,ly=x-(e.areaOffsetX or 0),y-(e.areaOffsetY or 0)
    local from={cellX=e.cellX-(e.areaOffsetX or 0),cellY=e.cellY-(e.areaOffsetY or 0),
      currentElevation=e.currentElevation,elevation=e.elevation,facing=e.facing}
    return A:allowed(lx,ly,e.surface,from,nil,area)
  end
  function M:habitat(e,x,y)
    local area=self:source(e)
    return area~=nil and A:habitat(x-(e.areaOffsetX or 0),y-(e.areaOffsetY or 0),e.surface,area)
  end
  function M:grass(e)
    local area=self:source(e)
    return area~=nil and A:grass(e.cellX-(e.areaOffsetX or 0),e.cellY-(e.areaOffsetY or 0),area)
  end
  function M:land(e)
    local area=self:source(e);if not area then return end
    local localActor={cellX=e.cellX-(e.areaOffsetX or 0),cellY=e.cellY-(e.areaOffsetY or 0),
      currentElevation=e.currentElevation,elevation=e.elevation}
    A:land(localActor,area)
    e.currentElevation,e.elevation=localActor.currentElevation,localActor.elevation
    self:sync(e)
  end
  function M:retire(e,reason)
    if not e._expiresAt then e._expiresAt=self.clock+15;e._retirement=reason end
  end
  function M:resolve()
    local id=A:mapId();local root=A:area(id)
    if not root then self:clear();return nil end
    if self.current~=id then
      local from=self.current;local origin
      if from and self.pending and self.pending.via=='connection'
          and (not self.pending.from or self.pending.from==from)
          and (not self.pending.map or self.pending.map==id) then
        origin=self.views[id] and self.origins[id]
        if not origin then
          for _,neighbor in ipairs(A:adjacent(root)) do
            if neighbor.id==from and self.origins[from] then
              origin={x=self.origins[from].x-neighbor.offsetX,y=self.origins[from].y-neighbor.offsetY};break
            end
          end
        end
      end
      if from and not origin then self:clear() end
      self.origins[id]=origin or {x=0,y=0}
      if from and origin then
        local p=self.populations[from]
        for _,e in ipairs(p and p.actors or {}) do self:retire(e,'departure') end
      end
      self.current=id;self.pending=nil
    end
    local origin=self.origins[id] or {x=0,y=0};self.origins[id]=origin
    root.originX,root.originY=origin.x,origin.y;root.current=true
    local views={[id]=root};local adjacent={}
    for _,area in ipairs(A:adjacent(root)) do
      local at={x=origin.x+area.offsetX,y=origin.y+area.offsetY}
      self.origins[area.id]=at
      area.originX,area.originY=at.x,at.y;area.current=false
      views[area.id]=area;adjacent[#adjacent+1]=area
    end
    self.views=views
    return root,adjacent
  end
  local function closest(root,neighbors,px,py,radius)
    local best,distance
    for _,area in ipairs(neighbors) do
      local x,y=area.originX-root.originX,area.originY-root.originY
      local dx=math.max(x-px,px-(x+area.width-1),0)
      local dy=math.max(y-py,py-(y+area.height-1),0)
      local d=math.max(dx,dy)
      if dx<=radius and dy<=radius and (distance==nil or d<distance
          or d==distance and tostring(area.id)<tostring(best.id)) then best,distance=area,d end
    end
    return best
  end
  function M:occupied(C,x,y)
    for _,p in pairs(self.populations) do for _,e in ipairs(p.actors) do
      if e.cellX==x and e.cellY==y or e.targetX==x and e.targetY==y then return true end
    end end
    for _,e in ipairs(C.followers or {}) do
      if e.cellX==x and e.cellY==y or e.targetX==x and e.targetY==y then return true end
    end
    local p=A:player()
    if p.cellX==x and p.cellY==y or p.moving and p.targetX==x and p.targetY==y then return true end
    local px,py=p.px or p.cellX*16,p.py or p.cellY*16
    return x*16<px+16 and x*16+16>px and y*16<py+16 and y*16+16>py
  end
  function M:fill(C,area,root,radius,caps,preview)
    if not area or A:encountersBlocked(area) or not A:healthy() then return end
    local pop=self.populations[area.id]
    if not pop then pop={actors={},retryAt=0};self.populations[area.id]=pop end
    local counts={land=0,water=0}
    for _,e in ipairs(pop.actors)do counts[e.surface]=counts[e.surface]+1 end
    local global={land=actorCount(self.populations,'land'),water=actorCount(self.populations,'water')}
    if (counts.land>=caps.land or global.land>=16) and (counts.water>=caps.water or global.water>=16)
        or self.clock<pop.retryAt then return end
    local ox,oy=area.originX-root.originX,area.originY-root.originY
    local p=A:player();local px=p.moving and p.targetX or p.cellX;local py=p.moving and p.targetY or p.cellY
    local x0,x1=math.max(0,px-radius-ox),math.min(area.width-1,px+radius-ox)
    local y0,y1=math.max(0,py-radius-oy),math.min(area.height-1,py+radius-oy)
    if x0>x1 or y0>y1 then pop.retryAt=self.clock+.1;return end
    x0,y0,x1,y1=math.ceil(x0),math.ceil(y0),math.floor(x1),math.floor(y1)
    local success=false
    -- Geometry is stable for a source map; occupancy and range are live.
    -- Four-connected habitats are independent patches, regardless of area.
    if not pop.patches or pop.patchDef~=area.def or pop.patchWidth~=area.width or pop.patchHeight~=area.height then
      pop.patchDef,pop.patchWidth,pop.patchHeight=area.def,area.width,area.height
      pop.patches={};pop.patchAt={}
      local at=pop.patchAt
      for cy=0,area.height-1 do for cx=0,area.width-1 do
        local key=cy*area.width+cx
        if not at[key] then
          local kind=A:water(cx,cy,area) and 'water' or 'land'
          if A:habitat(cx,cy,kind,area) then
            local patch={kind=kind,cells={}};pop.patches[#pop.patches+1]=patch
            local queue={{cx,cy}};at[key]=patch;local head=1
            while head<=#queue do
              local cell=queue[head];head=head+1;patch.cells[#patch.cells+1]=cell
              for _,d in ipairs({{1,0},{-1,0},{0,1},{0,-1}})do
                local nx,ny=cell[1]+d[1],cell[2]+d[2];local nk=ny*area.width+nx
                if nx>=0 and ny>=0 and nx<area.width and ny<area.height and not at[nk]
                    and (A:water(nx,ny,area) and 'water' or 'land')==kind
                    and A:habitat(nx,ny,kind,area) then at[nk]=patch;queue[#queue+1]={nx,ny} end
              end
            end
          else at[key]=false end
        end
      end end
    end
    local candidates={}
    for _,patch in ipairs(pop.patches)do
      if counts[patch.kind]<caps[patch.kind] and global[patch.kind]<16 then
        local cells={}
        for _,cell in ipairs(patch.cells)do
          local cx,cy=cell[1],cell[2]
          if cx>=x0 and cx<=x1 and cy>=y0 and cy<=y1
              and math.max(math.abs(cx+ox-px),math.abs(cy+oy-py))>=(patch.kind=='water' and 3 or 1)
              and not self:occupied(C,cx+ox,cy+oy) then
            cells[#cells+1]=cell
          end
        end
        if #cells>0 then
          local n=0
          for _,e in ipairs(pop.actors)do
            local ex,ey=e.cellX-ox,e.cellY-oy
            if pop.patchAt[ey*area.width+ex]==patch then n=n+1 end
          end
          candidates[#candidates+1]={patch=patch,cells=cells,count=n,attempts=0}
        end
      end
    end
    for _=1,24 do
      if #candidates==0 then break end
      local best,ties=nil,{}
      for _,candidate in ipairs(candidates)do
        local score=candidate.count+candidate.attempts
        if best==nil or score<best then best=score;ties={candidate}
        elseif score==best then ties[#ties+1]=candidate end
      end
      local selected=ties[math.random(1,#ties)];selected.attempts=selected.attempts+1
      local cell=selected.cells[math.random(1,#selected.cells)]
      local x,y=cell[1],cell[2]
      local wx,wy=x+ox,y+oy;local kind=A:water(x,y,area) and 'water' or 'land'
      local distance=math.max(math.abs(wx-px),math.abs(wy-py))
      if counts[kind]<caps[kind] and global[kind]<16 and distance>=(kind=='water' and 3 or 1)
          and not self:occupied(C,wx,wy) and (not A.occupied or not A:occupied(x,y,nil,area))
          and A:habitat(x,y,kind,area) and A:allowed(x,y,kind,nil,nil,area) then
        local hit=A:choose(kind,math.random,area)
        local anchor
        if hit and C.ecosystemSpawn then hit,anchor=C:ecosystemSpawn(area,kind,hit,pop.actors) end
        if hit and anchor and pop.patchAt[(anchor.cellY-oy)*area.width+anchor.cellX-ox]==selected.patch then
          -- Place related/compatible encounters together so sparse populations
          -- can actually interact. The fallback remains the original legal cell.
          local ax,ay=anchor.cellX-ox,anchor.cellY-oy
          for attempt=1,24 do
            local radius=attempt<=8 and 2 or 3
            local nx,ny=ax+math.random(-radius,radius),ay+math.random(-radius,radius)
            local tx,ty=nx+ox,ny+oy
            local d=math.max(math.abs(tx-px),math.abs(ty-py))
            if pop.patchAt[ny*area.width+nx]==selected.patch and nx>=x0 and nx<=x1 and ny>=y0 and ny<=y1 and d>=(kind=='water' and 3 or 1)
                and not self:occupied(C,tx,ty) and (not A.occupied or not A:occupied(nx,ny,nil,area))
                and A:habitat(nx,ny,kind,area) and A:allowed(nx,ny,kind,nil,nil,area) then
              x,y,wx,wy=nx,ny,tx,ty;break
            end
          end
        end
        if hit and not A:repelled(hit.level) then
          local view=copy(area);view.localX,view.localY=x,y;view.offsetX,view.offsetY=ox,oy
          local e=C:actor(hit.species,hit.level,wx,wy,kind,nil,view)
          if e then
            e.sourceMap,e.mapId=area.id,area.id;e.sourceX,e.sourceY=x,y
            e.areaOffsetX,e.areaOffsetY=ox,oy;e._sourceArea=area
            e.currentEligible,e.previewEligible,e.retired=not preview,preview,false
            e._areaState=preview and 'preview' or 'active'
            pop.actors[#pop.actors+1]=e;self:sync(e);success=true;break
          end
        end
      end
    end
    pop.retryAt=self.clock+((preview or not success) and .1 or 0)
  end
  function M:update(C,dt)
    dt=tonumber(dt) or 1/60;if dt<0 or dt~=dt or dt==math.huge then dt=0 end
    local identity=A:save()
    if self.identity~=identity then self:clear();self.identity=identity end
    if option('enabled')==false or option('WE_OW_ENCOUNTERS')==false then self:clear();return {} end
    for _,pop in pairs(self.populations) do for _,e in ipairs(pop.actors) do self:sync(e) end end
    local root,neighbors=self:resolve();if not root then return {} end
    if not A:busy() then self.clock=self.clock+dt end
    local radius=ranges[option('spawn_range')] or 12
    local caps={land=amounts[option('spawn_density')] or 4,
      water=option('WE_OW_WATER')==false and 0 or amounts[option('water_spawn_density')] or 4}
    local p=A:player();local preview=closest(root,neighbors,p.cellX,p.cellY,radius)
    self.nearest=preview and preview.id or nil
    for id,pop in pairs(self.populations) do
      local source=self.views[id]
      for i=#pop.actors,1,-1 do
        local e=pop.actors[i]
        if option('WE_OW_WATER')==false and e.surface=='water' then table.remove(pop.actors,i)
        else
          if id==self.current then e._expiresAt=nil;e._retirement=nil;e._areaState='active'
          elseif id==self.nearest and (not e._expiresAt or e._retirement=='preview') then
            e._expiresAt=nil;e._retirement=nil;e._areaState='preview'
          else self:retire(e,e._areaState=='active' and 'departure' or 'preview');e._areaState='retired' end
          if e._expiresAt and self.clock>=e._expiresAt then table.remove(pop.actors,i)
          else
            local origin=self.origins[id]
            if origin then project(e,origin.x-root.originX,origin.y-root.originY) end
            if source then e._sourceArea=source else e._sourceArea=copy(e._sourceArea);e._sourceArea.current=false end
            e.currentEligible=id==self.current
            e.previewEligible=e._areaState=='preview';e.retired=e._areaState=='retired'
            e.areaLinger=e._expiresAt and math.max(0,e._expiresAt-self.clock) or nil
            e.hidden=false
          end
        end
      end
      -- Explicit amount reductions never evict a departing population.
      for _,kind in ipairs({'land','water'})do
        local count=0;for _,e in ipairs(pop.actors)do if e.surface==kind then count=count+1 end end
        local excess=count-caps[kind]
        for i=#pop.actors,1,-1 do
          if excess<=0 then break end
          if pop.actors[i].surface==kind and not pop.actors[i].retired then table.remove(pop.actors,i);excess=excess-1 end
        end
      end
      if #pop.actors==0 and id~=self.current and id~=self.nearest then self.populations[id]=nil end
    end
    if not A:busy() then
      self:fill(C,root,root,radius,caps,false)
      self:fill(C,preview,root,radius,caps,true)
    end
    local out={};local ids={};for id in pairs(self.populations) do ids[#ids+1]=id end;table.sort(ids)
    for _,id in ipairs(ids) do for _,e in ipairs(self.populations[id].actors) do out[#out+1]=e end end
    return out
  end
  return M
end
