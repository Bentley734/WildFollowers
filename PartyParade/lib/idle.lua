-- New idle poses: render-only head turns and hops, leaving native tile ownership intact.
return function(E,heads)
  local M={}
  -- Saved conflicts retain Wander's earlier priority. Menu selection always wins.
  local modes={
    {'OW_FOLLOWERS_MIXED','wildsG3FollowerMixed'},
    {'OW_FOLLOWERS_RANDOM','wildsG3FollowerRandom'},
    {'OW_FOLLOWERS_RANDOM_WAVE','wildsG3FollowerRandomWave'},
    {'OW_FOLLOWERS_BOUNCE_WAVE','wildsG3FollowerBounceWave'},
    {'OW_FOLLOWERS_SPIN_WAVE','wildsG3FollowerSpinWave'},
    {'OW_FOLLOWERS_PULSE_WAVE','wildsG3FollowerPulseWave'},
    {'OW_FOLLOWERS_ZOOMIES','wildsG3FollowerZoomies'},
    {'OW_FOLLOWERS_COPYCAT','wildsG3FollowerCopycat'},
    {'OW_FOLLOWERS_SLEEPY_BUDDY','wildsG3FollowerSleepyBuddy'},
    {'OW_FOLLOWERS_WANDER','wildsG3FollowerWander'},
    {'OW_FOLLOWERS_DOZE','wildsG3FollowerDoze'},
    {'OW_FOLLOWERS_LOOK_AROUND','wildsG3FollowerLookAround'},
    {'OW_FOLLOWERS_JUMP','wildsG3FollowerJump'},
    {'OW_FOLLOWERS_JUMP_WAVE','wildsG3FollowerJumpWave'},
    {'OW_FOLLOWERS_PLAY','wildsG3FollowerPlay'},
    {'OW_FOLLOWERS_CHEER','wildsG3FollowerCheer'},
    {'OW_FOLLOWERS_STRETCH','wildsG3FollowerStretch'},
  }
  function M.normalize(block)
    local target=block or E.C;local chosen=false
    for _,mode in ipairs(modes)do
      local key=block and mode[2] or mode[1]
      if target[key] then
        if chosen then target[key]=false else chosen=true end
      end
    end
  end
  function M.select(block,key)
    local isMode=false
    for _,mode in ipairs(modes)do if mode[1]==key then isMode=true;break end end
    if isMode then
      for _,mode in ipairs(modes)do if mode[1]~=key then block[mode[2]]=false end end
    end
  end
  function M.delay()
    local seconds=tonumber(E.C.OW_FOLLOWERS_IDLE_TIME) or 3
    return math.floor(math.max(0,math.min(60,seconds))*60+.5)
  end
  local function mode()
    if E.C.OW_FOLLOWERS_BOUNCE_WAVE then return 'bounce_wave' end
    if E.C.OW_FOLLOWERS_SPIN_WAVE then return 'spin_wave' end
    if E.C.OW_FOLLOWERS_PULSE_WAVE then return 'pulse_wave' end
    if E.C.OW_FOLLOWERS_COPYCAT then return 'copycat' end
    if E.C.OW_FOLLOWERS_LOOK_AROUND then return 'look' end
    if E.C.OW_FOLLOWERS_JUMP then return 'jump' end
    if E.C.OW_FOLLOWERS_JUMP_WAVE then return 'jump_wave' end
    if E.C.OW_FOLLOWERS_CHEER then return 'cheer' end
    if E.C.OW_FOLLOWERS_STRETCH then return 'stretch' end
  end
  local mixedModes={'look','jump','jump_wave','cheer','stretch','zoomies','copycat','bounce_wave','spin_wave','pulse_wave'}
  local mixedPair
  local randomModes={'look','jump','jump_wave','cheer','stretch','doze','wander','play','zoomies','copycat','bounce_wave','spin_wave','pulse_wave'}
  local waveModes={'jump_wave','bounce_wave','spin_wave','pulse_wave'}
  local randomChoice,randomKind
  local dances={}
  local danceModes={bounce_wave=true,spin_wave=true,pulse_wave=true}
  local mixedKeys={OW_FOLLOWERS_BOUNCE_WAVE='bounce_wave',OW_FOLLOWERS_SPIN_WAVE='spin_wave',OW_FOLLOWERS_PULSE_WAVE='pulse_wave',OW_FOLLOWERS_ZOOMIES='zoomies',OW_FOLLOWERS_COPYCAT='copycat',OW_FOLLOWERS_SLEEPY_BUDDY='sleepy_buddy',OW_FOLLOWERS_LOOK_AROUND='look',OW_FOLLOWERS_JUMP='jump',
    OW_FOLLOWERS_JUMP_WAVE='jump_wave',OW_FOLLOWERS_CHEER='cheer',
    OW_FOLLOWERS_STRETCH='stretch'}
  local randomKeys={}
  for key,value in pairs(mixedKeys)do randomKeys[key]=value end
  randomKeys.OW_FOLLOWERS_SLEEPY_BUDDY=nil
  randomKeys.OW_FOLLOWERS_DOZE='doze'
  randomKeys.OW_FOLLOWERS_WANDER='wander'
  randomKeys.OW_FOLLOWERS_PLAY='play'
  function M.modeFor(a)
    if E.C.OW_FOLLOWERS_MIXED then return a and a.mixedIdle end
    if E.C.OW_FOLLOWERS_RANDOM or E.C.OW_FOLLOWERS_RANDOM_WAVE then return randomChoice end
    return mode()
  end
  function M.enabled(key,a)
    if E.C.OW_FOLLOWERS_MIXED then return a and mixedKeys[key]~=nil and a.mixedIdle==mixedKeys[key] end
    if E.C.OW_FOLLOWERS_RANDOM or E.C.OW_FOLLOWERS_RANDOM_WAVE then return randomKeys[key]~=nil and randomChoice==randomKeys[key] end
    return E.C[key]
  end
  local function eligible(a)
    local c=a.nativeCore
    return E.C.OW_FOLLOWERS_ENABLED and a.active and not a.invisible
      and not a.moving and not a.independent and not a.ballGfx and not a.affine
      and a.emote<0 and not a.tType and not E.Player.moving and not E.Player.jumping
      and not E.controlsLocked() and E.followerVisible() and c and not c.talking()
      and (a.act==c.A.NONE or a.act==c.A.IN_PLACE)
  end
  function M.cancel(a)a.idleTicks=nil;a.idleMode=nil end
  local wave
  local copycat
  function M.beginTick(order)
    local interrupted=not E.C.OW_FOLLOWERS_ENABLED or E.Player.moving
      or E.Player.jumping or E.controlsLocked() or not E.followerVisible()
    local kind=E.C.OW_FOLLOWERS_RANDOM and 'all' or E.C.OW_FOLLOWERS_RANDOM_WAVE and 'wave' or nil
    if interrupted or not kind or E.C.OW_FOLLOWERS_MIXED then randomChoice=nil;randomKind=nil
    else
      if randomKind~=kind then randomChoice=nil;randomKind=kind end
      if not randomChoice then
        local choices=kind=='wave' and waveModes or randomModes
        for _,a in ipairs(order)do if eligible(a) then
          randomChoice=choices[math.random(#choices)];break
        end end
      end
    end
    if interrupted or not E.C.OW_FOLLOWERS_MIXED then mixedPair=nil
    else
      local function present(a)
        for _,b in ipairs(order)do
          if b==a then
            return a.active and not a.invisible and not a.ballGfx and not a.affine
              and a.emote<0 and not a.tType and a.nativeCore and not a.nativeCore.talking()
          end
        end
      end
      if mixedPair and (not present(mixedPair[1]) or not present(mixedPair[2])) then mixedPair=nil end
      if not mixedPair then
        local pairs={}
        for i,a in ipairs(order)do if eligible(a) then
          for j=i+1,#order do
            local b=order[j]
            if eligible(b) and math.abs(a.cellX-b.cellX)+math.abs(a.cellY-b.cellY)<=6 then
              pairs[#pairs+1]={a,b}
            end
          end
        end end
        if #pairs>0 then mixedPair=pairs[math.random(#pairs)] end
      end
    end
    local members={}
    for _,a in ipairs(order) do
      if interrupted or not E.C.OW_FOLLOWERS_MIXED then
        a.mixedIdle=nil
      elseif mixedPair and (a==mixedPair[1] or a==mixedPair[2]) then
        a.mixedIdle='sleepy_buddy'
      elseif a.mixedIdle=='sleepy_buddy' or a.mixedIdle=='doze'
          or a.mixedIdle=='play' or a.mixedIdle=='wander' then
        a.mixedIdle=nil
      end
      if not interrupted and E.C.OW_FOLLOWERS_MIXED and eligible(a) and not a.mixedIdle then
        a.mixedIdle=mixedModes[math.random(#mixedModes)]
      end
      -- Invisible/ball/busy followers must not hold the entire line's
      -- wave at zero. Synchronize only the currently ready participants.
      if not interrupted and M.modeFor(a)=='jump_wave' and eligible(a) then
        members[#members+1]=a
      end
    end
    -- One clock per choreography, shared by its ready participants. Hidden
    -- or busy followers cannot hold up the visible group.
    for name in pairs(danceModes)do
      local list={}
      for _,a in ipairs(order)do
        if not interrupted and M.modeFor(a)==name and eligible(a) then list[#list+1]=a end
      end
      local old=dances[name];local changed=not old or #old.order~=#list
      for i,a in ipairs(list)do
        if old and (old.order[i]~=a or old.species[i]~=a.species) then changed=true end
      end
      if #list==0 then dances[name]=nil
      elseif changed then
        local species={};for i,a in ipairs(list)do species[i]=a.species end
        dances[name]={ticks=1,order=list,species=species}
      else old.ticks=old.ticks+1 end
    end
    local copies={}
    for _,a in ipairs(order)do if not interrupted and M.modeFor(a)=='copycat' and eligible(a) then copies[#copies+1]=a end end
    local changed=not copycat or #copycat.order~=#copies
    for i,a in ipairs(copies)do if copycat and copycat.order[i]~=a then changed=true end end
    if #copies==0 then copycat=nil
    elseif changed then copycat={ticks=1,order=copies}
    else copycat.ticks=copycat.ticks+1 end
    if #members==0 then wave=nil;return end
    local changed=not wave or #wave.order~=#members
    for i,a in ipairs(members) do
      if wave and (wave.order[i]~=a or wave.species[i]~=a.species) then changed=true end
    end
    if changed then
      wave={ticks=0,order={},species={}}
      for i,a in ipairs(members) do wave.order[i]=a;wave.species[i]=a.species end
    end
    wave.ticks=wave.ticks+1
  end
  function M.tick(a)
    local chosen=M.modeFor(a)
    if not chosen or not eligible(a) then M.cancel(a);return end
    if a.idleMode~=chosen then a.idleTicks=0;a.idleMode=chosen end
    a.idleTicks=(a.idleTicks or 0)+1
  end
  function M.age(a)
    local chosen=M.modeFor(a)
    if not chosen or chosen~=a.idleMode or not a.idleTicks or not eligible(a) then return end
    if danceModes[chosen] then
      local d=dances[chosen];if not d then return end
      local t=d.ticks-M.delay();if t<0 then return end
      local owner=a.nativeActor or a
      for i,b in ipairs(d.order)do if b==owner then
        local rank=math.floor(t/240)%2==0 and i-1 or #d.order-i
        local phase=t%240-rank*18
        return phase>=0 and phase or 239,chosen
      end end
      return
    end
    if chosen=='copycat' then
      if not copycat then return end
      local owner=a.nativeActor or a
      for i,b in ipairs(copycat.order)do if b==owner then
        local t=copycat.ticks-M.delay()-(i-1)*24
        if t>=0 then return t,chosen end
      end end
      return
    end
    if chosen=='jump_wave' then
      if not wave then return end
      local t=wave.ticks-M.delay()
      if t<0 then return end
      local index
      local owner=a.nativeActor or a
      for i,member in ipairs(wave.order) do if member==owner then index=i;break end end
      if not index then return end
      -- A shared round clock keeps every follower on the same direction.
      local rank=math.floor(t/300)%2==0 and index-1 or #wave.order-index
      local phase=t%300-rank*24
      return phase>=0 and phase or 299,chosen
    end
    local stagger=(a.followSlot or 1)-1
    local t=a.idleTicks-M.delay()-stagger*(chosen=='jump' and 12 or 18)
    if t>=0 then return t,chosen end
  end
  local left={up='left',left='down',down='right',right='up'}
  local right={up='right',right='down',down='left',left='up'}
  local function faceTrainer(a)
    local x,y=E.Player.px-a.px,E.Player.py-a.py
    if x==0 and y==0 then return a.facing end
    return math.abs(x)>math.abs(y) and (x<0 and 'left' or 'right') or (y<0 and 'up' or 'down')
  end
  function M.scale(a)
    local t,chosen=M.age(a)
    if chosen=='pulse_wave' then
      local amount=0
      if t<12 then amount=-.16*math.sin(math.pi*t/12)
      elseif t<48 then amount=.20*math.sin(math.pi*(t-12)/36) end
      return 1-amount*.6,1+amount
    end
    if chosen~='stretch' then return 1,1 end
    local phase=t%420
    local amount=0
    if phase<36 then amount=-math.sin(math.pi*phase/36)*.10
    elseif phase>=48 and phase<108 then amount=math.sin(math.pi*(phase-48)/60)*.10 end
    return 1-amount*.5,1+amount
  end
  function M.pose(a)
    if E.Social then local dir,y,hop=E.Social.pose(a);if dir then return dir,y,hop end end
    if E.Play then
      local dir,y,hop=E.Play.pose(a)
      if dir then return dir,y,hop end
    end
    local t,chosen=M.age(a)
    if not t then return end
    if chosen=='doze' or chosen=='wander' or chosen=='play' then return end
    local facing=a.facing or 'down'
    if chosen=='pulse_wave' then return facing,0,false end
    if chosen=='bounce_wave' then
      local hop,height=t,6
      if t>=32 then hop,height=t-32,9 end
      local y=hop>=0 and hop<24 and -math.floor(height*math.sin(math.pi*hop/24)+.5) or 0
      return facing,y,hop<24
    end
    if chosen=='spin_wave' then
      local dir=facing
      if t<48 then for _=1,math.floor(t/12)+1 do dir=right[dir] or dir end end
      local hop=t-48
      return dir,hop>=0 and hop<24 and -math.floor(5*math.sin(math.pi*hop/24)+.5) or 0,hop>=0 and hop<24
    end
    if chosen=='copycat' then
      local phase=t%420
      if phase<24 then return left[facing] or facing,0,false end
      if phase<48 then return right[facing] or facing,0,false end
      local hop=phase-48
      return facing,hop<24 and -math.floor(7*math.sin(math.pi*hop/24)+.5) or 0,hop<24
    end
    if chosen=='look' then
      local phase=t%300
      local first=math.floor(t/300)+(a.followSlot or 1)
      local firstSide=first%2==0 and left or right
      local secondSide=first%2==0 and right or left
      if phase<36 then facing=firstSide[facing] or facing
      elseif phase>=66 and phase<102 then facing=secondSide[facing] or facing end
      return facing,0,false
    end
    if chosen=='stretch' then return facing,0,false end
    if chosen=='cheer' then
      local phase=t%360;local y=0
      if phase<18 then y=-math.floor(5*math.sin(math.pi*phase/18)+.5)
      elseif phase>=30 and phase<48 then y=-math.floor(7*math.sin(math.pi*(phase-30)/18)+.5) end
      return faceTrainer(a),y,true
    end
    -- One 24-frame hop per follower, staggered along the line, then a rest.
    local phase=t%300
    local y=0
    if phase<24 then y=-math.floor(8*math.sin(math.pi*phase/24)+.5) end
    return facing,y,true
  end
  local queue={}
  function M.clearQueue()for i=#queue,1,-1 do queue[i]=nil end end
  function M.queue(a,sx,sy,frame)
    if E.redrawing then return end
    local t,chosen=M.age(a)
    if chosen~='cheer' or t%360>=84 then return end
    queue[#queue+1]={a,sx,sy,frame,t%360}
  end
  function M.flush()
    if #queue==0 then return end
    local G=love.graphics;local shader=G.getShader();local cr,cg,cb,ca=G.getColor()
    G.setShader()
    local glyph={{1,0,1,1},{3,0,1,1},{0,1,5,1},{1,2,3,1},{2,3,1,1}}
    for _,q in ipairs(queue)do
      local a=q[1];local age=q[5]
      local height=E.Data.ATLAS.sheets[(a.sheet-1)*6+4]
      local h=heads and heads[a.sheet]
      local top=E.SpriteSets.head(a,q[4]) or (16-height+(h and h[math.floor(q[4]/2)+1] or 0))
      local x,y=q[2]+6,q[3]+top-7-math.floor(age/12)
      G.setColor(.95,.30,.48,math.min(1,age/8,(84-age)/20)*.85)
      for _,r in ipairs(glyph)do G.rectangle('fill',x+r[1],y+r[2],r[3],r[4]) end
    end
    G.setShader(shader);G.setColor(cr,cg,cb,ca);M.clearQueue()
  end
  return M
end
