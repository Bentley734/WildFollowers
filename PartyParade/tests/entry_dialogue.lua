local checks=0;local function eq(a,b,msg)checks=checks+1;assert(a==b,msg..': '..tostring(a)..' ~= '..tostring(b))end
local warp,fade,battle,forced,dialog=false,false,false,false,true
local space={vm={ctx={activeMoves={}},isRunning=function()return dialog end}}
package.loaded['src.ui.game3.fade']={isActive=function()return fade end}
package.loaded['src.ui.game3.map_preview_screen']={isActive=function()return false end}
package.loaded['src.core.game3.battle']={isActive=function()return battle end}
package.loaded['src.core.game3.forced_movement']={isForced=function()return forced end}
package.loaded['src.core.game3.scripting.space']=space
local E={Map={},C={OW_FOLLOWERS_ENABLED=true,OW_FOLLOWERS_ARRIVAL_BALLS=true},Player={cellX=5,cellY=5,facing='down'},Field={},
 Warp={isBusy=function()return warp end},actors={},Runtime={getSession=function()end},Pokemon={isEgg=function()return false end,speciesOf=function(m)return m.species end},
 Collision={inBounds=function(x,y)return x>=0 and y>=0 and x<30 and y<30 end,warpAt=function()return false end},
 Objects={blocks=function()return false end},controlsLocked=function()return dialog end,followerVisible=function()return not forced end,
 playerCur=function()return 5,5 end,mapId=function()return 'NEW_ROOM'end}
local party={};for i=1,6 do party[i]={species=i,hp=10};E.actors[i]={index=i,active=false,invisible=true,act=0}end
E.party=function()return party end;E.Idle={normalize=function()end,beginTick=function()end}
local releases=0
local function inert()return setmetatable({time=0},{__index=function()return function()end end})end
local function core()
 local a,partyForCore;local c={A={NONE=0,ENTER=5},init=function(e)a=e.FOLLOWER;partyForCore=e.party end}
 c.update=function()a.active=partyForCore()[1]~=nil end;c.onMapEntered=function()a.invisible=true end;c.tick=function()end;c.talking=function()return false end
 c.place=function(x,y,visible)a.cellX=x;a.cellY=y;a.invisible=not visible end
 c.exitBall=function()releases=releases+1;a.invisible=false;return true end
 return c
end
local function include(p)
 if p=='follower.lua'then return core()end
 if p=='lib/arrival.lua'then return assert(loadfile(p))()end
 if p=='lib/terrain.lua'then return {followerCellAllowed=function()return true end}end
 if p=='lib/map_offset.lua'then return {}end
 return function()return inert()end
end
package.loaded['src.core.game3.options']={block=function(o)return o end}
local M=assert(loadfile('lib/native_followers.lua'))()(E,include,{options={get=function()return 6 end},events={on=function()end}})
M.queueDoorArrival('NEW_ROOM');M.onMapEntered({via='warp'})
eq(M.arrivalPending,true,'door waits for transition');eq(#M.order,6,'all six selected')
warp=true;M.tick();eq(M.arrivalPending,true,'warp waits');warp=false;fade=true;M.tick();eq(M.arrivalPending,true,'palette fade waits');fade=false
E.Player.moving=true;M.tick();eq(M.arrivalPending,true,'entry step waits');E.Player.moving=false
space.vm.ctx.activeMoves[1]={done=false};M.tick();eq(M.arrivalPending,true,'NPC movement waits');space.vm.ctx.activeMoves[1].done=true
M.tick();eq(M.arrivalPending,false,'dialogue lock does not delay arrival');eq(releases,6,'all six balls released during conversation')
local positions={};for _,a in ipairs(M.order)do eq(a.invisible,false,'visible during dialogue');local k=a.cellX..':'..a.cellY;eq(positions[k],nil,'formation does not stack');positions[k]=true end
M.onMapEntered({via='warp'});eq(M.arrivalPending,true,'stairs/room warp gets arrival check');M.tick();eq(M.arrivalPending,false,'room settled during dialogue');eq(releases,6,'non-door does not add ball animation')
forced=true;eq(E.arrivalBlocked(),true,'forced motion blocked');forced=false;battle=true;eq(E.arrivalBlocked(),true,'battle blocked');battle=false;eq(E.arrivalBlocked(),false,'running VM alone does not block')
-- Initial loads and non-ball door arrivals must never seed before the avatar.
local currentX,currentY=5,5
E.playerCur=function()return currentX,currentY end
local blocked={}
E.Collision.warpAt=function(x,y)return blocked[x..':'..y]=='door'end
E.Objects.blocks=function(x,y)return blocked[x..':'..y]=='npc'end
local chosenCount=6
local readCount=M.readOptions
M.readOptions=function()readCount();M.follower_count=chosenCount end
for _,facing in ipairs({'up','down','left','right'})do
 for count=1,6 do
  chosenCount=count;E.Player.facing=facing
  for _,balls in ipairs({false,true})do
   E.C.OW_FOLLOWERS_ARRIVAL_BALLS=balls
   M.queueDoorArrival('NEW_ROOM')
   E.Player.visible=false;E.Player.isVisible=function()return E.Player.visible end
   M.onMapEntered({via='warp'})
   eq(#M.order,count,'requested follower count selected')
   for _,actor in ipairs(M.order)do eq(actor.invisible,true,'map event stays hidden')end
   M.tick();eq(M.arrivalPending,true,'hidden player delays spawn')
   for _,actor in ipairs(M.order)do eq(actor.invisible,true,'hidden player has no visible followers')end
   E.Player.visible=true;E.Player.moving=true;currentY=6
   E.Player.cellX=5;E.Player.cellY=5;E.Player.targetX=5;E.Player.targetY=6
   M.tick();eq(M.arrivalPending,true,'door exit step delays spawn')
   E.Player.moving=false;E.Player.cellY=6;E.Player.px=80;E.Player.py=96
   blocked={['5:5']='door',['4:6']='npc'}
   M.tick();eq(M.arrivalPending,false,'settled visible player releases formation')
   local occupied={}
   for _,actor in ipairs(M.order)do
    if not actor.invisible then
     local key=actor.cellX..':'..actor.cellY
     eq(key=='5:6',false,'spawn excludes player')
     eq(key=='5:5',false,'spawn excludes doorway')
     eq(key=='4:6',false,'spawn excludes NPC')
     eq(occupied[key],nil,'spawn excludes another follower');occupied[key]=true
    end
   end
   currentY=5;E.Player.cellY=5;E.Player.targetY=5;E.Player.py=80;blocked={}
  end
 end
end
-- A partially positioned avatar reserves both tiles touched by its footprint.
chosenCount=6;E.Player.px=72;E.Player.py=80
M.onMapEntered({via='warp'});M.tick()
for _,actor in ipairs(M.order)do
 if not actor.invisible then eq(actor.cellX==4 and actor.cellY==5,false,'reserve avatar pixel footprint')end
end
-- Cramped exits leave unplaceable followers hidden rather than stack on player.
E.Player.px=80
E.Collision.inBounds=function(x,y)return x==5 and y==5 end
M.onMapEntered({via='warp'});M.tick()
for _,actor in ipairs(M.order)do eq(actor.invisible,true,'no legal spawn remains hidden')end
E.Collision.inBounds=function()return true end
E.Player.visible=false;eq(E.arrivalBlocked(),true,'visibility blocks standalone appearance')
E.Player.visible=true
local Sandbox=require('src.mods.Sandbox')
local arrivalSource=assert(io.open('lib/arrival.lua')):read('*a')
local sandboxEnv=Sandbox.envFor({modId='wildfollowers',permissions={engine_internals=true}})
local sandboxArrival=assert(load(arrivalSource,'@arrival.lua','t',sandboxEnv))()(E)
E.Player.visible=false;eq(sandboxArrival(),true,'real sandbox waits for visible player')
E.Player.visible=true;eq(sandboxArrival(),false,'real sandbox permits settled arrival')
E.Player.visible=false;M.seed();eq(M.arrivalPending,true,'initial formation waits for player')
for _,actor in ipairs(M.order)do eq(actor.invisible,true,'direct seed cannot reveal followers early')end
E.Player.visible=true;M.tick()
local f=assert(io.open('follower.lua'));local s=f:read('*a');f:close();local a=s:find('function Follower.appearNow()',1,true);local b=s:find('\nfunction Follower.place',a,true)
local actor={active=true,invisible=true};local F={};local placed
local env=setmetatable({Follower=F,E={C={OW_FOLLOWERS_APPEAR_NOW=true},arrivalBlocked=E.arrivalBlocked,controlsLocked=function()return true end,
 followerVisible=function()return true end,playerCur=function()return 5,5 end,canMove=function()return true end},actor=actor,
 Player={facing='down'},SIDES={down={'up'}},DX={up=0},DY={up=-1},moveToMapCoords=function(x,y)placed={x,y}end,faceDirection=function()end},{__index=_G})
assert(load(s:sub(a,b-1),'production appearNow','t',env))();F.appearNow();eq(actor.invisible,false,'single core appears during dialog');eq(placed[2],4,'single core placed behind trainer')
print('Entry-dialogue arrival checks',checks)
