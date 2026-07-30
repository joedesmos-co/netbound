# Netbound Levels 21–30

Date: 2026-07-29
World: Stadium Showdown

## Route Table

| Level | Name | Mechanic | Shots | Par | Verified route |
| --- | --- | --- | ---: | ---: | --- |
| 21 | Opening Night | Timing gate + wide goal | 4 | 2 | Wait briefly, then shoot straight. |
| 22 | Floodlight | Elevation + curve | 5 | 3 | Lift wide left and bend around the tall pad. |
| 23 | Split Stands | Dual route | 4 | 2 | Safe high lob over the low barrier. |
| 24 | Moving Frame | Moving goal | 5 | 3 | Lead the translating goal through center. |
| 25 | Crossbar Club | Vertical window | 4 | 2 | Clear the pad with controlled air under a lower crossbar. |
| 26 | Stadium Swerve | Side-net curve | 5 | 3 | Bend around the divider into the right enclosure. |
| 27 | Scoreboard Shift | Dual movers | 5 | 3 | Release through the shared staggered opening. |
| 28 | Double Bank | Dual rebound | 5 | 3 | Bank from the bright right wall. |
| 29 | Final Whistle | Three-beat rhythm | 5 | 3 | Wait for the shared open beat, then shoot. |
| 30 | Grand Final | Timing + lift + side entry | 6 | 4 | Use the opening beat and bend into the right side. |

## Scripted Solution Parameters

| Level | Swipe offset | Curve px | Wait |
| --- | ---: | ---: | ---: |
| 21 | `(0, -230)` | `0` | `0.25` |
| 22 | `(-165, -260)` | `-16` | `0.0` |
| 23 | `(0, -245)` | `0` | `0.0` |
| 24 | `(0, -230)` | `0` | `0.4` |
| 25 | `(0, -225)` | `0` | `0.0` |
| 26 | `(30, -230)` | `14` | `0.0` |
| 27 | `(0, -225)` | `0` | `0.45` |
| 28 | `(230, -205)` | `0` | `0.0` |
| 29 | `(0, -225)` | `0` | `0.5` |
| 30 | `(75, -230)` | `20` | `0.0` |

## Progression Notes

- Completing Level 20 unlocks Level 21.
- Level 30 is the final production level (`next_level_id` empty).
- Maximum stars become `90`.
- Existing version-2 saves remain valid; wallet and cosmetics are unchanged.
- Early 6–30 star cosmetic milestones remain early/mid-route rewards and are never revoked.
