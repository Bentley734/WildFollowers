-- Called from the real cartridge movement fixture, using its jump renderer.
return function(include,values,player,check,eq,near,schema)
  local I,J=include('idle'),include('jumps')
  local modes
  for _,entry in ipairs(schema) do
    if entry.key=='OW_FOLLOWERS_IDLE_MODE' then modes=entry.choices end
  end
  local function group(mode)
    values.OW_FOLLOWERS_IDLE_MODE=mode;values.OW_FOLLOWERS_IDLE_TIME=1
    local c={followers={},occupied=function()return false end,
      move=function(_,e,x,y)e.moving=true;e.targetX=x;e.targetY=y;return true end}
    for slot=1,6 do
      -- Middle members of a fractional formation are paused native steps.
      c.followers[slot]={slot=slot,lineSlot=slot,facing='down',cellX=player.cellX-slot,
        cellY=player.cellY,px=(player.cellX-slot)*16,py=player.cellY*16,
        moving=slot>1 and slot<6,spacingPaused=slot>1 and slot<6}
    end
    player.moving=true;I:tick(c,c.followers[1],0);player.moving=false
    return c
  end
  local function frame(c,dt)
    for _,e in ipairs(c.followers) do
      I:tick(c,e,dt)
      if e.idleWander then
        local home=e.idleWander
        if e.moving and not e.spacingPaused then
          e.cellX,e.cellY=e.targetX,e.targetY;e.moving=false;e.targetX=nil;e.targetY=nil
        end
        check(math.abs(e.cellX-home.x)+math.abs(e.cellY-home.y)<=2,'wandering respects its home radius')
      end
    end
  end
  -- Exercise every menu choice over multiple cycles, not just its first frame.
  for _,choice in ipairs(modes) do
    local mode=choice[2];local c=group(mode)
    for n=1,900 do
      frame(c,1/60)
      for _,e in ipairs(c.followers) do
        local pose=e.idlePose
        if mode=='none' then check(not pose,'NONE leaves every companion still')
        elseif pose then
          check(pose.sx>=.85 and pose.sx<=1.15 and pose.sy>=.85 and pose.sy<=1.15,'idle scaling stays bounded: '..mode)
          check(pose.frame>=0 and pose.frame<=3,'idle selects a valid frame: '..mode)
          if pose.jumping then
            local offset,active=J:pose(e)
            check(active,'idle hop renders for integer and fractional slots: '..mode)
            near(offset,pose.hop,'rendered jump height matches idle curve: '..mode)
          end
        end
      end
    end
    if mode~='none' then
      for _,e in ipairs(c.followers) do check(e.idlePose~=nil,'every member participates: '..mode) end
    end
    player.moving=true;frame(c,1/60);player.moving=false
    for _,e in ipairs(c.followers) do
      check(not e.idlePose and not e.idleMode,'movement cancels every mode: '..mode)
      if e.idleWander then error('wander anchor survived interruption') end
    end
  end
  -- Six companions must visibly jump in order, at all common update rates.
  for _,rate in ipairs({30,60,144}) do
    for _,mode in ipairs({'wave','bounce'}) do
      local c=group(mode);local counts,first,peaks,was={},{},{},{}
      for n=1,30*rate do
        frame(c,1/rate)
        for slot,e in ipairs(c.followers) do
          local pose=e.idlePose;local active=pose and pose.jumping or false
          if active and not was[slot] then
            counts[slot]=(counts[slot] or 0)+1
            first[slot]=first[slot] or n/rate
          end
          local height=J:pose(e)
          peaks[slot]=math.min(peaks[slot] or 0,height)
          was[slot]=active
        end
      end
      for slot=1,6 do
        eq(counts[slot],mode=='wave' and 6 or 12,'complete bounded jump cycles for slot '..slot..' at '..rate..'Hz')
        check(peaks[slot]<=-8,'every member leaves the ground visibly: '..mode..' slot '..slot)
        if slot>1 then
          check(math.abs(first[slot]-first[1]-(slot-1)*.22)<=2/rate,'wave follows procession order at '..rate..'Hz')
        end
      end
    end
  end
  -- Single looping waves have exactly one airborne member, including the wrap.
  for _,rate in ipairs({30,60,144}) do
    for _,count in ipairs({1,2,6}) do
      local c=group('wave_single')
      for slot=6,count+1,-1 do c.followers[slot]=nil end
      local starts,was={},{}
      for n=1,30*rate do
        frame(c,1/rate)
        local airborne=0
        for slot,e in ipairs(c.followers) do
          local active=e.idlePose and e.idlePose.jumping or false
          if active then
            airborne=airborne+1
            if not was[slot] then
              starts[slot]=starts[slot] or {}
              starts[slot][#starts[slot]+1]=n/rate
            end
          end
          was[slot]=active
        end
        check(airborne<=1,'single wave never overlaps at '..rate..'Hz with '..count..' followers')
      end
      local spacing=J.duration+.1
      for slot=1,count do
        check(starts[slot] and #starts[slot]>=7,'single wave repeatedly visits every member')
        for n=2,#starts[slot] do
          check(math.abs(starts[slot][n]-starts[slot][n-1]-count*spacing)<=2/rate,'single wave loops without an extra group pause')
        end
        check(math.abs(starts[slot][1]-starts[1][1]-(slot-1)*spacing)<=2/rate,'single wave waits for the preceding full jump')
      end
    end
  end
  -- Spins finish one turn and remain at rest for most of each five-second cycle.
  local c=group('spin');local changes,rest,previous={},{},{}
  for n=1,30*60 do
    frame(c,1/60)
    for slot,e in ipairs(c.followers) do
      local pose=e.idlePose
      if pose then
        if previous[slot] and previous[slot]~=pose.facing then changes[slot]=(changes[slot] or 0)+1 end
        if pose.facing==e.facing then rest[slot]=(rest[slot] or 0)+1 end
        previous[slot]=pose.facing
      end
    end
  end
  for slot=1,6 do
    check(changes[slot]>=18 and changes[slot]<=24,'spin performs one turn per cycle: '..slot)
    check(rest[slot]>1400,'spin pauses between turns: '..slot)
  end
  -- Changing a live selection or delay discards the previous animation.
  c=group('jump');frame(c,1.2)
  check(c.followers[1].idlePose.jumping,'fixture starts with a visible jump')
  values.OW_FOLLOWERS_IDLE_MODE='doze';frame(c,1/60)
  for _,e in ipairs(c.followers) do check(not e.idlePose,'mode switch clears old pose immediately') end
  frame(c,1.1)
  for _,e in ipairs(c.followers) do check(e.idlePose and e.idlePose.sleep,'new mode starts after its delay') end
  values.OW_FOLLOWERS_IDLE_TIME=5;frame(c,1/60)
  for _,e in ipairs(c.followers) do check(not e.idlePose,'longer delay clears previous pose') end
  frame(c,4)
  for _,e in ipairs(c.followers) do check(not e.idlePose,'changed delay is honored') end
  values.OW_FOLLOWERS_IDLE_MODE='none';values.OW_FOLLOWERS_IDLE_TIME=1
end
