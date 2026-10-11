return function(mod,values,player,owner,tick,replaceTables,check,eq)
  local keys={'enabled','OW_FOLLOWERS_ENABLED','WE_OW_ENCOUNTERS','WE_OW_WATER','spawn_density','water_spawn_density','spawn_range'}
  local before={};for _,key in ipairs(keys)do before[key]=values[key]end
  local x,y,px,py=player.cellX,player.cellY,player.px,player.py
  replaceTables(163)
  values.enabled=true;values.OW_FOLLOWERS_ENABLED=false;values.WE_OW_ENCOUNTERS=true;values.WE_OW_WATER=true
  values.spawn_range='normal';values.spawn_density='low';values.water_spawn_density='very_high'
  player.cellX,player.cellY,player.px,player.py=12,12,192,192
  player.moving=false;player.targetX=nil;player.targetY=nil
  local function counts()
    local n={land=0,water=0};for _,e in ipairs(owner.wilds)do n[e.surface]=n[e.surface]+1 end;return n
  end
  mod.exports.clearAll();tick(600)
  local n=counts();eq(n.land,2,'land low limit fills independently');eq(n.water,8,'water high limit fills independently')
  local water={};for _,e in ipairs(owner.wilds)do if e.surface=='water' then water[e]=true end end
  values.spawn_density='very_high';tick(600)
  n=counts();eq(n.land,8,'raising land fills only land deficit');eq(n.water,8,'land increase preserves water limit')
  values.spawn_density='low';tick(1)
  n=counts();eq(n.land,2,'lowering land trims only land');eq(n.water,8,'lowering land preserves water population')
  for _,e in ipairs(owner.wilds)do if e.surface=='water' then check(water[e],'land change retains existing water actors') end end
  values.water_spawn_density='low';tick(1)
  n=counts();eq(n.land,2,'lowering water preserves land');eq(n.water,2,'lowering water trims water only')
  values.water_spawn_density='none';tick(1)
  n=counts();eq(n.land,2,'water NONE preserves land');eq(n.water,0,'water NONE clears aquatic population')
  values.water_spawn_density='normal';tick(600)
  n=counts();eq(n.land,2,'raising water preserves land limit');eq(n.water,4,'raising water refills aquatic population')
  values.WE_OW_WATER=false;tick(1)
  n=counts();eq(n.land,2,'water toggle preserves land');eq(n.water,0,'water toggle overrides water amount')
  mod.exports.clearAll()
  for _,key in ipairs(keys)do values[key]=before[key]end
  player.cellX,player.cellY,player.px,player.py=x,y,px,py
end
