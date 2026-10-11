from pathlib import Path
import os,sys
root=Path(__file__).resolve().parents[1];workspace=root.parent
sys.path.insert(0,str(workspace/'.tools/python'))
from lupa.lua53 import LuaRuntime
from lupa.luajit21 import LuaRuntime as JitRuntime
os.chdir(workspace/'gen1recomp-0.3.54')
for runtime in (LuaRuntime,JitRuntime):
 for version in ('red','blue','yellow','gold','silver','crystal','ruby','sapphire','firered','leafgreen','emerald'):
  lua=runtime(unpack_returned_tuples=True);lua.globals().arg=lua.table_from([str(root),version]);lua.execute((root/'tests/ee_sprites.lua').read_text())

