-- Fresh cooperative play controller: native one-tile actions and the current
-- bounded legal-route helper, never the old free-will movement implementation.
return function(E,Walk)
 local M={round=nil,turn=0,nextRound=0}
 local dirs={'up','right','down','left'}
 local dx={up=0,right=1,down=0,left=-1};local dy={up=-1,right=0,down=1,left=0}
 local opposite={up='down',right='left',down='up',left='right'}
 local time=0
 local function eligible(a)
  local c=a.nativeCore
  return a.active and not a.invisible and not a.ballGfx and not a.affine
   and a.emote<0 and not a.tType and not c.talking()
   and (a.act==c.A.NONE or a.act==c.A.IN_PLACE or a.act==c.A.WALK)
 end
 function M.reset()
  local r=M.round
  if r then for _,a in ipairs(r.actors)do
   if a.play then a.nativeCore.stopIndependent();a.play=nil end
  end end
  M.round=nil;M.recovery=nil;M.nextRound=time
 end
 local function phase(name)
  local r=M.round;r.phase=name;r.since=time;r.deadline=time+(name=='chase' and 240 or name=='retreat' and 480 or 150)
  for _,a in ipairs(r.actors)do if a.play then a.play.next=time end end
 end
 local function chooseShelter(a,front)
  local p=E.Player;local d=p.facing or 'down';local sign=front and 1 or -1
  for _,point in ipairs({{1,0},{2,0},{1,-1},{1,1},{2,-1},{2,1}})do
   local x=p.cellX+dx[d]*point[1]*sign-dy[d]*point[2]
   local y=p.cellY+dy[d]*point[1]*sign+dx[d]*point[2]
   if x==a.cellX and y==a.cellY or Walk.free(a,x,y,d) then return {cellX=x,cellY=y} end
  end
 end
 local function start(actors)
  local list={}
  for _,a in ipairs(actors)do if eligible(a) and not a.moving and not a.independent then list[#list+1]=a end end
  if #list==0 then return end
  -- Avoid commandeering a partially returning line or a scripted actor.
  if #list~=#actors then return end
  M.turn=M.turn+1
  local slot=(M.turn-1)%#list+1
  local runner=list[slot];local chaser=#list>1 and list[slot%#list+1] or nil
  local p=E.Player
  M.round={actors=list,runner=runner,chaser=chaser,x=p.cellX,y=p.cellY,facing=p.facing}
  for _,a in ipairs(list)do
   if E.Spacing then E.Spacing.beginIndependent(a) end
   a.play={next=time,returning=false};a.independent=true
   E.Idle.cancel(a);E.Doze.cancel(a)
  end
  phase(chaser and 'chase' or 'retreat')
 end
 function M.beginTick(actors)
  if E.C.OW_FOLLOWERS_MIXED then
   local players={}
   for _,a in ipairs(actors)do if E.Idle.enabled('OW_FOLLOWERS_PLAY',a) or a.play then players[#players+1]=a end end
   actors=players
  end
  time=Walk.time
  local p=E.Player;local r=M.round
  -- A dialog pauses on legal source cells. Resume with a legal return,
  -- rather than handing a scattered line to permissive native following.
  if M.recovery and not r then
   if E.controlsLocked() or not E.followerVisible() then return end
   local ready=true
   for _,a in ipairs(actors)do if not eligible(a) or a.moving then ready=false end end
   if not ready then return end
   M.recovery=nil
   if #actors==0 then return end
   local list={};for _,a in ipairs(actors)do
    list[#list+1]=a;a.play={next=time,returning=true};a.independent=true
   end
   M.round={actors=list,runner=list[1],x=p.cellX,y=p.cellY,facing=p.facing};phase('return');r=M.round
  end
  local interrupted=not (E.C.OW_FOLLOWERS_PLAY or E.C.OW_FOLLOWERS_MIXED) or not E.C.OW_FOLLOWERS_ENABLED
   or p.moving or p.jumping or E.controlsLocked() or not E.followerVisible()
  if r then
   local changed=#actors~=#r.actors
   interrupted=interrupted or p.cellX~=r.x or p.cellY~=r.y or p.facing~=r.facing
   for i,a in ipairs(r.actors)do
    if actors[i]~=a or not eligible(a) then changed=true end
   end
   if changed or interrupted then
    if E.controlsLocked() then
     M.reset();M.recovery=true;return
    end
    if not E.followerVisible() or changed then M.reset();return end
    if r.phase~='return' then phase('return') end
   elseif r.phase=='chase' and time>=r.deadline then phase('retreat')
   elseif r.phase=='retreat' and time>=r.deadline then phase('return')
   elseif r.phase=='hide' and time>=r.deadline then phase('return') end
  elseif not E.idleReturning and time>=(E.idleRecoveryUntil or 0) and not interrupted and Walk.idle>=E.Idle.delay() and time>=M.nextRound then start(actors) end
 end
 local function stepToward(a,target,exact,frames)
  if not target then return false end
  local dist=math.abs(a.cellX-target.cellX)+math.abs(a.cellY-target.cellY)
  if dist==(exact and 0 or 1) then return true end
  if time<(a.play.next or 0) then return false end
  a.play.next=time+12
  local dir=Walk.directionTo(a,target,exact)
  if dir and Walk.free(a,a.cellX+dx[dir],a.cellY+dy[dir],dir) then
   a.nativeCore.independentStep(dir,frames)
  end
  return false
 end
 function M.returnToLine()
  if M.round and M.round.phase~='return' then phase('return') end
 end
 function M.tick(a,leader)
  local r=M.round;if not r or not a.play then return end
  if a.moving then return end
  if r.phase=='return' then
   a.play.returning=true
   if Walk.returnStep(a,leader) then
    a.nativeCore.stopIndependent();a.play=nil
    local remaining=false
    for _,b in ipairs(r.actors)do if b.play then remaining=true end end
    if not remaining then M.round=nil;M.nextRound=time+240 end
   end
   return
  end
  if a~=r.runner and a~=r.chaser then return end
  if r.phase=='chase' then
   if a==r.runner then
    if time<a.play.next then return end
    a.play.next=time+30
    local best,score
    local offset=M.turn%4
    for k=0,3 do
     local dir=dirs[(offset+k)%4+1];local x,y=a.cellX+dx[dir],a.cellY+dy[dir]
     if math.abs(x-r.x)<=4 and math.abs(y-r.y)<=4 and Walk.free(a,x,y,dir) then
      local distance=math.abs(x-r.chaser.cellX)+math.abs(y-r.chaser.cellY)
      local value=distance*3-(dir==a.play.last and 0 or 1)-(dir==a.play.reverse and 2 or 0)
      if not score or value>score then best,score=dir,value end
     end
    end
    if best then
     a.play.last=best;a.play.reverse=opposite[best]
     a.nativeCore.independentStep(best,12)
    end
   else
    stepToward(a,r.runner,false,16)
   end
   if time-r.since>=90 and math.abs(r.runner.cellX-r.chaser.cellX)+math.abs(r.runner.cellY-r.chaser.cellY)<=1 then phase('retreat') end
  elseif r.phase=='retreat' then
   if a==r.runner then
    r.shelter=r.shelter or chooseShelter(a,false)
    if not r.shelter then phase('return');return end
    if stepToward(a,r.shelter,true,12) then phase('hide') end
   else
    r.guard=r.guard or chooseShelter(a,true)
    if r.guard then stepToward(a,r.guard,true,16) end
   end
  elseif r.phase=='hide' and a==r.chaser then
   r.guard=r.guard or chooseShelter(a,true)
   if r.guard then stepToward(a,r.guard,true,16) end
  end
 end
 function M.pose(a)
  local r=M.round
  if not r or not a.play or a.moving or r.phase=='return' then return end
  local target=a==r.runner and r.chaser or r.runner
  if r.phase=='hide' and a==r.runner then
   local sides={up={'left','right'},down={'right','left'},left={'down','up'},right={'up','down'}}
   local pair=sides[E.Player.facing or 'down'];return pair[math.floor((time-r.since)/36)%2+1],0,false
  end
  if target then
   local x,y=target.px-a.px,target.py-a.py
   return math.abs(x)>math.abs(y) and (x<0 and 'left' or 'right') or (y<0 and 'up' or 'down'),0,false
  end
 end
 return M
end
