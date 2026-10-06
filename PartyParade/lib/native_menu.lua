-- Native OPTION pages also synchronize preferences with an enabled KantoHoenn campaign.
return function(E,mod,schema)
 function E.syncCampaignSettings()
  if E.captureSharedSettings then E.captureSharedSettings() end
  if E.onSettingsChanged then E.onSettingsChanged() end
  local other=mod.find and mod:find('kanto_hoenn')
  local sync=other and other.exports and other.exports.syncWildFollowersOptions
  if type(sync)=='function' then sync() end
 end
 local Rows=require('src.ui.game3.option_rows')
 local Options=require('src.core.game3.options')
 local keys={follower_trainer_spacing='wildsG3TrainerSpacing',follower_spacing='wildsG3FollowerSpacing',follower_count='wildsG3FollowerCount',OW_FOLLOWERS_ENABLED='wildsG3Follower',
 follower_sprite_set='wildsG3FollowerSpriteSet',land_sprite_set='wildsG3LandSpriteSet',water_sprite_set='wildsG3WaterSpriteSet',
 spawn_density='wildsFrDensity',spawn_range='wildsG3Range',
 OW_FOLLOWERS_RUN_TO_CATCH_UP='wildsG3FollowerRunToCatchUp',
 OW_FOLLOWERS_IDLE_WALK='wildsG3FollowerIdleWalk',
 OW_FOLLOWERS_DOZE='wildsG3FollowerDoze',
 OW_FOLLOWERS_IDLE_TIME='wildsG3FollowerIdleDelay',
 OW_FOLLOWERS_LOOK_AROUND='wildsG3FollowerLookAround',
 OW_FOLLOWERS_JUMP='wildsG3FollowerJump',
 OW_FOLLOWERS_JUMP_WAVE='wildsG3FollowerJumpWave',
 OW_FOLLOWERS_MIXED='wildsG3FollowerMixed',
 OW_FOLLOWERS_RANDOM='wildsG3FollowerRandom',
 OW_FOLLOWERS_RANDOM_WAVE='wildsG3FollowerRandomWave',
 OW_FOLLOWERS_BOUNCE_WAVE='wildsG3FollowerBounceWave',
 OW_FOLLOWERS_SPIN_WAVE='wildsG3FollowerSpinWave',
 OW_FOLLOWERS_PULSE_WAVE='wildsG3FollowerPulseWave',
 OW_FOLLOWERS_ZOOMIES='wildsG3FollowerZoomies',OW_FOLLOWERS_COPYCAT='wildsG3FollowerCopycat',
 OW_FOLLOWERS_SLEEPY_BUDDY='wildsG3FollowerSleepyBuddy',
 OW_FOLLOWERS_PLAY='wildsG3FollowerPlay',OW_FOLLOWERS_CHEER='wildsG3FollowerCheer',OW_FOLLOWERS_STRETCH='wildsG3FollowerStretch',
 OW_FOLLOWERS_WANDER='wildsG3FollowerWander',
 OW_FOLLOWERS_WANDER_SPEED='wildsG3FollowerWanderSpeed',
 OW_FOLLOWERS_WANDER_RANGE='wildsG3FollowerWanderRange',
 OW_FOLLOWERS_ARRIVAL_BALLS='wildsG3FollowerArrivalBalls',
 WE_OW_ENCOUNTERS='wildsFrEnabled',WE_OW_WATER='wildsG3WaterWilds',
 WE_OWE_INITIATE_BATTLES='wildsG3WildsInitiate',WE_VANILLA_RANDOM='wildsFrRandom'}
 local follower,wild,idle={},{},{}
 local idleKeys={OW_FOLLOWERS_BOUNCE_WAVE=true,OW_FOLLOWERS_SPIN_WAVE=true,OW_FOLLOWERS_PULSE_WAVE=true,OW_FOLLOWERS_ZOOMIES=true,OW_FOLLOWERS_COPYCAT=true,OW_FOLLOWERS_SLEEPY_BUDDY=true,OW_FOLLOWERS_IDLE_WALK=true,OW_FOLLOWERS_IDLE_TIME=true,
 OW_FOLLOWERS_DOZE=true,OW_FOLLOWERS_WANDER=true,OW_FOLLOWERS_LOOK_AROUND=true,
 OW_FOLLOWERS_JUMP=true,OW_FOLLOWERS_JUMP_WAVE=true,OW_FOLLOWERS_MIXED=true,OW_FOLLOWERS_RANDOM=true,OW_FOLLOWERS_RANDOM_WAVE=true,OW_FOLLOWERS_PLAY=true,OW_FOLLOWERS_CHEER=true,
 OW_FOLLOWERS_STRETCH=true,OW_FOLLOWERS_WANDER_SPEED=true,OW_FOLLOWERS_WANDER_RANGE=true}
 local idleIds={}

 local function block(c)
  c.options=c.options or {};return Options.block(c.options)
 end
 for _,row in ipairs(schema)do
  row.nativeKey=keys[row.key] or ('wildsNative_'..row.key)
  if idleKeys[row.key] then idleIds[row.nativeKey]=true end
  local group=idleKeys[row.key] and idle or (row.key:match('^follower_') or row.key:match('^OW_FOLLOWERS_')) and follower or wild
  group[#group+1]=row.nativeKey
 end
 follower[#follower+1]='wildsG3IdleBehaviors'
 E.nativeOptionSchema=schema
 for _,g in ipairs({{id='group.wildFollowersFollowers',label='PARTY PARADE',members=follower}})do
  Rows.GROUPS[#Rows.GROUPS+1]=g;Rows.ORDER[#Rows.ORDER+1]=g.id
 end
 -- Native pages already support an activate callback and page stack in
 -- FR/LG and Emerald. Nest the idle launcher in FOLLOWERS without a second
 -- top-level group or a custom menu implementation.
 local rawGroup=Rows.group
 Rows.group=function(rows,openPage)
  local flat,children={},{}
  for _,row in ipairs(rows)do
   if idleIds[row.id] then children[#children+1]=row else flat[#flat+1]=row end
  end
  if #children>0 then
   flat[#flat+1]={id='wildsG3IdleBehaviors',label='IDLE BEHAVIORS',group=true,
    value=function()return tostring(#children)..' OPTIONS' end,
    activate=function()openPage('IDLE BEHAVIORS',children)end}
  end
  return rawGroup(flat,openPage)
 end
 local raw=Rows.build
 Rows.build=function(c)
  local rows=raw(c) or {}
  for _,def in ipairs(schema)do
   local row=def
   local function value(ctx)
    local b=block(ctx);if b[row.nativeKey]==nil then b[row.nativeKey]=row.default end
    if row.key:match('sprite_set$') and b[row.nativeKey]~='g9rp' then b[row.nativeKey]='untamed' end
    return b[row.nativeKey]
   end
   rows[#rows+1]={id=row.nativeKey,label=row.label:upper(),
    value=function(ctx)
     local v=value(ctx);if row.type=='toggle' then return v and 'ON' or 'OFF' end
     for _,choice in ipairs(row.choices or {})do if choice[2]==v then return choice[1]:upper()end end
     return tostring(v):upper()
    end,
    step=function(ctx,dir)
     local v=value(ctx);local b=block(ctx)
     if row.type=='toggle' then
      b[row.nativeKey]=not v
      if b[row.nativeKey] then
       E.Idle.select(b,row.key)
      end
     else
      local choices=row.choices or {};local at=1
      for i,choice in ipairs(choices)do if choice[2]==v then at=i;break end end
      b[row.nativeKey]=choices[(at-1+((dir or 1)<0 and -1 or 1))%#choices+1][2]
     end
     E.syncCampaignSettings()
     return true
    end}
  end
  return rows
 end
end
