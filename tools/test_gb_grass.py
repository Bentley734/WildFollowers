"""Exercise native Gen 1/2 grass strip rendering with authored fixtures."""
import os
import sys
from pathlib import Path
root = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(root.parent / '.tools/lua-test'))
from lupa.luajit21 import LuaRuntime
os.chdir(root.parent / 'gen1recomp-0.3.54')
for game in ['red', 'blue', 'yellow', 'gold', 'silver', 'crystal']:
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.globals().arg = lua.table_from([str(root), game])
    lua.execute((root / 'tests/gb_grass.lua').read_text(encoding='utf-8'))
print('PASS native GB grass for six cartridges')
