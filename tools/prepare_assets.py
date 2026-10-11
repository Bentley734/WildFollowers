"""Copy only the supplied PNG artwork and its notice; never import legacy Lua."""
import hashlib
import json
import struct
import zipfile
from pathlib import Path

root = Path(__file__).resolve().parents[1]
archive = Path.home() / 'Downloads/WildFollowers-v2.22.17.zip'
records = []
with zipfile.ZipFile(archive) as source:
    for national in range(1, 1026):
        relative = f'assets/g9rpsprites/{national:03d}-normal.png'
        data = source.read('wildfollowers/' + relative)
        assert data[:8] == b'\x89PNG\r\n\x1a\n'
        width, height = struct.unpack('>II', data[16:24])
        assert width % 4 == 0 and height % 4 == 0
        target = root / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(data)
        records.append({'national': national, 'path': relative,
                        'sha256': hashlib.sha256(data).hexdigest(),
                        'width': width, 'height': height})
    (root / 'SUPPLIED-ARTWORK-NOTICES.md').write_bytes(
        source.read('wildfollowers/THIRD_PARTY_NOTICES.md'))
(root / 'asset-provenance.json').write_text(json.dumps({
    'source': archive.name,
    'source_sha256': hashlib.sha256(archive.read_bytes()).hexdigest(),
    'files': records,
}, indent=2) + '\n', encoding='utf-8')
print(f'Prepared {len(records)} unchanged PNGs; no legacy Lua copied.')
