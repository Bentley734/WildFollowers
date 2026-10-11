# WildFollowers 3.3.5

Simplifies followers returning to the procession: each follower keeps its recorded rendezvous while approaching it, then resumes normal trail following. Obstacle detours retain their remaining steps instead of recalculating a greedy turn toward the obstacle at every tile. Terrain and occupancy are checked before each step; blocked detours are replanned within the existing search budget.

Smart spacing, follower size, normal following and march settings are unchanged.

Validation: a wall-detour regression reproduces circling in 3.3.4 and completes the shortest eight-step route without revisiting tiles in 3.3.5. Native movement, full runtime and six-follower smart-spacing fixtures with G9 and EE sprites pass across all eleven supported games. The 189 spacing/overlap/march checks also pass. Validation uses engine fixtures, without a live gameplay capture.

Restart the game to load the update.
