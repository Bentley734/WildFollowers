return function(mod,values,data,P,gen,Sandbox,env,check,eq,verifyBattle)
  local modules={}
  local function include(name)
    if not modules[name] then
      modules[name]=assert(Sandbox.compile(mod:read('src/'..name..'.lua'),'@wildfollowers/'..name,env))()(mod,include)
    end
    return modules[name]
  end
  local Forms,EE,A=include('forms'),include('ee_data'),include('adapter')
  local make=assert(Sandbox.compile(mod:read('src/sprites.lua'),'@wildfollowers/form-sprites',env))()
  local originalImage=mod.assets.image
  mod.assets.image=function(_,path)return originalImage(mod.assets,path)end
  local wild,follow=values.wild_sprites,values.follower_sprites
  local total=0
  local oldMeta=P._speciesMeta
  if gen==3 then P._speciesMeta={} end
  for name,row in pairs(Forms.catalog)do
    total=total+1
    local id=6000+total
    if gen==3 then P._names[id]=name;P._national.toNational[id]=1300+total;P._speciesMeta[id]={genderRatio=255}
    else data.pokemon[name]={dex=1300+total,form=name,baseSpecies=row.base} end
    local species=gen==3 and id or name
    eq(A:national(species),row.national,'form resolves base National identity '..name)
    check(A:start({species=species,level=50}),'form can enter native battle '..name)
    verifyBattle(species)
    local S=make(mod,include)
    for _,set in ipairs({'g9','ee'})do for _,follower in ipairs({false,true})do
      values.wild_sprites=set;values.follower_sprites=set
      for _,isShiny in ipairs({false,true})do
        local mon=follower and {species=species,shiny=isShiny,isShiny=isShiny,personality=100,gender='M'} or nil
        local actor={species=species,follower=follower,mon=mon}
        local art=set=='ee' and row.ee or row.g9
        local other=set=='ee' and row.g9 or row.ee
        local expected=(mon and isShiny and art.shiny) or art.normal
          or (mon and isShiny and other.shiny) or other.normal
          or (row.mega and EE.species[row.base..'_shiny'])
          or (set=='ee' and ((mon and isShiny and EE.species[row.base..'_shiny']) or EE.species[row.base]))
          or ('assets/g9rpsprites/%03d-normal.png'):format(row.national)
        local record=S:get(1300+total,actor)
        check(record~=nil,'form remains visible '..name..' '..set)
        eq(record.path,expected,'correct set, form and shiny art '..name..' '..set)
        eq(actor.species,species,'renderer preserves battle identity')
        if mon then eq(mon.isShiny,isShiny,'renderer preserves actual shiny status') end
      end
    end end
    if gen==3 then P._names[id]=nil;P._national.toNational[id]=nil else data.pokemon[name]=nil end
  end
  eq(total,364,'every 1025Dex alternate form is covered')
  eq(Forms.catalog.VENUSAUR_MEGA.ee.normal,EE.species.VENUSAUR_MEGA,'EE keeps original Mega art')
  eq(Forms.catalog.RAICHU_ALOLA.g9.normal,'assets/g9rpforms/RAICHU_ALOLA.png','G9 Alolan Raichu has distinct art')
  eq(Forms.catalog.URSHIFU_RAPID_STRIKE_GMAX.g9.normal,'assets/g9rpforms/URSHIFU_RAPID_STRIKE_GMAX.png','Rapid Strike Gmax has distinct art')
  values.wild_sprites='g9';values.follower_sprites='ee'
  local S=make(mod,include)
  eq(S:get(3,{species='VENUSAUR_MEGA'}).path,Forms.catalog.VENUSAUR_MEGA.g9.normal,'wild setting remains independent')
  eq(S:get(3,{species='VENUSAUR_MEGA',follower=true}).path,EE.species.VENUSAUR_MEGA,'follower setting remains independent')
  -- Failed images continue through the fallback chain, including cached failures.
  local bad=Forms.catalog.VENUSAUR_MEGA.g9.normal
  mod.assets.image=function(_,path)if path==bad then error('missing asset')end;return originalImage(mod.assets,path)end
  S=make(mod,include)
  for i=1,2 do eq(S:get(3,{species='VENUSAUR_MEGA'}).path,EE.species.VENUSAUR_MEGA,'missing G9 form falls back to exact EE form')end
  mod.assets.image=function(_,path)
    if path:find('VENUSAUR_MEGA',1,true) then error('missing both sets') end
    return originalImage(mod.assets,path)
  end
  eq(make(mod,include):get(3,{species='VENUSAUR_MEGA'}).path,EE.species.VENUSAUR_shiny,'missing true Mega art uses requested shiny-base fallback')
  mod.assets.image=function(_,path)
    if path:find('VENUSAUR_MEGA',1,true) or path==EE.species.VENUSAUR_shiny then error('missing Mega and shiny art')end
    return originalImage(mod.assets,path)
  end
  eq(make(mod,include):get(3,{species='VENUSAUR_MEGA'}).path,'assets/g9rpsprites/003-normal.png','missing shiny base uses normal base')
  values.wild_sprites,values.follower_sprites=wild,follow;mod.assets.image=originalImage
  P._speciesMeta=oldMeta
end
