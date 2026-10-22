# Pokemon Companion overworld artwork

WildFollowers' optional **Companion** sprite source imports walking artwork from
the user-supplied `PokemonCompanion-FireRed-v0.1.2.zip`, whose manifest identifies
**TheOriginalDrJ** as the author of Pokemon Companion v0.1.2. Pokemon Companion's
following, dialogue, gifts, save handling, and other runtime code are not included.

The supplied package attributes its artwork to **Pokemon Mystery Dungeon: Red
Rescue Team (USA/Australia)**, extracted using G1R's `src/import/pmd` decoder.
Its README identifies the source ROM by MD5
`2100cf6f17e12cd34f1513647dfa506b`. No ROM, engine, story text, portraits,
voices, or other game data is distributed by this import.

The source has 423 sprite sets. WildFollowers includes the 420 Pokemon sets:
all 386 Gen 1–3 species, Munchlax (correctly mapped to National Dex 446), all 28
Unown forms, all four Deoxys forms, and all four Castform forms. The decoy,
statue, and Rayquaza cutscene actor are excluded. Sprite sets for later species
or unsupported forms continue to use WildFollowers' existing artwork fallback.

Only the four cardinal walking sequences from animation group 0 are imported.
Original visible pixels, normal palettes, frame durations at 60 Hz, walking
offsets, and ground pivots are retained. The conversion rearranges poses into
directional rows and changes transparent padding without scaling or recoloring.
It preserves each complete 2–16-frame sequence. The source has no separate
shiny or female palette set, so this style displays original PMD colors for
those Pokemon rather than generating replacement colors.

`COMPANION-OVERWORLD-AUDIT.json` records the supplied archive hash, input and
output PNG hashes, source metadata hashes, per-pose offsets and timings, frame
dimensions, and anchors. Rebuild using `tools/import_companion_sprites.py`
with the original ZIP, Python, Pillow, and Lupa's LuaJIT 2.1 runtime.

The supplied archive contains no explicit LICENSE file or redistribution grant.
This credit documents provenance; it does not assert a new license or ownership
of Pokemon artwork. Existing artwork rights remain with their respective owners.
