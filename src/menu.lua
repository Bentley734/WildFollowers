-- Expose the same persisted mod settings in the cartridge's main OPTION menu.
return function(mod,include)
  local A=include('adapter')
  local M={}
  function M:sync(game)
    game=game or mod.game
    local loader=game and game.mods
    if not loader then return end
    loader.modOptions=loader.modOptions or {}
    local bucket=loader.modOptions[mod.id] or {}
    loader.modOptions[mod.id]=bucket
    -- Native GBA Mods edits save.options; main OPTION writes game.options.
    -- The serializer can replace either bucket, so bind both to live settings
    -- before every write and again after serialization.
    local function bind(options)
      if not options then return end
      options.modOptions=options.modOptions or {}
      for key,value in pairs(options.modOptions[mod.id] or {}) do
        if bucket[key]==nil then bucket[key]=value end
      end
      options.modOptions[mod.id]=bucket
    end
    bind(game.options);bind(game.save and game.save.options)
    for _,key in ipairs({'OW_FOLLOWERS_TRAINER_SPACING','OW_FOLLOWERS_SPACING'}) do
      if bucket[key]~=nil then
        local n=tonumber(bucket[key]) or 1
        bucket[key]=tonumber(string.format('%.1f',math.max(1,math.min(4,n))))
      end
    end
  end
  function M:set(game,key,value)
    if require('src.mods.Runtime').safeMode then return false end
    game=game or mod.game
    local options=A.generation==3 and game.options or game.save and game.save.options
    if options then
      options.modOptions=options.modOptions or {}
      options.modOptions[mod.id]=options.modOptions[mod.id] or {}
      options.modOptions[mod.id][key]=value
    end
    local loader=game.mods
    if not loader then return false end
    loader.modOptions=loader.modOptions or {}
    loader.modOptions[mod.id]=loader.modOptions[mod.id] or {}
    loader.modOptions[mod.id][key]=value
    self:sync(game)
    if game.writeOptions then game:writeOptions() end
    self:sync(game)
    if loader.events then loader.events:emit('mod.options_changed',{mod=mod.id,key=key,value=value}) end
    return true
  end
  function M:rows(schema)
    local rows={}
    for _,definition in ipairs(schema) do
      local def=definition
      rows[#rows+1]={id='wildfollowers.'..def.key,label=string.upper(def.label),
        value=function()
          local value=mod.options:get(def.key)
          if def.type=='toggle' then return value and 'ON' or 'OFF' end
          for _,choice in ipairs(def.choices or {}) do if choice[2]==value then return choice[1] end end
          return tostring(value)
        end,
        step=function(context,dir)
          local game=context and context.game or context or mod.game
          local value=mod.options:get(def.key)
          if def.type=='toggle' then return M:set(game,def.key,not value) end
          local choices=def.choices or {};if #choices==0 then return false end
          local at=1
          for i,choice in ipairs(choices) do if choice[2]==value then at=i;break end end
          return M:set(game,def.key,choices[(at-1+(dir or 1))%#choices+1][2])
        end}
    end
    return rows
  end
  function M:open(game,schema)
    local rows=self:rows(schema)
    if A.generation==1 then
      game.stack:push(require('src.ui.OptionsMenu').new(game,{rows=rows}))
    else
      -- The Gen 2 native group page shares the parent's options and closes
      -- only itself. Construct the same page without firing the top-level hook.
      local Options=require('src.ui.gen2.OptionsMenu')
      local page=setmetatable({game=game,rows=rows,options=game.options or game.save.options,
        index=1,scroll=0,sub=true,view={}},Options)
      for i,row in ipairs(rows) do page.view[i]=row end
      page.view[#page.view+1]={id='cancel',label='BACK',cancel=true}
      game.stack:push(page)
    end
  end
  function M:install(c,schema)
    self:sync(mod.game)
    if mod.game and mod.game.writeOptions then
      c:wrap(mod.game,'writeOptions',function(old,game,...)
        M:sync(game)
        local result=old(game,...)
        M:sync(game)
        return result
      end)
    end
    if A.generation==3 then
      -- All five GBA games build port sections through this shared group API.
      local Rows=require('src.ui.game3.option_rows')
      c:wrap(Rows,'build',function(old,...)
        local rows=old(...)
        for _,row in ipairs(self:rows(schema)) do rows[#rows+1]=row end
        return rows
      end)
      c:wrap(Rows,'group',function(old,rows,openPage)
        local members,keep={},{}
        for _,row in ipairs(rows) do
          if row.id and row.id:sub(1,14)=='wildfollowers.' then members[#members+1]=row
          else keep[#keep+1]=row end
        end
        local view=old(keep,openPage)
        if #members>0 then view[#view+1]={id='wildfollowers',label='WILDFOLLOWERS',group=true,
          value=function()return tostring(#members)..' OPTIONS' end,
          activate=function()openPage('WILDFOLLOWERS',members)end} end
        return view
      end)
    else
      mod.hooks:wrap('ui.options.rows',function(next_,game,rows)
        local result=next_(game,rows)
        for _,row in ipairs(result) do if row.id=='wildfollowers' then return result end end
        local entry={id='wildfollowers',label='WILDFOLLOWERS',group=true,
          value=function()return tostring(#schema)..' OPTIONS' end,
          activate=function(g)M:open(g,schema)end}
        local at=#result+1
        for i,row in ipairs(result) do if row.cancel then at=i;break end end
        table.insert(result,at,entry)
        return result
      end)
    end
  end
  return M
end
