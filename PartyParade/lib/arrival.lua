-- Dialogue locks field input, but does not make a settled arrival unsafe.
-- Wait for actual scene transitions and scripted movement, not the whole VM.
return function(E)
 local function module(path)
  local ok,value=pcall(require,path)
  return ok and value or nil
 end
 local warp=E.Warp or module('src.core.game3.warp')
 local transitions={}
 for _,path in ipairs({'src.ui.game3.fade','src.ui.game3.map_preview_screen','src.core.game3.battle'})do
  local value=module(path);if value then transitions[#transitions+1]=value end
 end
 local forced=E.Forced or module('src.core.game3.forced_movement')
 local space=module('src.core.game3.scripting.space')
 return function()
  local p=E.Player
  if not p or p.visible==false or p.hidden==true
      or p.isVisible and not p.isVisible() then return true end
  if p.moving or p.jumping then return true end
  if warp and (warp._busy or warp.isBusy and warp.isBusy()) then return true end
  for _,m in ipairs(transitions) do
   if m and m.isActive and m.isActive() then return true end
  end
  if forced and forced.isForced and forced.isForced() then return true end
  local moves=space and space.vm and space.vm.ctx and space.vm.ctx.activeMoves
  for _,move in pairs(moves or {}) do if not move.done then return true end end
  return false
 end
end
