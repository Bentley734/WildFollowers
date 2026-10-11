"""Check literal engine module references against case-sensitive archive names.

Windows filesystem imports can hide module-name casing errors that fail in
LÖVE's packaged virtual filesystem (and can load duplicate module tables).
"""
import re
from pathlib import Path


def validate(root, engine):
    paths = {p.relative_to(engine).as_posix() for p in (engine / 'src').rglob('*.lua')}
    checked = 0
    for source in (root / 'src').glob('*.lua'):
        for name in re.findall(r"['\"](src\.[A-Za-z0-9_.]+)['\"]", source.read_text()):
            if name.endswith('.'):
                continue  # A generation-specific module prefix, not an import.
            path = name.replace('.', '/') + '.lua'
            assert path in paths, f'{source.name}: engine module missing or wrong case: {name}'
            checked += 1
    print(f'PASS {checked} engine module references use exact packaged filenames')


if __name__ == '__main__':
    root = Path(__file__).resolve().parents[1]
    validate(root, root.parent / 'gen1recomp-0.3.54')
