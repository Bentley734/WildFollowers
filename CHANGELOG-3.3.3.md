# WildFollowers 3.3.3

Tightens SMART SPACING: measure visible alpha across walking frames separately for each facing, then separate each pair on its actual horizontal or vertical line axis. Removes the blanket 25% idle allowance, uses a one-pixel edge margin and excludes transparent padding below the feet. Tall sprites no longer force wide horizontal gaps.

Smart catch-up also stops adding the old two-tile-per-slot rejoin delay. Six narrow followers can maintain a six-tile horizontal line at the default manual minima. Larger bodies still receive their required individual gaps, and the visual overlap guard remains active. Manual trainer/follower spacing remains a minimum; march toggles are unchanged.

Validation: 186 targeted production-code checks including directional bounds, compact six-follower lines, no idle inflation, catch-up gaps, manual minima, overlap prevention/escape and march frames. Full runtime/settings/persistence and native movement fixtures pass across all eleven games. All Lua source compiles. Existing sprite artwork is byte-identical. No live gameplay capture.

Restart after replacing the mod. Walk a short distance for the existing line to settle into its tighter smart gaps.
