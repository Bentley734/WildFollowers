-- Resolve form display metadata without replacing the actor's battle species.
return function(mod,include)
  local catalog=include and include('form_data') or assert(load(assert(mod:read('src/form_data.lua'))))()()
  local G=require('src.core.GameVersion').generation()
  local F={catalog=catalog}
  function F:resolve(species)
    local name=species
    if type(name)~='string' then
      if G~=3 then return nil end
      name=require('src.core.game3.pokemon').keyName(species)
    end
    if type(name)~='string' then return nil end
    name=name:upper():gsub('[%s%-]+','_')
    return catalog[name],name
  end
  return F
end
