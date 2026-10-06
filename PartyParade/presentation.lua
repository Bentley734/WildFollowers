-- Share UA's renderer and field services; add only follower draw/interaction.
return function(E,base,controller)
  local drawing=false
  local overlays={}
  E.queueOverlay=function(...)overlays[#overlays+1]={...}end
  function E.tickExtraGrass()
    for i=2,6 do
      local a=E.actors[i]
      if a.active then
        local x,y=a.cellX,a.cellY
        if a.moving then x,y=a.targetX,a.targetY end
        if x~=a.grX or y~=a.grY then
          local fresh=a.grX==nil and not a.moving
          a.grX,a.grY=x,y
          a.grStep=E.Collision.isGrass and E.Collision.isGrass(x,y) and (fresh and 4 or 0) or nil
          a.grT=0
        elseif a.grStep and a.grStep<4 then
          a.grT=a.grT+1
          if a.grT>=10 then a.grT,a.grStep=0,a.grStep+1 end
        end
      else a.grX,a.grY,a.grStep=nil,nil,nil end
    end
  end
  local drawGrass=base.drawGrass
  E.drawGrass=function(a,sx,sy,front)
    drawGrass(a,sx,sy,front)
    if front and drawing and not a.invisible and (a.y2 or 0)>=-2 then
      E.Flowers.drawAt(a.px,a.py,a.px-sx,a.py-sy)
    end
  end
  local rawDraw=E.FieldView.draw
  E.FieldView.draw=function(...)
    drawing=true;overlays={};E.Doze.clearQueue();E.Idle.clearQueue();E.Flowers.beginFrame()
    local ok,result=pcall(rawDraw,...)
    drawing=false
    if not ok then overlays={};E.Doze.clearQueue();E.Idle.clearQueue();error(result,0)end
    if #overlays>0 then
      E.Gfx.bind()
      for _,q in ipairs(overlays)do E.Gfx.draw(q[1],q[2],false,q[3],q[4],q[5])end
      E.Gfx.unbind()
    end
    E.Doze.flush();E.Idle.flush()
    return result
  end
  local rawForDraw=E.Objects.forDraw
  E.Objects.forDraw=function(...)
    local list=rawForDraw(...)
    if not drawing then return list end
    for i,a in ipairs(list)do
      if a==base.FOLLOWER then list[i]=E.Spacing.view(a) end
    end
    for i=2,6 do
      local a=E.actors[i]
      if a.active and a.visible and not a.invisible and a.draw then list[#list+1]=E.Spacing.view(a) end
    end
    return list
  end
  local rawInteract=E.Field.interact
  local dx={left=-1,right=1,up=0,down=0};local dy={up=-1,down=1,left=0,right=0}
  E.Field.interact=function(game,...)
    local p=E.Player
    if E.C.OW_FOLLOWERS_ENABLED and E.Field.running and not E.Field.locked
        and not p.moving and not E.controlsLocked()
        and not (E.Runtime.uiBusy and E.Runtime.uiBusy()) and not controller.talking() then
      local x,y=p.cellX+(dx[p.facing] or 0),p.cellY+(dy[p.facing] or 0)
      local a=E.Spacing.at(x,y)
      if a and not a.moving and not E.Objects.at(x,y) then return controller.talk(a) end
    end
    return rawInteract(game,...)
  end
  local recorder=E.QuestRecorder
  if recorder and recorder.capture then
    local rawCapture=recorder.capture
    recorder.capture=function(...)
      local frame=rawCapture(...)
      if frame and frame.actors then
        for i=2,6 do
          local a=E.actors[i]
          if a.active and not a.invisible and a.pose then
            local sheet,f,flip,row,y=a.pose(a)
            if sheet then
              local v=E.Spacing.view(a)
              frame.actors[#frame.actors+1]={id=a.localId,x=v.px,y=v.py,facing=v.facing,
                graphicsId=string.format('uadv:%d:%d:%d:%d:%d',sheet,f,flip and 1 or 0,row,y or 0)}
            end
          end
        end
      end
      return frame
    end
  end
end
