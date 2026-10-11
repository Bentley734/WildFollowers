local root=arg[1]
local f=assert(io.open(root..'/src/avoidance.lua'));local text=f:read('*a');f:close()
local A={area=function()return {width=12,height=12}end,
 allowed=function(_,x,y)return x>=0 and x<=4 and y>=-2 and y<=0 and not(x==2 and math.abs(y)<=1)end}
local M=assert(load(text))()({options={get=function()return true end}},function(n)return n=='adapter' and A or {} end)
local e={cellX=0,cellY=0,follower=true}
local c={followers={e},occupied=function()return false end}
local goal={x=4,y=0,n=10,slot=1}
local visited={['0:0']=true};local count=0
while e.cellX~=goal.x or e.cellY~=goal.y do
 c.routeBudget=64;c.routeAllowances={}
 local step,g=M:route(c,e,{goal})
 assert(step and g==goal,'detour must reach the reserved destination')
 local key=step.x..':'..step.y
 assert(not visited[key],'return route must not circle back to '..key)
 visited[key]=true;e.cellX=step.x;e.cellY=step.y;count=count+1
 assert(count<=10,'bounded direct return around obstacle')
end
assert(count==8,'shortest detour around wall')
print('PASS return detour completes without reversing or circling ('..count..' steps)')

