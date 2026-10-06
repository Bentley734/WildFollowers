-- Stationary sleep pose only. Native following continues to own every tile.
return function(E, heads)
  local M = {}
  local STAGGER, LIFE, GAP = 15, 144, 48
  local floor, cos, pi = math.floor, math.cos, math.pi
  local function round(n) return floor(n + 0.5) end

  local function eligible(a)
    if not E.Idle.enabled('OW_FOLLOWERS_DOZE',a) or not E.C.OW_FOLLOWERS_ENABLED
        or not a.active or a.invisible or a.moving or a.independent or a.ballGfx or a.affine
        or a.emote >= 0 or a.tType or E.Player.moving or E.Player.jumping
        or E.controlsLocked() or not E.followerVisible() then return false end
    local core = a.nativeCore
    return core and not core.talking()
      and (a.act == core.A.NONE or a.act == core.A.IN_PLACE)
  end
  function M.cancel(a) a.dozeTicks = nil end
  function M.tick(a)
    if eligible(a) then a.dozeTicks = (a.dozeTicks or 0) + 1
    else M.cancel(a) end
  end
  function M.age(a)
    if E.Social then local t=E.Social.sleepAge(a);if t then return t end end
    if not a.dozeTicks or not eligible(a) then return nil end
    local t = a.dozeTicks - E.Idle.delay() - ((a.followSlot or 1) - 1) * STAGGER
    if t >= 0 then return t end
  end
  function M.sleeping(a) return M.age(a) ~= nil end
  function M.offset(a)
    local t = M.age(a) or 0
    return -round((0.5 - 0.5 * cos(t * 2 * pi / LIFE)) * math.min(1, t / 18))
  end
  function M.effect(a, index)
    local t = M.age(a)
    if not t or index < 1 or index > 3 then return nil end
    -- Emit three staggered Zs, then let the whole batch expire before
    -- the first slot can emit again.
    local cycle = LIFE + 2 * GAP
    local phase = t % cycle - (index - 1) * GAP
    if phase < 0 or phase >= LIFE then return nil end
    -- Fixed 65% transparency for both the white Z and its blue outline.
    local alpha = math.min(1, phase / 12, (LIFE - phase) / 18) * 0.35
    if alpha <= 0 then return nil end
    -- Continue left/right alternation across the three-Z batches.
    local emission = index - 1 + floor(t / cycle) * 3
    return emission % 2 == 0 and -3 or 3, -round(phase * 24 / LIFE), alpha
  end

  -- A readable 4x5 Z with a one-pixel outline (6x7 overall). The outline
  -- follows cardinal pixel edges, avoiding a bulky halo at the corners.
  local glyph = {{0,0,4,1},{3,1,1,1},{2,2,1,1},{1,3,1,1},{0,4,4,1}}
  local outline = {{0,-1,4,1},{-1,0,6,1},{0,1,5,1},{1,2,3,1},
    {0,3,4,1},{-1,4,6,1},{0,5,4,1}}

  -- Draw after the actor/grass passes, outside the palette shader. A redraw
  -- over player grass must not enqueue a second set of Zs.
  local queued, count = {}, 0
  for i = 1, E.FOLLOWER_SLOTS do queued[i] = {} end
  function M.clearQueue() count = 0 end
  function M.queue(a, sx, sy, frame)
    if E.redrawing or count >= #queued or not M.sleeping(a) then return end
    count = count + 1
    local q = queued[count]
    q.actor, q.x, q.y, q.frame = a, sx, sy, frame
  end
  function M.flush()
    if count == 0 then return end
    local G = love.graphics
    local shader = G.getShader()
    G.setShader()
    for i = 1, count do
      local q = queued[i]
      local a = q.actor
      local height = E.Data.ATLAS.sheets[(a.sheet - 1) * 6 + 4]
      local head = heads[a.sheet]
      local top = head and head[floor((q.frame or 0) / 2) + 1] or 0
      local spriteTop = E.SpriteSets.head(a, q.frame)
      local ox, oy = q.x + 6, q.y + (spriteTop or (16 - height + top)) - 8
      for z = 1, 3 do
        local x, y, alpha = M.effect(a, z)
        if x then
          G.setColor(0.08, 0.16, 0.34, alpha)
          for _, r in ipairs(outline) do
            G.rectangle('fill', ox + x + r[1], oy + y + r[2], r[3], r[4])
          end
          G.setColor(1, 1, 1, alpha)
          for _, r in ipairs(glyph) do
            G.rectangle('fill', ox + x + r[1], oy + y + r[2], r[3], r[4])
          end
        end
      end
    end
    G.setShader(shader)
    G.setColor(1, 1, 1, 1)
    M.clearQueue()
  end
  return M
end
