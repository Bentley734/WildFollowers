local checks=0
local function eq(a,b,msg)checks=checks+1;assert(a==b,msg)end
local E={C={follower_spacing=7,follower_trainer_spacing=7},Player={},Follower={order={}},
 Collision={inBounds=function()return true end},Objects={blocks=function()return false end}}
local T={followerCellAllowed=function()return true end}
E.Spacing=assert(loadfile('lib/spacing.lua'))()(E,T)
local function actor(x,y)
 return {active=true,cellX=x,cellY=y,targetX=x,targetY=y,px=x*16,py=y*16,
 nativeCore={A={JUMP=3}},act=0}
end
local a,b=actor(5,5),actor(7,5)
E.Follower.order={a,b}
eq(E.Spacing.blocksIdleStep(a,6,5),false,'adjacent endpoint may touch without overlapping')
b.cellX=6;b.px=96
eq(E.Spacing.blocksIdleStep(a,6,5),true,'stationary follower blocks endpoint')
b.moving=true;b.targetX=5
eq(E.Spacing.blocksIdleStep(a,6,5),true,'head-on swap blocked')
b.cellX=6;b.cellY=4;b.px=96;b.py=64;b.targetX=6;b.targetY=6
eq(E.Spacing.blocksIdleStep(a,6,5),true,'crossing reserved segment blocked')
b.moving=false;b.cellX=7;b.cellY=5;b.px=112;b.py=80;b.targetX=7;b.targetY=5
E.Spacing.track(b,{px=128,py=80});E.Spacing.beginIndependent(b);b.independent=true
-- Slot-one spacing shifts this follower 7px left, into the candidate endpoint.
eq(E.Spacing.view(b).px,105,'visible spacing retained')
eq(E.Spacing.blocksIdleStep(a,6,5),true,'visible footprint blocks despite different native cells')
b.invisible=true
eq(E.Spacing.blocksIdleStep(a,6,5),false,'hidden follower does not block')
b.invisible=false;b.active=false
eq(E.Spacing.blocksIdleStep(a,6,5),false,'inactive follower does not block')
b.active=true
local probe=setmetatable({nativeActor=a,cellX=4,cellY=4},{__index=a})
eq(E.Spacing.blocksIdleStep(probe,4,5),false,'BFS uses virtual source and excludes owner')
b.independent=false;E.Spacing.reset();b.cellX=5;b.cellY=5;b.px=88;b.py=80;b.moving=false
eq(E.Spacing.blocksIdleStep(a,4,5),false,'existing cramped overlap can separate')
eq(E.Spacing.blocksIdleStep(a,6,5),true,'existing overlap cannot pass through another follower')
b.px=80
eq(E.Spacing.blocksIdleStep(a,5,4),false,'coincident followers can separate without getting stuck')
-- Production walking safety hook, not just geometry in isolation.
E.Field={_game='firered'};E.Collision.warpAt=function()return false end
E.Collision.ledgeLanding=function()return false end
E.Objects.at=function()end;E.actorAt=function()end;E.canMove=function()return true end
E.Player={cellX=0,cellY=0}
local W=assert(loadfile('lib/wander.lua'))()(E,T)
for _,game in ipairs({'firered','leafgreen','emerald'}) do
 E.Field._game=game
 eq(W.free(a,6,5,'right'),true,'coincident formation can separate in '..game)
 eq(W.free(a,4,5,'left'),true,'coincident formation can separate left in '..game)
 b.px=112;b.cellX=7
 eq(W.free(a,6,5,'right'),true,'clear movement allowed in '..game)
 b.px=80;b.cellX=5
end
print('PASS: '..checks..' visible idle collision assertions')
