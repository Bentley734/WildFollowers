-- Map coordinate translation for a line crossing area connections.
local M={}
local function worldOffset(from,to,world)
  local a,b
  for _,entry in ipairs(world or {}) do
    if entry.id==from then a=entry elseif entry.id==to then b=entry end
  end
  if a and b then return ((a.ox or 0)-(b.ox or 0))*16,((a.oy or 0)-(b.oy or 0))*16 end
end

function M.offset(from,to,world,maps,root)
  local dx,dy=worldOffset(from,to,world)
  if dx then return dx,dy end
  for _,entry in ipairs(world or {}) do
    if root==from and entry.id==to then return -(entry.ox or 0)*16,-(entry.oy or 0)*16 end
    if root==to and entry.id==from then return (entry.ox or 0)*16,(entry.oy or 0)*16 end
  end
  local ok,C=pcall(require,'src.core.game3.connections')
  if not ok then return nil end
  local a,b=maps and maps[from],maps and maps[to]
  if not a or not b then return nil end
  local aw,ah=C.sizeOf(a);local bw,bh=C.sizeOf(b)
  for _,conn in ipairs(C.each(a)) do
    if conn.map==to then
      local off=tonumber(conn.offset) or 0
      if conn.dir=='north' then return -off*16,bh*16
      elseif conn.dir=='south' then return -off*16,-ah*16
      elseif conn.dir=='west' then return bw*16,-off*16
      elseif conn.dir=='east' then return -aw*16,-off*16 end
    end
  end
end

return M
