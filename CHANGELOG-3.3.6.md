# WildFollowers 3.3.6

Keeps the six-follower procession closer together while walking and turning. Smart followers catch up as soon as they lag, with interpolation capped to the trainer's actual movement. Leaders update before followers behind them, and leftover frame time carries into the next trail step at integer as well as fractional spacing. At sprite boundaries, followers use the safe portion of a frame instead of discarding all movement.

Returning followers keep their own position while the trainer is moving rather than repeatedly trading vacancies. The shared detour search now resumes across frames with a bounded 256-cell total search, retaining the existing per-frame budget. This lets the last companions finish searches that previously restarted with only ten nodes per attempt in a full party. Cached steps still check current terrain and occupancy before moving.

Smart spacing dimensions, manual spacing minima, sprite sizes and march settings are retained.

Validation: native movement and runtime fixtures across all eleven games; G9 and EE smart formation fixtures; two large mixed-party nine-segment walking/turning regressions at 60 and 30 updates per second; 192 sprite-boundary, spacing and march checks; obstacle return and six-follower search-budget regressions. The moving-party tests assert every follower remains within 2.25 trail cells of its smart target, a bound exceeded by 3.3.5. The update was tested on the user's Windows PC through engine fixtures. Live window automation was denied by Computer Use, so there was no live gameplay test.

Restart the game to load the update.
