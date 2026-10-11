from pathlib import Path
import os,sys,zipfile
root=Path(__file__).resolve().parents[1];workspace=root.parent;sys.path.insert(0,str(workspace/'.tools/python'))
from lupa.luajit21 import LuaRuntime
lua=LuaRuntime(unpack_returned_tuples=True)
with zipfile.ZipFile(workspace/'WildFollowers-v3.1.0.zip') as z:lua.globals().before=z.read('src/avoidance.lua').decode()
lua.globals().after=(root/'src/avoidance.lua').read_text()
lua.execute('''
local function benchmark(source)
 local calls=0
 local A={allowed=function(_,x,y)calls=calls+1;return x>=0 and y>=0 and x<200 and y<200 and not (x==101 and y==100 or x==100 and y==101) end,
 area=function()return {width=200,height=200}end,player=function()return {moving=false}end}
 local T={};local Y=assert(loadstring(source))()({options={get=function()return nil end}},function(n)return n=='adapter' and A or T end)
 local c={followers={},occupied=function()return false end}
 for i=1,6 do c.followers[i]={cellX=100,cellY=100,follower=true,surface='land'}end
 local started=os.clock()
 for _,e in ipairs(c.followers)do for i=1,4 do Y:route(c,e,{{x=180,y=180}})end end
 return calls,os.clock()-started,Y,A,T,c
end
local old,oldTime=benchmark(before)
local new,newTime,Y,A,T,c=benchmark(after)
assert(new<=304 and c.routeBudget>=0,'shared frame budget is bounded')
for _,e in ipairs(c.followers)do assert(c.routeAllowances[e]==0,'all six followers receive a search allowance')end
print(string.format('Blocked six-follower frame: collision probes %d -> %d (%.1f%% fewer), CPU %.3f -> %.3f ms',old,new,(1-new/old)*100,oldTime*1000,newTime*1000))
local scans=0
Y.goals=function()scans=scans+1;return {},{}end
T.joinGap=function()return 1 end;T.cellGap=T.joinGap;T.index=0;T.points={}
c.followers={};c.move=function()return false end
local e={yielding=true,cellX=0,cellY=0,follower=true,clock=0}
for i=0,59 do e.clock=i/60;Y:tick(c,e)end
assert(scans<=5,'blocked retries are throttled to five per second')
print('PASS blocked follower retry scans in 60 frames:',scans)
''')

