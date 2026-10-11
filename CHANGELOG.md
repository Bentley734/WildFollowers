## 3.4.5

- Automatically use the game music when the PC audio helper is missing, stopped, stale or unavailable.
- Analyze the game BGM buffers at playback position; all music effects and sensitivity settings remain available.
- Return to PC audio when the helper recovers. Pausing the helper explicitly still pauses the visualizer.
- Ignore sound effects and muted or paused game music; release audio hooks when the mod is disposed.
