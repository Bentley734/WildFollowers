import os,sys,ast,json
from pathlib import Path
root=Path(__file__).resolve().parent
sys.path.insert(0,str(root/'.tools/python'))
from lupa.lua53 import LuaRuntime
engine=root/'gen1recomp-0.3.54'
addon=root/'PartyParade'
os.chdir(addon)
shim="\n      package.preload.bit=function()\n        local B={}\n        function B.band(a,b,...) local n=a & b;if select('#',...)>0 then return B.band(n,...) end;return n end\n        function B.bor(a,b,...) local n=a | b;if select('#',...)>0 then return B.bor(n,...) end;return n end\n        function B.bxor(a,b,...) local n=a ~ b;if select('#',...)>0 then return B.bxor(n,...) end;return n end\n        function B.bnot(a) return (~a) & 0xffffffff end\n        function B.lshift(a,b) return (a << b) & 0xffffffff end\n        function B.rshift(a,b) return (a & 0xffffffff) >> b end\n        function B.tobit(a) a=a & 0xffffffff;if a>=0x80000000 then return a-0x100000000 end;return a end\n        return B\n      end\n      bit=require('bit')\n    "
names=['graphics_adapter','dependency_integration','entry_dialogue','idle_spacing','idle_collision','return_speed','jump_wave','mixed_idle','random_idle','random_wave','social_idle','dance_idle','flowers']
failures=0
checkLua=LuaRuntime(unpack_returned_tuples=True)
checkLua.execute(shim)
checkLua.execute('package.path='+repr(engine.as_posix()+'/?.lua;')+'..package.path')
for path in addon.rglob('*.lua'):
    checkLua.eval('function(source,name) assert(load(source,name)) end')(path.read_text(encoding='utf-8'),'@'+path.as_posix())
manifest=checkLua.table_from(json.loads((addon/'manifest.json').read_text()),recursive=True)
checkLua.eval('function(raw) return require("src.mods.Manifest").validate(raw,"PartyParade") end')(manifest)
print('All Lua source compiles; engine manifest validation passes',flush=True)
for name in names:
    path=addon/'tests'/f'{name}.lua'
    if not path.exists():continue
    lua=LuaRuntime(unpack_returned_tuples=True)
    lua.execute(shim)
    lua.execute('package.path='+repr(engine.as_posix()+'/?.lua;')+'..package.path')
    lua.globals().arg=lua.table_from([engine.as_posix(),(root/'untamed_advanced').as_posix(),addon.as_posix()] if name=='dependency_integration' else ['.'])
    try:lua.execute(path.read_text(encoding='utf-8'))
    except Exception as err:failures+=1;print(f'FAIL {name}: {err}',flush=True)
sys.exit(bool(failures))
