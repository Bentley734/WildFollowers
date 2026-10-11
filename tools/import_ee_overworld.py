"""Convert EE indexed overworld strips to four-direction RGBA walk sheets."""
from pathlib import Path
from PIL import Image, ImageOps
import json,re,hashlib
root=Path(__file__).resolve().parents[2];mod=root/'WildFollowersRewrite';source=root/'Emerald Expansion Sprites'
roster=dict((int(n),s) for n,s in re.findall(r'id=(\d+),name="([^"]+)"',(root/'1025Dex/encounters/roster.lua').read_text()))
folders={re.sub('[^A-Z0-9]','',p.name.upper()):p for p in source.iterdir() if p.is_dir()}
audit=json.loads((root/'1025Dex/EE-SPRITE-AUDIT.json').read_text())
speciesFolders={r['species']:source/Path(r['source']).parent for r in audit['sources'] if r['folder']=='front'}
speciesFolders['ALCREMIE']=source/'alcremie/strawberry'
for n,s in roster.items():
 if s not in speciesFolders and re.sub('[^A-Z0-9]','',s) in folders:speciesFolders[s]=folders[re.sub('[^A-Z0-9]','',s)]
entries={};report=[]
def pal(path):
 lines=path.read_text().splitlines();assert lines[:2]==['JASC-PAL','0100'];count=int(lines[2]);colors=[tuple(map(int,l.split())) for l in lines[3:3+count]];assert len(colors)==count;return colors
def convert(path,palette):
 im=Image.open(path);assert im.mode=='P';size=im.height;count=im.width//size;assert im.width==size*count and count in (6,8),(path,im.size)
 colors=pal(palette);rgba=Image.new('RGBA',im.size);rgba.putdata([(*colors[i],0 if i==0 else 255) for i in im.getdata()])
 out=Image.new('RGBA',(size*4,size*4));rows=[0,4,6 if count==8 else 4,2]
 for row,start in enumerate(rows):
  for step in range(4):
   k=start+step%2;frame=rgba.crop((k*size,0,(k+1)*size,size))
   if row==2 and count==6:frame=ImageOps.mirror(frame)
   out.paste(frame,(step*size,row*size))
 assert out.getbbox();return out,count
for species,folder in sorted(speciesFolders.items()):
 for female in (False,True):
  path=folder/('overworldf.png' if female else 'overworld.png')
  if female and not path.is_file() and (folder/'overworld_normalf.pal').is_file():
   path=folder/'overworld.png'
  if not path.is_file():continue
  for shiny in (False,True):
   palette=folder/('overworld_shiny.pal' if shiny else 'overworld_normal.pal')
   fp=folder/('overworld_shinyf.pal' if shiny else 'overworld_normalf.pal')
   if female and fp.is_file():palette=fp
   if not palette.is_file():continue
   key=species+('_female' if female else '')+('_shiny' if shiny else '')
   out,count=convert(path,palette);relative='assets/ee/'+key+'.png';dest=mod/relative;dest.parent.mkdir(parents=True,exist_ok=True);out.save(dest)
   entries[key]=relative;report.append(dict(key=key,path=relative,source=path.relative_to(source).as_posix(),palette=palette.relative_to(source).as_posix(),size=out.height//4,source_frames=count,sha256=hashlib.sha256(dest.read_bytes()).hexdigest()))
lines=['return function() return { species = {']+[f' [{json.dumps(k)}]={json.dumps(v)},' for k,v in entries.items()]+['}, national = {']+[f' [{n}]={json.dumps(s)},' for n,s in roster.items()]+['} } end']
(mod/'src/ee_data.lua').write_text('\n'.join(lines)+'\n');missing=[s for s in roster.values() if s not in entries]
(mod/'EE-OVERWORLD-AUDIT.json').write_text(json.dumps(dict(files=report,missing_base=missing),indent=2)+'\n');print(len(report),'sheets; missing base:',missing)
