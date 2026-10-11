-- Living populations use only sampled encounters and the controller's legal
-- movement path. No damage, species conversion, teleporting or forced battles.
return function(mod,include)
  local A,W,D=include('adapter'),include('areas'),include('ecology_data')
  local E={groups={},present={},age=0,planIn=0}
  local directions={{0,-1},{0,1},{-1,0},{1,0}}
  local slots={{-1,1},{1,1},{0,2}}
  local function option(k)return mod.options:get(k)~=false end
  local function distance(a,b)return math.abs(a.cellX-b.cellX)+math.abs(a.cellY-b.cellY) end
  local function family(e)return D.familyOf(e.national) end
  local function stage(e)return D.stage[e.national] or 1 end
  local function alive(e)return e and not e.follower and not e.retired and not e.hidden end
  local function compatible(a,b)
    return a~=b and alive(b) and E.present[b] and a.sourceMap==b.sourceMap and a.surface==b.surface
      and (a.currentElevation or a.elevation)==(b.currentElevation or b.elevation)
  end
  local function hunts(a,b)return D.hunts(a.national,b.national) end
  local function friendly(a,b)return not hunts(a,b) and not hunts(b,a) end
  local function outranks(a,b)
    if stage(a)~=stage(b) then return stage(a)>stage(b) end
    if (a.level or 1)~=(b.level or 1) then return (a.level or 1)>(b.level or 1) end
    return tostring(a.id)<tostring(b.id)
  end
  local function key(e)return tostring(e.sourceMap)..':'..tostring(e.surface) end
  local function face(e,other)
    local dx,dy=other.cellX-e.cellX,other.cellY-e.cellY
    if dx==0 and dy==0 then return end
    e.facing=math.abs(dx)>math.abs(dy) and (dx>0 and 'right' or 'left') or (dy>0 and 'down' or 'up')
  end
  local function wake(e)
    local s=e.ecology
    s.sleepLeft=nil;e.idlePose=nil;s.restIn=math.max(s.restIn,30)
    s.activity=nil;s.activityLeft=nil
  end
  function E:state(e)
    if not e.ecology then
      e.ecology={homeX=e.cellX-(e.areaOffsetX or 0),homeY=e.cellY-(e.areaOffsetY or 0),
        next=math.random()*.35,restIn=65+math.random()*85,mode='wander',
        activityIn=2+math.random()*6,playIn=8+math.random()*10}
    end
    return e.ecology
  end
  function E:prepare(actors,dt)
    self.enabled=option('living_ecosystems');self.groups={};self.present={}
    self.age=self.age+(dt or 1/60);self.planIn=self.planIn-(dt or 1/60)
    local changed=false
    for _,e in ipairs(actors)do
      if not self.enabled or not alive(e) then
        if e.ecology then e.ecology=nil;e.idlePose=nil;e.idle=0;changed=true end
      else
        self.present[e]=true
        if not e.ecology then changed=true end
        self:state(e)
        local k=key(e);self.groups[k]=self.groups[k] or {};table.insert(self.groups[k],e)
      end
    end
    local signature=''
    for _,e in ipairs(actors)do if alive(e)then signature=signature..tostring(e.id)..',' end end
    if signature~=self.signature then changed=true;self.signature=signature end
    local grouping=option('ecosystem_groups')
    if grouping~=self.grouping then changed=true;self.grouping=grouping end
    if not self.enabled then self.planIn=0;return end
    if self.planIn>0 and not changed then return end
    self.planIn=1
    for _,list in pairs(self.groups)do
      table.sort(list,outranks)
      for _,e in ipairs(list)do e.ecology.band=nil;e.ecology.rank=nil end
      if grouping then
        for _,leader in ipairs(list)do
          if not leader.ecology.band then
            local band={leader=leader,members={leader}}
            -- Family members get first choice; peaceful mixed-species herds
            -- fill sparse encounter pools without inventing new Pokemon.
            for pass=1,2 do for _,other in ipairs(list)do
              if #band.members<4 and not other.ecology.band and compatible(leader,other)
                  and distance(leader,other)<=10 and (family(leader)==family(other))==(pass==1) then
                local safe=true
                for _,member in ipairs(band.members)do if not friendly(member,other)then safe=false;break end end
                if safe then
                  band.members[#band.members+1]=other;other.ecology.band=band
                  other.ecology.rank=#band.members-1
                end
              end
            end end
            if #band.members>1 then leader.ecology.band=band end
          end
        end
      end
    end
  end
  function E:room(C,e,x,y)
    local s=self:state(e)
    local sx,sy=x-(e.areaOffsetX or 0),y-(e.areaOffsetY or 0)
    return math.abs(sx-s.homeX)+math.abs(sy-s.homeY)<=8
      and W:habitat(e,x,y) and W:allowed(e,x,y) and not C:occupied(x,y,e)
  end
  function E:travel(C,e,x,y,away,duration)
    local choices={}
    for i,d in ipairs(directions)do
      local tx,ty=e.cellX+d[1],e.cellY+d[2]
      local score=away and ((tx-x)^2+(ty-y)^2) or math.abs(tx-x)+math.abs(ty-y)
      choices[i]={x=tx,y=ty,score=away and -score or score,order=i}
    end
    table.sort(choices,function(a,b)return a.score<b.score or a.score==b.score and a.order<b.order end)
    local before=away and ((e.cellX-x)^2+(e.cellY-y)^2) or math.abs(e.cellX-x)+math.abs(e.cellY-y)
    for _,c in ipairs(choices)do
      if (away and -c.score>before or not away and c.score<before) and self:room(C,e,c.x,c.y)
          and C:move(e,c.x,c.y,duration or .24) then e.ecology.blocked=0;return true end
    end
    e.ecology.blocked=(e.ecology.blocked or 0)+1
    return false
  end
  function E:wander(C,e)
    local first=math.random(1,4)
    for i=0,3 do
      local d=directions[(first+i-1)%4+1];local x,y=e.cellX+d[1],e.cellY+d[2]
      if self:room(C,e,x,y) and C:move(e,x,y,.28) then return true end
    end
    return false
  end
  function E:spawn(area,kind,hit,actors)
    if not option('living_ecosystems') or not (option('ecosystem_groups') or option('ecosystem_chases')) then return hit end
    local anchors={}
    for _,e in ipairs(actors or {})do
      if alive(e) and e.surface==kind then anchors[#anchors+1]=e end
    end
    if #anchors==0 then return hit end
    local preferChase=#anchors%3==2 and option('ecosystem_chases')
    local function score(candidate)
      if not candidate or A:repelled(candidate.level) then return -1 end
      local n=A:national(candidate.species);if not n then return -1 end
      local best,anchor=0,nil
      for _,e in ipairs(anchors)do
        local value=0
        local relative=D.familyOf(n)==family(e)
        local chase=D.hunts(n,e.national) or D.hunts(e.national,n)
        if option('ecosystem_groups') and relative then value=preferChase and 5 or 10
        elseif option('ecosystem_chases') and chase then value=preferChase and 12 or 6
        elseif option('ecosystem_groups') then value=2 end
        if value>best then best,anchor=value,e end
      end
      return best,anchor
    end
    local best,anchor=score(hit);local selected=hit
    -- Small bounded sampling budget, through the actual current source provider.
    -- Never clone an old actor or inject an unavailable relative/predator.
    for _=1,4 do
      if best>=(preferChase and 12 or 10) then break end
      local candidate=A:choose(kind,math.random,area)
      local value,target=score(candidate)
      if value>best and A:national(candidate.species)~=924 then best,anchor,selected=value,target,candidate end
    end
    return selected,anchor
  end
  function E:step(C,e,dt)
    if not self.enabled or not alive(e) then return false end
    local s=self:state(e)
    s.next=s.next-dt;s.restIn=s.restIn-dt;s.activityIn=s.activityIn-dt;s.playIn=s.playIn-dt
    s.cooldown=math.max(0,(s.cooldown or 0)-dt)
    s.chaseLeft=math.max(0,(s.chaseLeft or 0)-dt)
    s.playLeft=math.max(0,(s.playLeft or 0)-dt)
    if s.chasing and (not option('ecosystem_chases') or not compatible(e,s.chasing)
        or s.chaseLeft<=0 or distance(e,s.chasing)>10 or (s.blocked or 0)>=4) then
      s.chasing=nil;s.cooldown=12+math.random()*8
    end
    if s.playTarget and (not option('ecosystem_variety') or not compatible(e,s.playTarget) or s.playLeft<=0) then
      s.playTarget=nil;s.playIn=12+math.random()*12
    end
    if s.activityLeft then
      s.activityLeft=s.activityLeft-dt
      if s.activityLeft<=0 or not option('ecosystem_variety') then s.activityLeft=nil;s.activity=nil;e.idlePose=nil end
    end
    if s.sleepLeft then
      s.sleepLeft=s.sleepLeft-dt
      if s.sleepLeft<=0 or not option('ecosystem_rest') then
        wake(e);s.restIn=75+math.random()*90;s.mode='wander'
      else
        local t=e.clock or 0;e.idlePose={sleep=true,sx=1+math.sin(t*2)*.018,sy=1-math.sin(t*2)*.035}
      end
    end
    if e.moving or s.next>0 then return true end
    s.next=.35+math.random()*.2
    local nearby=self.groups[key(e)] or {}
    local predator,prey,juvenile,guardian
    for _,other in ipairs(nearby)do
      if compatible(e,other) and distance(e,other)<=10 then
        if option('ecosystem_chases') then
          local active=other.ecology and other.ecology.chasing==e
          if hunts(other,e) and (active or distance(e,other)<=3)
              and (not predator or distance(e,other)<distance(e,predator)) then predator=other end
          if hunts(e,other) and (not prey or distance(e,other)<distance(e,prey)) then prey=other end
        end
        if option('ecosystem_groups') and friendly(e,other) then
          if stage(other)<stage(e) and distance(e,other)<=6
              and (family(other)==family(e) or D.timid[other.national] or stage(other)==1 and D.family[other.national])
              and (not juvenile or distance(e,other)<distance(e,juvenile)) then juvenile=other end
          if stage(other)>stage(e) and distance(e,other)<=4
              and (family(other)==family(e) or D.timid[e.national] or stage(e)==1 and D.family[e.national])
              and (not guardian or distance(e,other)<distance(e,guardian)) then guardian=other end
        end
      end
    end
    local p=A:player()
    local playerNear=p and e.currentEligible~=false and e.surface=='land'
      and (p.currentElevation or p.elevation)==(e.currentElevation or e.elevation) and distance(e,p)<=3
    if s.sleepLeft and playerNear then wake(e) end
    local threat=predator or option('ecosystem_timidity') and D.timid[e.national] and playerNear and p
    if threat then
      wake(e);s.mode='flee';s.chasing=nil;s.cooldown=10;s.next=.12
      if guardian and threat~=p and distance(e,guardian)>1 then
        s.mode='seek_guardian';self:travel(C,e,guardian.cellX,guardian.cellY,false,.18)
      else self:travel(C,e,threat.cellX,threat.cellY,true,.18) end
      return true
    end
    if juvenile then
      local danger
      for _,other in ipairs(nearby)do
        if option('ecosystem_chases') and compatible(e,other) and hunts(other,juvenile)
            and distance(juvenile,other)<=7 then danger=other;break end
      end
      if danger then
        wake(e);s.mode='protect';s.next=.16;face(e,danger)
        local dx,dy=danger.cellX-juvenile.cellX,danger.cellY-juvenile.cellY
        local gx,gy=juvenile.cellX,juvenile.cellY
        if math.abs(dx)>math.abs(dy) then gx=gx+(dx>0 and 1 or -1) else gy=gy+(dy>0 and 1 or -1) end
        self:travel(C,e,gx,gy,false,.22);return true
      end
    end
    if option('ecosystem_chases') and (s.chasing or prey and s.cooldown<=0) then
      wake(e)
      if not s.chasing then s.chasing=prey;s.chaseLeft=5+math.random()*3;s.blocked=0 end
      local target=s.chasing;local defender
      for _,other in ipairs(nearby)do
        if compatible(e,other) and other~=target and stage(other)>stage(target)
            and friendly(other,target) and distance(target,other)<=3 and distance(e,other)<=2 then defender=other;break end
      end
      if defender then
        s.mode='back_off';s.chasing=nil;s.cooldown=12;s.next=.2
        self:travel(C,e,defender.cellX,defender.cellY,true,.24)
      else
        s.mode='stalk';s.next=.12;face(e,target)
        if distance(e,target)>1 then self:travel(C,e,target.cellX,target.cellY,false,.22)
        else s.chasing=nil;s.cooldown=12+math.random()*8;s.mode='watch' end
      end
      return true
    end
    if s.sleepLeft then s.mode='rest';return true end
    local band=s.band;local leader=band and band.leader
    if leader and not compatible(e,leader) and leader~=e then band=nil;leader=nil end
    if option('ecosystem_variety') then
      local playFrom=s.playFrom
      if playFrom and (not compatible(e,playFrom) or not playFrom.ecology or playFrom.ecology.playTarget~=e) then s.playFrom=nil;playFrom=nil end
      if playFrom then
        wake(e);s.mode='play_run';s.next=.16
        if distance(e,playFrom)<4 then self:travel(C,e,playFrom.cellX,playFrom.cellY,true,.24) else face(e,playFrom) end
        return true
      end
      if s.playTarget then
        wake(e);s.mode='play_chase';s.next=.16
        if distance(e,s.playTarget)>1 then self:travel(C,e,s.playTarget.cellX,s.playTarget.cellY,false,.24)
        else s.playTarget=nil;s.playIn=12+math.random()*12 end
        return true
      end
      if band and s.playIn<=0 then
        for _,other in ipairs(band.members)do
          local os=other.ecology
          if compatible(e,other) and os and not os.sleepLeft and not os.playTarget and not os.playFrom
              and distance(e,other)<=4 and not s.playFrom then
            s.playTarget=other;s.playLeft=3+math.random()*2;os.playFrom=e;s.playIn=15;break
          end
        end
        if not s.playTarget then s.playIn=5 end
      end
    else s.playTarget=nil;s.playFrom=nil end
    if juvenile and distance(e,juvenile)>3 then
      s.mode='escort';s.next=.25
      if self:travel(C,e,juvenile.cellX,juvenile.cellY,false,.25) then return true end
    end
    if leader and leader~=e then
      local at=slots[s.rank or 1] or slots[1]
      local tx,ty=leader.cellX+at[1],leader.cellY+at[2]
      if math.abs(e.cellX-tx)+math.abs(e.cellY-ty)>1 then
        wake(e);s.mode=stage(leader)>stage(e) and 'shelter' or 'group';s.next=.22
        if self:travel(C,e,tx,ty,false,.25) then return true end
        if (s.blocked or 0)>=3 then self:wander(C,e);s.blocked=0 end
        return true
      end
    end
    -- At most one sleeper per source habitat, short and infrequent. Leaders
    -- stay awake while responsible for a group; active social work wins.
    if option('ecosystem_rest') and s.restIn<=0 and leader~=e and not s.playTarget then
      local sleeping=false
      for _,other in ipairs(nearby)do if other.ecology and other.ecology.sleepLeft then sleeping=true;break end end
      s.restIn=65+math.random()*85
      if not sleeping and math.random()<.3 then
        s.mode='rest';s.sleepLeft=3+math.random()*2;e.idlePose={sleep=true,sx=1,sy=.98};return true
      end
    end
    if option('ecosystem_variety') and s.activityIn<=0 and not s.activityLeft then
      s.activity=math.random()<.65 and 'forage' or 'look';s.activityLeft=1.2+math.random()*1.8
      s.activityIn=5+math.random()*8
    end
    if s.activityLeft then
      s.mode=s.activity
      if s.activity=='forage' then
        local t=e.clock or 0;e.idlePose={sx=1+.035*math.sin(t*8),sy=1-.08*math.abs(math.sin(t*4))}
      else
        e.idlePose=nil;e.facing=({'up','right','down','left'})[math.floor((e.clock or 0)*2)%4+1]
      end
      return true
    end
    e.idlePose=nil
    if leader and leader~=e then
      s.mode=stage(leader)>stage(e) and 'shelter' or 'group';face(e,leader);return true
    end
    s.mode=juvenile and 'guard' or leader==e and 'lead' or 'wander'
    s.next=.55+math.random()*.35
    if math.random()<.8 then self:wander(C,e) end
    return true
  end
  return E
end
