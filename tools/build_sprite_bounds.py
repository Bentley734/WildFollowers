from pathlib import Path
from PIL import Image
r=Path(__file__).resolve().parents[1];lines=['-- Visible bounds per facing, unioned over its four walking frames.','return function() return {']
for p in sorted((r/'assets').rglob('*.png')):
 im=Image.open(p).convert('RGBA');w,h=im.size
 if w%4 or h%4:continue
 fw,fh=w//4,h//4;directions=[]
 for y,name in enumerate(['down','left','right','up']):
  boxes=[im.crop((x*fw,y*fh,(x+1)*fw,(y+1)*fh)).getchannel('A').getbbox() for x in range(4)];boxes=[b for b in boxes if b]
  b=[min(t[0]for t in boxes),min(t[1]for t in boxes),max(t[2]for t in boxes),max(t[3]for t in boxes)]if boxes else [0,0,fw,fh]
  directions.append(name+'={'+','.join(map(str,b))+'}')
 lines.append(" ['"+p.relative_to(r).as_posix()+"']={"+','.join(directions)+'},')
lines.append('} end');(r/'src/sprite_bounds.lua').write_text('\n'.join(lines)+'\n')
