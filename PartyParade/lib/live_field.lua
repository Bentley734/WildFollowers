-- Keep mod actors alive when the engine skips Field.update for an open menu.
-- Engines that already update the field behind menus must not tick twice.
return function(E,tick)
  local function optional(path)
    local ok,value=pcall(require,path)
    return ok and type(value)=='table' and value or nil
  end
  local Hud=optional('src.ui.game3.hud')
  local Battle=optional('src.core.game3.battle')
  local Fade=optional('src.ui.game3.fade')
  local Choice=optional('src.ui.game3.choice')
  local serviced=false
  function E.menuOpen()
    return Hud and Hud.isMenuOpen and Hud.isMenuOpen() or false
  end
  local function backgroundAllowed()
    if E.Runtime.active==false or not E.Runtime.getSession() or not E.Field.running
      or not E.menuOpen() or E.controlsLocked() then return false end
    if Battle and Battle.isActive and Battle.isActive() then return false end
    if Fade and Fade.isActive and Fade.isActive() then return false end
    if E.Message and E.Message.isOpen and E.Message.isOpen() then return false end
    if Choice and Choice.active then return false end
    if Hud and Hud._waitButton then return false end
    return true
  end
  local rawField=E.Field.update
  E.Field.update=function(dt)
    local result=rawField(dt)
    serviced=true
    tick(dt)
    return result
  end
  if type(E.Runtime.update)=='function' then
    local rawRuntime=E.Runtime.update
    E.Runtime.update=function(dt)
      serviced=false
      local result=rawRuntime(dt)
      if not serviced and backgroundAllowed() then
        E.menuBackground=true
        local ok,err=pcall(tick,dt)
        E.menuBackground=false
        if not ok then error(err,0) end
      end
      return result
    end
  end
end
