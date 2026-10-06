-- Store follower preferences once in the saved engine options, across games.
return function(E,mod,schema)
  local Options=require('src.core.game3.options')
  local lastSession,lastBlock
  local function state()
    local s=E.Runtime.getSession()
    if not s or not s.engineOptions then return end
    local engine=s.engineOptions
    engine.partyParade=engine.partyParade or {}
    return s,Options.block(engine),engine.partyParade,engine
  end
  function E.applySharedSettings()
    local s,b,shared=state()
    if not s or s==lastSession and b==lastBlock then return end
    for _,row in ipairs(schema)do
      local k=row.nativeKey
      if shared[k]==nil then
        shared[k]=b[k]
        if shared[k]==nil then shared[k]=mod.options:get(row.key) end
        if shared[k]==nil then shared[k]=row.default end
      end
      b[k]=shared[k]
    end
    lastSession,lastBlock=s,b
  end
  function E.captureSharedSettings()
    local s,b,shared,engine=state()
    if not s then return end
    for _,row in ipairs(schema)do
      local k=row.nativeKey
      if b[k]~=nil then shared[k]=b[k] end
      for _,id in ipairs({'firered','leafgreen','emerald'})do
        if type(engine[id])=='table' and shared[k]~=nil then engine[id][k]=shared[k] end
      end
    end
  end
  E.applySharedSettings()
end
