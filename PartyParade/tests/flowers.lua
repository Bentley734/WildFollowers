-- Exercise the production overlay against tile crossings and camera movement.
local checks=0
local function check(ok,msg) checks=checks+1;assert(ok,msg) end
local draws,shader,color={},'original',{.2,.3,.4,.5}
local animation=0
local ts={cols=2,midToSlot={[1]=0,[2]=1},imageData={}}
function ts.imageData:getPixel(x,y)
  if x>=16 and (x+y)%3~=0 then return 1,animation/32,0,1 end
  return 0,.5,0,1
end
local pairs={fr={banks={flower={midIndex={[2]=1}}}},
  emerald={rse=true,banks={{row={name='Flower animation',mids={2}}}}}}
package.loaded['src.core.game3.tileset_native']={get=function()return ts end}
package.loaded['src.core.game3.tileset_anim']={_pairs=pairs}
love={image={newImageData=function(w,h,fmt,data)
  check(w==16 and h==6 and #data==384,'flower strip dimensions')
  return {data=data}
end},graphics={}}
local lg=love.graphics
function lg.newImage(data)
  return {data=data.data,setFilter=function()end,release=function()end}
end
function lg.newQuad(x,y,w,h,tw,th)
  local q={}
  function q:setViewport(a,b,c,d,e,f)
    check(a>=0 and b>=0 and c>0 and d>0 and a+c<=16 and b+d<=6,
      'source crop stays inside the flower strip')
    check(e==16 and f==6,'quad texture dimensions')
    self.x,self.y,self.w,self.h=a,b,c,d
  end
  q:setViewport(x,y,w,h,tw,th)
  return q
end
function lg.getShader()return shader end
function lg.setShader(s)shader=s end
function lg.getColor()return table.unpack(color)end
function lg.setColor(...)color={...}end
function lg.draw(image,q,x,y)
  check(shader==nil and color[1]==1 and color[4]==1,'neutral overlay state')
  draws[#draws+1]={x=x,y=y,w=q.w,h=q.h,u=q.x,v=q.y,image=image}
end
local pair='fr'
local E={Collision={_mapDef={midLayout={}}},Map={}}
function E.Map.worldMidAt(x,y)
  -- Flower, ordinary ground, and void on adjacent columns.
  return x==1 and 1 or 2,pair,x==2
end
local flowers=assert(loadfile('lib/flowers.lua'))()(E)
local function verify(px,py,cx,cy)
  draws={};flowers.drawAt(px,py,cx,cy)
  check(shader=='original' and color[1]==.2 and color[4]==.5,'render state restored')
  for _,d in ipairs(draws)do
    local x,y=d.x+cx,d.y+cy
    check(x>=px and x+d.w<=px+16 and y>=py+10 and y+d.h<=py+16,
      'overlay escaped the actor feet')
    check((x-d.u)%16==0 and (y-d.v-10)%16==0,'flower pixels retain world alignment')
    -- Matching grass pixels must stay transparent, flower pixels opaque.
    for v=0,5 do for u=0,15 do
      local alpha=d.image.data:byte((v*16+u)*4+4)
      check(alpha==(((u+16+v+10)%3==0) and 0 or 255),'ground transparency')
    end end
  end
  -- Independently sample the entire actor footprint, including its head.
  for dy=0,15 do for dx=0,15 do
    local x,y=px+dx+.5,py+dy+.5
    local painted=0
    for _,d in ipairs(draws)do
      if x>=d.x+cx and x<d.x+cx+d.w and y>=d.y+cy and y<d.y+cy+d.h then
        painted=painted+1
      end
    end
    local column=math.floor(x/16)
    local expected=dy>=10 and y%16>=10 and column~=1 and column~=2
    check(painted==(expected and 1 or 0),'missing flower pixels, head coverage, or duplicate overlay')
  end end
end
for _,bank in ipairs({'fr','emerald'})do
  pair=bank;flowers.beginFrame()
  -- Both axes, backwards/negative coordinates, fractional steps and cameras.
  for y=-16,31 do for x=-16,47 do
    verify(x,y,13.25,-7.5)
  end end
  for phase=0,63 do verify(phase/4-8,phase/4-8,-3.5,8.25)end
end
pair='fr';flowers.beginFrame();verify(0,0,0,0)
local first=draws[1].image
animation=1;flowers.beginFrame();verify(0,0,0,0)
check(draws[1].image~=first,'native animation frame refreshes')
animation=0;flowers.beginFrame();verify(0,0,0,0)
check(draws[1].image==first,'reuses cached animation frames')
E.Collision._mapDef=nil;draws={};flowers.drawAt(0,0,0,0)
check(#draws==0,'missing map is safe')
print('PASS: '..checks..' flower rendering checks; player/follower feet clipping, FR/LG and Emerald')
