# WildFollowers 3.4.1 — Music Visualizer effects and speed

Adds MUSIC EFFECT with DANCE, WAVE JUMPS, BAR WALK / RUN, and BAR STRETCH. Wave Jumps sends staggered bass-triggered jumps along the procession. Bar Walk / Run makes each follower's rendered body travel up and down with delayed music energy, using walking/running frames and up/down facing. Bar Stretch changes height with music energy while keeping feet anchored. Dance retains the original hop, turn and gentle squash/stretch effect.

Adds VISUALIZER SPEED from 10% through 200%, defaulting to a calmer 50%. It adjusts wave timing, bar response and sprite animation together. Beat pulses are spaced appropriately at slower settings so followers can land between jumps. Every wave still reaches the tail at 10% speed. MUSIC SENSITIVITY remains independent.

Bar movement changes rendered offsets only; ground coordinates, trail history and collision reservations are retained. Walking, menus and normal idle interruptions remove all effects. Missing/stopped/silent audio rests safely. The existing local Windows audio helper and scalar protocol are unchanged.

Validation: 126,121 music bridge/effect checks exercise all four effects, all ten speeds, every follower rank, slow-wave propagation, bounded movement/stretch, safe interruption and malformed/stale input. 19,422 renderer/march/spacing checks include matching 2D/native bar offsets without logical movement. Full runtime and native menu persistence fixtures pass across all eleven supported games. No live game-window animation capture.

Restart the game. Choose MUSIC VISUALIZER under IDLE BEHAVIOR, then set MUSIC EFFECT and VISUALIZER SPEED. The installed Windows helper is restarted after updating.
