"""Package only the new runtime and traceable artwork, then inspect the ZIP."""
import hashlib
import json
import zipfile
from pathlib import Path

root = Path(__file__).resolve().parents[1]
workspace = root.parent
from check_engine_modules import validate
validate(root, workspace / 'gen1recomp-0.3.54')
manifest = json.loads((root / 'manifest.json').read_text())
target = workspace / f"WildFollowers-v{manifest['version']}.zip"
files = sorted(p for p in root.rglob('*') if p.is_file()
               and '__pycache__' not in p.parts and 'obj' not in p.parts and 'bin' not in p.parts
               and p.name not in {'music-signal.txt','music-signal.txt.tmp'})
legacy = Path.home() / 'Downloads/WildFollowers-v2.22.17.zip'
with zipfile.ZipFile(legacy) as archive:
    old_lua = {hashlib.sha256(archive.read(n)).hexdigest()
               for n in archive.namelist() if n.endswith('.lua')}
for p in files:
    if p.suffix.lower()=='.exe':
        audit=json.loads((root/'MUSIC-HELPER-AUDIT.json').read_text())
        assert p.relative_to(root).as_posix()==audit['file']
        assert hashlib.sha256(p.read_bytes()).hexdigest()==audit['sha256']
    else:
        assert p.suffix.lower() not in {'.gba', '.gb', '.gbc', '.dll'}, p
    if p.suffix == '.lua':
        assert hashlib.sha256(p.read_bytes()).hexdigest() not in old_lua, p
provenance = json.loads((root / 'asset-provenance.json').read_text())
assert len(provenance['files']) == 1025
assert hashlib.sha256(legacy.read_bytes()).hexdigest() == provenance['source_sha256']
for entry in provenance['files']:
    assert hashlib.sha256((root / entry['path']).read_bytes()).hexdigest() == entry['sha256']
with zipfile.ZipFile(target, 'w', zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
    for p in files:
        archive.write(p, p.relative_to(root).as_posix())
with zipfile.ZipFile(target) as archive:
    assert archive.testzip() is None
    assert json.loads(archive.read('manifest.json')) == manifest
    ee=json.loads((root/'EE-OVERWORLD-AUDIT.json').read_text())
    assert not ee['missing_base']
    forms=json.loads((root/'FORM-ARTWORK-AUDIT.json').read_text())
    assert len(forms['forms'])==364
    assert len({r['path'] for r in forms['files']})==len(forms['files'])
    assert len([n for n in archive.namelist() if n.endswith('.png')]) == 1025+len(ee['files'])+len(forms['files'])
    for row in ee['files']:
        assert hashlib.sha256(archive.read(row['path'])).hexdigest()==row['sha256']
    for row in forms['files']:
        assert hashlib.sha256(archive.read(row['path'])).hexdigest()==row['sha256']
digest = hashlib.sha256(target.read_bytes()).hexdigest()
target.with_suffix('.sha256').write_text(f'{digest}  {target.name}\n')
print(f'PASS {target.name}: {len(files)} files; artwork hashes/ZIP CRCs checked; no verbatim legacy Lua')
