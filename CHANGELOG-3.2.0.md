# 3.2.0 — Living Ecosystems

Based on the latest GitHub release, 3.1.14.

Added an optional ecosystem layer to existing wild populations: same-species/evolution-family groups, strongest local leaders, evolved guardians, authored predator/prey stalking and flight, timid reactions to the trainer, and periodic resting with breathing and 2D Zs. Added five persisted settings, all enabled by default. Existing encounter pools, species, levels, spawn amounts and party followers are retained.

Social decisions are throttled, activity is bounded near the source-local home, chases expire with cooldowns, and all movement uses existing habitat/collision/reservation checks. Source-map projection, bridge elevation separation and retiring actors are respected. Status exports include the current behavior for diagnostics.

Headless ecology/rendering and main-hook connected-map tests pass across all eleven games. See VALIDATION-3.2.0.md for exact boundaries; live graphical testing is pending.
