-- Follower Pokemon: pool slot 1 (E.FOLLOWER); pret sprite state lives on the actor.
local Follower = {}
local E, C, A, D, V, Player, Collision
local actor
local band, rshift, floor = bit.band, bit.rshift, math.floor

-- movement actions (< A_EXIT_POKEBALL = walk-type; A_DELAY / A_FACE are script-only)
local A_NONE, A_WALK, A_JUMP, A_WALK_IN_PLACE, A_EXIT_POKEBALL, A_ENTER_POKEBALL = 0, 1, 2, 3, 4, 5
local A_DELAY, A_FACE = 6, 7
-- COPY_MOVE_* the follower cares about (movement_type_func_tables.h:420)
local COPY_NONE, COPY_FACE, COPY_WALK, COPY_JUMP2 = 0, 1, 2, 3
-- jump types (event_object_movement.c:7334) / JUMP_DISTANCE_*
local JUMP_TYPE_HIGH, JUMP_TYPE_NORMAL, JUMP_TYPE_FAST, JUMP_TYPE_FASTER = 0, 2, 3, 4
local JUMP_DISTANCE_IN_PLACE, JUMP_DISTANCE_NORMAL, JUMP_DISTANCE_FAR = 0, 1, 2
-- enum TransformType (event_object_movement.h:61)
local TRANSFORM_TYPE_RANDOM_WILD, TRANSFORM_TYPE_WEATHER = 2, 3

local DX = { up = 0, down = 0, left = -1, right = 1 }
local DY = { up = -1, down = 1, left = 0, right = 0 }
local OPPOSITE = { up = "down", down = "up", left = "right", right = "left" }

-- src/event_object_movement.c:10772 sJumpY_High / :10782 sJumpY_Normal
local JUMP_Y_HIGH = { [0] = -4, -6, -8, -10, -11, -12, -12, -12, -11, -10, -9, -8, -6, -4, 0, 0 }
local JUMP_Y_NORMAL = { [0] = -2, -4, -6, -8, -9, -10, -10, -10, -9, -8, -6, -5, -3, -2, 0, 0 }
local JUMP_Y_LOW = { [0] = 0, -2, -3, -4, -5, -6, -6, -6, -5, -5, -4, -3, -2, 0, 0, 0 }
local JUMP_Y_TABLE = { [0] = JUMP_Y_HIGH, JUMP_Y_LOW, JUMP_Y_NORMAL } -- sJumpYTable

-- Anims.  sAnimTable_Following / _Asym (object_event_anims.h:1246-1297).
-- Flat {frame, duration, hflip(0/1), ...}; JUMP(0) = loop.  Built once.
local FACE_FRAME = { down = 0, up = 2, left = 4, right = 4 }
local ANIMS = { [false] = {}, [true] = {} } -- [asym][kind][dir]

local function buildAnims(asym)
  local T = { face = {}, go = {}, goFast = {}, enter = {}, exit = {}, exitFast = {} }
  for dir, f in pairs(FACE_FRAME) do
    local east = dir == "right"
    local fl = (east and not asym) and 1 or 0
    if east and asym then f = 6 end
    local f2 = f + 1
    T.face[dir] = { f, 16, fl }
    T.go[dir] = { f, 6, fl, f2, 6, fl, f2, 6, fl, f, 6, fl }
    T.goFast[dir] = { f, 4, fl, f2, 4, fl, f2, 4, fl, f, 4, fl }
    -- sAnim_Enter*: face frame, then ball frames 4..0 (gfx swaps mid-anim)
    T.enter[dir] = { f, 8, fl, 4, 1, 0, 3, 1, 0, 2, 1, 0, 1, 1, 0, 0, 1, 0, 0, 3, 0 }
    -- sAnim_ExitPokeball*: ball frames 0..4, then face frame
    T.exit[dir] = { 0, 1, fl, 0, 3, 0, 0, 1, 0, 1, 1, 0, 2, 1, 0, 3, 1, 0, 4, 1, 0, f, 8, fl }
    T.exitFast[dir] = { 0, 1, fl, 1, 1, 0, 2, 1, 0, 3, 1, 0, 4, 1, 0, f, 2, fl, f, 1, fl }
  end
  return T
end
ANIMS[false], ANIMS[true] = buildAnims(false), buildAnims(true)
Follower.ANIMS = ANIMS -- OWEs use the same OW mon tables

-- frame + hflip of `anim` at tick t (loops)
local function animFrame(anim, t)
  local total = 0
  for i = 2, #anim, 3 do total = total + anim[i] end
  t = t % total
  for i = 1, #anim, 3 do
    t = t - anim[i + 1]
    if t < 0 then return anim[i], anim[i + 2] == 1 end
  end
  return anim[1], anim[3] == 1
end
Follower.animFrame = animFrame

-- StartSpriteAnim / SetStepAnimHandleAlternation: restarting the same anim
-- keeps its phase (the step alternation), a new anim starts at 0
local function setAnim(anim)
  if actor.anim ~= anim then
    actor.anim = anim
    actor.animT = 0
  end
end

local function anims() return ANIMS[actor.asym == true] end

-- Graphics.  FollowerSetGraphics / ObjectEventSetPokeballGfx.
-- FR item ids (items.h ITEM_MASTER_BALL..ITEM_PREMIER_BALL) -> atlas ball
local BALL_BY_ITEM = { "MASTER", "ULTRA", "GREAT", "POKE", "SAFARI", "NET",
  "DIVE", "NEST", "REPEAT", "TIMER", "LUXURY", "PREMIER" }

-- RefreshFollowerGraphics: show `species` with the follower's shiny/female
local function refreshFollowerGraphics(species)
  local sheet, row = E.Gfx.sheetFor(species, actor.female, actor.shiny)
  if not sheet then return end
  actor.sheet, actor.palRow = sheet, row
  actor.asym = A.asym[species] == 1
  local b = (sheet - 1) * 6
  actor.large = A.sheets[b + 3] > 32 or A.sheets[b + 4] > 32
end

-- species/shiny/female = the lead mon (what UpdateFollowingPokemon compares);
-- owSpecies = OW_SPECIES(objectEvent), which a weather form changes
local function followerSetGraphics(species, shiny, female)
  actor.species, actor.shiny, actor.female = species, shiny, female
  actor.owSpecies = species
  refreshFollowerGraphics(species)
  actor.ballGfx = false
end

local function objectEventSetPokeballGfx(mon)
  local name = "POKE"
  if C.OW_FOLLOWERS_POKEBALLS and mon then
    name = BALL_BY_ITEM[tonumber(mon.pokeball) or 4] or "STRANGE"
  end
  local s = A.balls[name] or A.balls.POKE
  actor.ballSheet, actor.ballPalRow = s, A.sheets[(s - 1) * 6 + 6]
  actor.ballGfx = true
end

local function moveToMapCoords(x, y)
  actor.cellX, actor.cellY = x, y
  actor.targetX, actor.targetY = x, y
  actor.px, actor.py = x * 16, y * 16
  actor.moving = false
end

local function clearMovement()
  actor.singleMovementActive = false
  actor.facingDirectionLocked = false
  actor.act, actor.actStep, actor.actT = A_NONE, 0, 0
end

local function directionToFace(x, y, tx, ty)
  if x > tx then return "left" end
  if x < tx then return "right" end
  if y > ty then return "up" end
  return "down"
end

-- SetObjectEventDirection: facing follows unless lock_facing_direction
local function setDirection(dir)
  if not actor.facingDirectionLocked then actor.facing = dir end
end

-- ShiftObjectEventCoords + elevation (event_object_movement.c:8400)
local function beginMove(dir, tiles)
  setDirection(dir)
  actor.moveDir = dir
  actor.targetX = actor.cellX + DX[dir] * tiles
  actor.targetY = actor.cellY + DY[dir] * tiles
  if tiles == 0 then return end
  actor.moving = true
  local cur = Collision.nextElevation(Collision._mapDef, actor.currentElevation,
    actor.targetX, actor.targetY, actor.cellX, actor.cellY)
  actor.currentElevation = cur
end

local function endMove()
  actor.cellX, actor.cellY = actor.targetX, actor.targetY
  actor.px, actor.py = actor.cellX * 16, actor.cellY * 16
  actor.moving = false
end

-- InitMovementNormal (walk_* / walk_fast_* / walk_faster_* / slide_*):
-- step anim of the (possibly locked) facing direction
local function startWalk(dir, frames)
  beginMove(dir, 1)
  actor.act, actor.actStep, actor.actT = A_WALK, 1, 0
  actor.actDur = frames
  setAnim(frames <= 8 and anims().goFast[actor.facing] or anims().go[actor.facing])
end

-- InitJumpRegular (distance 0 = in place, 1 = jump_*, 2 = ledge)
local function startJump(dir, jumpType, distance)
  distance = distance or JUMP_DISTANCE_FAR
  beginMove(dir, distance)
  actor.act, actor.actStep, actor.actT = A_JUMP, 1, 0
  actor.jumpType, actor.jumpDist = jumpType, distance
  setAnim(anims().go[actor.facing])
end

-- InitMoveInPlace(dir, anim, duration): sprite->data[3] = duration
local function startWalkInPlace(dir, duration, fast)
  setDirection(dir)
  actor.act, actor.actStep, actor.actT = A_WALK_IN_PLACE, 1, 0
  actor.actDur = duration or 16
  actor.slowAnim = (duration == 32)
  setAnim(fast and anims().goFast[actor.facing] or anims().go[actor.facing])
end

-- FaceDirection: face anim, done in Step0
local function faceDirection(dir)
  setDirection(dir)
  setAnim(anims().face[actor.facing])
end

-- Movement actions.  Each returns true when finished (sActionFuncId done).
-- MovementAction_ExitPokeball_Step0/1 (:7716-7790)
local function exitPokeballStep0()
  local dir = Player.facing
  actor.invisible = false
  actor.facing = dir
  if Player.running then
    -- player is dashing: the Pokemon comes out faster
    actor.anim, actor.animT = anims().exitFast[dir], 0
    actor.duration, actor.speedFlip = 8, 0
  else
    actor.anim, actor.animT = anims().exit[dir], 0
    actor.duration, actor.speedFlip = 16, 1
  end
  objectEventSetPokeballGfx(Follower.firstLiveMon())
  actor.affine = false
end

local function exitPokeballStep1()
  local animStepFrame = (actor.speedFlip == 1) and 7 or 3
  actor.duration = actor.duration - 1
  if actor.duration == 0 then
    actor.actStep = 2
    return true
  elseif actor.duration == animStepFrame then
    -- mon graphics, white palette, affine grow (sAffineAnim_PokeballExit)
    actor.ballGfx = false
    actor.white = 1
    actor.affine, actor.affineT, actor.affineEnter = true, 0, false
  elseif actor.duration == rshift(animStepFrame, 1) then
    actor.affine = false
    actor.white = 0
  end
  return false
end

-- MovementAction_EnterPokeball_Step0/1/2 (:7792-7858)
local function enterPokeballStep0()
  local dir = actor.facing
  actor.anim, actor.animT = anims().enter[dir], 0
  actor.duration = 16
  Follower.endTransformEffect()
end

local function enterPokeballStep1()
  actor.duration = actor.duration - 1
  if actor.duration == 0 then
    actor.actStep = 2
    return false
  elseif actor.duration == 11 then
    actor.white = 1
    actor.affine, actor.affineT, actor.affineEnter = true, 0, true
  elseif actor.duration == 7 then
    actor.affine = false
    actor.white = 0
    objectEventSetPokeballGfx(Follower.firstLiveMon())
  end
  return false
end

local function enterPokeballStep2()
  actor.ballGfx = false
  actor.invisible = true
  actor.typeFunc = 0
  actor.speedFlip = 0
  return true
end

-- NpcTakeStep / UpdateWalkSlowAnim / DoJumpSpriteMovement
local function stepAction()
  local act = actor.act
  if act == A_EXIT_POKEBALL then
    if actor.actStep == 0 then exitPokeballStep0(); actor.actStep = 1 end
    return exitPokeballStep1()
  elseif act == A_ENTER_POKEBALL then
    if actor.actStep == 0 then enterPokeballStep0(); actor.actStep = 1 end
    if actor.actStep == 2 then return enterPokeballStep2() end
    return enterPokeballStep1()
  end
  local t = actor.actT + 1
  actor.actT = t
  if act == A_WALK then
    local dur = actor.actDur
    local px
    if dur == 31 then
      px = rshift(t + 1, 1)                -- walk slow: Step1 on even timer
      if px > 16 then px = 16 end
    else
      px = floor(t * 16 / dur)
    end
    actor.px = actor.cellX * 16 + DX[actor.moveDir] * px
    actor.py = actor.cellY * 16 + DY[actor.moveDir] * px
    if t >= dur then endMove(); return true end
  elseif act == A_JUMP then
    -- DoJumpSpriteMovement: sTimer before this frame is st; FASTER adds 4
    -- per frame (Step1+Step3), FAST 2 (Step1 twice), others 1 (Step1)
    local jt, dist = actor.jumpType, actor.jumpDist
    local shift = (dist == JUMP_DISTANCE_FAR) and 1 or 0
    local total = (dist == JUMP_DISTANCE_FAR) and 32 or 16
    local inc, px, ytab = 1, t, JUMP_Y_TABLE[jt] or JUMP_Y_HIGH
    if jt == JUMP_TYPE_FASTER then
      inc, ytab = 4, JUMP_Y_NORMAL
      px = (dist == JUMP_DISTANCE_IN_PLACE) and 3 * t or 4 * t
    elseif jt == JUMP_TYPE_FAST then
      inc, ytab = 2, JUMP_Y_NORMAL
      px = (dist == JUMP_DISTANCE_IN_PLACE) and t or 2 * t
    elseif dist == JUMP_DISTANCE_IN_PLACE then
      px = 0
    end
    local st = inc * (t - 1)
    actor.y2 = ytab[rshift(st, shift)] or 0
    if dist == JUMP_DISTANCE_IN_PLACE then px = 0 end
    actor.px = actor.cellX * 16 + DX[actor.moveDir] * px
    actor.py = actor.cellY * 16 + DY[actor.moveDir] * px
    if st + inc >= total then
      actor.y2 = 0
      if dist ~= JUMP_DISTANCE_IN_PLACE then endMove() end
      return true
    end
  elseif act == A_WALK_IN_PLACE then
    actor.duration = actor.actDur - t -- sprite->data[3] countdown
    if t >= actor.actDur then return true end
  elseif act == A_DELAY then
    -- MovementAction_Delay_Step1: --sprite->data[3] == 0
    if t >= actor.actDur then return true end
  elseif act == A_FACE then
    return true
  end
  return false
end

-- Party / spawn.  GetFirstLiveMon, UpdateFollowingPokemon.
function Follower.firstLiveMon()
  local party = E.party()
  if not party then return nil end
  for i = 1, 6 do
    local mon = party[i]
    if mon and (tonumber(mon.species or mon.speciesId) or 0) ~= 0 then
      local vs, vl, vm = V.vars.allowedSpecies, V.vars.allowedMetLvl, V.vars.allowedMetLoc
      if (vs and E.Pokemon.speciesOf(mon) ~= E.varGet(vs))
          or (vl and (tonumber(mon.metLevel) or 0) ~= E.varGet(vl))
          or (vm and (tonumber(mon.metLocation) or 0) ~= E.varGet(vm)) then
        -- OW_FOLLOWERS_ALLOWED_SPECIES / MET_LVL / MET_LOC: skip this mon
      elseif (tonumber(mon.hp) or 0) > 0 and not E.Pokemon.isEgg(mon) then
        return mon
      end
    end
  end
  return nil
end

local swap = nil -- { species, shiny, female } waiting on the ball swap

local function removeFollowingPokemon()
  swap = nil
  Follower.stopIndependent()
  E.Doze.cancel(actor);E.Idle.cancel(actor)
  if not actor.active then return end
  actor.active = false
  actor.moving = false
  clearMovement()
end
Follower.remove = removeFollowingPokemon

function Follower.update()
  if not C.OW_FOLLOWERS_ENABLED or E.flagGet(V.flags.followersDisabled) then
    return removeFollowingPokemon()
  end
  local species, shiny, female = E.monInfo(Follower.firstLiveMon())
  if not species then return removeFollowingPokemon() end
  local sheet = E.Gfx.sheetFor(species, female, shiny)
  if not sheet then return removeFollowingPokemon() end
  local b = (sheet - 1) * 6
  if E.mapIndoor() and (A.sheets[b + 3] > 32 or A.sheets[b + 4] > 32) then
    return removeFollowingPokemon()
  end
  if E.flagGet(V.flags.hideFollower) then return removeFollowingPokemon() end

  local px, py = E.playerCur()
  if not actor.active then
    -- SpawnSpecialObjectEvent(MOVEMENT_TYPE_FOLLOW_PLAYER), invisible
    actor.active = true
    actor.visible = true
    moveToMapCoords(px, py)
    actor.currentElevation = Player.currentElevation or 3
    actor.elevation = actor.currentElevation
    actor.facing = Player.facing
    actor.typeFunc = 0
    clearMovement()
    actor.y2, actor.white, actor.affine = 0, 0, false
    actor.anim, actor.animT = nil, 0
    followerSetGraphics(species, shiny, female)
    actor.invisible = true
  elseif species ~= actor.species or shiny ~= actor.shiny or female ~= actor.female then
    if not actor.invisible then
      swap = { species, shiny, female }
      return
    end
    swap = nil
    moveToMapCoords(px, py)
    followerSetGraphics(species, shiny, female)
    actor.invisible = true
  end
end

-- MovementType_FollowPlayer (:5688-5900)
local copyMove = COPY_NONE -- PlayerGetCopyableMovement

local function updateMonMoveInPlace()
  -- Only the automatic standing routine is optional. Scripted interactions,
  -- walking, ledge jumps and Poke Ball actions keep their native animations.
  if not C.OW_FOLLOWERS_IDLE_WALK or E.Doze.sleeping(actor) then
    if actor.act == A_WALK_IN_PLACE then clearMovement() end
    faceDirection(actor.facing)
    actor.y2 = 0
    return false
  end
  if not actor.singleMovementActive then
    startWalkInPlace(actor.facing)
    actor.singleMovementActive = true
    return true
  elseif stepAction() then
    actor.singleMovementActive = false
    actor.act = A_NONE
  elseif C.OW_FOLLOWERS_BOBBING and band(actor.duration, 7) == 2 then
    actor.y2 = (actor.y2 == 0) and -1 or 0
  end
  return false
end

local function followablePlayerMovement_Idle()
  if updateMonMoveInPlace() then
    actor.typeFunc = 1
    return true
  end
  Follower.updateTransformEffect()
  return false
end

local function followablePlayerMovement_Step()
  local targetX, targetY = E.playerPrev()
  local x, y = E.playerCur()
  -- don't move on player collision or if not visible
  if (x == targetX and y == targetY) or not E.followerVisible() then return false end

  x, y = actor.cellX, actor.cellY
  clearMovement()

  if actor.invisible then
    -- exit the ball, unless the player is jumping or moving via script
    if copyMove == COPY_JUMP2 or E.controlsLocked() then
      actor.typeFunc = 0
      return false
    end
    moveToMapCoords(targetX, targetY)
    actor.act, actor.actStep = A_EXIT_POKEBALL, 0
    actor.singleMovementActive = true
    actor.typeFunc = 2
    if C.OW_FOLLOWERS_BOBBING then actor.y2 = 0 end
    return true
  elseif x == targetX and y == targetY then
    return false -- already in the player's last position
  end

  local direction = directionToFace(x, y, targetX, targetY)
  -- no script sidestep/backstep mirroring: game3 has no movementDirection (D10)
  if Collision.ledgeLanding(E.Field._game, x, y, direction) then
    -- InitJumpRegular: match the player's speed unless the player jumps too
    local jt = JUMP_TYPE_HIGH
    if copyMove ~= COPY_JUMP2 then
      jt = Player.running and JUMP_TYPE_FASTER or JUMP_TYPE_FAST
    end
    startJump(direction, jt)
  elseif copyMove == COPY_JUMP2 then
    startWalk(direction, 31)         -- GetWalkSlowMovementAction
  elseif Player.running or (C.OW_FOLLOWERS_RUN_TO_CATCH_UP~=false
      and math.abs(actor.cellX-Player.cellX)+math.abs(actor.cellY-Player.cellY)>1) then
    startWalk(direction, 8)          -- MOVE_SPEED_FAST_1
  else
    startWalk(direction, 16)
    if C.OW_FOLLOWERS_BOBBING then actor.y2 = -1 end
  end
  -- (WALK_SLOW_STAIRS: no sideways stairs in FR; PARITY D10)
  actor.singleMovementActive = true
  actor.typeFunc = 2
  return true
end

local function followPlayer_Shadow()
  clearMovement()
  local px, py = E.playerCur()
  if not E.followerVisible() then
    actor.invisible = true
    moveToMapCoords(px, py)
    return false
  end
  -- move to the player so the invisible follower can't be talked to
  if actor.invisible then moveToMapCoords(px, py) end
  actor.typeFunc = 1
  return true
end

local function followPlayer_Active()
  if not E.followerVisible() then
    if actor.invisible then
      actor.typeFunc = 0
      return false
    end
    clearMovement()
    actor.act, actor.actStep = A_ENTER_POKEBALL, 0
    actor.singleMovementActive = true
    actor.typeFunc = 2
    return true
  end
  if copyMove == COPY_WALK or copyMove == COPY_JUMP2 then
    return followablePlayerMovement_Step()
  end
  return followablePlayerMovement_Idle()
end

local function followPlayer_Moving()
  if stepAction() then
    actor.act, actor.actStep = A_NONE, 0
    actor.singleMovementActive = false
    actor.facingDirectionLocked = false
    if actor.typeFunc ~= 0 then actor.typeFunc = 1 end
  elseif actor.act < A_EXIT_POKEBALL then
    Follower.updateTransformEffect()
    if C.OW_FOLLOWERS_BOBBING and actor.act == A_WALK and band(actor.actT, 7) == 2 then
      actor.y2 = (actor.y2 == 0) and -1 or 0
    end
  end
  return false
end

-- movement_type_def: loop while the step function returns TRUE
local function movementType_FollowPlayer()
  for _ = 1, 4 do
    local tf, again = actor.typeFunc
    if tf == 0 then again = followPlayer_Shadow()
    elseif tf == 1 then again = followPlayer_Active()
    else again = followPlayer_Moving() end
    if not again then return end
  end
end

-- game3 has no COPY_MOVE: a new step is WALK or JUMP2, an idle frame is FACE.
local lastPX, lastPY, lastTX, lastTY = -1, -1, -1, -1
local function updateCopyMove()
  if Player.moving then
    if Player.prevCellX ~= lastPX or Player.prevCellY ~= lastPY
        or Player.targetX ~= lastTX or Player.targetY ~= lastTY then
      lastPX, lastPY, lastTX, lastTY = Player.prevCellX, Player.prevCellY, Player.targetX, Player.targetY
      copyMove = (Player.jumping and not Player.surfHopping and not Player.dismounting)
        and COPY_JUMP2 or COPY_WALK
    end
  else
    lastPX = -1
    copyMove = COPY_FACE
  end
end

-- REG_MOSAIC becomes actor.mosaic, applied by the atlas shader to this sprite only.
local function overworldWeatherSpecies(species)
  local forms = C.OW_FOLLOWERS_WEATHER_FORMS and D.WEATHER_FORMS[species]
  if not forms then return species end
  local weather = E.weather()
  for i = 1, #forms do
    local f = forms[i]
    local w = D.WEATHER[f[2]]
    if w == weather then return f[1] end
    if w == 0 then species = f[1] end -- WEATHER_NONE: default form
  end
  return species
end
Follower.overworldWeatherSpecies = overworldWeatherSpecies

function Follower.endTransformEffect()
  actor.mosaic = 1
  actor.tType, actor.tFrames = nil, 0
  return false
end

local function tryStartFollowerTransformEffect()
  local sp = actor.owSpecies
  if C.OW_FOLLOWERS_WEATHER_FORMS and D.WEATHER_FORMS[sp]
      and sp ~= overworldWeatherSpecies(sp) then
    actor.tType, actor.tFrames = TRANSFORM_TYPE_WEATHER, 0
    E.playSe("SE_M_MINIMIZE")
    return true
  end
  if C.OW_FOLLOWERS_COPY_WILD_PKMN then
    local mon = Follower.firstLiveMon()
    if mon then
      local ok = E.knowsMove(mon, D.MOVE_TRANSFORM)
      if not ok then
        local ab = E.monAbility(mon)
        ok = ab == V.abilities.IMPOSTER or ab == V.abilities.ILLUSION
      end
      if ok and band(E.random(), 0xFFFF) < 18 and E.localWildMon() then
        actor.tType, actor.tFrames = TRANSFORM_TYPE_RANDOM_WILD, 0
        E.playSe("SE_M_MINIMIZE")
        return true
      end
    end
  end
  return false
end

function Follower.updateTransformEffect()
  local ty = actor.tType
  if not ty then return tryStartFollowerTransformEffect() end
  local frames = actor.tFrames
  local stretch
  if frames < 8 then
    stretch = rshift(frames, 1)
  elseif frames < 16 then
    stretch = rshift(16 - frames, 1)
  else
    return Follower.endTransformEffect()
  end
  if frames == 8 then
    if ty == TRANSFORM_TYPE_WEATHER then
      local sp = overworldWeatherSpecies(actor.owSpecies)
      if sp and sp ~= 0 then
        actor.owSpecies = sp
        refreshFollowerGraphics(sp)
      end
    elseif ty == TRANSFORM_TYPE_RANDOM_WILD then
      -- graphicsId is restored after the refresh: only the sprite changes
      local sp = E.localWildMon()
      if sp then refreshFollowerGraphics(sp) end
    end
  end
  actor.mosaic = stretch + 1
  actor.tFrames = frames + 1
  return true
end

-- Emote (FLDEFF_EMOTE: trainer_see.c FldEff_QuestionMarkIcon with an
-- emotion, SetIconSpriteData, SpriteCB_TrainerIcons, sSpriteAnim_Emotes*)
local EMOTE_FRAMES = 85 -- ANIMCMD_FRAME 30 + 25 + 30, then ANIMCMD_END

local function objectEventEmote(emotion)
  actor.emote = emotion % D.FOLLOWER_EMOTION_LENGTH
  actor.emoteT, actor.emoteY, actor.emoteVel = 0, 0, -5
end
Follower.emote = objectEventEmote

local function updateEmote()
  if actor.emote < 0 then return end
  local t = actor.emoteT + 1
  actor.emoteT = t
  if t >= EMOTE_FRAMES then actor.emote = -1; return end -- FieldEffectStop
  actor.emoteY = actor.emoteY + actor.emoteVel
  if actor.emoteY ~= 0 then actor.emoteVel = actor.emoteVel + 1 else actor.emoteVel = 0 end
end

-- Movement lists compile once into { op, dir, n } arrays.
local M_FACE, M_FACE_PLAYER, M_FACE_AWAY, M_LOCK, M_UNLOCK = 1, 2, 3, 4, 5
local M_WALK, M_IN_PLACE, M_JUMP_IN_PLACE, M_JUMP, M_DELAY, M_ENTER_BALL = 6, 7, 8, 9, 10, 11

local function compileMove(name)
  local dir = name:match("_(%a+)$")
  if name == "face_player" then return { M_FACE_PLAYER } end
  if name == "face_away_player" then return { M_FACE_AWAY } end
  if name == "lock_facing_direction" then return { M_LOCK } end
  if name == "unlock_facing_direction" then return { M_UNLOCK } end
  if name == "enter_pokeball" then return { M_ENTER_BALL } end
  local n = name:match("^delay_(%d+)$")
  if n then return { M_DELAY, nil, tonumber(n) } end
  if name:match("^face_") then return { M_FACE, dir } end
  if name:match("^walk_in_place_fast_") then return { M_IN_PLACE, dir, 8 } end
  if name:match("^walk_in_place_slow_") then return { M_IN_PLACE, dir, 32 } end
  if name:match("^walk_in_place_") then return { M_IN_PLACE, dir, 16 } end
  if name:match("^walk_faster_") then return { M_WALK, dir, 4 } end   -- MOVE_SPEED_FASTER
  if name:match("^walk_fast_") then return { M_WALK, dir, 8 } end     -- MOVE_SPEED_FAST_1
  if name:match("^slide_") then return { M_WALK, dir, 2 } end         -- MOVE_SPEED_FASTEST
  if name:match("^walk_") then return { M_WALK, dir, 16 } end         -- MOVE_SPEED_NORMAL
  if name:match("^jump_in_place_") then return { M_JUMP_IN_PLACE, dir } end
  if name:match("^jump_") then return { M_JUMP, dir } end
  error("follower movement not ported: " .. name)
end

local MOVES = {} -- name -> compiled op list
local function compileMoves()
  for name, list in pairs(D.MOVES) do
    local ops = {}
    for i = 1, #list do ops[i] = compileMove(list[i]) end
    MOVES[name] = ops
  end
end

local moveOps, moveIdx = nil, 0 -- running movement script

-- player currentCoords for face_player / faceplayer
local function playerDirection()
  local px, py = E.playerCur()
  return directionToFace(actor.cellX, actor.cellY, px, py)
end

-- start one movement action (Step0); returns true if it already finished
local function startMoveOp(op)
  local k = op[1]
  if k == M_FACE then faceDirection(op[2]); return true
  elseif k == M_FACE_PLAYER then faceDirection(playerDirection()); return true
  elseif k == M_FACE_AWAY then faceDirection(OPPOSITE[playerDirection()]); return true
  elseif k == M_LOCK then actor.facingDirectionLocked = true; return true
  elseif k == M_UNLOCK then actor.facingDirectionLocked = false; return true
  elseif k == M_WALK then startWalk(op[2], op[3])
  elseif k == M_IN_PLACE then startWalkInPlace(op[2], op[3], op[3] == 8)
  elseif k == M_JUMP_IN_PLACE then startJump(op[2], JUMP_TYPE_HIGH, JUMP_DISTANCE_IN_PLACE)
  elseif k == M_JUMP then startJump(op[2], JUMP_TYPE_NORMAL, JUMP_DISTANCE_NORMAL)
  elseif k == M_DELAY then
    actor.act, actor.actStep, actor.actT, actor.actDur = A_DELAY, 1, 0, op[3]
  elseif k == M_ENTER_BALL then
    actor.act, actor.actStep = A_ENTER_POKEBALL, 0
  end
  return stepAction() -- Step0 runs Step1 in the same frame
end

-- ScriptMovement: one action per frame at most; next starts the frame after
local function updateScriptMovement()
  if not moveOps then return true end
  if actor.act ~= A_NONE then
    if not stepAction() then return false end
    actor.act = A_NONE
    setAnim(anims().face[actor.facing]) -- animPaused on the still frame
    return false
  end
  moveIdx = moveIdx + 1
  local op = moveOps[moveIdx]
  if not op then moveOps = nil; return true end
  if not startMoveOp(op) then return false end
  actor.act = A_NONE
  return false
end

-- Talk runs as a coroutine created on A press, so its allocations stay out of the frame loop.
local talkCo = nil
local resultDir = nil -- gSpecialVar_Result (MSG_COND_NEAR_MB direction)
local COND = nil      -- D.COND_MSG with names resolved for this version

local function yield() coroutine.yield() end

local function applyMovement(name)
  moveOps, moveIdx = MOVES[name], 0
  actor.act = A_NONE
  repeat yield() until moveOps == nil -- waitmovement
end

local function waitEmote() -- waitfieldeffect FLDEFF_EMOTE
  while actor.emote >= 0 do yield() end
end

local function facePlayer() faceDirection(playerDirection()) end

local function message(text) -- message 0x0 / waitmessage / waitbuttonpress
  local done = false
  E.message(text, function() done = true end)
  while not done do yield() end
end

-- resolve every symbolic condition argument once (false = never matches)
local function resolveConds()
  COND = {}
  for i, info in ipairs(D.COND_MSG) do
    local conds = {}
    for j, c in ipairs(info.conds) do
      local k, a, b, x = c[1], c[2], c[3], c[4]
      if k == "TYPE" then a, b = E.typeId(a) or false, E.typeId(b) or false
      elseif k == "MAP" then a = V.maps[a] or false
      elseif k == "ON_MB" then a, b = V.mb[a] or false, V.mb[b] or false
      elseif k == "NEAR_MB" then a = V.mb[a] or false
      elseif k == "WEATHER" then a, b = D.WEATHER[a], D.WEATHER[b]
      elseif k == "MUSIC" then a = V.songs[a] or false
      elseif k == "TIME_OF_DAY" then a = V.timeOfDay and a or false
      elseif k == "SPECIES" then x = b end
      conds[j] = { k, a, b, x }
    end
    COND[i] = { info = info, conds = conds }
  end
end

-- FindMetatileBehaviorWithinRange: '+' shape, S, N, E, W order
local function findBehaviorWithinRange(x, y, mb, distance)
  for i = y + 1, y + distance do if E.behaviorAt(x, i) == mb then return "down" end end
  for i = y - 1, y - distance, -1 do if E.behaviorAt(x, i) == mb then return "up" end end
  for i = x + 1, x + distance do if E.behaviorAt(i, y) == mb then return "right" end end
  for i = x - 1, x - distance, -1 do if E.behaviorAt(i, y) == mb then return "left" end end
  return nil
end

local function speciesHasType(mon, t)
  local t1, t2 = E.monTypes(mon)
  return t ~= false and (t1 == t or t2 == t)
end

local function checkMsgCondition(c, mon, species)
  local k = c[1]
  if k == "SPECIES" then
    if c[4] then return c[2] ~= species end
    return c[2] == species
  elseif k == "TYPE" then
    local multi = speciesHasType(mon, c[2]) or speciesHasType(mon, c[3])
    if c[4] then return not multi end
    return multi
  elseif k == "STATUS" then
    local s = E.monStatus(mon)
    return s ~= nil and (s == c[2] or (c[2] == "PSN" and s == "TOX"))
  elseif k == "MAPSEC" then
    return c[2] == E.mapsec()
  elseif k == "MAP" then
    return c[2] ~= false and c[2] == E.mapId()
  elseif k == "ON_MB" then
    local b = E.behaviorAt(actor.cellX, actor.cellY)
    return (c[2] ~= false and b == c[2]) or (c[3] ~= false and b == c[3])
  elseif k == "WEATHER" then
    local w = E.weather()
    return w == c[2] or w == c[3]
  elseif k == "MUSIC" then
    return c[2] ~= false and c[2] == E.mapMusic()
  elseif k == "TIME_OF_DAY" then
    return false -- no RTC in this version (VERSIONS.timeOfDay)
  elseif k == "NEAR_MB" then
    if c[2] == false then return false end
    local dir = findBehaviorWithinRange(actor.cellX, actor.cellY, c[2], c[3])
    if dir then resultDir = dir end
    return dir ~= nil
  end
  return true
end

local function checkMsgInfo(entry, mon, species)
  local conds = entry.conds
  if entry.info.orFlag then
    for i = 1, #conds do
      if checkMsgCondition(conds[i], mon, species) then return true end
    end
    return false
  end
  for i = 1, #conds do
    if not checkMsgCondition(conds[i], mon, species) then return false end
  end
  return true
end

-- GetFollowerAction (event_object_movement.c:2561) -> emotion, text, D.SCRIPTS key
local function getFollowerAction(mon)
  local EM, BASIC = D.EMOTION, D.BASIC
  local species = actor.species
  local w = { [0] = 10, 15, 5, 15, 15, 15, 0, 10, 10, 15, 0 }
  local condEmotes, condCount = {}, 0
  local function addCond(emotion, index)
    condCount = condCount + 1
    condEmotes[condCount] = { emotion, index }
  end
  local multi = E.friendship(mon)
  if multi > 80 then
    w[EM.HAPPY], w[EM.UPSET], w[EM.ANGRY], w[EM.LOVE], w[EM.MUSIC] = 20, 5, 5, 20, 20
  end
  if multi > 170 then w[EM.HAPPY], w[EM.LOVE] = 30, 30 end
  -- weather-related
  if E.weather() == D.WEATHER.SUNNY_CLOUDS then addCond(EM.HAPPY, 31) end
  -- health & status-related (SAFE_DIV)
  local maxHP = tonumber(mon.maxHp or mon.maxHP) or 0
  multi = maxHP > 0 and floor((tonumber(mon.hp) or 0) * 100 / maxHP) or 0
  local status = E.monStatus(mon)
  if multi < 20 then
    w[EM.SAD] = 30
    addCond(EM.SAD, 4); addCond(EM.SAD, 5)
  end
  if multi < 50 or status == "PAR" then
    w[EM.SAD] = 30
    addCond(EM.SAD, 6)
  end
  -- gym type advantage/disadvantage
  local music = E.mapMusic()
  if (V.songs.MUS_GYM and music == V.songs.MUS_GYM) or (V.songs.MUS_RG_GYM and music == V.songs.MUS_RG_GYM) then
    local t = D.GYM_TYPE[E.mapsec()]
    if t then
      local eff = E.typeEffect(E.typeId(t), mon)
      if eff <= 0.5 then addCond(EM.HAPPY, 32)
      elseif eff >= 2 then addCond(EM.SAD, 7) end
    end
  end

  local sum = 0
  for i = 0, D.FOLLOWER_EMOTION_LENGTH - 1 do sum = sum + w[i] end
  local r = sum > 0 and E.random() % sum or 0
  local emotion = 0
  sum = 0
  for i = 0, D.FOLLOWER_EMOTION_LENGTH - 1 do
    sum = sum + w[i]
    if r < sum then emotion = i; break end
  end
  if (status == "PSN" or status == "TOX") and E.monAbility(mon) ~= V.abilities.POISON_HEAL then
    emotion = EM.POISONED
  end

  -- roll for basic/unconditional message
  multi = E.random() % BASIC[emotion].length
  -- (50%) special condition via reservoir sampling
  local j = 1
  for i = (band(E.random(), 1) == 1) and condCount + 1 or 1, condCount do
    local ce = condEmotes[i]
    if ce[1] == emotion then
      local jj = j; j = j + 1
      if E.random() < floor(0x10000 / jj) then multi = ce[2] end
    end
  end
  -- (50%) scripted conditional messages
  local picked = false
  j = 1
  local n = #COND
  for i = (band(E.random(), 1) == 1) and n + 1 or 1, n do
    local entry = COND[i]
    if checkMsgInfo(entry, mon, species) then
      local jj = j; j = j + 1
      if E.random() < floor(0x10000 / jj) * (entry.info.weight or 1) then
        multi = i
        picked = true
      end
    end
  end

  if picked then
    local info = COND[multi].info
    local text = info.text
    if type(text) == "table" then
      local cnt = math.min(#text, 4)
      text = cnt > 0 and text[E.random() % cnt + 1] or ""
    end
    return info.emotion, text, info.script or "Generic"
  end
  local m = BASIC[emotion][multi + 1]
  return emotion, m[1], m[2] or "Generic"
end
Follower.getFollowerAction = getFollowerAction

-- EventScript_FollowerGeneric / ..SkipFace
local function scriptGeneric(text, skipFace)
  if not skipFace then facePlayer() end
  waitEmote()
  message(text)
end

-- runs one D.SCRIPTS entry (ScriptCall target)
local function runScript(name, text)
  local s = D.SCRIPTS[name] or D.SCRIPTS.Generic
  if s.faceResult then
    -- EventScript_FollowerFaceResult: switch VAR_RESULT
    if not resultDir then return scriptGeneric(text) end
    applyMovement(resultDir == "down" and "Common_Movement_FaceDown"
      or resultDir == "up" and "Common_Movement_FaceUp"
      or resultDir == "left" and "Common_Movement_FaceLeft" or "Common_Movement_FaceRight")
    return scriptGeneric(text, true)
  end
  if s.face then facePlayer() end
  local list = s.move or (s.byFacing and s.byFacing[Player.facing])
  if list then
    for i = 1, #list do applyMovement(list[i]) end
  end
  scriptGeneric(text, s.tail == "S")
end

local function eventScriptFollower()
  E.lock()
  local mon = Follower.firstLiveMon()
  local name = mon and E.monName(mon) or ""
  local function buffer(t) -- bufferlivemonnickname STR_VAR_1
    return (t:gsub("{STR_VAR_1}", function() return name end))
  end
  if mon then E.playCry(mon) end
  resultDir = nil
  if not mon then
    -- EventScript_FollowerLovesYou failsafe (heart emote movement)
    objectEventEmote(D.EMOTION.LOVE)
    waitEmote()
    message(buffer(D.TEXT_LOVES_YOU))
  else
    local emotion, text, script = getFollowerAction(mon)
    objectEventEmote(emotion)
    runScript(script, buffer(text))
  end
  waitEmote()
  E.release()
end

--- A-press on the follower (GetInteractedObjectEventScript -> EventScript_Follower).
function Follower.talk()
  if talkCo or not actor.active or actor.invisible then return false end
  Follower.stopIndependent()
  E.Doze.cancel(actor);E.Idle.cancel(actor)
  clearMovement()
  moveOps = nil
  actor.y2 = 0
  talkCo = coroutine.create(eventScriptFollower)
  local ok, err = coroutine.resume(talkCo)
  if not ok then talkCo = nil; E.release(); error(err, 0) end
  return true
end

function Follower.talking() return talkCo ~= nil end

-- ObjectEventTurn(followerMon, dir) from another script (facetogether)
function Follower.face(dir)
  if actor.active then faceDirection(dir) end
end

-- ENTER_POKEBALL held movement (Task_OWEApproachForBattle recall).
-- comeBack: pop out on the same cell once the script releases control.
local backX, backY = nil, nil
local appearPending = false
function Follower.enterBall(comeBack)
  if not actor.active or actor.invisible or talkCo then return false end
  Follower.stopIndependent()
  E.Doze.cancel(actor);E.Idle.cancel(actor)
  if comeBack then backX, backY = actor.cellX, actor.cellY end
  clearMovement()
  actor.act, actor.actStep = A_ENTER_POKEBALL, 0
  actor.singleMovementActive = true
  actor.typeFunc = 2
  return true
end

-- Explicit arrival release: reuse the native reverse animation and each mon's ball.
function Follower.exitBall()
  if not actor.active or talkCo or not E.followerVisible() then return false end
  E.Doze.cancel(actor);E.Idle.cancel(actor)
  appearPending=false;backX,backY=nil,nil
  clearMovement()
  actor.y2,actor.white=0,0
  actor.act,actor.actStep=A_EXIT_POKEBALL,1
  actor.singleMovementActive,actor.typeFunc=true,2
  exitPokeballStep0()
  return true
end

local function updateTalk()
  if updateScriptMovement() and coroutine.status(talkCo) == "suspended" then
    local ok, err = coroutine.resume(talkCo)
    if not ok then talkCo = nil; moveOps = nil; E.release(); error(err, 0) end
  end
  if coroutine.status(talkCo) == "dead" then
    talkCo = nil
    moveOps = nil
    clearMovement()
    actor.typeFunc = 1 -- resume MovementType_FollowPlayer_Active
  end
end

-- Draw.  sAffineAnims_PokeballFollower: x scale 1/4 steps, one per frame.
local EXIT_SCALE = { [0] = 0.25, 0.5, 0.75, 1 }
local ENTER_SCALE = { [0] = 1, 0.75, 0.5, 0.25 }

-- sprite frame without effects; also what the Quest Log records
local function pose(a)
  if a.invisible then return nil end
  local frame, flip = 0, false
  if a.anim then frame, flip = animFrame(a.anim, a.animT) end
  if a.ballGfx then return a.ballSheet, frame, flip, a.ballPalRow, a.y2 end
  if E.Doze.sleeping(a) then
    frame, flip = animFrame(ANIMS[a.asym == true].face[a.facing], 0)
    return a.sheet, frame, flip, a.palRow, E.Doze.offset(a)
  end
  local dir, idleY, hopping = E.Idle.pose(a)
  if dir then
    frame, flip = animFrame(ANIMS[a.asym == true].face[dir], 0)
    return a.sheet, frame, flip, a.palRow, idleY, hopping
  end
  return a.sheet, frame, flip, a.palRow, a.y2
end

local function draw(a, sx, sy)
  if a.invisible then return true end
  local _, frame, flip, _, y2, idleHop = pose(a)
  local xs,ys = E.Idle.scale(a)
  if a.affine then
    local t = a.affineT
    if t > 3 then t = 3 end
    xs = a.affineEnter and ENTER_SCALE[t] or EXIT_SCALE[t]
  end
  local sheet, row = a.sheet, a.palRow
  if a.ballGfx then sheet, row = a.ballSheet, a.ballPalRow
  else E.drawShadow(a, sx, sy, a.act == A_JUMP or (idleHop and y2 < 0)) end
  local grass = not a.ballGfx and a.act ~= A_JUMP and not (idleHop and y2 < 0)
  if grass then E.drawGrass(a, sx, sy, false) end
  local ok = not a.ballGfx and E.SpriteSets.draw(a, frame, flip, sx, sy + y2, a.white, 1, xs, a.mosaic, ys)
  if not ok then ok = E.Gfx.draw(sheet, frame, flip, row, sx, sy + y2, a.white, 1, xs, a.mosaic, ys) end
  if grass then E.drawGrass(a, sx, sy, true) end
  if ok then E.Doze.queue(a, sx, sy + y2, frame);E.Idle.queue(a,sx,sy+y2,frame) end
  if a.emote >= 0 and ok then
    -- SpriteCB_TrainerIcons: x = object x, y = object centre - 16, plus the
    -- object's y2 and the bounce; sSpriteAnim_Emotes: frame 2e 30, 2e+1 25, 2e 30
    local fh = A.sheets[(sheet - 1) * 6 + 4]
    local t, f = a.emoteT, a.emote * 2
    if t >= 30 and t < 55 then f = f + 1 end
    local es = A.EMOTES
    E.queueOverlay(es, f, A.sheets[(es - 1) * 6 + 6],
      sx, sy + 16 - rshift(fh, 1) - 24 + a.y2 + a.emoteY) -- OAM priority 1
  end
  return ok
end

function Follower.init(engine)
  E, C, A, D, V = engine, engine.C, engine.Data.ATLAS, engine.Data, engine.V
  Player, Collision = engine.Player, engine.Collision
  actor = E.FOLLOWER
  actor.draw, actor.pose = draw, pose
  actor.moveDir, actor.emote, actor.emoteT, actor.emoteY, actor.emoteVel = "down", -1, 0, 0, 0
  actor.mosaic, actor.tType, actor.tFrames = 1, nil, 0
  compileMoves()
  resolveConds()
  actor.typeFunc, actor.act, actor.actStep, actor.actT, actor.actDur = 0, A_NONE, 0, 0, 16
  actor.y2, actor.white, actor.affine, actor.affineT, actor.duration = 0, 0, false, 0, 0
  actor.animT, actor.speedFlip, actor.invisible = 0, 0, true
  Follower.A = { NONE = A_NONE, WALK = A_WALK, JUMP = A_JUMP, EXIT = A_EXIT_POKEBALL,
    ENTER = A_ENTER_POKEBALL, IN_PLACE = A_WALK_IN_PLACE, DELAY = A_DELAY, FACE = A_FACE }
end

function Follower.reset()
  backX, backY = nil, nil
  appearPending=false
  if talkCo then talkCo = nil; moveOps = nil; E.release() end
  removeFollowingPokemon()
  lastPX = -1
end

local wasLocked = false
local lastLead, lastLeadSp = false, nil
function Follower.tick()
  if appearPending then Follower.appearNow() end
  -- menus pause the field without locking controls, so also watch the lead mon
  local locked = E.controlsLocked()
  local lead = Follower.firstLiveMon()
  local sp = lead and (lead.species or lead.speciesId)
  if (wasLocked and not locked) or lead ~= lastLead or sp ~= lastLeadSp then
    lastLead, lastLeadSp = lead, sp
    Follower.update()
    if backX and not locked then
      local px, py = E.playerCur()
      if actor.active and actor.invisible and not swap and E.followerVisible()
          and (px ~= backX or py ~= backY) then
        moveToMapCoords(backX, backY)
        clearMovement()
        actor.act, actor.actStep = A_EXIT_POKEBALL, 0
        actor.singleMovementActive, actor.typeFunc = true, 2
      end
      backX, backY = nil, nil
    end
  end
  wasLocked = locked
  if not actor.active then return end
  if swap and (actor.act == A_NONE or actor.act == A_WALK_IN_PLACE) and not talkCo then
    clearMovement()
    actor.singleMovementActive, actor.typeFunc = true, 2
    if not actor.invisible then
      actor.act, actor.actStep = A_ENTER_POKEBALL, 0
    else
      followerSetGraphics(swap[1], swap[2], swap[3])
      swap = nil
      if E.followerVisible() and not locked then
        actor.act, actor.actStep = A_EXIT_POKEBALL, 0
      else
        actor.singleMovementActive, actor.typeFunc = false, 0
      end
    end
  end
  updateCopyMove()
  if talkCo then
    updateTalk() -- the script owns the follower (applymovement)
  elseif actor.independent then
    if actor.moving then followPlayer_Moving()
    else followablePlayerMovement_Idle() end
  else
    movementType_FollowPlayer()
  end
  updateEmote()
  -- WalkInPlaceSlow: animDelayCounter++ on odd frames = half-speed anim
  if not (actor.slowAnim and actor.act == A_WALK_IN_PLACE and band(actor.actT, 1) == 1) then
    actor.animT = actor.animT + 1
  end
  if actor.affine then actor.affineT = actor.affineT + 1 end
  E.Doze.tick(actor)
  E.Idle.tick(actor)
end

function Follower.onStep(_) Follower.update() end

-- game3 parks the player on the edge cell after a connection;
-- the follower goes one cell behind it, keeping any step in progress.
function Follower.onMapEntered(ev)
  backX, backY = nil, nil
  local d = Player.facing
  if ev and ev.via == "connection" and actor.active and DX[d] then
    local ex, ey = Player.cellX - DX[d], Player.cellY - DY[d]
    local prog = 0
    if actor.moving then
      prog = math.abs(actor.px - actor.cellX * 16) + math.abs(actor.py - actor.cellY * 16)
    end
    actor.cellX, actor.cellY = ex - DX[d], ey - DY[d]
    if actor.moving then
      actor.targetX, actor.targetY, actor.moveDir = ex, ey, d
      actor.facing = d
    else
      actor.targetX, actor.targetY = actor.cellX, actor.cellY
    end
    actor.px = actor.cellX * 16 + DX[d] * prog
    actor.py = actor.cellY * 16 + DY[d] * prog
    lastPX = -1
    return Follower.update()
  end
  -- object events are rebuilt on map load: respawn invisible at the player
  removeFollowingPokemon()
  lastPX = -1
  copyMove = COPY_NONE
  Follower.update()
  appearPending = true
end

-- Not expansion (D39): show the follower at once on the first free side, behind first.
-- Waits for the warp fade to release controls; one try per map entry.
local SIDES = { up = { "down", "left", "right", "up" }, down = { "up", "right", "left", "down" },
  left = { "right", "up", "down", "left" }, right = { "left", "down", "up", "right" } }
function Follower.appearNow()
  if not E.C.OW_FOLLOWERS_APPEAR_NOW then appearPending = false return end
  local blocked=E.arrivalBlocked and E.arrivalBlocked() or (not E.arrivalBlocked and E.controlsLocked())
  if blocked or not actor.active then return end
  appearPending = false
  if not actor.invisible or not E.followerVisible() then return end
  local px, py = E.playerCur()
  for _, d in ipairs(SIDES[Player.facing] or SIDES.down) do
    local tx, ty = px + DX[d], py + DY[d]
    if E.canMove(actor, tx, ty, d) then
      moveToMapCoords(tx, ty)
      actor.invisible = false
      faceDirection(Player.facing)
      return
    end
  end
end

function Follower.onBattleStarted(_) E.Doze.cancel(actor);E.Idle.cancel(actor) end
function Follower.onBattleEnded(_) Follower.update() end

-- Place each native follower on a separate legal tile after a warp.
function Follower.place(x,y,visible)
  actor.independent=false;actor.wander=nil
  E.Doze.cancel(actor);E.Idle.cancel(actor)
  appearPending=false;backX,backY=nil,nil
  clearMovement();moveToMapCoords(x,y)
  actor.typeFunc=visible and 1 or 0;actor.invisible=not visible;actor.ballGfx=false;actor.affine=false
  actor.y2=0;actor.white=0
  faceDirection(actor.facing or "down")
end
function Follower.translate(dx,dy)
  actor.independent=false;actor.wander=nil
  E.Doze.cancel(actor);E.Idle.cancel(actor)
  actor.px,actor.py=actor.px+dx,actor.py+dy
  actor.cellX,actor.cellY=actor.cellX+dx/16,actor.cellY+dy/16
  actor.targetX,actor.targetY=actor.targetX+dx/16,actor.targetY+dy/16
end
-- Wander/return actions use the same native gait and elevation handling.
function Follower.independentStep(dir,frames)
  if actor.moving or actor.invisible or actor.ballGfx or talkCo then return false end
  clearMovement();E.Doze.cancel(actor);E.Idle.cancel(actor)
  startWalk(dir,frames)
  actor.singleMovementActive=true;actor.typeFunc=2;actor.independent=true
  return true
end
function Follower.stopIndependent()
  if not actor.independent then return end
  if actor.moving then moveToMapCoords(actor.cellX,actor.cellY) end
  clearMovement();actor.y2=0;actor.typeFunc=1
  actor.independent=false;actor.wander=nil;actor.returnRetry=nil
end
return Follower
