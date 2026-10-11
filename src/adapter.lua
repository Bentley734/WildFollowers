return function(mod,include)
  local A={}
  local Forms=include and include('forms') or assert(load(assert(mod:read('src/forms.lua'))))()(mod)
  local Version=require('src.core.GameVersion')
  A.generation=Version.generation()
  A.version=Version.get()
  local G=A.generation
  -- Gen 1 reuses water/shore tile numbers in furniture and door tilesets.
  -- The native caller gates Map:isWaterCell with water_tilesets.asm membership.
  local gen1WaterFallback={OVERWORLD=true,FOREST=true,DOJO=true,GYM=true,SHIP=true,
    SHIP_PORT=true,CAVERN=true,FACILITY=true,PLATEAU=true}
  local function mapHasWater(map)
    if G~=1 then return true end
    local tileset=map and map.def and map.def.tileset
    local list=mod.game and mod.game.data and mod.game.data.field and mod.game.data.field.waterTilesets
    if list then
      for _,name in ipairs(list)do if name==tileset then return true end end
      return false
    end
    return gen1WaterFallback[tileset]==true
  end
  local function native(name) return require('src.core.game3.'..name) end
  function A:world()
    if G==3 then return mod.game and (mod.game.overworld or mod.game.world) end
    return mod.world and mod.world:overworld()
  end
  function A:save()
    return G==3 and native('runtime').getSession() or mod.game and mod.game.save
  end
  function A:mapId()
    local s=self:save();local w=self:world()
    return G==3 and s and s.map or w and w.map and w.map.id
  end
  function A:player()
    if G==3 then return native('player') end
    local w=self:world();return w and w.player
  end
  function A:occupied(x,y,ignore,area,followersPassable,vacatingPlayer)
    if area and not area.current then
      for _,e in ipairs(area.def.objects or area.def.objectEvents or {}) do
        if tonumber(e.x)==x and tonumber(e.y)==y then return true end
      end
      return false
    end
    local function occupied(list)
      for _,e in ipairs(list or {}) do
        if e~=ignore and not e.hidden and not e.storyRecall and not (vacatingPlayer and e==self:player() and e.moving and not (e.targetX==x and e.targetY==y)) and not (followersPassable and e._wildFollowersRewrite and e.follower) and
            (e.cellX==x and e.cellY==y or e.targetX==x and e.targetY==y) then return true end
      end
      return false
    end
    local w=self:world()
    if occupied(w and w.entities) or occupied(w and w.npcs) then return true end
    if G==3 then
      local O=native('objects')
      if O.forDraw and occupied(O.forDraw()) then return true end
    end
    return false
  end
  -- Detached map views let visible populations use their own terrain and
  -- encounter tables without changing the active collision grid or session.
  function A:area(id)
    id=id or self:mapId()
    if not id then return nil end
    local w=self:world();local game=mod.game;local current=id==self:mapId()
    local m=current and w and w.map or nil
    local maps=G==2 and w and w.maps or game and game.data and game.data.maps
    local def=m and m.def or maps and maps[id]
    if G==3 then
      local C=native('collision')
      def=def or current and C._mapDef
      if not def then return nil end
      if not def.midLayout and native('map').ensureMidLayout then native('map').ensureMidLayout(game,id,def) end
      local l=def.midLayout
      local width=l and l.width or current and C._widthCells or tonumber(def.width) and def.width*2
      local height=l and l.height or current and C._heightCells or tonumber(def.height) and def.height*2
      if not width or not height or width<=0 or height<=0 then return nil end
      return {id=id,def=def,width=width,height=height,current=current}
    end
    if not m then
      for _,n in ipairs(w and w.neighbors or {}) do
        if n.map and n.map.id==id then m=n.map;break end
      end
    end
    if not m and G==2 and w and w.connectionMap then m=w:connectionMap(id) end
    if not m and def then
      local sets=G==2 and w and w.tilesets or game and game.data and game.data.tilesets
      local tileset=sets and sets[def.tileset]
      if tileset then m=require(G==2 and 'src.world.gen2.Map' or 'src.world.Map').new(def,tileset) end
    end
    if not m then return nil end
    def=m.def or def
    local width=m.widthCells or def and tonumber(def.width) and def.width*2
    local height=m.heightCells or def and tonumber(def.height) and def.height*2
    if not width or not height or width<=0 or height<=0 then return nil end
    return {id=id,map=m,def=def,width=width,height=height,current=current}
  end
  function A:adjacent(area)
    local out={};if not area or not area.def then return out end
    local entries={}
    if G==3 then entries=native('connections').each(area.def)
    else
      for dir,c in pairs(area.def.connections or {}) do
        if type(c)=='table' then entries[#entries+1]={dir=dir,map=c.map or c.mapId,offset=tonumber(c.offset) or 0} end
      end
    end
    table.sort(entries,function(a,b)return tostring(a.map)<tostring(b.map) end)
    for _,conn in ipairs(entries) do
      local other=self:area(conn.map)
      if other and other.id~=area.id then
        local offset=(tonumber(conn.offset) or 0)*(G==3 and 1 or 2)
        local dir=conn.dir;local x,y
        if dir=='north' or dir=='up' then x,y=offset,-other.height
        elseif dir=='south' or dir=='down' then x,y=offset,area.height
        elseif dir=='west' or dir=='left' then x,y=-other.width,offset
        elseif dir=='east' or dir=='right' then x,y=area.width,offset end
        if x then other.offsetX,other.offsetY=x,y;out[#out+1]=other end
      end
    end
    return out
  end
  function A:connectedCell(x,y)
    local root=self:area();if not root or x>=0 and y>=0 and x<root.width and y<root.height then return nil end
    local crossing=self.crossingArea
    if crossing and crossing.destination==root.id then
      local lx,ly=x-crossing.offsetX,y-crossing.offsetY
      if lx>=0 and ly>=0 and lx<crossing.width and ly<crossing.height then return crossing,lx,ly end
    end
    for _,view in ipairs(self:adjacent(root)) do
      local lx,ly=x-view.offsetX,y-view.offsetY
      if lx>=0 and ly>=0 and lx<view.width and ly<view.height then return view,lx,ly end
    end
  end
  function A:elevations(x,y,area)
    if G~=3 then return 3,3 end
    local C=native('collision')
    local elevation=area and C.elevationOn and C.elevationOn(area.def,x,y)
      or not area and C.elevationAt and C.elevationAt(x,y)
    if not elevation or elevation==0 or elevation==15 then
      if not area or area.current then
        local p=self:player()
        return p.currentElevation or p.elevation or 3,p.elevation or p.currentElevation or 3
      end
      elevation=3
    end
    return elevation,elevation
  end
  function A:party() local s=self:save();return s and s.party or {} end
  function A:egg(mon)
    return G==3 and native('pokemon').isEgg(mon) or mon.egg==true or mon.isEgg==true or mon.species=='EGG'
  end
  function A:healthy()
    for _,mon in ipairs(self:party()) do if not self:egg(mon) and (tonumber(mon.hp) or 0)>0 then return mon end end
  end
  function A:national(species)
    local form=Forms:resolve(species);if form then return form.national end
    if G==3 then
      local P=native('pokemon')
      if type(species)=='string' and not tonumber(species) then species=P.speciesFromName(species) end
      return species and P.national(tonumber(species))
    end
    local row=mod.game and mod.game.data and mod.game.data.pokemon and mod.game.data.pokemon[species]
    return row and not row.form and row.dex
  end
  function A:species(mon)
    return G==3 and native('pokemon').speciesOf(mon) or mon.species
  end
  function A:ledgeTraversal()
    -- R/B/Y implements ordinary ledges using the same queue as cutscenes.
    -- Exempt only a player-only ledge queue; actual NPC scripts still recall.
    local p,w=self:player(),self:world()
    if G~=1 or not p or not p.ledgeHop or not w then return false end
    for _,move in ipairs(w.scriptMoves or {}) do
      if move.entity~=p or move.inPlace then return false end
    end
    return not (w.textbox or w.choicebox or w.mapSetup or w.engaging
      or w.vm and w.vm.running and w.vm:running())
  end
  function A:storyBusy()
    local p,w=self:player(),self:world()
    if G==3 then
      local vm=native('scripting.space').getVm()
      return vm and vm.isRunning and vm:isRunning() or false
    end
    if not w then return false end
    local ledge=self:ledgeTraversal()
    return w.textbox or w.choicebox or w.mapSetup or w.engaging
      or w.runner and w.runner.isRunning and w.runner:isRunning() and not ledge
      or w.vm and w.vm.running and w.vm:running()
      or #(w.scriptMoves or {})>0 and not ledge or p and p.inputLocked and not ledge or false
  end
  function A:busy()
    if Version.get()~=self.version or not self:mapId() then return true end
    local game=mod.game
    if game and game.mods and game.mods.exports and game.mods.exports.wildfollowers~=mod.exports then return true end
    local p=self:player();if not p then return true end
    local stack=game and game.stack and game.stack.states or {}
    if #stack>0 and (G~=1 or not stack[#stack].isOverworld) then return true end
    if G==3 then
      local R=native('runtime');local F=native('field')
      if game and game.phase and game.phase~='field' then return true end
      if not R.isActive() or not F.running or F.isLocked() or R.uiBusy() then return true end
      for _,name in ipairs({'battle','warp'}) do
        local m=native(name)
        if m.isActive and m.isActive() or m.isBusy and m.isBusy() then return true end
      end
      local space=native('scripting.space');local vm=space.getVm()
      if vm and vm.isRunning and vm:isRunning() then return true end
    else
      local w=self:world()
      if not w or w.transitioning or w.engaging or w.battleActive or w.textbox or w.choicebox or w.mapSetup or w.flyAnim or w.healAnim then return true end
      if w.busy and w:busy() and not self:ledgeTraversal() then return true end
      if w.runner and w.runner.isRunning and w.runner:isRunning() and not self:ledgeTraversal() then return true end
      if w.vm and w.vm.running and w.vm:running() then return true end
    end
    return false
  end
  function A:encountersBlocked(area)
    if self:busy() then return true end
    local s=self:save()
    if s and (s.safari==true or type(s.safari)=='table' and s.safari.active
        or s.safariZone==true or s.bugContest and s.bugContest.active) then return true end
    if G==3 and native('forced_movement').isForced() then return true end
    local map=(area and area.id or self:mapId()):upper()
    if map:find('SAFARI',1,true) or G==3 and (map:find('BATTLE_FRONTIER',1,true)
        or map:find('BATTLE_TOWER',1,true) or map:find('POKEMON_TOWER',1,true)) then return true end
    if G==1 then
      local w,s=self:world(),self:save()
      local ghost=require('src.world.Map').ghostBattles(area and area.def or w.map.def)
      if ghost and not (ghost.unlessItem and s and s.inventory and s.inventory[ghost.unlessItem]) then return true end
    end
    return false
  end
  function A:water(x,y,area)
    if not area then local view,lx,ly=self:connectedCell(x,y);if view then return self:water(lx,ly,view) end end
    if area then
      if x<0 or y<0 or x>=area.width or y>=area.height then return false end
      if G==3 then
        local C=native('collision')
        if area.current then return C.isWater(x,y) end
        return C.isWaterOn and C.isWaterOn(area.def,x,y) or false
      end
      return mapHasWater(area.map) and area.map:isWaterCell(x,y)
    end
    if G==3 then return native('collision').isWater(x,y) end
    local w=self:world();return w and w.map and mapHasWater(w.map) and w.map:isWaterCell(x,y) or false
  end
  function A:grass(x,y,area)
    if not area then local view,lx,ly=self:connectedCell(x,y);if view then return self:grass(lx,ly,view) end end
    if area then
      if x<0 or y<0 or x>=area.width or y>=area.height then return false end
      if G==3 then
        local C=native('collision')
        if area.current and C.isGrass then return C.isGrass(x,y) end
        local l=area.def.midLayout
        local coll=l and l:collAt(x,y)
        if coll==nil then return false end
        coll=coll%256
        return coll==0x10 or coll==0x14 or coll==0x18 or coll==0x1c
      end
      return area.map.isGrassCell and area.map:isGrassCell(x,y) or false
    end
    local w=self:world();local m=w and w.map
    return G<3 and m and m.isGrassCell and m:isGrassCell(x,y) or false
  end
  function A:land(actor,area)
    if G~=3 then return end
    if not area and actor.follower then
      local view,lx,ly=self:connectedCell(actor.cellX,actor.cellY)
      if view then
        local localActor={cellX=lx,cellY=ly,currentElevation=actor.currentElevation,elevation=actor.elevation}
        self:land(localActor,view)
        actor.currentElevation,actor.elevation=localActor.currentElevation,localActor.elevation
        return
      end
    end
    local C=native('collision')
    if type(C.nextElevation)~='function' then return end
    -- Native finish-step semantics can change the bridge layer on arrival.
    local current,draw=C.nextElevation(area and area.def or C._mapDef,actor.currentElevation or 3,
      actor.cellX,actor.cellY,actor.cellX,actor.cellY)
    actor.currentElevation=current
    if draw~=nil then actor.elevation=draw end
  end
  function A:allowed(x,y,kind,from,point,area)
    if not area and from and from.follower then
      local view,lx,ly=self:connectedCell(x,y)
      if view then
        local mover={cellX=from.cellX-view.offsetX,cellY=from.cellY-view.offsetY,
          currentElevation=from.currentElevation,elevation=from.elevation,facing=from.facing}
        return self:allowed(lx,ly,kind,mover,point,view)
      end
    end
    if area and not area.current then
      if x<0 or y<0 or x>=area.width or y>=area.height then return false end
      if self:water(x,y,area)~=(kind=='water') then return false end
      local def=area.def or {}
      for _,warp in ipairs(def.warps or {}) do if tonumber(warp.x)==x and tonumber(warp.y)==y then return false end end
      local objects=def.objects or def.objectEvents or {}
      if G==3 then
        local Space=native('scripting.space')
        local events=Space.bundle and Space.bundle.events and Space.bundle.events[area.id]
        objects=events and (events.objects or events.objectEvents) or objects
      end
      for _,object in ipairs(objects) do
        if tonumber(object.x)==x and tonumber(object.y)==y then return false end
      end
      if G==3 then
        local C=native('collision');local l=def.midLayout
        if not l then return false end
        local P=require('src.core.CollPermissions');local coll=l:collAt(x,y)
        if kind~='water' and (P.isLedge(coll) or not P.isWalkable(coll)) then return false end
        if from and C.directionallyImpassableOn(def,from.cellX,from.cellY,x,y,from.facing) then return false end
        if from and C.elevationMismatchOn(def,from.currentElevation or from.elevation,x,y) then return false end
        local F=native('field');local override=F.metatileOverrideAt and F.metatileOverrideAt(area.id,x,y)
        if override and override.impassable then return false end
        return true
      end
      local m=area.map
      if m:warpAtCell(x,y) then return false end
      return kind=='water' or m:isWalkableCell(x,y)
    end
    if G==3 then
      local C=native('collision')
      if not C.inBounds(x,y) or C.warpAt and C.warpAt(x,y) then return false end
      if self:water(x,y)~=(kind=='water') then return false end
      if from and from.follower and point then
        -- Replay a committed player trail without repeating NPC, directional
        -- and elevation checks. Retain current bounds, warps and real walls.
        return kind=='water' or C.isWalkable(x,y)
      end
      local p=self:player()
      local allowed,reason=C.canEnter(mod.game,x,y,{surfing=kind=='water',elevation=point and (point.currentElevation or point.elevation)
        or from and (from.currentElevation or from.elevation or 3) or area and self:elevations(x,y,area)
        or p.currentElevation or p.elevation or 3,
        fromX=from and from.cellX,fromY=from and from.cellY,dir=from and from.facing})
      if allowed==true then return true end
      return false
    end
    local w=self:world();local m=w and w.map
    if not m or not m:inBounds(x,y) then return false end
    local warp=type(m.warpAtCell)=='function' and m:warpAtCell(x,y)
      or type(m.warpAt)=='function' and m:warpAt(x,y)
    if warp then return false end
    if self:water(x,y)~=(kind=='water') then return false end
    if kind~='water' and not m:isWalkableCell(x,y) then return false end
    if from and from.follower and point then return true end
    if from and from.cellX and from.cellY and from.facing and not point and G==1 then
      local mover={cellX=from.cellX,cellY=from.cellY,surfing=kind=='water'}
      if not require('src.world.Collision').canMove(m,w.entities or {},mover,from.facing) then return false end
    end
    do
      for _,e in ipairs(w.entities or {}) do
        if not e._wildFollowersRewrite and not e.passable
          and not (e==self:player() and e.moving and from and from.follower and point
            and not (e.targetX==x and e.targetY==y)) and
          (e.cellX==x and e.cellY==y or e.targetX==x and e.targetY==y) then return false end
      end
    end
    return true
  end
  function A:habitat(x,y,kind,area)
    if area and (x<0 or y<0 or x>=area.width or y>=area.height) then return false end
    if G==3 then
      if not area or area.current then return native('encounters').terrainAt(x,y)==kind end
      local l=area.def.midLayout;if not l then return false end
      local E=native('encounters');local types=E._encounterTypes
      local pair=area.def.pair or l.pair;local byPair=types and types[pair]
      if byPair then return byPair[l:midAt(x,y)]==(kind=='water' and 2 or 1) end
      return kind=='water' and self:water(x,y,area) or kind=='land' and self:grass(x,y,area)
    end
    local w=self:world();local m=area and area.map or w and w.map
    if not m or not m:inBounds(x,y) then return false end
    if kind=='water' then return m:isWaterCell(x,y) end
    if G==2 then
      local F=require('src.world.gen2.FieldMoves')
      return F.canEncounterWildMon(m.def and m.def.environment,m:cellCollision(x,y),
        (not area or area.current) and w.noWildEncounters or false)==true
    end
    if m:isGrassCell(x,y) then return true end
    local indoor=mod.game.data.field and mod.game.data.field.indoorEncounters
    return indoor~=nil and m.def~=nil and (tonumber(m.def.index) or -1)>=indoor.firstIndoorMap
      and m.def.tileset~=indoor.excludedTileset
  end
  function A:tables(kind,area)
    local id=area and area.id or self:mapId()
    if G==3 then
      local t=native('encounters').tableFor(id)
      return t and (kind=='water' and t.water or (t.land or t.grass))
    end
    local w=self:world();local d=mod.game and mod.game.data
    if G==1 then
      local t=d and d.encounters and d.encounters[id]
      -- OverworldController passes {grass=encDef.water} to Encounter.roll
      -- while surfing. The generated dataset itself keeps the habitats apart.
      -- Do not fall back to grass on a map without surfing encounters.
      if kind~='water' then return t and t.grass end
      if t and t.water then return t.water end
      -- Inland ponds (such as Route 22) have fishing groups, not surfing
      -- encounters. Display that map's native aquatic pool on water only.
      local rods=require('src.world.FieldDefaults').field(d,'fishing')
      local rod=rods and rods.SUPER_ROD
      local groups=rod and rod.perMap and d.field and d.field[rod.perMap]
      local slots=rod and rod.pool or groups and groups[id]
      if not slots or not slots[1] then return nil end
      self.fishingTables=self.fishingTables or {}
      local table_=self.fishingTables[id]
      if not table_ or table_.slots~=slots or #table_.buckets~=#slots then
        local buckets={}
        for i=1,#slots do buckets[i]=math.floor(i*256/#slots) end
        table_={rate=255,slots=slots,buckets=buckets}
        self.fishingTables[id]=table_
      end
      return table_
    end
    local t=w and w.wildTables and w:wildTables() or w and w.encounterTables and w:encounterTables()
      or d and (d.gen2Encounters or d.encounters)
    local group=t and t[kind=='water' and 'water' or 'grass']
    return group and group[id],t
  end
  function A:choose(kind,rng,source)
    local area,tables=self:tables(kind,source)
    local id=source and source.id or self:mapId()
    if not area then return nil end
    local hit
    if G==2 then
      local E=require('src.battle.gen2.Encounter');local w=self:world()
      local tod=w.tod or w.daytime or 'DAY'
      local rate=kind=='water' and E.waterRate(tables,id) or E.grassRate(tables,id,tod)
      if rate<=0 then return nil end
      local rand=function(n) return rng(0,n-1) end
      hit=kind=='water' and E.waterSlot(tables,id,rand) or E.grassSlot(tables,id,tod,rand)
    else
      local slots=area.slots or area.mons or area
      if (area.rate~=nil and area.rate<=0) or not slots[1] then return nil end
      local weights
      if G==3 then
        local E=native('encounters')._h
        -- Native selection helpers, with no rate/cooldown mutation.
        if E then
          local row=E.pick_slot(slots,kind=='water' and E.WATER_WEIGHTS or E.LAND_WEIGHTS)
          hit=row and {species=row.species or row[1],level=E.level_of(row)}
        end
      else
        local data=mod.game.data
        local buckets=area.buckets or data.constants and data.constants.encounterBuckets
          or require('src.world.FieldDefaults').CONSTANTS.encounterBuckets
        weights={};local last=0
        for i=1,#slots do local threshold=buckets[i] or 256;weights[i]=math.max(0,threshold-last);last=threshold end
      end
      if not hit then
        -- Imported GBA weights are cartridge facts, not species IDs.
        weights=weights or (kind=='water' and {60,30,5,4,1} or {20,20,10,10,10,10,5,5,4,4,1,1})
        local total=0;for i=1,#slots do total=total+(weights[i] or 1) end
        local roll=rng(1,total);local row
        for i,s in ipairs(slots) do roll=roll-(weights[i] or 1);if roll<=0 then row=s;break end end
        if row then
          local lo=tonumber(row.minLevel or row.level or row[2]) or 1
          local hi=tonumber(row.maxLevel or row.level or row[2]) or lo
          if hi<lo then lo,hi=hi,lo end
          hit={species=row.species or row[1],level=rng(lo,hi)}
        end
      end
    end
    if not hit then return nil end
    local peer=mod.find and mod:find('1025dex');local dex=peer and peer.exports
    if dex then
      if G==3 and dex.chooseWildEncounter then
        local _,species,level=dex.chooseWildEncounter(id,kind,hit.level)
        if species then hit={species=species,level=level} end
      elseif G<3 and dex.chooseGBWildEncounter then
        hit=dex.chooseGBWildEncounter(hit,id,kind,rng)
      end
    end
    if not hit or not self:national(hit.species) or not hit.level or hit.level<1 or hit.level>100 then return nil end
    -- Wingull's overworld art does not fit visible land or water wilds.
    -- Filter after Dex substitution, using National identity across games.
    -- Native battle encounters and party followers remain available.
    if self:national(hit.species)==278 then return nil end
    -- Tandemaus's supplied overworld art is oversized. Keep it available as
    -- an exceptionally rare visible spawn without changing encounter battles
    -- or party companions. National identity covers every cartridge mapping.
    if self:national(hit.species)==924 and rng(1,1000)~=1 then return nil end
    if G==2 and hit.species=='UNOWN' then
      local w=self:world();local U=require('src.core.gen2.Unown')
      if not w.unownUnlockFlags or not U.anyUnlocked(w:unownUnlockFlags()) then return nil end
    end
    return hit
  end
  function A:repelled(level)
    local s=self:save();if not s then return false end
    local steps=tonumber(s.repelSteps) or 0
    if G==3 then steps=tonumber(native('field_semantics').getVar(s,'repelSteps')) or steps end
    local lead=G==1 and self:party()[1] or self:healthy()
    return steps>0 and lead~=nil and level<(tonumber(lead.level) or 0)
  end
  function A:start(hit)
    if self:encountersBlocked() or not self:healthy() or self:repelled(hit.level) then return false end
    if G==3 then
      return native('battle_bridge').startWild(mod,mod.game,{species=hit.species,level=hit.level},
        {__completeDexExact=true})==true
    elseif G==2 then
      local w=self:world();local Mon=require('src.battle.gen2.Mon')
      local opts={}
      if hit.species=='UNOWN' then
        local U=require('src.core.gen2.Unown');local flags=w:unownUnlockFlags()
        if not U.anyUnlocked(flags) then return false end
        opts.dvs=U.wildDVs(flags,Mon.randomDVs)
      end
      local mon=Mon.new(mod.game.data,hit.species,hit.level,opts)
      if not mon then return false end
      return w:startBattle({wild=mon},function() end)~=false
    end
    return mod.world:startWildBattle(hit.species,hit.level)==true
  end
  return A
end
