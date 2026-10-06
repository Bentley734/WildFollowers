local checks=0
local function eq(a,b)checks=checks+1;assert(a==b,tostring(a)..' ~= '..tostring(b))end
local shader='previous';local drawn;local native=0
love={graphics={getShader=function()return shader end,setShader=function(s)shader=s end,
 setColor=function()end,newQuad=function(...)return {...}end,draw=function(...)drawn={...}end}}
local base={C={},Data={ATLAS={species={},sheets={0,256,32,32,3,0},w=128,h=256}},
 FOLLOWER={},Gfx={ready=true,quads={},pages={'page1','page2'},shader={send=function()end},mosaic=1,
 draw=function()native=native+1;return true end}}
local E=dofile('adapter.lua')(base,{},function()return {}end)
eq(E.Gfx.draw(1,0,false,1,10,20,0,1,1,1,1),true);eq(native,1)
eq(E.Gfx.draw(1,8,true,1,10,20,0,1,1.5,1,.5),true)
eq(drawn[1],'page2');eq(drawn[2][1],64);eq(drawn[4],20);eq(drawn[6],-1.5);eq(drawn[7],.5)
eq(shader,'previous');eq(base.Gfx.draw~=E.Gfx.draw,true)
print('Party Parade native atlas / pulse scaling checks',checks)
