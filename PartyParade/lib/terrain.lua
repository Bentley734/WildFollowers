-- Canonical Game3 behavior IDs; Emerald raw bytes are translated by the engine.
local M={}
local ok,MB=pcall(require,"src.core.game3.mb")
local function id(name,fallback) return ok and MB.id and MB.id(name) or fallback end
local TALL=id("TALL_GRASS",2)
local LONG=id("LONG_GRASS",0x103)
local ASH=id("ASHGRASS",0x124)
local SAND=id("DEEP_SAND",0x106)
local SEAWEED=id("SEAWEED",0x22)
local SEAWEED_NO_SURF=id("SEAWEED_NO_SURFACING",0x12a)
function M.isGrass(b) return b==TALL or b==0xd1 or b==LONG or b==ASH end
function M.isEncounterLand(mapId,b)
  return M.isGrass(b) or (tostring(mapId or ""):match("^EM_")~=nil and b==SAND)
end
function M.isWater(def,b,ordinary,walkable)
  if tonumber(def and def.mapType)==5 then
    return (ordinary==true or walkable~=false) and (b==SEAWEED or b==SEAWEED_NO_SURF)
  end
  return ordinary==true
end
function M.followerCellAllowed(player,collision,x,y)
  local water=collision.isWater(x,y)
  if player.underwater or tonumber(collision._mapDef and collision._mapDef.mapType)==5 then
    return water or collision.isWalkable(x,y)
  end
  if player.surfing then return water end
  return not water and (collision.isWalkable(x,y) or collision.isGrass(x,y))
end
function M.grassSheet(b,effects)
  local name=b==LONG and "long_grass" or (b==TALL or b==0xd1) and "tall_grass" or nil
  if not name then return nil end
  return effects.loadSheet(name,16,16,5),name
end
function M.grassFrame(effects,name,ticks,fallback)
  local obj=name and effects.manifestObject and effects.manifestObject(name)
  local seq=obj and obj.anims and obj.anims[1]
  if not seq then return fallback or 0 end
  local last=0
  for _,command in ipairs(seq) do
    if command[1]=="frame" then
      last=command[2]
      if ticks~=nil then
        local duration=command[3] or 1
        if ticks<duration then return last end
        ticks=ticks-duration
      end
    end
  end
  return last
end
function M.isEmerald() return require("src.core.GameVersion").get()=="emerald" end
function M.behaviorAt(collision,map,x,y)
  local b=collision.behavior and collision.behavior(x,y)
  if b~=nil then return b end
  if collision.behaviorOn then
    for _,entry in ipairs(map.world or {}) do
      local l=entry.def and entry.def.midLayout
      local nx,ny=x-(entry.ox or 0),y-(entry.oy or 0)
      if l and nx>=0 and ny>=0 and nx<l.width and ny<l.height then
        return collision.behaviorOn(entry.def,nx,ny)
      end
    end
  end
end
return M
