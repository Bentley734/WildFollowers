-- Short legal native walks, shared sleep/wake moments and bounded line returns.
return function(E,Walk)
 local M={actors={},time=0}
 local dirs={'up','right','down','left'}
 local dx={up=0,right=1,down=0,left=-1};local dy={up=-1,right=0,down=1,left=0}
 local function ready(a)
  local c=a.nativeCore
  return c and a.active and not a.invisible and not a.moving and not a.independent
   and not a.ballGfx and not a.affine and a.emote<0 and not a.tType and not c.talking()
   and (a.act==c.A.NONE or a.act==c.A.IN_PLACE)
 end
 local function release(a)
  if a.social then a.nativeCore.stopIndependent();a.social=nil end
 end
 function M.reset()
  for _,a in ipairs(M.actors)do release(a);a.socialNext=nil end
  M.actors={}
 end
 local function claim(a,state)
  if state.kind=='sleepy' then
   state.home={cellX=a.cellX,cellY=a.cellY}
   state.trainerX,state.trainerY=E.Player.cellX,E.Player.cellY
  end
  if E.Spacing then E.Spacing.beginIndependent(a) end
  a.social=state;a.independent=true;E.Doze.cancel(a);E.Idle.cancel(a)
 end
 local function interrupted()
  return not E.C.OW_FOLLOWERS_ENABLED or E.Player.moving or E.Player.jumping
   or E.controlsLocked() or not E.followerVisible()
 end
 function M.beginTick(order)
  M.time=Walk.time
  for _,old in ipairs(M.actors)do
   local found=false;for _,a in ipairs(order)do if a==old then found=true;break end end
   if not found then release(old) end
  end
  M.actors=order
  for _,a in ipairs(order)do
   local s=a.social
   if s then
    -- While the trainer stays put, adjacency to the sleeper is not the
    -- buddy's place in line. Restore the exact pre-activity formation slot.
    if E.Player.moving or E.Player.jumping or E.Player.cellX~=s.trainerX
      or E.Player.cellY~=s.trainerY then s.home=nil end
    local key=s.kind=='zoomies' and 'OW_FOLLOWERS_ZOOMIES' or 'OW_FOLLOWERS_SLEEPY_BUDDY'
    if interrupted() or not E.Idle.enabled(key,a) or not a.active or a.invisible
      or a.ballGfx or a.affine or a.tType or a.emote>=0 or a.nativeCore.talking() then
     s.returning=true
     if s.partner and s.partner.social then s.partner.social.returning=true end
    end
    if not a.active or a.invisible then release(a) end
   elseif not E.idleReturning and M.time>=(E.idleRecoveryUntil or 0) and not interrupted() and Walk.idle>=E.Idle.delay()
     and M.time>=(a.socialNext or 0)+(a.followSlot or 1)*18 and ready(a) then
    if E.Idle.enabled('OW_FOLLOWERS_ZOOMIES',a) then
     claim(a,{kind='zoomies',step=0,offset=math.random(4)-1,next=M.time})
    elseif E.Idle.enabled('OW_FOLLOWERS_SLEEPY_BUDDY',a) then
     local buddy,best
     for _,b in ipairs(order)do
      -- A mixed-mode buddy retains its own assignment; avoid commandeering
      -- another behavior, or a follower currently returning to the line.
      if b~=a and ready(b) and E.Idle.enabled('OW_FOLLOWERS_SLEEPY_BUDDY',b) then
       local d=math.abs(b.cellX-a.cellX)+math.abs(b.cellY-a.cellY)
       if d<=6 and (not best or d<best) then buddy,best=b,d end
      end
     end
     -- Mixed never starts a solo fallback while its selected partner is busy.
     if buddy or not E.C.OW_FOLLOWERS_MIXED then
      claim(a,{kind='sleepy',role='sleeper',since=M.time,next=M.time,partner=buddy})
      if buddy then claim(buddy,{kind='sleepy',role='buddy',since=M.time,next=M.time,partner=a}) end
     end
    end
   end
  end
 end
 local function toward(a,target,exact,frames)
  local s=a.social
  local d=math.abs(a.cellX-target.cellX)+math.abs(a.cellY-target.cellY)
  if d==(exact and 0 or 1) then return true end
  if M.time<s.next then return false end
  s.next=M.time+12
  local dir=Walk.directionTo(a,target,exact)
  if dir and Walk.free(a,a.cellX+dx[dir],a.cellY+dy[dir],dir) then
   a.nativeCore.independentStep(dir,frames)
  end
  return false
 end
 function M.tick(a,leader)
  local s=a.social;if not s or a.moving then return end
  if E.controlsLocked() or not E.followerVisible() or a.nativeCore.talking() then return end
  if s.returning then
   if Walk.returnStep(a,leader,s.home) then
    release(a);a.socialNext=M.time+360
   end
   return
  end
  if s.kind=='zoomies' then
   if M.time<s.next then return end
   if s.step>=4 then s.returning=true;return end
   local dir=dirs[(s.offset+s.step)%4+1]
   if Walk.free(a,a.cellX+dx[dir],a.cellY+dy[dir],dir) then
    if a.nativeCore.independentStep(dir,8)~=false then s.step=s.step+1;s.next=M.time+8 end
   else s.returning=true end
  elseif s.role=='buddy' then
   local partner=s.partner
   if not partner or not partner.social then s.returning=true;return end
   if M.time-s.since>=90 and toward(a,partner,false,16) then
    partner.social.wake=partner.social.wake or M.time;s.wake=partner.social.wake
   end
   if M.time-s.since>360 and not s.wake then s.returning=true;partner.social.returning=true end
   if s.wake and M.time-s.wake>=72 then s.returning=true;partner.social.returning=true end
  else
   if not s.partner and M.time-s.since>=180 then s.wake=s.wake or M.time end
   if s.wake and M.time-s.wake>=72 then s.returning=true end
  end
 end
 function M.sleepAge(a)
  local s=a.social
  if s and s.kind=='sleepy' and s.role=='sleeper' and not s.wake and not s.returning
    and not interrupted() then return M.time-s.since end
 end
 function M.pose(a)
  local s=a.social
  if not s or s.returning or a.moving then return end
  if s.wake then
   local t=M.time-s.wake-(s.role=='sleeper' and 24 or 0)
   local y=t>=0 and t<24 and -math.floor(6*math.sin(math.pi*t/24)+.5) or 0
   return a.facing,y,true
  end
  if s.partner and s.role=='buddy' then
   local x,y=s.partner.cellX-a.cellX,s.partner.cellY-a.cellY
   return math.abs(x)>math.abs(y) and (x<0 and 'left' or 'right') or (y<0 and 'up' or 'down'),0,false
  end
 end
 return M
end
