local function spacingChoices()
  local choices={}
  for tenth=10,40 do
    local value=string.format('%.1f',tenth/10)
    choices[#choices+1]={value..' TILES',tonumber(value)}
  end
  return choices
end
return {
  {key='enabled',label='Enabled',type='toggle',default=true},
  {key='OW_FOLLOWERS_ENABLED',label='Followers',type='toggle',default=true},
  {key='OW_FOLLOWERS_PLAYER_YIELD',label='Yield to player',type='toggle',default=true},
  {key='follower_sprites',label='Follower sprites',type='choice',default='g9',choices={{'G9','g9'},{'EE','ee'}}},
  {key='smart_spacing',label='SMART SPACING',type='toggle',default=false},
  {key='followers_march',label='FOLLOWERS MARCH',type='toggle',default=false},
  {key='followers_march_speed',label='FOLLOWERS MARCH SPEED',type='choice',default=1,choices={{'10%',.1},{'20%',.2},{'25%',.25},{'33%',.33},{'50%',.5},{'75%',.75},{'100%',1},{'125%',1.25},{'150%',1.5},{'200%',2},{'300%',3}}},
  {key='OW_FOLLOWERS_TRAINER_SPACING',label='Trainer spacing',type='choice',default=1,choices=spacingChoices()},
  {key='OW_FOLLOWERS_SPACING',label='Follower spacing',type='choice',default=1,choices=spacingChoices()},
  {key='OW_FOLLOWERS_POKEBALLS',label='Pokeball animations',type='toggle',default=true},
  {key='OW_FOLLOWERS_RUN_TO_CATCH_UP',label='Run to catch up',type='toggle',default=true},
  {key='OW_FOLLOWERS_CATCH_UP_SPEED',label='Catch-up speed',type='choice',default=2,choices={{'2X',2},{'3X',3},{'4X',4},{'6X',6}}},
  {key='OW_FOLLOWERS_IDLE_MODE',label='Idle behavior',type='choice',default='mixed',choices={{'NONE','none'},{'MUSIC VISUALIZER','music'},{'MIXED','mixed'},{'RANDOM','random'},{'RANDOM WAVE','random_wave'},{'LOOK AROUND','look'},{'IDLE WALK','walk'},{'JUMP','jump'},{'JUMP WAVE','wave'},{'SINGLE JUMP WAVE','wave_single'},{'SPIN WAVE','spin'},{'BOUNCE WAVE','bounce'},{'PULSE WAVE','pulse'},{'COPYCAT','copycat'},{'DANCE','dance'},{'STRETCH','stretch'},{'DOZE','doze'},{'CHEER','cheer'},{'WANDER','wander'}}},
  {key='music_effect',label='Music effect',type='choice',default='dance',choices={{'DANCE','dance'},{'WAVE JUMPS','wave'},{'BAR WALK / RUN','bars'},{'BAR STRETCH','stretch'}}},
  {key='music_speed',label='Visualizer speed',type='choice',default=.5,choices={{'10%',.1},{'20%',.2},{'25%',.25},{'33%',.33},{'50%',.5},{'75%',.75},{'100%',1},{'125%',1.25},{'150%',1.5},{'200%',2}}},
  {key='music_sensitivity',label='Music sensitivity',type='choice',default=1,choices={{'LOW',.5},{'NORMAL',1},{'HIGH',2},{'VERY HIGH',4}}},
  {key='OW_FOLLOWERS_IDLE_TIME',label='Idle time',type='choice',default=3,choices={{'1 SECOND',1},{'3 SECONDS',3},{'5 SECONDS',5},{'10 SECONDS',10},{'30 SECONDS',30},{'60 SECONDS',60}}},
  {key='OW_FOLLOWERS_WANDER_RANGE',label='Wander range',type='choice',default=2,choices={{'1 TILE',1},{'2 TILES',2},{'3 TILES',3},{'4 TILES',4}}},
  {key='follower_count',label='Follower count',type='choice',default=1,choices={{'NONE',0},{'ONE',1},{'TWO',2},{'THREE',3},{'FOUR',4},{'FIVE',5},{'SIX',6}}},
  {key='WE_OW_ENCOUNTERS',label='Visible wilds',type='toggle',default=true},
  {key='living_ecosystems',label='Living ecosystems',type='toggle',default=true},
  {key='ecosystem_groups',label='Groups and guardians',type='toggle',default=true},
  {key='ecosystem_chases',label='Predator and prey',type='toggle',default=true},
  {key='ecosystem_timidity',label='Timid wilds',type='toggle',default=true},
  {key='ecosystem_rest',label='Wild resting',type='toggle',default=true},
  {key='ecosystem_variety',label='Foraging and play',type='toggle',default=true},
  {key='wilds_march',label='WILDS MARCH',type='toggle',default=false},
  {key='wilds_march_speed',label='WILDS MARCH SPEED',type='choice',default=1,choices={{'10%',.1},{'20%',.2},{'25%',.25},{'33%',.33},{'50%',.5},{'75%',.75},{'100%',1},{'125%',1.25},{'150%',1.5},{'200%',2},{'300%',3}}},
  {key='wild_sprites',label='Wild sprites',type='choice',default='g9',choices={{'G9','g9'},{'EE','ee'}}},
  {key='WE_OW_WATER',label='Water wilds',type='toggle',default=true},
  {key='water_sprite_crop',label='Water sprite crop',type='choice',default=0,choices={{'OFF',0},{'1 PX',1},{'2 PX',2},{'3 PX',3}}},
  {key='WE_VANILLA_RANDOM',label='Random battles',type='toggle',default=false},
  {key='WE_OWE_INITIATE_BATTLES',label='Touch battles',type='toggle',default=false},
  {key='spawn_density',label='Land spawn amount',type='choice',default='normal',choices={{'LOW (2)','low'},{'NORMAL (4)','normal'},{'HIGH (6)','high'},{'VERY HIGH (8)','very_high'}}},
  {key='water_spawn_density',label='Water spawn amount',type='choice',default='normal',choices={{'NONE (0)','none'},{'LOW (2)','low'},{'NORMAL (4)','normal'},{'HIGH (6)','high'},{'VERY HIGH (8)','very_high'}}},
  {key='spawn_range',label='Spawn range',type='choice',default='normal',choices={{'NORMAL (12)','normal'},{'FAR (20)','far'},{'WIDE (32)','wide'},{'VERY WIDE (48)','very_wide'},{'ULTRA WIDE (64)','ultra_wide'}}},
}
