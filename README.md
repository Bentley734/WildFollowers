# WildFollowers 3.3.0 — Ledges and livelier ecosystems

Based on the latest GitHub release, 3.2.0, retrieved and compared byte-for-byte on October 9, 2026.

Followers now stay outside their Pokéballs during normal ledge hops. Gen 1’s native ledge movement queue is distinguished from story scripts, so the recorded two-step hop stays intact. All selected followers replay the jump with the existing native jump curve and their own spacing. Real dialogue, NPC scripts and doors retain their existing recall behavior.

Living ecosystems are more visible at ordinary spawn amounts:

- Valid encounters can be placed near compatible existing wilds. A maximum of four additional samples from the current source encounter provider favors relatives or predator/prey pairs when available. This deliberately favors social combinations over the original random mix; it never injects a species that the current provider did not return, changes its level, increases the spawn cap or copies a stale encounter. The special Tandemaus result is not promoted by extra sampling.
- Peaceful mixed-species groups of up to four supplement same-species and evolution-family groups. Leaders move; companions follow compact positions nearby.
- Evolved guardians escort nearby young Pokémon, intervene against approaching predators, and can make a predator back off. Young Pokémon can seek a guardian instead of always running away.
- Broader authored food-web profiles cover later-generation families. Faster chases have short movement intervals, an eight-second maximum episode and cooldowns. Pokémon never hunt their own evolution family, and these interactions do not damage, remove or automatically battle wilds.
- Foraging, looking around and short playful pursuits add activity between encounters. FORAGING AND PLAY is a new toggle, ON by default.
- Sleep is brief (3–5 seconds), infrequent, and limited to one sleeper per source habitat. The initial opportunity is 65–150 seconds away, with a 30% chance when due; group leaders remain awake. Nearby threats or the trainer wake sleepers.

Existing ecosystem toggles remain in WILDFOLLOWERS options. Turn LIVING ECOSYSTEMS OFF to restore ordinary wandering and encounter sampling. All movement still checks terrain, source-map boundaries, elevation and actor reservations; source-local roaming stays bounded. Preview and retained populations keep the existing lifecycle.

Import WildFollowers-v3.3.0.zip, replacing the older WildFollowers install, and restart gen1recomp. Existing settings retain the same keys. Requires gen1recomp >=0.3.54 and <0.4.0. See VALIDATION-3.3.0.md for tested behavior and remaining visual QA.

---

## Previous release notes

# WildFollowers 3.2.0 — Living Ecosystems

Built from the latest GitHub release, WildFollowers 3.1.14 (tag 3.1.14), downloaded on October 9, 2026. Keeps that release’s followers, settings, artwork, connected-map populations, battle integration and encounter selection.

Wild Pokémon now interact with the existing local population:

- Groups follow the strongest local member of their species or supported evolution family. Evolved leaders shelter younger members; guardians move between a juvenile and a nearby predator.
- Selected predators stalk compatible prey. Prey flee through legal habitat. Each chase lasts at most eight active seconds, followed by a ten-second cooldown.
- Selected timid species move away when the trainer approaches on the same map and elevation.
- Wilds occasionally rest with a breathing pose and floating Zs in the 2D renderer. Nearby threats or an approaching trainer wake them. The voxel body pose also receives the breathing scale; the Z overlay is 2D only.

In WILDFOLLOWERS options: LIVING ECOSYSTEMS, GROUPS AND GUARDIANS, PREDATOR AND PREY, TIMID WILDS and WILD RESTING. All default ON. Switch LIVING ECOSYSTEMS OFF to restore the original wild wandering. Settings use the existing persisted options system.

The mod does not introduce new encounter species, change levels, increase spawn amounts or remove prey. Family interactions require eligible members already present in the encounter pool; a lone Pokémon will still wander and rest. All 1,025 National identities can group with their own species. Cross-species evolution families and predator/prey relationships use authored profiles in src/ecology_data.lua, rather than claiming every species has a bespoke ecology.

Behavior stays within the actor’s source map, land/water habitat, elevation and an eight-tile home radius. Movement uses the existing collision/reservation path. Preview populations can socialize locally; retired populations keep the existing fifteen-second retention. Menus and battles keep the existing pause/reset behavior. 1025Dex and Hoennto encounter providers are unchanged.

Import WildFollowers-v3.2.0.zip, replacing the older WildFollowers install, and restart gen1recomp. The existing mod ID and saved option keys are retained. Requires gen1recomp >=0.3.54 and <0.4.0, as in the base release.

See VALIDATION-3.2.0.md for test coverage and remaining gameplay checks.

---

# WildFollowers 3.1.14

Version 3.1.14 restores compatibility with Battle Art Voxel Fork 1.11.1 and
Terrarium 1.30.1. Published actors now supply valid sprite poses instead of a
nil sprite, which crashed the voxel entity renderer and caused a 2D fallback.
The compatibility bridge uses each renderer's exported library to draw our
four-direction sheets at their actual size, with the same walking frames,
idle jumps/stretching, recall/release body scaling and selected water crop.
Both solid and shadow passes share the sprite geometry. Ordinary NPCs retain
their original renderer; no third-party mod files are changed. Integrations
install after all mods load and restore the original APIs when disposed.

Validation runs the actual SpriteBillboards and VoxelScene modules from the
two supplied archives with recorded GPU calls. Their pose assembly and entity
draw paths also run during every Gen 1 field tick (and Terrarium during Gen 2)
in the existing map seam,
door warp, save reload and story recall fixtures. All eleven supported games
are checked under Lua 5.3 and LuaJIT. These are headless tests, not a live GPU
playthrough. Reference archives are extracted under
`.work/voxel-reference/BATTLE_ART_VOXEL_FORK-1.11.1` and
`.work/voxel-reference/TERRARIUM-1.30.1/TERRARIUM` beside the project for these
tests; neither archive is redistributed in WildFollowers.

Version 3.1.13 recalls followers during story scripts and dialogue so they
cannot obstruct scripted NPC movement, including the rival approaching after
starter selection with a Hoennto-transferred party. Collision cells and movement
reservations clear before the first NPC script step, while the Poké Ball recall
plays. Followers remain recalled through script waits and battles, then release
onto safe floor after control returns. This also works with Poké Ball animations
disabled. Party Pokémon remain unchanged.

A newly written follower and visible-wild runtime for Gen1Recomp 0.3.54:
Red, Blue, Yellow, Gold, Silver, Crystal, Ruby, Sapphire, FireRed, LeafGreen
and Emerald. Gen 3 uses the new implementation too.

Version 3.1.12 uses actual Mega, Primal, regional and other alternate-form overworld art. EE prefers the existing Emerald Expansion sheets. G9RP prefers imported G9 Resource Pack and Willøw resource sheets, including Gmax and supported newer Megas. Wild and follower settings remain independent. Missing art first tries the other set's exact form; Megas without form art retain the shiny-base fallback, then normal base art. Battle species and actual shiny status are preserved.

554 new PNG variants cover 282 form identities in G9RP; EE supplies 188 identities including visually identical ability/Totem variants. Combined coverage is 289 of 364 1025Dex forms; the remaining 75 use base fallbacks. See `FORM-ARTWORK-AUDIT.json` for the exact coverage, missing-art list, source filenames, hashes and layout conversions. Some supplied Gmax sheets contain static poses. Mixed direction orders and clipped canvas edges are normalized during import. Artist attribution is in `FORM-ARTWORK-CREDITS.md` and `G9RP-SOURCE-CREDITS.txt`.

Version 3.1.10 excludes Wingull from visible land and water wilds in every supported game, including 1025Dex encounter additions. Party followers and native battle encounters are unchanged.

Version 3.1.9 separates **Land spawn amount** (existing setting, 2/4/6/8) and **Water spawn amount** (0/2/4/6/8, default 4). Each source map fills and trims its land and water populations independently. Water wilds OFF overrides the water amount; NONE removes water wilds without changing land wilds. Safety limits across active, preview and lingering populations are 16 land and 16 water actors. Counts are targets subject to available habitat, encounters, occupancy and repel.

Version 3.1.8 adds native fishing-pool fallback for Gen 1 ponds such as Route 22, which have no surfing encounters. Nearby water gets the first available spawn slot when it has no water wild, so small ponds remain represented at low density. Geometry is cached per population; occupied ponds fall back to normal route spawning. In 3.1.9 each habitat stays within its own selected spawn amount.

Version 3.1.7 fixes Gen 1 habitat separation: land Pokémon such as Nidoran no longer spawn in water. The 3.1.6 grass-table fallback was incorrect and is removed. Actual Red/Blue/Yellow imported encounter datasets are covered by the regression checks.

Version 3.1.6 removes the surf artwork added in 3.1.5; water wilds draw only their own sprites. **Water sprite crop** remains OFF (default), 1 PX, 2 PX or 3 PX. Gen 1 water spawning uses the native `water` table, or the map's own fishing group when no surfing table exists. Explicitly disabled surfing tables remain disabled; grass encounters are never used for water. All walking land and water wilds cycle through their full four-frame sequence during each step, then return to their standing frame.

Version 3.1.5 adds native surfing artwork beneath water wilds and **Water sprite crop** with **OFF (default), 1 PX, 2 PX and 3 PX** choices. Crop depths remove visible bottom pixels, ignoring transparent padding, in both G9 and EE sprites. The effect follows each wild at its visible foot position: Gen 3 reuses its native surf blob and directional animation; Gen 1–2 reuse the lower native surf-sprite row with cartridge palette handling. Land wilds and followers retain their existing rendering.

Version 3.1.4 adds **SINGLE JUMP WAVE** to Idle behavior. One companion performs a complete jump, lands for 0.1 seconds, then the next companion jumps. After the last companion, the sequence loops from the first without the normal five-second wave pause. Only one companion jumps at a time, including at the loop boundary. The existing Jump Wave and other saved choices remain available.

Version 3.1.3 reworks idle timing and fixes jump rendering for companions resting between tiles at fractional spacing. Every wave uses one shared stop clock with a 0.22-second delay between procession positions and a five-second repeat period. Jump Wave gives every member a full native jump; Bounce Wave gives each two jumps with a short landing break; Spin Wave turns once over 0.8 seconds then rests; Pulse Wave stretches once then rests. Negative wave offsets wait for their turn rather than wrapping to the previous cycle.

Look Around now looks twice before resting. Idle Walk cycles its feet briefly, then stands still. Jump and Cheer hop once every three seconds. Dance performs a two-second burst followed by two seconds of rest. Stretch rises and returns over 1.2 seconds before resting. Doze breathes gently over 3.5 seconds, and Copycat follows the trainer's stationary turns. Wander retains its configured range and legal return path. Mixed chooses a style per companion; Random and Random Wave keep one shared choice for the current stop. Walking, menus, release animations, yielding and live setting changes clear stale idle poses. Existing option values remain compatible.

Version 3.1.2 adds **Yield to player** in the WildFollowers options. Turn it OFF to walk through companions without making them sidestep or interrupt their trail movement. It defaults ON. Existing sidesteps finish naturally when switched off; NPC courtesy and terrain rules still apply.

Version 3.1.1 reduces follower collision work. Recorded trail replay checks bounds, warps, terrain and real walls without repeating full NPC/direction/elevation collision. Followers can pass NPCs on that trail and cross teammates while returning, while keeping separate settled line positions. Direct approach steps precede local detour searches; all followers share a 64-node per-frame budget with fair allowances. Blocked rejoin attempts retry at most five times per second.

A controlled blocked six-follower benchmark reduced collision probes from 26,832 to 174 (99.4% fewer); this is a synthetic workload, not a live-game FPS measurement. Native movement, bridge elevation, wall safety and connected-area regressions passed.

Version 3.1.0 adds independent **Wild sprites** and **Follower sprites** choices: **G9** (existing artwork) or **EE** (Emerald Expansion). Set them separately in the main OPTION menu or MODS -> WildFollowers -> OPTIONS to mix and match. Existing G9 defaults are preserved. Choices apply to actors already on screen.

EE includes all 1,025 base species, supported alternate overworld forms, shiny palettes and supplied female variants for party followers. Indexed source PNGs and JASC .pal files are converted to transparent RGBA PNGs. Six-frame strips gain mirrored right-facing poses; eight-frame strips retain their distinct right poses. Native 32/64-pixel frame sizes and four directional walking poses are preserved. Missing EE variants fall back to the species art or existing G9 sprites.

Based off RHH's pokeemerald-expansion 1.17.1 https://github.com/rh-hideout/pokeemerald-expansion/
Credit to RHH (RomHackingHideout), its creators, maintainers and artists; see [upstream credits](https://github.com/rh-hideout/pokeemerald-expansion/blob/master/CREDITS.md) and EE-ARTWORK-CREDITS.md.

Version 3.0.3 keeps previous-area collision coordinates aligned with the actual
Gen 2 crossing, so trailing followers can continue through the seam.

Version 3.0.2 preserves follower positions and committed movement across Gen 2
connected route/town boundaries, using the completed native coordinate shift
including clamped landings. Followers retain their order and trail history.

Version 3.0.1 connects the arrival row directly to the walking trail.
With normal one-tile spacing, all six companions start on the trainer's first
safe committed step; they do not rearrange while standing beside the trainer.
Walking ends any outstanding release effect. Unobstructed following retains
assigned party order. Necessary detours retain order within the moving and
returning groups, with flexible rejoining when the assigned route is blocked.
Larger configured gaps still apply their normal movement delay.

Version 3.0.0 adds group Random and Random Wave idle choices that remain
stable until the trainer moves, including followers joining an ongoing rest.
Copycat mirrors stationary trainer turns; Dance adds a grounded step/turn
pose, and Pulse Wave stretches gently down the formation. Mixed uses stationary
poses so random selection cannot unexpectedly wander away; Wander remains an
explicit choice. Idle delay now also offers 60 seconds.

Pokeball animations can be disabled independently of safe arrival placement.
The native transition then runs immediately; followers still wait for the player
to settle and appear in party order to the left, then right, excluding the
player's forward tile. Existing saved settings and defaults are preserved.

This release is an independent implementation. Untamed Advanced and the older
WildFollowers were reviewed as behavioral references only. See
[DESIGN-REFERENCES.md](DESIGN-REFERENCES.md) for the review and chosen scope.
Automated native/sandbox tests cover all eleven supported cartridges. Live
visual gameplay remains unverified; the stable version number does not imply
full legacy feature parity or eleven complete graphical playthroughs.

## Earlier improvements

Beta.21 fixes spacing settings reverting after edits in the Mods menu.
The live mod bucket, main options and save options stay synchronized before
and after option writes, including GBA's separate option tables. Spacing
choices use canonical decimal values and independent choice lists. Fractional
gaps track the player's current pixels and carry unused step time across cell
boundaries, preventing the formation from pulsing during each walking step.

Beta.20 releases followers in party order along the screen-left row beside
an arrival tile, using the right row when the left has no available space.
Releases always exclude the player's tile, committed destination and facing
tile. Cramped rooms fall back to nearby legal floor; without safe floor,
followers remain recalled and retry. Trainer and follower spacing now offer
1.0-4.0 tiles in 0.1-tile steps. Normal trail movement settles at fractional
pixel positions; collision checks and side returns still reserve whole cells,
and ledge jumps finish intact before settling into the requested spacing.

Beta.19 preserves followers through battles: existing positions, line assignments,
trail history and in-flight movement stay paused during combat and resume
when field controls return. Battle map reloads retain the formation on the
same map; actual warps and save loads keep their normal arrival behavior.

Beta.18 preserves follower identity, order, pixel positions, committed steps,
jump progress and trail history across connected route/town boundaries.
The formation is translated by the native connection offset rather than
recreated. Followers still on the previous map use that map's legal tiles
while approaching the new area. Doors, warps and saves retain their existing
Pokeball release behavior.

Beta.17 fixes Gen 2 initialization: the NPC collision hook now imports the
engine's exact Npc module name. The previous NPC spelling can fail in the
case-sensitive packaged engine, stopping both followers and wild updates.
Movement validation and release packaging now check exact native module
filenames so Windows filesystem case folding cannot hide this regression.

Beta.16 restores separate Trainer spacing and Follower spacing choices
(1-4 tiles) in main OPTION > WILDFOLLOWERS and Mods. Both default to one
tile. Distances follow the recorded path, so corners and ledges retain their
legal movement. Spacing settles as the trainer walks; moving and stationary
return targets use the configured gaps too. Arrivals still use nearby legal
floor tiles, then settle into the requested formation during walking.

Beta.15 gives ledge jumps and idle jumps (including Jump Wave, Bounce Wave and
Cheer) the cartridge player's native jump arc and ground shadow. Gen 1 uses
its native hop shadow layout, including Yellow's two-piece shadow; Gen 2
uses its palette-aware shadow renderer; Gen 3 uses the player's medium
shadow field-effect sheet. Shadows remain grounded, avoid duplicate Crystal
OAM draws, and disappear on landing or during Poké Ball effects.

Beta.11 fixes Gen 1 house placement by applying the native water-tileset
allowlist before interpreting water/shore tile IDs. Interior doors and
bookshelves reuse those IDs, so followers previously searched for water and
released into furniture. House arrivals now use legal floor cells. The same
rule applies to detached map queries, movement and overworld spawn placement;
imported custom water-tileset declarations are honored.

Beta.10 makes Tandemaus exceptionally rare in visible overworld populations:
only one in 1,000 eligible Tandemaus selections can spawn. The gate applies
after National species mapping, including neighboring-map previews on every
supported cartridge. Party companions and battle encounter selection keep
their existing behavior.

Beta.9 lets returning companions fill the nearest reachable free position in
line, changing their order as needed. They can pass one another while returning
through narrow corridors, then reserve separate resting cells. Party order and
PokÃ©mon records stay intact. Returning companions fill active line gaps before
using older tail cells, preventing fixed-position waits and repeated exchanges.

The **Run to catch up** toggle is restored in mod options and defaults to on,
as in the old mod. It speeds up return routing and lagging trail movement.
Turning it off uses the player's normal step pace for catching up; matching a
running/cycling player and quick sidesteps still work. Changing the toggle
takes effect on the next step, preserving movement already in progress.

Beta.8 uses the door-arrival release on initial save startup, save reloads and
replacement save sessions. Companions emerge on separate nearest legal tiles
after the player settles. When approached, they sidestep the player's committed
destination, then walk around to their trailing cells. Detours avoid walls,
warp tiles, NPCs, other followers and reserved wild destinations.

Beta.7 waits for queued door steps, player movement and input locks to finish
before choosing arrival cells. A complete native movement update confirms the
player has settled, so companions cannot release onto the walk-out tile.

Beta.6 added Hoennto's shrinking PokÃ© Ball return effect at doorways. Followers
return before the native transition starts, then play the same effect backwards
after arrival. Each companion appears on its nearest free legal tile beside
the player, avoiding walls, warp tiles, NPCs and other companions. If no tile
is available, it waits hidden and retries. This works on entry and exit;
Gen 1/2 use their native warp entrypoint, while Gen 3 uses native door transitions.

Beta.5 added explicit native grass feet cover to Gen 1 and 2, including
source-map previews and retained wilds. Wilds block occupied and reserved
destination tiles; attempting to walk into a current-map wild starts its
battle while leaving the player on the approach tile. NPCs, custom followers
and other wilds cannot enter those occupied tiles.
Gen 3 retains native grass feet cover for followers and visible wilds,
including source-map previews, retained wilds and interpolated movement.
Cover uses the installed engine's tall/long grass sheets and actor elevation.
Gen 3 sprite feet use the native 16-pixel anchor; Gen 1 and 2 keep
their 12-pixel anchor and Crystal grass slices. It restores the original wild
spawn ranges, nearest connected-area preparation and 15-second departure grace.
Placement follows the engine's native coordinate rules; Untamed Advanced was
used as a behavior reference, with independent implementation.

The shared follower trail records destinations as the player commits a step, uses that step's native
duration, and keeps a separate history cursor for each follower. This follows
Yellow's useful movement behavior with newly written code across all three
generations. Approached followers yield and fill available positions behind the player during
reversals; this can briefly delay their normal slot spacing. Solid wilds block
their path. A native NPC walking onto a recorded trail does not strand a
follower; map bounds, walls and warp checks still apply. Script and menu locks
still pause following, while ordinary forced movement such as ice continues
to feed the trail.

## Install

Replace the old WildFollowers installation with this package; its mod ID remains
`wildfollowers`. Restart the game. Enable it in every cartridge used for Hoennto
travel. Use 1025Dex 1.2.15 for the complete 1,025-species roster and shared
encounter policy; Hoennto 0.2.0 supplies campaign travel. Without 1025Dex,
followers and visible encounters use the installed cartridge roster.

Do not enable another visible-wild spawner alongside this one. This package
does not include ROMs or modify the engine installation or save species IDs.

## Included behavior

- Up to six healthy, non-egg party followers, replaying committed player steps.
- Native walking, running and cycling pace, turns, reversals and ledge hops.
- Visible land and water encounters from the cartridge's current native tables.
- A-button and player bump battles with the visible species and level.
- Solid wild tiles and reserved destinations block NPCs, followers and wilds.
- Native level ranges, Gen 2 time-of-day/swarm tables and Repel checks.
- 1025Dex generation, habitat and League policy through its encounter exports.
- National-number sprite selection for all 1,025 supplied normal-color sheets.
- Wild populations prepared in the nearest connected area before entry.
- Wilds retained across seamless travel, with 15 seconds of grace after leaving.
- Actor cleanup on doors, warps, battles, loads and Hoennto session changes.
- Native rendering integration, including Crystal's split grass compositor.

Enable Random battles to retain ordinary random encounters alongside visible
wilds. With it off, ordinary step encounters are suppressed only while a working
visible encounter is present for that terrain. Missing artwork leaves the native
encounter path available. Fishing, scripted/roaming encounters and special
activities retain their native paths. Visible encounters are suspended in
Safari areas, battle facilities and GBA PokÃ©mon Tower; Gen 1's ghost/item gate
also remains native. Yellow's built-in story Pikachu is preserved separately.

Spawn range uses a square radius in tiles: NORMAL 12, FAR 20, WIDE 32,
VERY WIDE 48 or ULTRA WIDE 64. Spawn amount is 2, 4, 6 or 8 per area, with
16 wilds shared across active, prepared and recently departed areas. The
active area fills one successful spawn per gameplay frame; failed attempts
and the nearest connected-area preview retry after 0.1 seconds. Each area
uses its own native encounters and 1025Dex policy.

Range limits new spawning. Wilds on the current map stay when you walk farther
away or they leave the screen. After leaving through a map connection, their
15-second timer runs during overworld gameplay and pauses with menus/scripts.
Returning preserves those individuals and cancels their timer. Changing range
or raising the amount preserves the population; lowering the amount trims its
excess. Only wilds belonging to the current map can start or replace battles.

## Scope and validation

This is a core-feature rewrite, not full feature parity with 2.22.17. Legacy
chaining, special follower conversations, custom movement modes, alternate
art packs, shiny overworld previews and separate swimming artwork are not
implemented. Wild battle personality/shininess is decided by the native battle
creation path. Party shininess is unchanged; followers currently use normal
artwork. The follower count controls added followers; Yellow's story follower
can remain present independently.

The eleven adapters pass automated tests under Lua 5.3 and LuaJIT 2.1 using the
real mod sandbox, species lookup, encounter samplers and selected compositor
code. A separate movement suite drives the actual native player implementations
for all eleven games. Area tests drive lifecycle timing and native detached-map
collision/encounter queries through seamless transitions. Sprite feet are
checked against native renderer origins, including Crystal's sliced compositor.
Map geometry, graphics calls and battle transitions use fixtures.
Hoennto's 110 directed travel routes and 1025Dex's all-game regression suites
also pass. These are not eleven complete graphical playthroughs. See
[VALIDATION.md](VALIDATION.md) for exact coverage and remaining checks.

## Code and artwork provenance

`main.lua`, `options.lua`, and `src/*.lua` were newly written for this rewrite.
No legacy WildFollowers, Wilds of Kanto or Untamed Advanced Lua is bundled or
loaded. The runtime calls Gen1Recomp's installed engine modules as dependencies;
it does not reproduce those modules. Existing 1025Dex and Hoennto remain
separate dependencies with their existing provenance.

The 1,025 PNGs are unchanged artwork from the supplied WildFollowers 2.22.17
archive, not new artwork. [asset-provenance.json](asset-provenance.json) records
their hashes and source archive hash. [SUPPLIED-ARTWORK-NOTICES.md](SUPPLIED-ARTWORK-NOTICES.md)
preserves that archive's notice verbatim. Its references to legacy Lua and
other asset folders describe the old package; those files are absent here.
Original artwork ownership and applicable terms remain with its creators.

## Development

`tools/prepare_assets.py` copies only the specified PNGs and notice from the
user-supplied archive. `tools/test_rewrite.py` runs the eleven-game test matrix
against the adjacent engine checkout and `.tools/lua-test` dependency; pass
`--luajit` for LuaJIT. The test reads the supplied FireRed ROM's species map
locally; the ROM is never packaged. `tools/package_release.py` builds a ZIP,
verifies artwork hashes and checks that no legacy Lua file was copied verbatim.
`tools/test_native_movement.py` exercises native committed movement, interpolation,
six followers, path revisits, menu freezing, fast movement and ledges; it also
accepts `--luajit` and `--game <cartridge>`.
`tools/test_native_elevation.py` checks the native GBA bridge collision layers
and compositor priority under LuaJIT.
`tools/test_areas.py` checks connected-area populations, range, cadence, grace
timing and preservation. `tools/test_native_areas.py` checks native detached
geometry, source-specific encounters and actual main/controller map events.
Both accept `--luajit` and `--game <cartridge>`.
`tools/test_grass.py` checks native grass crops, moving feet, source projections,
camera offsets, graphics state, water/hidden exclusions and missing artwork
under LuaJIT for all five Gen 3 games.
`tools/test_gb_grass.py` checks native Gen 1 keyed strips and Gen 2 keyed
background/OAM cover, including source projection, hiding, water and motion.
The native movement suite also drives player bump battles and solid wild
occupancy through real player movement and native collision hooks.

Beta.12 restores configurable idle behavior (default Mixed after 3 seconds): look around, idle walk, jump and jump wave, spin/bounce waves, stretch, doze, cheer and bounded wander. These are adapted behaviors; play tag, sleepy buddy and zoomies remain outside this release. Set Idle behavior to NONE to disable. Wander returns through legal reserved cells when walking resumes. Catch-up speed offers 2x (default), 3x, 4x and 6x; turning Run to catch up off uses native walking speed. Existing steps finish at their original speed. Door release waits until native GB forced movement clears the door tile. Rejoining uses collision checks and coordinated gaps rather than crossing teammates.

Beta.13: ball halves visibly separate during release, with a white starburst and long cyan energy rays inspired by the anime reference. Recall reverses the same opening effect. Arrival timing and legal placement are unchanged.

Beta.14 adds a WILDFOLLOWERS section directly to the main OPTION menu in all eleven cartridges, backed by the same saved values as mod options. Roaming NPCs cannot enter follower cells or reserved destinations. Scripted NPCs wait or prompt a legal courtesy step; those steps can finish while field controls are locked. Followers no longer cross native NPCs on recorded trails. Moving returns reserve stable procession positions, complete on their committed landing, and wait for teammates instead of repeatedly detouring. A moving procession may leave extra space while source/destination reservations clear, then compacts through normal trail replay.

# WildFollowers 3.3.1

Spawns now prefer the least-populated eligible habitat patch instead of sampling the entire route uniformly. Four-connected grass/land habitats and water bodies are grouped separately, so large patches do not absorb every spawn while smaller patches remain empty. Social spawn placement stays inside the chosen patch. Refill counts use current actor positions.

Existing per-map land/water amounts, global safety caps, legal-cell checks, repel, encounter pools, spawn range and connected-map ownership are preserved. Only patches within the configured range compete for spawns; inaccessible or full patches can yield to other available patches. Habitat geometry is cached per source map definition/dimensions. Existing wilds are not teleported; the distribution applies when filling vacancies or entering a fresh map.

Validation: 880 dedicated land/water distribution assertions across 40 random seeds, including unequal patch sizes, social anchors, sparse-patch refill and geometry caching. Eleven-game area lifecycle and native detached-map integration checks and full runtime/native pond fixtures are also run. No live gameplay capture.

# WildFollowers 3.3.2

Adds three persisted WildFollowers menu toggles, all OFF by default:

- SMART SPACING: derives each trainer/follower and follower/follower gap from visible alpha bounds across every animation frame and direction, using the selected G9/EE/form artwork. Manual trainer/follower spacing remains a minimum. Larger artwork receives larger individual gaps. Movement pauses before increasing visual overlap with the trainer or another follower; pre-existing overlaps may unwind. Smart gaps are applied through the existing legal trail and catch-up movement, so the line settles into its new spacing as it follows the trainer. Native ledge hops and NPC yielding retain their existing movement behavior.
- WILDS MARCH: loops wild walking frames in place while stationary.
- FOLLOWERS MARCH: loops follower walking frames in place while stationary or paused. Both march toggles retain position, encounters, movement, and field-lock pauses, and work in the 2D and native/3D sprite paths.

Validation: 168 targeted production-code checks for mixed G9/EE bounds, individual gaps, manual minima, trainer/follower overlap guards, overlap escape, independent march toggles, and matching 2D/native pose frames across Gen 1/2/3. Full runtime/settings/persistence and native movement fixtures pass across all eleven games. Visible alpha bounds were generated for all 4,157 supplied sprite sheets. Existing artwork is unchanged. No live gameplay capture.

# WildFollowers 3.3.3

Tightens SMART SPACING: measure visible alpha across walking frames separately for each facing, then separate each pair on its actual horizontal or vertical line axis. Removes the blanket 25% idle allowance, uses a one-pixel edge margin and excludes transparent padding below the feet. Tall sprites no longer force wide horizontal gaps.

Smart catch-up also stops adding the old two-tile-per-slot rejoin delay. Six narrow followers can maintain a six-tile horizontal line at the default manual minima. Larger bodies still receive their required individual gaps, and the visual overlap guard remains active. Manual trainer/follower spacing remains a minimum; march toggles are unchanged.

Validation: 186 targeted production-code checks including directional bounds, compact six-follower lines, no idle inflation, catch-up gaps, manual minima, overlap prevention/escape and march frames. Full runtime/settings/persistence and native movement fixtures pass across all eleven games. All Lua source compiles. Existing sprite artwork is byte-identical. No live gameplay capture.

Restart after replacing the mod. Walk a short distance for the existing line to settle into its tighter smart gaps.

# WildFollowers 3.3.4

Fixes smart-spacing followers stopping at turns. The overlap guard previously made a leading follower wait for a trailing follower, while the trailing follower already depended on the leader advancing. It now checks only the trainer and followers earlier in the actual line order, removing that circular wait. Compact directional spacing from 3.3.3 and both march toggles are retained.

Validation: the production-code regression reproduces the leader/tail stall in 3.3.3 and passes in 3.3.4. 189 targeted spacing/overlap/march checks pass across Gen 1/2/3, alongside full runtime and native movement fixtures across all eleven games. Twenty-two dedicated smart-spacing fixtures drive six followers with both G9 and EE artwork through five multi-tile turns using all eleven cartridges' actual native player movement. No live gameplay capture.

Restart the game to reload the updated movement code.


## 3.3.5
Followers keep one return destination and finish obstacle detours without circling back. Restart the game after updating.


## 3.3.6
Smoother smart catch-up, safe partial movement at sprite boundaries, leaders advancing first, and resumable full-party detours prevent the tail from repeatedly losing ground. Restart after updating.


## 3.3.7
Separate FOLLOWERS MARCH SPEED and WILDS MARCH SPEED choices offer 50%�300%, defaulting to 100%. Restart after updating.


## 3.3.8
Both march speed settings now include 10%, 20%, 25%, and 33% for slower animation.


## 3.3.9
March speed applies while stationary. Walking always uses normal walking animation.


## 3.4.0 � Music Visualizer
Followers can dance to PC output audio while idle. Run the included Windows helper, select MUSIC VISUALIZER under IDLE BEHAVIOR, and adjust MUSIC SENSITIVITY. See [music/README.md](music/README.md) for setup, controls and local audio handling.


## 3.4.1 � Visualizer effects and speed
MUSIC EFFECT offers Dance, Wave Jumps, Bar Walk / Run and Bar Stretch. VISUALIZER SPEED ranges from 10% to 200%, with a calmer 50% default. All effects return to normal following when you walk.
