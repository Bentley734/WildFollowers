# WildFollowers 3.2.0 validation

Source: Bentley734/WildFollowers latest release 3.1.14, checked via GitHub releases API on October 9, 2026. The repository default branch is an older patch-only snapshot; the release ZIP is the actual base. The downloaded base ZIP is SHA-256 verified against the release checksum.

Engine source used for integration: bryanthaboi/gen1recomp commit 01b7835bae5accde60c6b8b39b24459c50a03448. Runs are headless, using the engine’s actual mod sandbox, controller movement and map/collision modules where specified. Geometry, UI/battle boundaries and graphics services are fixtures; no live ROM playthrough is claimed.

Passing checks:

- New ecosystem suite on all eleven cartridges under Lua 5.3 and LuaJIT: family/same-species groups, guardians, prey flight, aquatic chases, timed cooldowns, player timidity, bridge/source separation, wakeup, toggles, terrain/NPC/destination reservations, projected home radius, and forty-second mixed-population simulations across eight seeds per game. Sampled National/native identities, levels, habitats and source maps remain unchanged.
- New sleep-rendering suite on all eleven cartridges under Lua 5.3 and LuaJIT: G9/EE, zoom 1/2/3, ordinary/Crystal split passes, one body per pass, one Z overlay, hidden/moving/awake exclusions and restored graphics color.
- Existing connected-area lifecycle suite on all eleven cartridges under both runtimes. The fixture now explicitly supplies its absent Gen 1 water table.
- Actual main/controller detached-map suite on all eleven cartridges under LuaJIT, including new ecosystem ON/OFF and busy-timer assertions. Existing source-specific 1025Dex provider, preview activation, departure retention and native battle checks pass.
- Existing native grass compositing suites on all six GB/GBC and all five GBA cartridges under LuaJIT.
- All 37 Lua source and test files compile under Lua 5.3 and LuaJIT.

Boundaries: Gen 2 native integration requires LuaJIT’s bit module and cannot run under the bare Lua 5.3 executable used here. Initial attempts to run the bundled native-movement and older EE fixture suites hit fixture/API assumptions (jump timing, missing stair behavior and missing form resolver); these suites are not reported as passing. This change does not alter follower movement, species selection, battle entry or sprite catalog data. The new suites exercise actual controller movement and both sprite sets for the changed behavior.

Remaining manual verification: watch groups/guardians and chase interruptions in populated routes; observe sleepers with G9/EE and third-party voxel renderers; cross route connections/bridges, Surf, save/reload, enter battles, and travel with Hoennto using the actual enabled mod stack. Zs are a 2D overlay; voxel bodies receive breathing scale only. Runtime framerate and visual appeal have not been measured in live gameplay.
