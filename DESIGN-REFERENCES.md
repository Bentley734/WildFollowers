# Behavior review for 3.0.0

Reviewed the local Untamed Advanced feature declarations and old WildFollowers documentation. These references informed product behavior; no reference Lua was copied, translated, or imported into the rewrite.

| Reference idea | Independent implementation | Reason |
| --- | --- | --- |
| Untamed Advanced configurable ball effects | A saved toggle bypasses recall visuals and release drawing while preserving settled-arrival placement | Let players choose transition pacing without sacrificing safe tiles |
| Old WildFollowers group Random / Random Wave | One group choice per stationary trail epoch; late participants share it | Keep choices predictable and waves coordinated |
| Old WildFollowers Copycat and dance/pulse poses | Stationary facing mirroring, timed anchored sprite transforms and existing native jump arcs | Add personality without moving through teammates |
| Old WildFollowers restricted Mixed pool | Mixed chooses stationary poses; explicit Wander retains legal reservations | Avoid unsolicited roaming when idle defaults are enabled |
| Old WildFollowers longer idle delay | An additional 60-second choice | Allow quieter exploration |

Implementation stays in the rewrite's own idle, ball, option and native movement architecture. Existing artwork remains the previously supplied, attributed 1,025 PNGs. No new reference artwork was copied.

Deferred: social chase/pair activities, extra artwork styles, shiny previews, custom species forms and ambient cry audio. They need additional assets or movement/integration testing. 3.0.0 is the supported rewrite scope, not a claim of full legacy parity.
