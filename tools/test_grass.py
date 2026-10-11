"""Check native grass artwork crops and actor-specific grass cover."""
import os
import sys
from pathlib import Path

root = Path(__file__).resolve().parents[1]
workspace = root.parent
sys.path.insert(0, str(workspace / '.tools/lua-test'))
from lupa.luajit21 import LuaRuntime

os.chdir(workspace / 'gen1recomp-0.3.54')
games = ['ruby', 'sapphire', 'firered', 'leafgreen', 'emerald']
for game in games:
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.globals().arg = lua.table_from([str(root), game])
    lua.execute((root / 'tests/grass.lua').read_text(encoding='utf-8'))
print(f'PASS native grass cover for {len(games)} GBA cartridges')
