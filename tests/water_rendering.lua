-- Cropped water bodies must not depend on any native surf artwork.
return function(include,mod,values,world,player,gen,root,check,eq)
  local S=include('sprites');local G=love.graphics
  local oldDraw=G.draw;local draws={}
  G.draw=function(image,quad,x,y,rotation,sx,sy)
    draws[#draws+1]={image=image,q=quad,x=x,y=y,sx=sx or 1,sy=sy or 1}
  end
  local oldSurf,oldSprites=player.surfSprite,world.sprites
  player.surfSprite={draw=function()error('wild must never draw a surf mount')end}
  world.sprites=setmetatable({},{__index=function()error('wild must never load a surf mount')end})
  local F,oldLoad
  if gen==3 then
    F=require('src.core.game3.field_effects');oldLoad=F.loadSheet
    F.loadSheet=function()error('wild must never load a surf blob')end
  end
  local actor={national=1,px=64,py=80,cellX=4,cellY=5,clock=0,facing='down',surface='water'}
  for _,set in ipairs({'g9','ee'}) do
    values.wild_sprites=set;values.follower_sprites=set
    local record=S:get(1,actor);local size=record.ee and 1 or 32/record.w
    for crop=0,3 do
      values.water_sprite_crop=crop
      for _,face in ipairs({'down','up','left','right'}) do
        actor.facing=face
        for _,moving in ipairs({false,true}) do
          actor.moving=moving
          for _,clock in ipairs({0,.8}) do
            actor.clock=clock
            for _,scale in ipairs({1,2,3}) do
              draws={};S:draw(actor,3,5,scale)
              eq(#draws,1,'water wild body draws alone, without a surf mount')
              local body=draws[1]
              eq(body.image,record.image,'water wild uses its own species artwork')
              local frame=moving and math.floor(clock*8)%4 or 0
              local bottom=record.bottoms[({down=1,left=2,right=3,up=4})[face]][frame+1]
              local retained=crop>0 and bottom-crop/size or record.h
              eq(body.q.h,retained,'selected visible crop depth')
              eq(body.q.h*body.sy,retained*size*scale,'crop respects zoom')
              eq(body.y,5+(80+(gen==3 and 16 or 12))*scale-record.h*size*scale,'crop does not shift body anchor')
            end
          end
        end
      end
    end
    values.water_sprite_crop=1;actor.facing='down';actor.moving=false
    local visible=record.bottoms[1][1]
    draws={};S:draw(actor,3,5,2,'bottom')
    eq(#draws,1,'bottom OAM pass contains only the wild body')
    eq(draws[1].q.h*size,8-(record.h-visible)*size-1,'bottom row excludes padding and selected visible crop')
    draws={};S:draw(actor,3,5,2,'top')
    eq(#draws,1,'top OAM pass contains only the wild body')
    eq(draws[1].q.h*size,record.h*size-8,'upper crop unaffected')
    -- All land/water wilds visit the complete walking sequence in a short step.
    for _,surface in ipairs({'land','water'}) do
      actor.surface=surface;actor.moving=true;actor.clock=500
      for _,face in ipairs({'down','up','left','right'}) do
        actor.facing=face
        for index,progress in ipairs({.1,.35,.6,.85}) do
          actor.progress=progress;draws={};S:draw(actor,3,5,1)
          eq(#draws,1,'moving wild has one body')
          eq(draws[1].q.x,(index%4)*record.w,'short steps show every walk frame for '..set..' '..surface..' '..face)
        end
      end
      actor.moving=false;draws={};S:draw(actor,3,5,1)
      eq(draws[1].q.x,0,'landed wild returns to standing frame')
    end
    actor.progress=nil;actor.moving=false;actor.facing='down';values.water_sprite_crop=3
    actor.surface='land';draws={};S:draw(actor,3,5,2)
    eq(#draws,1,'land wild has one body');eq(draws[1].q.h,record.h,'land sprite remains whole')
    actor.surface='water';actor.follower=true;draws={};S:draw(actor,3,5,2)
    eq(#draws,1,'water follower has one body');eq(draws[1].q.h,record.h,'follower sprite remains whole')
    actor.follower=nil;actor.hidden=true;draws={};S:draw(actor,3,5,2)
    eq(#draws,0,'hidden wild does not draw');actor.hidden=nil
    actor.ballPhase='release';actor.ballTime=0;draws={};S:draw(actor,3,5,2)
    eq(#draws,0,'fully recalled body does not draw');actor.ballPhase=nil
  end
  if F then F.loadSheet=oldLoad end
  values.water_sprite_crop=0;values.wild_sprites='g9';values.follower_sprites='g9'
  player.surfSprite=oldSurf;world.sprites=oldSprites;G.draw=oldDraw
end
