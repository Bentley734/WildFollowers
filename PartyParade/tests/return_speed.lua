local checks=0
local function eq(a,b,msg)checks=checks+1;assert(a==b,msg..': '..tostring(a)..' ~= '..tostring(b))end
local blocked=false
local E={C={},Player={cellX=5,cellY=2},Field={},
 Collision={inBounds=function(x,y)return x>=0 and x<=6 and y==2 end,
 warpAt=function(x)return blocked and x==1 end,ledgeLanding=function()return false end},
 Objects={at=function()end},actorAt=function()end,canMove=function()return true end}
local W=assert(loadfile('lib/wander.lua'))()(E,{followerCellAllowed=function()return true end})
for _,on in ipairs({true,false})do
 E.C.OW_FOLLOWERS_RUN_TO_CATCH_UP=on
 local a={cellX=0,cellY=2};local frames,starts={},{}
 a.nativeCore={independentStep=function(dir,speed)
  starts[#starts+1]=W.time;frames[#frames+1]=speed
  eq(dir,'right','shortest corridor return')
  a.cellX=a.cellX+1;return true
 end}
 W.time=1
 for i=1,4 do
  eq(W.returnStep(a,E.Player),false,'step issued before adjacency')
  eq(frames[i],on and 8 or 16,'toggle chooses native gait')
  W.time=W.time+frames[i]
 end
 eq(W.returnStep(a,E.Player),true,'stops exactly beside leader')
 eq(#frames,4,'never overshoots')
 for i=2,4 do eq(starts[i]-starts[i-1],frames[i-1],'no extra wait after native step')end
 a.cellX=0;E.Player.independent=true;eq(W.returnStep(a,E.Player),false,'wait for returning leader');eq(#frames,4,'waiting does not move')
 E.Player.independent=false;blocked=true;W.time=100
 eq(W.returnStep(a,E.Player),false,'blocked path waits');eq(a.cellX,0,'blocked path never teleports')
 eq(a.returnRetry,104,'bounded blocked retry');blocked=false;W.time=104
 eq(W.returnStep(a,E.Player),false,'unblocked path resumes');eq(a.cellX,1,'legal step after blockage')
end
-- Execute the production native follow step, not a duplicate speed formula.
local f=assert(io.open('follower.lua'));local source=f:read('*a');f:close()
local a=assert(source:find('local function followablePlayerMovement_Step()',1,true))
local b=assert(source:find('local function followPlayer_Shadow()',a,true))
for _,on in ipairs({true,false})do
 local duration
 local actor={cellX=0,cellY=2};local player={cellX=5,cellY=2}
 local env=setmetatable({actor=actor,Player=player,C={OW_FOLLOWERS_RUN_TO_CATCH_UP=on},
  E={playerPrev=function()return 4,2 end,playerCur=function()return 5,2 end,followerVisible=function()return true end,Field={}},
  Collision={ledgeLanding=function()return false end},clearMovement=function()end,directionToFace=function()return 'right'end,
  startWalk=function(_,frames)duration=frames end,
  copyMove=0,COPY_JUMP2=2,
 },{__index=_G})
 local follow=assert(load(source:sub(a,b-1)..'return followablePlayerMovement_Step','real follow step','t',env))()
 follow();eq(duration,on and 8 or 16,'native follow respects catch-up toggle')
 player.running=true;follow();eq(duration,8,'native follow still matches running trainer')
end
-- Native settings persistence uses the same option block on all three games.
local Rows={GROUPS={},ORDER={},build=function()return {}end,group=function(r)return r end}
package.loaded['src.ui.game3.option_rows']=Rows
package.loaded['src.core.game3.options']={block=function(o)return o end}
E.Idle={select=function()end}
assert(loadfile('lib/native_menu.lua'))()(E,{},{{key='OW_FOLLOWERS_RUN_TO_CATCH_UP',label='Run to catch up',type='toggle',default=true}})
for _,game in ipairs({'firered','leafgreen','emerald'})do
 local ctx={options={}};local row=Rows.build(ctx)[1]
 eq(row.value(ctx),'ON',game..' default on');row.step(ctx,1)
 eq(ctx.options.wildsG3FollowerRunToCatchUp,false,game..' saved off')
 eq(Rows.build(ctx)[1].value(ctx),'OFF',game..' persists after reopening')
 row.step(ctx,1);eq(ctx.options.wildsG3FollowerRunToCatchUp,true,game..' saved on')
end
print('PASS: '..checks..' return routing / uninterrupted steps / native catch-up speed / persisted toggle assertions')
