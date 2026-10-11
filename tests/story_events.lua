return function(mod,values,world,player,owner,gen,tick,check,eq)
  local keys={'OW_FOLLOWERS_ENABLED','follower_count','OW_FOLLOWERS_POKEBALLS','WE_OW_ENCOUNTERS','WE_OW_WATER'}
  local previous={};for _,key in ipairs(keys)do previous[key]=values[key]end
  values.OW_FOLLOWERS_ENABLED=true;values.follower_count=6;values.WE_OW_ENCOUNTERS=false;values.WE_OW_WATER=false
  local active=false
  local oldRunner,oldVm=world.runner,world.vm
  local space,oldGetVm
  if gen==3 then
    space=require('src.core.game3.scripting.space');oldGetVm=space.getVm
    space.getVm=function()return {isRunning=function()return active end}end
  elseif gen==2 then world.vm={running=function()return active end}
  else world.runner={isRunning=function()return active end} end
  for _,animate in ipairs({true,false})do
    values.OW_FOLLOWERS_POKEBALLS=animate
    mod.exports.clearAll();owner.loadArrival=true;tick(120)
    eq(#owner.followers,6,'transferred party has six followers before story')
    local bodies={};for i,e in ipairs(owner.followers)do bodies[i]={actor=e,mon=e.mon}end
    local lead=owner.followers[1];local x,y=lead.cellX,lead.cellY
    lead.moving=true;lead.targetX=x-1;lead.targetY=y
    local npc={cellX=x,cellY=y-1,facing='down',moving=false}
    local nativeCalls=0
    local function nativeStep()
      nativeCalls=nativeCalls+1
      check(not npc.moving,'story NPC is never artificially held waiting for follower')
      eq(owner:followerAt(x,y),nil,'collision released before first native NPC step')
      check(not owner:occupied(x,y,npc),'recalling body cannot reserve NPC destination')
      check(not owner:occupied(x-1,y,npc),'moving follower target released immediately')
      if gen==1 then
        check(require('src.world.Collision').canMove(world.map,world.entities,npc,'down'),'native Gen 1 collision allows rival through recalled party')
      end
      return true
    end
    -- Start NPC movement before input.step can detect the new script.
    if gen==1 then
      world.storyStepAssertion=nativeStep
      world.scriptMoves={{entity=npc,dir='down',remaining=1}}
      check(world:updateScriptMoves(),'first queued NPC movement reaches native handler')
    else
      npc.storyStepAssertion=nativeStep
      local module=require(gen==3 and 'src.core.game3.objects' or 'src.world.gen2.Npc')
      check(module.scriptStep(npc,'down'),'first scripted NPC movement reaches native handler')
    end
    eq(nativeCalls,1,'story movement executes immediately once')
    check(owner.storyRecalled,'script callback recalls followers before next frame')
    active=true;tick(30)
    for i,record in ipairs(bodies)do
      check(record.actor.hidden and not record.actor.ballPhase,'followers remain recalled through story wait')
      eq(record.actor.mon,record.mon,'recall preserves transferred Pokemon identity')
    end
    active=false;world.scriptMoves={};world.storyStepAssertion=nil;tick(120)
    check(not owner.storyRecalled,'field control releases story recall')
    eq(#owner.followers,6,'party followers return after story')
    for i,e in ipairs(owner.followers)do
      eq(e.mon,bodies[i].mon,'return preserves original party Pokemon')
      check(not e.hidden,'follower reappears on safe floor')
      check(not (e.cellX==player.cellX and e.cellY==player.cellY+1),'release avoids player forward tile')
    end
    -- A dialogue/script with no queued movement also triggers recall.
    active=true;tick(1);check(owner.storyRecalled,'script runner detection recalls without NPC movement callback')
    active=false;tick(120)
  end
  if space then space.getVm=oldGetVm end
  world.runner,world.vm=oldRunner,oldVm
  for _,key in ipairs(keys)do values[key]=previous[key]end
  mod.exports.clearAll()
end
