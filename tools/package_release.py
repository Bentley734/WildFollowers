"""Build a release ZIP with traceable artwork and no checkout/build debris.

Pass --engine to validate against a specific unpacked Gen1Recomp version and
--output to choose the ZIP path. Artwork digests are always checked; the old
source archive is additionally checked when it is available locally.
"""
import argparse
import hashlib
import json
import re
import zipfile
from pathlib import Path, PurePosixPath, PureWindowsPath

from check_engine_modules import validate


EXCLUDED_DIRS = {
    '.git', '.hg', '.svn', '.work', '.venv', 'venv', 'node_modules',
    '__pycache__', '.pytest_cache', '.mypy_cache', '.ruff_cache', 'obj', 'bin',
}
EXCLUDED_NAMES = {'music-signal.txt', 'music-signal.txt.tmp', '.DS_Store', 'Thumbs.db'}
EXCLUDED_SUFFIXES = {'.pyc', '.pyo', '.tmp', '.log'}
FORBIDDEN_SUFFIXES = {'.gba', '.gb', '.gbc', '.dll'}


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read_json(path):
    return json.loads(path.read_text(encoding='utf-8'))


def resolve_inside(root, name):
    """Reject absolute paths and traversal in artwork audit entries."""
    relative = PurePosixPath(name)
    assert not relative.is_absolute() and '..' not in relative.parts, name
    assert not PureWindowsPath(name).drive and '\\' not in name, name
    path = (root / Path(*relative.parts)).resolve()
    assert path.is_relative_to(root.resolve()), name
    return path


def default_engine(root):
    candidates = []
    for parent in root.parents:
        candidates.extend(parent.glob('gen1recomp-*'))
        candidates.extend(parent.glob('.work/hd-battlefields-latest/v*/engine'))
    candidates = [p for p in candidates if (p / 'src/core/GameVersion.lua').is_file()]
    if not candidates:
        raise SystemExit('No unpacked Gen1Recomp found; pass --engine PATH.')
    def version(path):
        match = re.search(r'(\d+)\.(\d+)\.(\d+)', str(path))
        return tuple(map(int, match.groups())) if match else (0, 0, 0)
    return max(candidates, key=version)


def legacy_archive(root, provenance, explicit):
    if explicit:
        path = explicit.resolve()
        assert path.is_file(), f'Legacy artwork archive missing: {path}'
        return path
    filename = Path(provenance['source']).name
    candidates = [Path.home() / 'Downloads' / filename]
    candidates.extend(parent / filename for parent in root.parents)
    return next((p for p in candidates if p.is_file()), None)


def artwork_inventory(root):
    provenance = read_json(root / 'asset-provenance.json')
    assert len(provenance['files']) == 1025
    ee = read_json(root / 'EE-OVERWORLD-AUDIT.json')
    assert not ee['missing_base']
    forms = read_json(root / 'FORM-ARTWORK-AUDIT.json')
    assert len(forms['forms']) == 364
    audits = [provenance, ee, forms]
    companion_audit = root / 'COMPANION-OVERWORLD-AUDIT.json'
    if companion_audit.is_file():
        audits.append(read_json(companion_audit))
    else:
        assert not (root / 'assets/companion').exists(), 'Companion artwork audit missing'
    expected = {}
    for audit in audits:
        rows = audit['files']
        assert len({row['path'] for row in rows}) == len(rows), 'Duplicate audit paths'
        for row in rows:
            name, digest = row['path'], row['sha256']
            assert name not in expected or expected[name] == digest, name
            assert sha256(resolve_inside(root, name)) == digest, f'Artwork changed: {name}'
            expected[name] = digest
    return provenance, expected


def package(root, engine, target, old_source):
    validate(root, engine)
    manifest = read_json(root / 'manifest.json')
    provenance, artwork = artwork_inventory(root)
    old_lua = set()
    legacy = legacy_archive(root, provenance, old_source)
    if legacy:
        assert sha256(legacy) == provenance['source_sha256'], 'Legacy source archive changed'
        with zipfile.ZipFile(legacy) as archive:
            old_lua = {hashlib.sha256(archive.read(name)).hexdigest()
                       for name in archive.namelist() if name.endswith('.lua')}
    helper = read_json(root / 'MUSIC-HELPER-AUDIT.json')
    helper_path = resolve_inside(root, helper['file'])
    assert helper_path.is_file(), ('Missing audited Windows music helper; restore '
                                  'it from the latest verified WildFollowers release')
    assert sha256(helper_path) == helper['sha256'], 'Music helper digest mismatch'
    files = []
    for path in sorted(root.rglob('*')):
        if not path.is_file():
            continue
        relative = path.relative_to(root)
        if (set(relative.parts) & EXCLUDED_DIRS
                or path.name in EXCLUDED_NAMES
                or path.suffix.lower() in EXCLUDED_SUFFIXES
                or (path.name.startswith('WildFollowers-')
                    and (path.name.endswith('.zip') or path.name.endswith('.zip.sha256.txt')))
                or path.resolve() in {target.resolve(),
                                      target.with_name(target.name + '.sha256.txt').resolve()}):
            continue
        assert not path.is_symlink(), f'Release symlink not allowed: {relative}'
        if path.suffix.lower() == '.exe':
            assert relative.as_posix() == helper['file'], relative
            assert sha256(path) == helper['sha256']
        else:
            assert path.suffix.lower() not in FORBIDDEN_SUFFIXES, relative
        if path.suffix == '.lua' and old_lua:
            assert sha256(path) not in old_lua, f'Verbatim legacy Lua: {relative}'
        files.append(path)
    pngs = {p.relative_to(root).as_posix() for p in files if p.suffix.lower() == '.png'}
    assert pngs == set(artwork), ('PNG inventory mismatch', sorted(pngs - artwork.keys()),
                                  sorted(artwork.keys() - pngs))
    target.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(target, 'w', zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
        for path in files:
            archive.write(path, path.relative_to(root).as_posix())
    with zipfile.ZipFile(target) as archive:
        assert archive.testzip() is None
        assert json.loads(archive.read('manifest.json')) == manifest
        assert len(archive.namelist()) == len(set(archive.namelist()))
        assert not any(set(PurePosixPath(name).parts) & EXCLUDED_DIRS
                       for name in archive.namelist())
        for name, digest in artwork.items():
            assert hashlib.sha256(archive.read(name)).hexdigest() == digest, name
        assert hashlib.sha256(archive.read(helper['file'])).hexdigest() == helper['sha256']
    digest = sha256(target)
    checksum = target.with_name(target.name + '.sha256.txt')
    checksum.write_text(f'{digest}  {target.name}\n', encoding='utf-8')
    legacy_note = 'checked legacy source/Lua' if legacy else 'legacy archive unavailable'
    print(f'PASS {target.name}: {len(files)} files; {len(artwork)} artwork hashes; '
          f'audited music helper; ZIP CRCs; {legacy_note}')
    print(f'SHA256 {digest}')
    return target, checksum


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--engine', type=Path, help='Unpacked Gen1Recomp engine directory')
    parser.add_argument('--output', type=Path, help='Destination release ZIP path')
    parser.add_argument('--legacy-artwork', type=Path,
                        help='Optional original WildFollowers artwork ZIP for extra verification')
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    engine = args.engine.resolve() if args.engine else default_engine(root)
    assert (engine / 'src/core/GameVersion.lua').is_file(), f'Invalid engine directory: {engine}'
    version = read_json(root / 'manifest.json')['version']
    target = args.output.resolve() if args.output else root.parent / f'WildFollowers-v{version}.zip'
    package(root, engine, target, args.legacy_artwork)


if __name__ == '__main__':
    main()
