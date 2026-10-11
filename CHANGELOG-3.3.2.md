# WildFollowers 3.3.2

Adds three persisted WildFollowers menu toggles, all OFF by default:

- SMART SPACING: derives each trainer/follower and follower/follower gap from visible alpha bounds across every animation frame and direction, using the selected G9/EE/form artwork. Manual trainer/follower spacing remains a minimum. Larger artwork receives larger individual gaps. Movement pauses before increasing visual overlap with the trainer or another follower; pre-existing overlaps may unwind. Smart gaps are applied through the existing legal trail and catch-up movement, so the line settles into its new spacing as it follows the trainer. Native ledge hops and NPC yielding retain their existing movement behavior.
- WILDS MARCH: loops wild walking frames in place while stationary.
- FOLLOWERS MARCH: loops follower walking frames in place while stationary or paused. Both march toggles retain position, encounters, movement, and field-lock pauses, and work in the 2D and native/3D sprite paths.

Validation: 168 targeted production-code checks for mixed G9/EE bounds, individual gaps, manual minima, trainer/follower overlap guards, overlap escape, independent march toggles, and matching 2D/native pose frames across Gen 1/2/3. Full runtime/settings/persistence and native movement fixtures pass across all eleven games. Visible alpha bounds were generated for all 4,157 supplied sprite sheets. Existing artwork is unchanged. No live gameplay capture.
