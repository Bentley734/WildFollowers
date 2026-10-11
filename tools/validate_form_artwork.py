"""Verify source lineage, transparent frame grids and coverage references."""
import hashlib
import io
import json
import zipfile
from pathlib import Path
from PIL import Image

root=Path(__file__).resolve().parents[1]
workspace=root.parent
research=workspace/'sprite-research'
audit=json.loads((root/'FORM-ARTWORK-AUDIT.json').read_text())
archives={}
for name,digest in audit['archive_sha256'].items():
    path=(research/name) if (research/name).is_file() else workspace/name
    assert hashlib.sha256(path.read_bytes()).hexdigest()==digest
    archives[name]=zipfile.ZipFile(path)
assert hashlib.sha256((research/'Generation-9-Pack-v3.3.8.rar').read_bytes()).hexdigest()==audit['g9_archive_sha256']
files={row['path']:row for row in audit['files']}
assert len(files)==len(audit['files'])==554
for row in audit['files']:
    raw=(research/'g9-pack'/row['member']).read_bytes() if row['source']=='G9RP 3.3.8' else archives[row['source']].read(row['member'])
    assert hashlib.sha256(raw).hexdigest()==row['source_sha256'], row['member']
    path=root/row['path'];output=path.read_bytes()
    assert hashlib.sha256(output).hexdigest()==row['sha256'], path
    image=Image.open(io.BytesIO(output))
    assert image.mode=='RGBA' and image.width==image.height and image.width%4==0
    assert image.getpixel((0,0))[3]==0, path
    size=image.width//4
    source=Image.open(io.BytesIO(raw)).convert('RGBA')
    # Check every retained pixel against the declared original direction row.
    for dest,src in enumerate(row['row_order']):
        expected=source.crop((0,src*size,source.width,(src+1)*size))
        actual=image.crop((0,dest*size,source.width,(dest+1)*size))
        assert expected.tobytes()==actual.tobytes(),path
    for direction in range(4):
        for frame in range(4):
            assert image.getchannel('A').crop((frame*size,direction*size,(frame+1)*size,(direction+1)*size)).getbbox(),path
for form in audit['forms']:
    for art in (form['ee'],form['g9']):
        for path in art.values(): assert (root/path).is_file(),(form['id'],path)
by_id={row['id']:row for row in audit['files'] if row['variant']==''}
assert by_id['RAICHU_ALOLA']['member'].endswith('/RAICHU_1.png')
assert by_id['RAICHU_MEGA_X']['member'].endswith('/RAICHU_2.png')
assert by_id['MR_MIME_GALAR']['member'].endswith('/MRMIME_1.png')
assert by_id['PIDGEOT_MEGA']['member'].endswith('/PIDGEOTTO_1.png')
assert by_id['LUCARIO_MEGA_Z']['member']=='ZA Megas/LUCARIO_2.png'
assert by_id['URSHIFU_SINGLE_STRIKE_GMAX']['member'].endswith('/URSHIFU_1_gmax.png')
assert by_id['URSHIFU_RAPID_STRIKE_GMAX']['member'].endswith('/URSHIFU_2_gmax.png')
assert by_id['MEWTWO_MEGA_Y']['row_order']==[0,2,3,1]
assert by_id['CHARIZARD_GMAX']['row_order']==[0,1,2,3]
assert by_id['BLASTOISE_GMAX']['row_order']==[0,2,3,1]
assert len(audit['forms'])==364 and len(audit['missing_art'])==75
for z in archives.values():z.close()
print('PASS 554 imported sheets: source/output hashes, retained pixels, 8,864 visible frames, identity references and reviewed layout exceptions')
