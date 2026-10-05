# WildFollowers 2.22.17 - safe map-entry placement

Followers stay hidden until the player is visible and the map-entry fade, warp and scripted movement have finished. This applies to doors, stairs, room warps and initial formations, with arrival ball animations on or off. Settled automatic dialogue can still show followers.

Spawn placement reserves the player current tile, target tile and pixel footprint. It also excludes doorway warp tiles, blocked terrain, NPCs and other followers. When no free tile exists, the follower remains hidden rather than appearing beneath the player.

Validation: 7,941 passing headless checks across arrival (1,250), return routing (66), idle collision (21), spacing (6,397), menu scheduling (89), water wilds (84) and map persistence (34). Arrival checks include all four facing directions, counts 1-6, ball settings on/off, hidden players, entry steps, cramped exits and the actual mod sandbox. Live visual gameplay verification remains pending.

Import WildFollowers-v2.22.17.zip through the mod manager and restart the app. Existing options and saves are retained.
