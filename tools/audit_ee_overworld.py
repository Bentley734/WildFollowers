from pathlib import Path
from PIL import Image,ImageOps,ImageDraw
import json,hashlib
root=Path(__file__).resolve().parents[2];mod=root/'WildFollowersRewrite';source=root/'Emerald Expansion Sprites'
audit=json.loads((mod/'EE-OVERWORLD-AUDIT.json').read_text());assert not audit['missing_base']
for row in audit['files']:
 im=Image.open(source/row['source']);out=Image.open(mod/row['path']);assert out.mode=='RGBA'
 lines=(source/row['palette']).read_text().splitlines();colors=[tuple(map(int,l.split())) for l in lines[3:3+int(lines[2])]]
 s=row['size'];n=row['source_frames']
 for facing,start in enumerate((0,4,6 if n==8 else 4,2)):
  for frame in range(4):
   k=start+frame%2;expected=Image.new('RGBA',(s,s));indices=im.crop((k*s,0,(k+1)*s,s));expected.putdata([(*colors[i],0 if i==0 else 255)for i in indices.getdata()])
   if facing==2 and n==6:expected=ImageOps.mirror(expected)
   assert expected.tobytes()==out.crop((frame*s,facing*s,(frame+1)*s,(facing+1)*s)).tobytes(),row['key']
 assert hashlib.sha256((mod/row['path']).read_bytes()).hexdigest()==row['sha256']
canvas=Image.new('RGB',(896,672),(205,223,196));d=ImageDraw.Draw(canvas)
keys=['PIKACHU','PIKACHU_female_shiny','ABSOL','BULBASAUR','TORCHIC','WAILORD','ALCREMIE','CHARIZARD']
for i,key in enumerate(keys):
 row=next(r for r in audit['files'] if r['key']==key);im=Image.open(mod/row['path']);s=row['size'];x=(i%2)*448;y=(i//2)*168
 d.text((x+8,y+8),key,fill=(0,0,0))
 for direction in range(4):
  frame=im.crop((0,direction*s,s,(direction+1)*s)).resize((s*2,s*2),Image.Resampling.NEAREST);canvas.paste(frame,(x+direction*104+8,y+30),frame)
canvas.save(root/'EE-overworld-preview.png');print('PASS all',len(audit['files']),'converted sheets: every pixel, normal/shiny palettes, transparency, directions and mirrored six-frame right poses')
