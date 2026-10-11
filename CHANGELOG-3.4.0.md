# WildFollowers 3.4.0 — Music Visualizer

Adds MUSIC VISUALIZER to follower idle behavior and a MUSIC SENSITIVITY setting. Followers react to PC output audio: adaptive bass onsets produce staggered hops, while sound energy controls dance frames and gentle squash/stretch. Dance poses never change ground coordinates or the recorded trail. Walking and normal busy/recall states immediately interrupt the effect. Music poses take precedence over standing march frames.

Includes a self-contained Windows x64 audio helper in music/WildFollowersMusic.exe, with complete C# source, build project and dependency notices. It captures the default output through WASAPI loopback, analyzes samples only in memory, and writes a local scalar signal file inside the extracted mod directory. No microphone, audio recordings, network transfer, service or startup task is used. The notification-area menu supports pause/resume and exit. The helper detects output-device changes and retries unavailable devices. It must be launched once per PC session; see music/README.md.

The feature rests safely for missing, paused, silent, stale or malformed signals. Existing idle modes, spacing, following and march speed settings are retained. The Windows helper is optional on other platforms.

Validation: helper DSP self-test detects ten synthetic bass pulses and settles on silence; a real WASAPI loopback test on the user's Windows PC detects all ten low-volume beats played by a separate playback process. Lua tests cover head/tail wave timing, stationary coordinates, movement/busy interruption, helper restart, silence and invalid/stale/frozen input. Existing renderer, march and spacing tests plus full runtime/menu fixtures pass across all eleven games. No live game-window animation capture was performed.

Restart the game, run the helper, and select MUSIC VISUALIZER under IDLE BEHAVIOR.
