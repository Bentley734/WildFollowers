"""Import reviewed public form sheets; never infer identities from an index alone.

Inputs live in workspace/sprite-research plus the user-supplied Drive archive.
PBS FormName records identify G9RP sheets; reviewed exceptions identify Willow
filenames. Only PNG pixels are imported. Runtime identity remains 1025Dex's ID.
"""
import hashlib
import io
import json
import re
import zipfile
from pathlib import Path
from PIL import Image

root = Path(__file__).resolve().parents[1]
workspace = root.parent
research = workspace / 'sprite-research'
forms = json.loads((research / 'dex-forms.json').read_text())
by_id = {x['id']: x for x in forms}
ee = {x['key']: x['path'] for x in json.loads((root / 'EE-OVERWORLD-AUDIT.json').read_text())['files']}
normal = research / 'g9-pack/Graphics/Characters/Followers'
shiny = research / 'g9-pack/Graphics/Characters/Followers shiny'

def signature(name):
    name = name.upper().replace("'", '').replace('%', '')
    for a, b in {'ALOLAN':'ALOLA', 'GALARIAN':'GALAR', 'HISUIAN':'HISUI', 'PALDEAN':'PALDEA'}.items():
        name = name.replace(a, b)
    words = re.findall(r'[A-Z0-9]+', name)
    words = [w for w in words if w not in {'FORM', 'FORME', 'MODE', 'STYLE', 'TYPE', 'CLOAK', 'DRIVE', 'CORE', 'COLOR', 'FACE', 'RIDER', 'MANE', 'WINGS', 'FLOWER'}]
    return ''.join(sorted(words))

signatures = {}
bases = {re.sub(r'[^A-Z0-9]', '',x['base']):x['base'] for x in forms}
for x in forms:
    sig = signature(x['id'])
    assert sig not in signatures, (x['id'], signatures.get(sig))
    signatures[sig] = x['id']

sources = {}
def register(identity, variant, raw, origin, member, row_order=(0,1,2,3)):
    assert identity in by_id, identity
    image = Image.open(io.BytesIO(raw)).convert('RGBA')
    w, h = image.size
    # Seven supplied sheets have a clipped two-pixel right edge. Restore the
    # transparent canvas, retaining the 64/128-pixel frame grid and every pixel.
    target = h
    assert 128<=h<=1024 and h%4==0 and w in (h,h-2), (member, image.size)
    canvas = Image.new('RGBA', (target,target))
    canvas.paste(image, (0,0))
    frame = target//4
    ordered = Image.new('RGBA', canvas.size)
    for dest, src in enumerate(row_order):
        ordered.paste(canvas.crop((0,src*frame,target,(src+1)*frame)),(0,dest*frame))
    # Require a visible body in all four directions; malformed sheets cannot
    # make an otherwise eligible wild or follower invisible.
    for row in range(4):
        for col in range(4):
            assert ordered.getchannel('A').crop((col*frame,row*frame,(col+1)*frame,(row+1)*frame)).getbbox(), member
    key = identity+variant
    sources[key] = (ordered, {'id':identity,'variant':variant,'source':origin,'member':member,
        'source_sha256':hashlib.sha256(raw).hexdigest(),'source_size':[w,h],
        'row_order':list(row_order),'right_padding':target-w})

pbs = json.loads((research / 'g9-form-names.json').read_text())
text = (research / 'g9-pack/PBS/pokemon_forms_Gen_9_Pack.txt').read_text(encoding='utf-8-sig')
for section in re.split(r'(?=^\[)', text, flags=re.M):
    head = re.match(r'\[(\w+),(\d+)\]', section)
    named = re.search(r'^FormName\s*=\s*(.*)', section, re.M)
    if head and named:
        pbs.append({'base':head[1],'index':int(head[2]),'name':named[1].strip()})

# A few identity names include visually irrelevant ability/size labels, or
# use female suffixes rather than numbered filenames in the resource pack.
exceptions = {
    ('BASCULEGION',3):'BASCULEGION_FEMALE',
    ('NECROZMA',3):'NECROZMA_ULTRA',
    ('MEOWSTIC',2):'MEOWSTIC_MALE_MEGA',
    ('MAGEARNA',3):'MAGEARNA_ORIGINAL_MEGA',
    ('ZACIAN',1):'ZACIAN_CROWNED',('ZAMAZENTA',1):'ZAMAZENTA_CROWNED',
}
for entry in pbs:
    base = entry['base']; index = entry['index']
    label = re.sub(r'\b'+re.escape(base)+r'\b', '', entry['name'], flags=re.I)
    canonical_base=bases.get(base,base)
    identity = exceptions.get((base,index)) or signatures.get(signature(canonical_base+' '+label))
    if not identity:
        continue
    filename = f'{base}_{index}.png'
    if identity=='BASCULEGION_FEMALE': filename='BASCULEGION_female.png'
    if identity=='MEOWSTIC_FEMALE': filename='MEOWSTIC_female.png'
    for folder, variant in ((normal,''),(shiny,'_shiny')):
        path = folder / filename
        if path.is_file() and identity+variant not in sources:
            register(identity,variant,path.read_bytes(),'G9RP 3.3.8',path.relative_to(research/'g9-pack').as_posix())
        female = folder / (Path(filename).stem+'_female.png')
        if female.is_file():
            register(identity,'_female'+variant,female.read_bytes(),'G9RP 3.3.8',female.relative_to(research/'g9-pack').as_posix())

# PBS uses small as form zero; the current Dex's base is average-sized.
for base in ('PUMPKABOO','GOURGEIST'):
    for folder,variant in ((normal,''),(shiny,'_shiny')):
        path=folder/(base+'.png')
        if path.exists(): register(base+'_SMALL',variant,path.read_bytes(),'G9RP 3.3.8',path.relative_to(research/'g9-pack').as_posix())

archives=[research/'Willow-Mega-Sprites.zip',workspace/'drive-download-20261008T213343Z-1-001.zip']
archive_hashes={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in archives}
# Reviewed against the supplied directional sheets. This pack mixes
# down/left/right/up and RPG Maker down/up/left/right, even within one folder.
rpg_maker_rows={base+'_GMAX' for base in (
    'ALCREMIE','BLASTOISE','CENTISKORCH','CINDERACE','COALOSSAL','COPPERAJAH',
    'CORVIKNIGHT','DREDNAW','DURALUDON','EEVEE','GARBODOR','GENGAR','GRIMMSNARL',
    'HATTERENE','INTELEON','KINGLER','LAPRAS','MACHAMP','MELMETAL','ORBEETLE',
    'RILLABOOM','SANDACONDA','SNORLAX')}
rpg_maker_rows.update({'MEWTWO_MEGA_Y','ETERNATUS_ETERNAMAX','TOXTRICITY_AMPED_GMAX',
    'URSHIFU_SINGLE_STRIKE_GMAX','URSHIFU_RAPID_STRIKE_GMAX'})
for archive in archives:
    with zipfile.ZipFile(archive) as z:
        for member in sorted(z.namelist()):
            if not member.lower().endswith('.png'): continue
            filename=Path(member).stem.upper()
            variant='_shiny' if 'shiny' in member.lower() else ''
            identity=None
            if 'GMAX' in member.upper():
                filename=filename.replace('CORVINIGHT','CORVIKNIGHT')
                special={'ETERNATUS_GMAX':'ETERNATUS_ETERNAMAX','TOXTRICITY_GMAX':'TOXTRICITY_AMPED_GMAX',
                    'URSHIFU_1_GMAX':'URSHIFU_SINGLE_STRIKE_GMAX','URSHIFU_2_GMAX':'URSHIFU_RAPID_STRIKE_GMAX'}
                identity=special.get(filename,filename)
            elif member.startswith('ZA Megas/'):
                special={'RAICHU_3':'RAICHU_MEGA_X','RAICHU_4':'RAICHU_MEGA_Y','LUCARIO_2':'LUCARIO_MEGA_Z'}
                identity=special.get(filename,filename.rsplit('_',1)[0]+'_MEGA')
            else:
                filename=filename.replace('BANNETTE','BANETTE').replace('HOUDOOM','HOUNDOOM').replace('PIDGEOTTO','PIDGEOT')
                base,index=filename.rsplit('_',1)
                if base in ('GROUDON','KYOGRE'): identity=base+'_PRIMAL'
                elif base in ('CHARIZARD','MEWTWO'): identity=base+'_MEGA_'+('X' if index=='1' else 'Y')
                else: identity=base+'_MEGA'
            if identity not in by_id: continue
            # G9RP's own sheets win; use the other public pack to fill gaps.
            if identity+variant in sources: continue
            row_order=(0,2,3,1) if identity in rpg_maker_rows else (0,1,2,3)
            register(identity,variant,z.read(member),archive.name,member,row_order)

# Identical visible silhouettes share art without conflating battle identities.
aliases={'ZYGARDE_10_POWER_CONSTRUCT':'ZYGARDE_10','ZYGARDE_50_POWER_CONSTRUCT':'ZYGARDE',
    'GRENINJA_BATTLE_BOND':'GRENINJA','ROCKRUFF_OWN_TEMPO':'ROCKRUFF',
    'PIKACHU_STARTER':'PIKACHU','EEVEE_STARTER':'EEVEE',
    'TOXTRICITY_LOW_KEY_GMAX':'TOXTRICITY_AMPED_GMAX'}
for x in forms:
    if 'TOTEM' in x['id']:
        aliases[x['id']]=x['id'].replace('_TOTEM','').replace('_DISGUISED','')
    if x['id'].startswith('MINIOR_') and x['id'].endswith('_METEOR'):
        aliases[x['id']]='MINIOR'
aliases['MAROWAK_TOTEM']='MAROWAK_ALOLA'
for identity, alternate in aliases.items():
    if alternate in by_id: continue
    source_base=re.sub(r'[^A-Z0-9]', '',alternate)
    for folder,variant in ((normal,''),(shiny,'_shiny')):
        path=folder/(source_base+'.png')
        if path.exists(): register(identity,variant,path.read_bytes(),'G9RP 3.3.8',path.relative_to(research/'g9-pack').as_posix())

asset_folder=root/'assets/g9rpforms';asset_folder.mkdir(exist_ok=True)
files=[];catalog={}
for key,(image,row) in sorted(sources.items()):
    dest=asset_folder/(key+'.png');image.save(dest)
    row.update(path=dest.relative_to(root).as_posix(),sha256=hashlib.sha256(dest.read_bytes()).hexdigest())
    files.append(row);catalog[key]=row['path']

lines=['-- Generated by tools/import_form_overworld.py; display identity only.', 'return function() return {']
coverage=[]
for x in forms:
    identity=x['id']; entry={**x,'g9':{},'ee':{}}
    for variant in ('','_shiny','_female','_female_shiny'):
        key=identity+variant
        if key in catalog:entry['g9'][variant or 'normal']=catalog[key]
        if key in ee:entry['ee'][variant or 'normal']=ee[key]
        alternate=aliases.get(identity)
        if alternate:
            if alternate+variant in catalog and key not in catalog:entry['g9'][variant or 'normal']=catalog[alternate+variant]
            if alternate+variant in ee:entry['ee'][variant or 'normal']=ee[alternate+variant]
    lines.append(' [%s]={national=%d,base=%s,mega=%s,g9={%s},ee={%s}},' % (
        json.dumps(identity),x['national'],json.dumps(x['base']),'true' if '_MEGA' in identity else 'false',
        ','.join('[%s]=%s'%(json.dumps(k),json.dumps(v)) for k,v in entry['g9'].items()),
        ','.join('[%s]=%s'%(json.dumps(k),json.dumps(v)) for k,v in entry['ee'].items())))
    coverage.append(entry)
lines.append('} end')
(root/'src/form_data.lua').write_text('\n'.join(lines)+'\n',encoding='utf-8')
audit={'archive_sha256':archive_hashes,'g9_archive_sha256':hashlib.sha256((research/'Generation-9-Pack-v3.3.8.rar').read_bytes()).hexdigest(),
       'files':files,'forms':coverage,'missing_art':[x['id'] for x in coverage if not (x['g9'] or x['ee'])]}
(root/'FORM-ARTWORK-AUDIT.json').write_text(json.dumps(audit,indent=2)+'\n',encoding='utf-8')
print(f"Imported {len(files)} sheets; {sum(bool(x['g9']) for x in coverage)} G9 forms, {sum(bool(x['ee']) for x in coverage)} EE forms; {len(audit['missing_art'])} base fallbacks")
print('Missing art:',', '.join(audit['missing_art']))
