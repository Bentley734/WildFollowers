"""Run Companion integration against an explicit engine, without a fixed checkout layout.

Requires Lupa (Lua 5.3 and/or LuaJIT). A GPU is not required. Use --suite to
also run existing integration fixtures against the same selected engine.
"""
from __future__ import annotations

import argparse
import os
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
GAMES = ('red', 'blue', 'yellow', 'gold', 'silver', 'crystal',
         'ruby', 'sapphire', 'firered', 'leafgreen', 'emerald')
SUITES = {'companion': 'companion_sprites.lua', 'ee': 'ee_sprites.lua',
          'runtime': 'runtime.lua', 'movement': 'native_movement.lua',
          'music': 'music.lua', 'grass': 'grass.lua'}
BIT = '''
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


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--engine', type=Path, default=os.getenv('GEN1RECOMP_ENGINE'),
                        help='unpacked engine directory containing src/core/GameVersion.lua')
    parser.add_argument('--love-stub', type=Path,
                        help='headless love_stub.lua if not present in the engine tests directory')
    parser.add_argument('--runtime', choices=('lua53', 'luajit', 'both'), default='both')
    parser.add_argument('--game', action='append', choices=GAMES,
                        help='repeat for selected games; default: all eleven')
    parser.add_argument('--suite', action='append', choices=tuple(SUITES),
                        help='repeat for suites; default: companion')
    parser.add_argument('--dex-root', type=Path, help='1025Dex source for the existing runtime suite')
    parser.add_argument('--voxel-reference', type=Path,
                        help='directory containing the existing voxel integration reference mods')
    args = parser.parse_args()
    if not args.engine:
        parser.error('--engine or GEN1RECOMP_ENGINE is required')
    engine = args.engine.resolve()
    if not (engine / 'src/core/GameVersion.lua').is_file():
        parser.error(f'not an unpacked engine: {engine}')
    stub = (args.love_stub or engine / 'tests/love_stub.lua').resolve()
    if not stub.is_file():
        parser.error('this engine has no test stub; provide --love-stub')
    suites = args.suite or ['companion']
    if 'runtime' in suites and not args.dex_root:
        parser.error('--dex-root is required for the runtime regression fixture')
    sys.path.insert(0, str(ROOT / 'tools'))
    from check_engine_modules import validate
    validate(ROOT, engine)
    runtimes = []
    if args.runtime in ('lua53', 'both'):
        from lupa.lua53 import LuaRuntime
        runtimes.append(('Lua 5.3', LuaRuntime))
    if args.runtime in ('luajit', 'both'):
        from lupa.luajit21 import LuaRuntime
        runtimes.append(('LuaJIT 2.1', LuaRuntime))
    games = args.game or GAMES
    original_cwd = Path.cwd()
    completed = 0
    try:
        os.chdir(engine)
        for runtime_name, runtime in runtimes:
            for suite in suites:
                for game in games:
                    if suite == 'grass' and game not in GAMES[6:]:
                        continue
                    print(f'RUN {runtime_name} {suite} {game}', flush=True)
                    lua = runtime(unpack_returned_tuples=True)
                    if runtime_name == 'Lua 5.3':
                        lua.execute(BIT)
                    lua.execute("local path=...;package.preload['tests.love_stub']=function() return assert(loadfile(path))() end",
                                stub.as_posix())
                    lua.globals().arg = lua.table_from([
                        ROOT.as_posix(), game,
                        args.dex_root.resolve().as_posix() if args.dex_root else '',
                        args.voxel_reference.resolve().as_posix() if args.voxel_reference else '',
                    ])
                    lua.execute((ROOT / 'tests' / SUITES[suite]).read_text(encoding='utf-8'))
                    completed += 1
        print(f'PASS {completed} fixtures against {engine}', flush=True)
    finally:
        os.chdir(original_cwd)


if __name__ == '__main__':
    main()
