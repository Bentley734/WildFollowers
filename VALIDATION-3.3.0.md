# Validation — WildFollowers 3.3.0

Base: GitHub release Bentley734/WildFollowers 3.2.0. Downloaded release bytes match the previously delivered 3.2.0 package. Engine integration source: bryanthaboi/gen1recomp commit 01b7835bae5accde60c6b8b39b24459c50a03448.

77 targeted LuaJIT runs pass:

| Suite | Cartridge coverage | What it checks |
| --- | --- | --- |
| Native ledges | All eleven | Real player step/jump implementations; Gen 1 actual ledge detector and installed script-move wrapper; one/six followers, down/left/right, 1.0/1.3 spacing, all followers visibly jump, stable identities, no recall/hidden bodies, no landing on the ledge middle, genuine scripts still recall |
| Ecosystems | All eleven | Natural mixed-role simulations, actual controller interpolation, guardian/group/chase/forage/look/play activity, same-family protection, source/elevation/terrain isolation, NPC and target reservations, sample provenance and budget, repel, master toggle, disappearing prey, sleep frequency/cap |
| Sleep rendering | All eleven | G9/EE, zoom 1/2/3, Crystal split passes, one overlay, hidden/moving/awake exclusions, restored graphics color |
| Area lifecycle | All eleven | Spawn caps, current/preview populations, retention, pause and projection |
| Native connected-area integration | All eleven | Actual main/controller/adapter through sandbox, valid source-provider encounters, native geometry, busy timer pause, ecosystem toggles, preview activation, retention and battle entry |
| Native movement | All eleven | Existing follower movement and interpolation, yielding/rejoining, spacing, menu pause, jumps, idle behavior and NPC reservations/story recall |
| Grass | Six GB/GBC and five GBA games | Existing native grass compositing checks |

After the final guardian refinement, ecosystem and native-area suites were rerun on all eleven games (22/22). All 38 Lua source/test files compile on Lua 5.3 and LuaJIT.

The natural four-actor predator scenario produces a moving chase within five simulated seconds. Mixed populations naturally exercise guarding, sheltering, play pursuits, foraging and lookout behavior. In a four-minute solitary-population scenario, sleeping occupies 0.85% of actor time; the assertion requires less than 3% and never more than one sleeper in that habitat. These are fixture measurements, not a promise that every real route contains a predator/prey pair or family.

Fixtures use authored maps/encounter pools and controlled engine service, UI and graphics boundaries. The Gen 1 ledge detector receives the fixture Game singleton that the native constructor normally binds. Older movement tests were corrected to use a native roaming step for the ambient Gen 2 NPC scenario and to expect the pre-existing story recall behavior for scripted NPCs. GBA collision fixtures expose the newer stair/door behavior queries. These fixes allow the full movement suite to run rather than skipping its old failures.

Not verified: live GPU playthrough, every real map/cutscene/mod stack, or runtime framerate on the user’s device. Manual checks: jump ledges with six followers; watch groups and predators in populated grass; observe a guardian shielding a juvenile; Surf, cross bridges/map connections, battle/catch, reload a save and travel with Hoennto. Third-party voxel bodies receive existing pose transforms; sleep Zs remain 2D only.
