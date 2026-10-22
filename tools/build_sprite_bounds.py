from pathlib import Path
import json
from PIL import Image
r=Path(__file__).resolve().parents[1];lines=['-- Visible bounds per facing, unioned over its walking frames.','return function() return {']
audit=r/'COMPANION-OVERWORLD-AUDIT.json'
columns={row['path']:row['columns'] for row in json.loads(audit.read_text(encoding='utf-8'))['files']} if audit.is_file() else {}
for p in sorted((r/'assets').rglob('*.png')):
 im=Image.open(p).convert('RGBA');w,h=im.size
 count=columns.get(p.relative_to(r).as_posix(),4)
 assert w%count==0 and h%4==0,p
 fw,fh=w//count,h//4;directions=[]
 for y,name in enumerate(['down','left','right','up']):
  boxes=[im.crop((x*fw,y*fh,(x+1)*fw,(y+1)*fh)).getchannel('A').getbbox() for x in range(count)];boxes=[b for b in boxes if b]
  b=[min(t[0]for t in boxes),min(t[1]for t in boxes),max(t[2]for t in boxes),max(t[3]for t in boxes)]if boxes else [0,0,fw,fh]
  directions.append(name+'={'+','.join(map(str,b))+'}')
 lines.append(" ['"+p.relative_to(r).as_posix()+"']={"+','.join(directions)+'},')
lines.append('} end');(r/'src/sprite_bounds.lua').write_text('\n'.join(lines)+'\n',encoding='utf-8')
