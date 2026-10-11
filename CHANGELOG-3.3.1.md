# WildFollowers 3.3.1

Spawns now prefer the least-populated eligible habitat patch instead of sampling the entire route uniformly. Four-connected grass/land habitats and water bodies are grouped separately, so large patches do not absorb every spawn while smaller patches remain empty. Social spawn placement stays inside the chosen patch. Refill counts use current actor positions.

Existing per-map land/water amounts, global safety caps, legal-cell checks, repel, encounter pools, spawn range and connected-map ownership are preserved. Only patches within the configured range compete for spawns; inaccessible or full patches can yield to other available patches. Habitat geometry is cached per source map definition/dimensions. Existing wilds are not teleported; the distribution applies when filling vacancies or entering a fresh map.

Validation: 880 dedicated land/water distribution assertions across 40 random seeds, including unequal patch sizes, social anchors, sparse-patch refill and geometry caching. Eleven-game area lifecycle and native detached-map integration checks and full runtime/native pond fixtures are also run. No live gameplay capture.
