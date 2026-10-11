# Music Visualizer — Windows

1. Restart the game after installing WildFollowers 3.4.1.
2. Run `music/WildFollowersMusic.exe` from the extracted WildFollowers mod folder. The helper runs in the notification area; right-click its icon to pause/resume or exit. It is self-contained and requires no separate .NET installation.
3. In WILDFOLLOWERS, set IDLE BEHAVIOR to MUSIC VISUALIZER. IDLE TIME determines how long you must stand still first; MUSIC SENSITIVITY offers LOW, NORMAL, HIGH and VERY HIGH.
4. Choose MUSIC EFFECT: DANCE, WAVE JUMPS, BAR WALK / RUN, or BAR STRETCH. VISUALIZER SPEED offers 10%–200%, defaulting to 50%; try 10% or 25% for a slow response. Speed controls animation, wave timing and bar response; MUSIC SENSITIVITY controls strength. Bar movement changes only the rendered body position, preserving the follower's place in line.
5. Play music in your browser, player, or another app. Bass onsets send a hop down the line; volume controls the strength of the dance. Walking, menus, battles and ball animations cancel the idle dance normally.

Run the helper once per PC session, including after a PC restart. It never installs a service or startup task. Switching the default output device is detected automatically. It captures the default Windows multimedia output, which includes game audio, notifications and other apps as well as music. To react only to outside music, lower the game's music/sound volume. App-specific audio capture is not included in this version.

No microphone is used. Captured samples remain in memory and are discarded after analysis. Only current volume, bass energy, a beat counter and helper status are written locally to `music-signal.txt`; no sound recording or network connection is made. Stop or pause the helper at any time from its notification-area icon. If it is missing, stopped or silent, followers stand normally. The rest of WildFollowers continues to work on other platforms without this Windows helper.

The signal bridge requires an extracted mod directory. Do not run the helper while it is still inside a ZIP. Keep its executable in the `music` subfolder so the signal file is written beside `main.lua`.

## Building the helper

Source is in `helper/`. Install a Windows .NET SDK capable of targeting .NET 6, then run `dotnet publish music/helper/WildFollowersMusic.csproj -c Release -o <output-folder>` from the mod source root. Copy the resulting self-contained `WildFollowersMusic.exe` into `music/`. The release audit records the exact published executable hash and dependencies. NAudio is MIT-licensed; its license is included. The bundled .NET runtime notices are included as well.

## Signal format

`WFMusic1 sequence unix_seconds rms bass_rms beat_counter state`

The Lua bridge reads at most 20 times per second, treats input as data, rejects malformed/stale messages, caps animation strength, and detects a frozen helper within roughly half a second. It never loads or executes the signal file.
