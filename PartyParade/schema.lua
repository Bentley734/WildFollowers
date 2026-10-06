return function(E,mod,include)
  local FLAGS = {
    { "OW_FOLLOWERS_ENABLED",        true,  "Followers" },
    { "OW_FOLLOWERS_BOBBING",        true,  "Bobbing" },
    { "OW_FOLLOWERS_RUN_TO_CATCH_UP", true, "Run to catch up" },
    { "OW_FOLLOWERS_IDLE_WALK",      false, "Idle walk" },
    { "OW_FOLLOWERS_DOZE",           false, "Doze" },
    { "OW_FOLLOWERS_WANDER",         false, "Wander" },
    { "OW_FOLLOWERS_LOOK_AROUND",    false, "Look around" },
    { "OW_FOLLOWERS_JUMP",           false, "Jump" },
    { "OW_FOLLOWERS_JUMP_WAVE",      false, "Jump wave" },
    { "OW_FOLLOWERS_MIXED",          false, "Mixed" },
    { "OW_FOLLOWERS_RANDOM",         false, "Random" },
    { "OW_FOLLOWERS_RANDOM_WAVE",    false, "Random wave" },
    { "OW_FOLLOWERS_ZOOMIES",        false, "Zoomies" },
    { "OW_FOLLOWERS_BOUNCE_WAVE",    false, "Bounce wave" },
    { "OW_FOLLOWERS_SPIN_WAVE",      false, "Spin wave" },
    { "OW_FOLLOWERS_PULSE_WAVE",     false, "Pulse wave" },
    { "OW_FOLLOWERS_COPYCAT",        false, "Copycat" },
    { "OW_FOLLOWERS_SLEEPY_BUDDY",    false, "Sleepy buddy" },
    { "OW_FOLLOWERS_PLAY",           false, "Play tag" },
    { "OW_FOLLOWERS_CHEER",          false, "Cheer" },
    { "OW_FOLLOWERS_STRETCH",        false, "Stretch" },
    { "OW_FOLLOWERS_ARRIVAL_BALLS",  true,  "Arrival balls" },
    -- not expansion (D40): FR's own Pokémon objects use the mod's sprites
    -- locked
    { "OW_FOLLOWERS_POKEBALLS",      true },
    { "OW_FOLLOWERS_APPEAR_NOW",     true }, -- not expansion (D39)
    { "OW_FOLLOWERS_WEATHER_FORMS",  true },
    { "OW_FOLLOWERS_COPY_WILD_PKMN", false },
    { "OW_FOLLOWERS_SCRIPT_MOVEMENT", true },
  }
  local schema = {}
  for _, f in ipairs(FLAGS) do
    if f[3] then
      schema[#schema + 1] = { key = f[1], label = f[3], type = "toggle", default = f[2] }
      if f[1] == "OW_FOLLOWERS_IDLE_WALK" then
        schema[#schema+1] = {key="OW_FOLLOWERS_IDLE_TIME",label="Idle time",type="choice",default=3,
          choices={{"NOW",0},{"1 SEC",1},{"2 SECS",2},{"3 SECS",3},{"5 SECS",5},{"10 SECS",10},{"15 SECS",15},{"30 SECS",30},{"60 SECS",60}}}
      end
      if f[1] == "OW_FOLLOWERS_WANDER" then
        schema[#schema+1] = {key="OW_FOLLOWERS_WANDER_SPEED",label="Wander speed",type="choice",default="normal",
          choices={{"SLOWEST","slowest"},{"SLOWER","slower"},{"SLOW","slow"},{"NORMAL","normal"},{"FAST","fast"},{"FASTEST","fastest"}}}
        schema[#schema+1] = {key="OW_FOLLOWERS_WANDER_RANGE",label="Wander range",type="choice",default=2,
          choices={{"1 TILE",1},{"2 TILES",2},{"3 TILES",3},{"4 TILES",4},{"6 TILES",6},{"8 TILES",8}}}
      end
    end
  end
  for _,row in ipairs(include("options.lua")) do schema[#schema+1]=row end
  mod.options:define(schema)
  E.nativeOptionSchema=schema
  return schema,FLAGS
end
