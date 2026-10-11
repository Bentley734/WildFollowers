"""Run source under Lua 5.3 and the actual engine mod sandbox.

Rendering/window, field state and battle transitions use controlled fixtures.
Native encounter sampling, sandbox, species lookup and map predicates run as code.
"""
import os
import sys
from pathlib import Path

root = Path(__file__).resolve().parents[1]
workspace = root.parent
sys.path.insert(0, str(workspace / '.tools/lua-test'))
if '--luajit' in sys.argv:
    from lupa.luajit21 import LuaRuntime
else:
    from lupa.lua53 import LuaRuntime

os.chdir(workspace / 'gen1recomp-0.3.54')
games = ['red', 'blue', 'yellow', 'gold', 'silver', 'crystal',
         'ruby', 'sapphire', 'firered', 'leafgreen', 'emerald']
bit = '''
package.preload.bit=function()
 local b={}
 function b.band(a,c,...) local v=a & c;if select('#',...)>0 then return b.band(v,...) end;return v end
 function b.bor(a,c,...) local v=a | c;if select('#',...)>0 then return b.bor(v,...) end;return v end
 function b.bxor(a,c,...) local v=a ~ c;if select('#',...)>0 then return b.bxor(v,...) end;return v end
 function b.bnot(a)return (~a)&0xffffffff end
 function b.lshift(a,c)return (a<<c)&0xffffffff end
 function b.rshift(a,c)return (a&0xffffffff)>>c end
 function b.tobit(a) a=a&0xffffffff;return a>=0x80000000 and a-0x100000000 or a end
 return b
end
bit=require('bit')
'''
for game in games:
    lua = LuaRuntime(unpack_returned_tuples=True)
    if '--luajit' not in sys.argv:
        lua.execute(bit)
    lua.globals().arg = lua.table_from([str(root), game, str(workspace / '1025Dex')])
    lua.execute((root / 'tests/runtime.lua').read_text(encoding='utf-8'))
lua = LuaRuntime(unpack_returned_tuples=True)
for source in sorted(root.rglob('*.lua')):
    lua.execute('assert(load(...))', source.read_text(encoding='utf-8'))
print('PASS all rewrite Lua source compiles')
