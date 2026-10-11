# Validation — 2026-10-06

Beta.12 adds per-frame corridor reservation checks, catch-up multiplier checks, idle delay/cancellation tests and delayed Gen 2 door-step regressions across all eleven cartridges. Rendering and live gameplay remain unverified.

Beta.13 adds closed/open shell, cyan-ray/white-flash, reversed recall and Crystal split-pass rendering checks.

Beta.14: eleven-cartridge sandbox/menu tests cover the main options section, native submenu navigation, live choice/toggle updates, persistence calls and option-change events. Native movement tests cover three displaced followers rejoining during 12 uninterrupted walking commands, then retaining formation through 16 turning commands, with per-frame legal-tile and teammate reservation checks. NPC tests cover occupied cells, committed destinations, native roaming/script entry points and Gen 1 script recovery while controls are locked. Real native elevation checks verify NPC collision remains strict on bridge transitions. Live visual gameplay remains unverified.

Tested against the local Gen1Recomp 0.3.54 source.

Beta.11: the installed Red, Blue and Yellow house maps pass 328 checks each
across both floors and four arrival positions, using real native Map collision
data and six companion releases. No extracted map data is bundled in the mod.
An authored indoor fixture reproduces door 0x14 / shelf 0x32 water-ID reuse,
tests the native fallback and custom tileset declarations, and verifies legal
floor release. All eleven-game runtime, native movement and detached-area
matrices pass on LuaJIT. Live visual gameplay remains unverified.

Beta.10: the eleven-game LuaJIT runtime matrix checks all 1,000 Tandemaus
rarity outcomes after Dex/native species mapping: exactly one passes.
Other species bypass the rarity gate. All Lua source compiles.

Beta.9 adds regressions for an occupied original line position, a narrow
corridor blocked by teammates, two simultaneous returns, distinct resting
positions after reordering, and unchanged party objects. Catch-up tests cover
both toggle values, normal trail backlog, return-route durations and changing
the toggle during a step. Follower line positions are independent of party
indices. Live visual gameplay remains unverified.

Beta.8 adds eleven-game initial-save and same-session reload checks for ball
release, busy/load ordering, distinct legal cells and unchanged party object
identity. Native player tests cover approaches in all four directions, smooth
sidesteps and retreat, detours around NPC reservations, walls, warp tiles,
other followers and wild reservations, and regrouping after reversals. The
old immediate reversal-spacing assertions are replaced with legal detours and
eventual return to the six-slot trail. Rendering uses graphics fixtures;
live visual gameplay remains unverified.

Beta.7: the eleven-game runtime matrix includes the gap between map entry and
the scheduled door step, queued player script movement, active walk-out
interpolation and the settled landing cell. Followers remain recalled through
those stages and release only beside the final player position. Placement
retries also wait while the player is moving. Live gameplay remains unverified.

Beta.6: all eleven-game Lua 5.3 runtime checks pass, including installed door
wrappers, delayed recall, duplicate request suppression, reverse drawing scale
and anchors, six distinct legal arrival cells, stationary visibility, hidden
placement retries and cancellation/input unlock. Native player movement and
all five Gen 3 elevation suites also pass. Rendering checks use graphics
fixtures; doorway timing and Crystal compositing still need live visual QA.

| Check | Result | Boundary |
| --- | --- | --- |
| Rewrite on all eleven games, Lua 5.3 | Pass | Native sandbox and selected native modules; field/battle/graphics fixtures |
| Same matrix, LuaJIT 2.1 | Pass | Same fixture boundaries |
| National ↔ native identities | All 1,025 in each game | Real engine lookup functions; GB registry fixture; native GBA base map read from supplied FireRed ROM, expanded registry fixture |
| Visible battles | Pass | Species/level, no duplicate starts, busy guard, exact-species bridge flag |
| Native player movement, all eleven games, both runtimes | Pass | Actual player commitments and interpolation; six slots, walking, eight-frame running/GB cycling, four-frame Gen 3 cycling, corners, reversals, revisited cells, menu freeze/resume, native ledges |
| Sustained following | Pass | 340 cycling steps per game across history trimming, exact six-slot positions at each landing |
| Solid wild occupancy and player bump battles, all eleven games, both runtimes | Pass | Actual native player movement and GB collision hooks/GBA collision boundary; NPC, custom follower and wild refusals, moving-wild destination reservation, exact visible actor selection, player never commits overlapping movement |
| Native NPC crossing | Pass | Actual moving GB NPCs and GBA entity boundary on a recorded trail; followers pass, ordinary wilds stay blocked, solid walls remain blocked |
| GBA forced movement | Pass | Ten actual Player.forcedStep commitments while forced state is active; six followers keep their history when ordinary walking resumes |
| Native GBA bridge elevations, LuaJIT | Pass | All five GBA games: real Collision/Player elevation rules and FieldView draw priority; retained layer on zero/fifteen tiles, delayed layer change on arrival; geometry fixture |
| Follower lifecycle | Pass | Eggs/fainted, party reorder, UI freeze, map/battle/session resets |
| Compositors | Pass | Camera offsets, native grass footprint, native Crystal split compositor; no GPU rendering |
| Sprite feet alignment, all eleven games | Pass | Real native SpriteRenderer/OwSprites origins; Gen 3 feet at py + 16, Gen 1/2 at py + 12; Crystal top/bottom slices join correctly |
| Gen 3 grass cover, all five games, LuaJIT | Pass | Actual native grass sheet loader/crops and FieldView ordering; standing and interpolated feet, camera scrolling, bridge layers, source-map projection, retained/hidden/water actors, graphics state and missing-art fallback; authored artwork/terrain fixtures |
| Gen 1/2 explicit grass cover, all six games, LuaJIT | Pass | Actual native TileRenderer strip draw and World grass/OAM functions; source projection, hidden/water/plain-ground exclusions, retained wilds and moving feet; authored atlas and Crystal background-blit boundary |
| Area populations, all eleven games, both runtimes | Pass | 12/20/32/48/64 ranges, 2/4/6/8 amounts, one nearest preview, spawn cadence, exact 15-second grace, menu pause, return identity, option preservation and total cap of sixteen |
| Native connected-area adapters, all eleven games, both runtimes | Pass | Real GB Map constructors and GBA Collision helpers; connection units, detached source terrain/encounters, source-specific 1025Dex routing, unchanged live map/session/grid, main event projection and battle eligibility; authored geometry |
| Native Pikachu manager | Pass | Custom actors are not identified as the native story follower |
| Encounter fallback | Pass | Repel, missing assets, water option, ordinary replacement, roaming/contest preservation |
| 1025Dex all-game suite | Pass | Schema-backed registration, cry identities, collection projection, live Ruby/Sapphire encounter APIs |
| 1025Dex native encounter suite | Pass | Existing native/habitat, cave, League, generation and Ultra Beast regressions |
| Hoennto suite | Pass | 110 directed routes and roundtrips through the mod sandbox; native save schemas and existing lifecycle regressions |

For beta.5 the rewrite matrix performs 23,388 assertions per runtime, and the
native movement matrix performs 57,308. Species checks and repeated fast-path
positions account for most of these counts; counts are not story coverage.
The area lifecycle suite adds 4,466 assertions per runtime, and the native
connected-area integration suite adds 700 per runtime. The latter drives the
real Sandbox-loaded main/controller/adapter path through a seamless map event,
including a prepared actor becoming current without changing its identity,
and a locked seam preserving visible actors without consuming the grace timer.
Beta.4 adds 1,185 native grass-cover checks under LuaJIT. The source-map suite
also checks that actual main/controller collection adds covers to prepared
wilds and draws the native front crop at the projected camera coordinates.
Beta.5 adds 80 native Gen 1/2 grass-cover checks under LuaJIT and replaces
the former pass-through-wild movement case with solid occupancy/bump battles.
The native elevation suite adds 250 checks under LuaJIT, including real native
NPC collision refusals and the NPC-on-wall fallback.
The native movement tests execute installed player and script-movement modules
with controlled geometry and UI boundaries. Gen 1's warp lookup is a table,
with its real callable `warpAtCell` method, so the first-step failure cannot
be hidden by a differently shaped map fixture again.

1025Dex and Hoennto results above are the compatibility checks performed for
the beta.1 rewrite; those dependencies were not changed by beta.5. Current
WildFollowers tests exercise source-specific encounter provider exports with
fixtures; they do not repeat complete Hoennto travel sessions.

Not verified: a complete GPU playthrough on each cartridge; every scripted
cutscene, bridge/ledge combination, surf transition or third-party mod stack.
The supplied local ROM mapping validates the nonuniform native Hoenn ordering,
but it is not eleven imported-ROM graphical tests. The release is therefore
labeled beta rather than declaring that coverage complete.

Useful remaining manual checks: enter/exit buildings with six followers, cross
ledges and bridges, Surf and dismount, battle/catch a visible expanded species,
save/reload, and travel between generations with Hoennto. Yellow's story scenes
and Crystal's grass overdraw should also receive graphical checks.


## Beta.20 placement and fractional spacing

Native movement fixtures verify left-row party ordering, right fallback, facing-tile exclusion in four directions, no-floor retry, 31 choices per spacing option, and exact fractional pixel gaps along straight and turning routes across eleven cartridges. Existing runtime, area/battle and elevation suites also pass. Live gameplay rendering has not been verified.


## Beta.21 settings persistence

The beta.20 menu fails the new real ManagerState/SaveSerializer regression: a 1.1 Mods-menu value leaves the root writer at 1.0. The fix passes all 31 choices for both independent spacing settings across all eleven cartridges, with main-menu display and serialized reload values checked.

Fractional movement additionally tracks native player pixel progress and preserves frame time across cell boundaries. Frame-by-frame gap assertions pass for eleven cartridges, in addition to stationary gaps and corners.


## 3.0.0 release validation � 2026-10-07

New idle tests cover stable six-member group choices over 600 frames, late participants, immediate movement cancellation, Copycat in all directions, bounded Dance and grounded Pulse poses. Animation-off tests retain forward-tile exclusion and native transition success/failure results. Native movement tests pass across eleven cartridges. Full runtime, population, area/battle, grass and elevation matrices are rerun for release. Live graphical playtesting remains unverified.


## 3.0.1 immediate departure

Native player fixtures verify six-member left and right arrival rows remain stationary until departure, start on the first safe movement commitment, retain assigned order and cancel outstanding release effects. Existing displacement/reordering and continuous moving returns continue to pass across eleven cartridges. Larger gaps retain configured delay; blocked steps retain native collision rules.


## 3.0.2 Gen 2 connected boundaries

The 3.0.1 implementation fails the new native Gen 2 connection regression for a clamped landing. Tests call the engine World.tryConnection implementation with its map.entered-before-final-position lifecycle. Gold, Silver and Crystal cover all four directions at three boundary coordinates, including native landing clamps, exact horizontal/vertical pixels and destinations, movement progress, follower identity, order, trail cursor and resumed movement. Failed connections also clear the temporary crossing capture. Runtime, movement, area/battle, grass and elevation matrices pass. Live graphical playtesting remains unverified.


## 3.0.3 trailing seam collision

Published 3.0.2 fails the new trailing-step collision regression when the previous map has an obstacle at the incorrectly queried coordinate after a clamped crossing. The corrected collision view passes in all four directions for Gold, Silver and Crystal. Full six-member walking sequences also verify identity, destination entry and spacing against each assigned procession position after continued movement. Lua 5.3 and LuaJIT runtime/movement suites and area, grass and elevation matrices pass. Live gameplay remains unverified.


## 3.1.3 idle behavior rework

The native cartridge movement fixture loads tests/idle_behaviors.lua and exercises every idle option for 900 updates with six companions, including paused interpolated middle slots. Jump and bounce waves run for 30 seconds at 30, 60 and 144Hz, verifying complete jump counts, visible height and procession-order starts for all six members. Spin is bounded to one turn per five-second cycle and rests for most of each cycle. Tests cover mode/delay changes, movement cancellation, bounded wandering, actual fractional formation hop heights and G9/EE sprite renderer heights/frames using the native jump curves. All eleven cartridges pass Lua 5.3 and LuaJIT movement suites, plus runtime integration. Live graphical gameplay remains unverified.


## 3.1.4 single looping jump wave

Single Jump Wave tests track every update over thirty seconds with one, two and six companions at 30, 60 and 144Hz. At most one jump is active at any time, all members participate repeatedly in procession order, and each cycle repeats after exactly count * (native jump duration + 0.1 seconds), within update quantization. Native fractional formation checks cover both Jump Wave and Single Jump Wave; existing G9/EE idle draw checks and movement interruption tests continue to pass. Live graphical gameplay remains unverified.


## 3.1.5 water wild rendering

Water rendering tests exercise OFF/1/2/3 visible-pixel crop depths, G9 and EE, four facings, moving/still phases and zoom 1/2/3. They verify body anchors, native surf direction/flip/frame selection, underlay placement at visible feet, Crystal bottom/top passes, and exclusions for land wilds, followers, hidden actors and recalled bodies. Native lower-row SpriteRenderer is exercised for Gen 1-2, and surf_blob loader/manifest frame fixtures for Gen 3. tools/build_water_bounds.py --check recomputes all 57,648 visible frame bottoms against bundled PNG alpha. Cached bounds avoid runtime pixel scans; cached water quads avoid repeated crop allocation. Both Lua runtimes pass eleven-cartridge runtime tests; EE variant/rendering tests pass. Live graphical gameplay remains unverified.


## 3.1.6 crop-only water rendering and walking frames

Water rendering tests deliberately make native surf sprite/blob loading fail, then assert exactly one Pokemon body draw for every crop depth, sprite set, facing, moving/still phase and zoom. Split OAM passes contain body slices only. Land and water wilds show all four walk frames across one short step, independent of their global clock, and stand after landing. Gen 1 tests compare the shared grass table with native Encounter.roll, honor explicit water rate-zero overrides, and exercise actual population spawning/publishing/drawing plus legal roaming-step rendering on a surf-only fixture. The prior fixture's fictional separate Gen 1 water table was removed. Gen 2 spawning logic is unchanged. Live graphical gameplay remains unverified.

## 3.1.7 Gen 1 habitat regression

The 3.1.6 shared-table inference and its authored fixture were incorrect: the native OverworldController wraps the separate `encDef.water` table as `grass` only when calling Encounter.roll. The adapter now reads only the imported `water` field. Tests read every map in each installed Red/Blue/Yellow dataset, verify absent water tables never fall back to grass, compare native surfing rolls, create/draw actual Route 19 aquatic populations, and verify a grass-only Nidoran table cannot publish water actors. Existing disabled-table, crop, movement and other-cartridge checks remain. Live graphical gameplay remains unverified.

## 3.1.8 actual Route 22 pond

Route 22 has no native surfing table; its water Pokemon are in the map-specific Super Rod group. The adapter uses that group only when no surfing table exists, preserving explicit disabled water tables and never using grass. Tests load the actual imported Route 22 geometry, tileset, encounter/fishing data and the actual 1025Dex GB public encounter API. Twenty low-density seeds per Gen 1 cartridge must each publish and draw a pond wild; non-native results must belong to the actual aquatic addition pool. Water OFF suppresses pond actors; filling the pond with occupied native cells still allows land wilds. Nearby aquatic selection uses cached water cells and the existing spawn cap. Live graphical gameplay remains unverified.

## 3.1.9 independent spawn amounts

Runtime tests for all eleven cartridges fill two land/eight water actors, raise land to eight, lower it to two while preserving all original water actors, lower water independently, set water NONE, refill water and switch Water wilds OFF. Both Lua 5.3 and LuaJIT are covered, together with connected-map source ownership and lingering regressions. Terrain limits are independent per source map and globally bounded at sixteen each; unavailable habitat or blocked encounters may prevent reaching a target. Actual Route 22 geometry/1025Dex tests remain. Live graphical gameplay remains unverified.
