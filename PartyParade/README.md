# Party Parade 3.0.0

A follower add-on for [Untamed Advanced](https://github.com/goldenroddeptstore/Untamed-Advanced). This is the successor to WildFollowers: Untamed owns the wild encounters, and Party Parade extends its party followers.

## Install

1. Use Gen1Recomp 0.3.54 or later in the 0.3 series.
2. Install and enable Untamed Advanced 1.0.0-beta.7 or later compatible 1.x version.
3. Install **PartyParade-v3.0.0.zip** through the mod manager, replacing WildFollowers, then restart.
4. In FireRed, LeafGreen or Emerald, open OPTION → PARTY PARADE. Enable followers in Untamed as well. Open IDLE BEHAVIORS for the idle modes.

The internal mod ID remains `wildfollowers`, and updates remain on the existing GitHub repository, so installed WildFollowers preferences can migrate. Keep only one copy installed. Untamed must be enabled; this add-on cannot run by itself. Hoennto and 1025Dex are optional.

## Features

- Choose zero to six healthy party followers.
- Separate trainer and follower spacing, native catch-up movement, dialogue and cries.
- Native Untamed art or G9RP follower sprites, with native fallback for unsupported forms, gender differences and shiny art.
- Idle walking, wandering with speed/range, looking around, jumps and waves, mixed/random behaviors, coordinated dances, zoomies, copycat, sleepy buddy, play tag, cheer, stretch and Doze.
- Safe arrival placement: followers wait for the player, avoid the player's occupied/moving tiles, doorway warp tiles, NPCs and each other, and remain hidden when no legal spot exists.
- Arrival balls and door recalls, flower feet cover, grass animation and recorded follower frames.
- Follower updates behind menus without duplicate normal field ticks.
- Shared follower settings across FireRed, LeafGreen and Emerald, including fresh game option blocks. Settings are saved with the engine options through the normal OPTION/save flow; Hoennto's linked settings sync remains supported.

Party Parade has no wild actor pool, encounter engine, spawn controls or wild option page. Configure wild encounters in Untamed Advanced. Old WildFollowers wild-specific preferences are not copied into Untamed.

## Validation

The Lua 5.3 headless suites load the supplied Untamed Advanced beta.7 and this add-on through Gen1Recomp 0.3.54's real mod sandbox. They check dependency failure, unchanged wild services, all follower counts, rendering injection, menu scheduling, both option surfaces, game/new-option migration, safe arrivals, spacing, idle collisions, return routing and idle controllers. A rendering adapter check verifies native paged atlas selection and vertical pulse scaling. Flower clipping tests cover FireRed/LeafGreen and Emerald.

Headless checks pass. Live visual gameplay verification is pending; the test environment mocks engine services and does not run LOVE's actual GPU renderer.

Source is in `PartyParade/` on the repository. Install the attached release ZIP; its G9RP image assets are distributed with the ZIP rather than the GitHub-generated source archives.
