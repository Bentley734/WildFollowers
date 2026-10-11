-- Ground anchors stay fixed while the body follows the cartridge's jump arc.
return function(mod,include)
  local A=include('adapter')
  local J={duration=32/60}
  local high={-4,-6,-8,-10,-11,-12,-12,-12,-11,-10,-9,-8,-6,-4,0,0}
  function J:offset(progress,duration)
    local t=math.max(0,math.min(1,progress or 0))
    if t>=1 then return 0 end
    if A.generation==1 then return -math.floor(10*math.sin(t*math.pi)+.5) end
    local frames=math.max(1,math.floor((duration or self.duration)*60+.5))
    local frame=math.min(frames,math.floor(t*frames)+1)
    if A.generation==2 then
      return require('src.script.gen2.Movement').jumpYOffset(frame,frames)
    end
    return high[math.min(16,math.floor((frame-1)*16/frames)+1)] or 0
  end
  function J:pose(e)
    if e.hidden or e.ballPhase then return 0,false end
    if e.jumpActive and e.moving then return self:offset(e.progress,e.duration),true end
    local pose=e.idlePose
    if pose and (not e.moving or e.spacingPaused) and pose.jumping then return pose.hop or 0,true end
    return 0,false
  end
  function J:shadow(e,ox,oy,scale,row)
    if row=='top' then return end
    local _,active=self:pose(e);if not active then return end
    local G=love.graphics
    G.push('all');G.setColor(1,1,1,1)
    if A.generation==3 then
      local F=require('src.core.game3.field_effects')
      local sheet=F.loadSheet and F.loadSheet('shadow_medium')
      if sheet and sheet.quads[0] then
        G.draw(sheet.image,sheet.quads[0],ox+e.px*scale,oy+(e.py+16-sheet.fh)*scale,0,scale,scale)
      end
    elseif A.generation==2 then
      local w=A:world()
      if w and w.drawJumpShadow then
        w:drawJumpShadow({px=e.px,py=e.py,facing=e.idlePose and e.idlePose.facing or e.facing,jumping=true},ox,oy,scale)
      end
    else
      local p=A:player();local img=p and p.shadowImg
      if img then
        local yellow=require('src.core.GameVersion').isYellow()
        local x,y=ox+e.px*scale,oy+(e.py+4+(yellow and 4 or 0))*scale
        G.draw(img,x,y,0,scale,scale);G.draw(img,x+16*scale,y,0,-scale,scale)
        if not yellow then
          G.draw(img,x,y+16*scale,0,scale,-scale);G.draw(img,x+16*scale,y+16*scale,0,-scale,-scale)
        end
      end
    end
    G.pop()
  end
  return J
end
