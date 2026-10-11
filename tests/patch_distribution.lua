local root=arg[1]
local f=assert(io.open(root..'/src/areas.lua'));local source=f:read('*a');f:close()
local checks=0
local function check(v,msg)checks=checks+1;assert(v,msg)end
for seed=1,40 do
 math.randomseed(seed)
 local player={cellX=0,cellY=0,px=0,py=0}
 local function patch(x,y)
  if y>=3 and y<=8 and x>=3 and x<=10 then return 1,'land' end
  if y>=3 and y<=4 and x>=15 and x<=16 then return 2,'land' end
  if y>=3 and y<=8 and x>=25 and x<=28 then return 3,'water' end
  if y>=3 and y<=4 and x>=35 and x<=36 then return 4,'water' end
 end
 local A={generation=1,player=function()return player end,healthy=function()return true end,
  encountersBlocked=function()return false end,water=function(_,x,y)local _,k=patch(x,y);return k=='water'end,
  habitat=function(_,x,y,k)local _,s=patch(x,y);return s==k end,allowed=function()return true end,
  choose=function(_,k)return {species=k,level=5}end,repelled=function()return false end}
 local M=assert(load(source))()({options={get=function()end}},function()return A end)
 local C={followers={},actor=function(_,s,l,x,y,k)return {species=s,level=l,cellX=x,cellY=y,px=x*16,py=y*16,surface=k}end,
  ecosystemSpawn=function(_,a,k,hit,actors)return hit,actors[1]end}
 local area={id='patches',width=40,height=12,originX=0,originY=0,def={}}
 for i=1,16 do M:fill(C,area,area,64,{land=8,water=8},false) end
 local counts={0,0,0,0}
 for _,e in ipairs(M.populations.patches.actors)do
  local p=patch(e.cellX,e.cellY);check(p~=nil,'spawn stays in habitat');counts[p]=counts[p]+1
 end
 for i=1,4 do check(counts[i]==4,'unequal patch sizes evenly populated despite social anchor')end
 -- Retiring one actor refills its under-populated patch, not a crowded patch.
 local actors=M.populations.patches.actors;local removed=table.remove(actors,1);local expected=patch(removed.cellX,removed.cellY)
 M:fill(C,area,area,64,{land=8,water=8},false)
 check(patch(actors[#actors].cellX,actors[#actors].cellY)==expected,'refill chooses sparse patch')
 -- Full geometry must be reused rather than scanning native maps each frame.
 A.habitat=function()return true end
 local cached=M.populations.patches.patches
 M:fill(C,area,area,64,{land=8,water=8},false)
 check(M.populations.patches.patches==cached,'patch geometry cached')
end
print('PASS '..checks..' balanced land/water patches, unequal sizes, social anchors, refill and cache checks')
