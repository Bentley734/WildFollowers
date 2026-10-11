# 3.3.0

- Fixed ordinary Gen 1 ledge scripts being mistaken for cutscenes and recalling followers. Player-only ledge queues keep the trail and every follower body; real NPC/story movement still recalls.
- Added all-eleven-game native ledge regression tests for one and six followers, three directions, whole/fractional spacing, follower identity, visible jump arcs and no ball phases.
- Added bounded source-provider sampling and nearby legal placement to make social encounters observable at ordinary spawn amounts.
- Added peaceful mixed-species herds, broader family-based predator/prey roles, guardian escorts, seeking shelter and predator retreat.
- Increased chase movement cadence, preserved timed episodes/cooldowns, and cancel references immediately when their actor leaves the active population.
- Added foraging, lookout poses and short play chases, controlled by FORAGING AND PLAY.
- Greatly reduced sleeping frequency and duration, capped sleepers per source habitat and kept active leaders awake.
- Updated old movement-test fixtures to distinguish roaming NPC movement from the story recall behavior introduced before 3.2.0.

No live graphical playthrough is claimed. All 77 targeted LuaJIT test runs pass; see VALIDATION-3.3.0.md.
