# Validation - WildFollowers 3.4.6

Based on the latest upstream 3.4.5 source, commit `abda2022ab10d4d902265c795ca277eca7898859`. Integration tests used the unpacked Gen1Recomp **0.3.95** engine with its real game modules and mod sandbox. Both **Lua 5.3** and **LuaJIT 2.1** passed.

## Imported artwork

`PokemonCompanion-FireRed-v0.1.2.zip` SHA-256:

`02db04b95cafe96e7645f8e1b7fdba8fd2a1717c3ade6eeb54562311d8acecdf`

The conversion audit verifies **420 sheets**, **387 base species** (1-386 plus Munchlax), **33 additional forms**, **1,680 cardinal direction sequences**, and **9,600 walking frames**. All **3,110,035 visible pixel instances** match the supplied source pixels after applying the source frame offsets. Conversion retains original palettes, native pixels, ground anchors and 60 Hz frame durations; transparent padding is normalized without resampling. Per-file hashes and source metadata are recorded in `COMPANION-OVERWORLD-AUDIT.json`.

## Automated integration matrix

**120 fixture runs passed.** All eleven games are Red, Blue, Yellow, Gold, Silver, Crystal, Ruby, Sapphire, FireRed, LeafGreen and Emerald.

| Suite | Games | Runtimes | Runs |
| --- | --- | --- | ---: |
| Companion source and rendering | All eleven | Lua 5.3, LuaJIT | 22 |
| Existing EE source regression | All eleven | Lua 5.3, LuaJIT | 22 |
| Native player movement/followers | All eleven | Lua 5.3, LuaJIT | 22 |
| Full runtime/sandbox integration | All eleven | Lua 5.3, LuaJIT | 22 |
| Music effects and queued BGM observer | All eleven | Lua 5.3, LuaJIT | 22 |
| Native GBA grass compositing | Five GBA games | Lua 5.3, LuaJIT | 10 |

The Companion suite loads every imported sheet and checks every actual source frame and duration in all four directions, including animations longer than four frames. It covers independent wild/follower choices, unchanged G9 defaults and EE ordering, native menu persistence, missing-asset and exact-form fallbacks, original-palette behavior, Unown personality/DV/stored-letter forms, punctuation aliases, and version-specific Deoxys forms.

Rendering checks cover native ground anchors at 1x/2x/3x zoom, visible-bottom water cropping, followers remaining uncropped, Crystal's top/bottom OAM split, ball recall/hidden bodies, and the voxel bridge's selected frame, anchors, UVs, mesh reuse/disposal and native-entity delegation. Existing runtime fixtures also exercise the actual supported third-party voxel renderer modules.

The music regression compiles the queue observer through the real mod sandbox, where the global `package` table is unavailable. Both the GB/GBC ChipAudio and GBA audio backends pass BGM-envelope/playback-position checks, SFX exclusion, mute/pause handling and hook restoration.

Existing fixtures received compatibility corrections for the current engine: use the real additional sprite catalogues, accept an explicit voxel-reference directory, allow the native eight-frame GBA turn before the following movement poll, expose the controlled field-effects `rse()` predicate, and use a Lua 5.3/LuaJIT-compatible local `unpack`. Assertions and production movement behavior remain unchanged.

All 51 Lua source/test files compile on both runtimes, and all 45 literal engine-module references match the engine's case-sensitive packaged filenames.

## GPU rendering

A separate **2,956-check** rendering run passed under real LÖVE/OpenGL on an NVIDIA GPU, using the updated WildFollowers renderer and G1R 0.3.95's version module. All 420 textures loaded; ten representative species/forms were rendered in four directions and three timed poses. Rendered water cropping and pixel-identical Crystal split composition passed. This is an isolated rendering harness, not an in-game playthrough.

## Release packaging

The release packager verifies all **4,577 artwork hashes**, ZIP CRCs, manifest
contents, and the unchanged Windows music helper against its existing audit.
It excludes Git metadata, caches, build debris, and previous packages. A separate
SHA-256 checksum accompanies the release ZIP.

## Reproduction and limits

`tools/test_companion_sprites.py` accepts explicit engine and test-support paths instead of relying on a particular workspace layout. With Lupa installed, run:

```text
python tools/test_companion_sprites.py --engine "<unpacked-engine>" --love-stub "<test-support>/tests/love_stub.lua" --suite companion --suite ee --suite movement --suite runtime --suite music --suite grass --dex-root "<1025Dex-source>" --voxel-reference "<voxel-reference-directory>"
```

The runtime fixture uses a locally owned FireRed cartridge adjacent to the supplied 1025Dex source for its native species mapping. No cartridge files are included in the mod.

Headless fixtures use controlled maps, UI/service boundaries and recorded graphics calls. The older engine test stub supplies the headless LÖVE API only; gameplay modules are imported from 0.3.95. Android hardware, a full interactive playthrough, every real map/cutscene and every possible mod combination were not tested. The Companion source contains its original normal palettes; it does not invent shiny recolors. Species without supplied Companion art retain the existing artwork fallback.
