-- Some native screens pass the already-bound flat session options to block().
-- Treat that exact live table as a block, rather than nesting another defaults
-- block inside it (which ensure() would subsequently mistake for an engine).
return function(getSession)
  local Options=require('src.core.game3.options')
  local raw=Options.block
  Options.block=function(engine,blockId)
    local session=getSession()
    if blockId==nil and type(engine)=='table' and session and engine==session.options
        and engine~=session.engineOptions then
      return Options.ensure(session)
    end
    return raw(engine,blockId)
  end
end
