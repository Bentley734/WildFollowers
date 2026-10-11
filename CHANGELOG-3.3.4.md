# WildFollowers 3.3.4

Fixes smart-spacing followers stopping at turns. The overlap guard previously made a leading follower wait for a trailing follower, while the trailing follower already depended on the leader advancing. It now checks only the trainer and followers earlier in the actual line order, removing that circular wait. Compact directional spacing from 3.3.3 and both march toggles are retained.

Validation: the production-code regression reproduces the leader/tail stall in 3.3.3 and passes in 3.3.4. 189 targeted spacing/overlap/march checks pass across Gen 1/2/3, alongside full runtime and native movement fixtures across all eleven games. Twenty-two dedicated smart-spacing fixtures drive six followers with both G9 and EE artwork through five multi-tile turns using all eleven cartridges' actual native player movement. No live gameplay capture.

Restart the game to reload the updated movement code.
