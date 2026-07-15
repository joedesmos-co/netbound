# Netbound Cosmetic Visual Audit

## Problem Reproduced

Before this pass, every non-Classic ball inherited the same band and two rectangular patches. Material color and emission changed, but silhouette, panel structure, and visual rhythm did not. At gameplay distance the catalog therefore read as recolors. The Locker camera also framed the whole dummy field, leaving the selected ball too small to inspect. Goal celebrations used small pieces near the center of the giant goal and did not feel collectible.

## Ball Classification

| Ball | Previous classification | Production concept |
| --- | --- | --- |
| Classic | Acceptable soccer variation | Eight dark pentagonal panels on a white match ball |
| Neon | Weak recolor | Cyan soccer panels plus a luminous lane ring |
| Fire | Weak recolor | Charcoal soccer panels with triangular ember marks |
| Ice | Weak recolor | Frosted shell with six crystal facets |
| Galaxy | Weak recolor | Star-map dots and crossing orbital rings |
| Champion | Weak recolor | Medal ring and visual-only trophy crown fins |
| Gold | Weak recolor | Metallic trophy ball with panel and latitude structure |
| Supporter | Weak recolor | Teal/gold medallion rings and badge fins |
| Candy Stripe | Weak recolor | Cherry spiral rings and candy dots |
| Mint Chip | Weak recolor | Uneven dark chips on a mint shell |
| Watermelon | Weak recolor | Raised green rind and dark seed pattern |
| Sunset Pop | Weak recolor | Warm orbit arcs and a sun disc |
| Checkerboard | Weak recolor | Raised high-contrast square tiles |
| Cloud Nine | Weak recolor | Cartoon cloud-puff clusters on a sky core |
| Comet | Weak recolor | Strike ring and three visual-only comet fins |
| Lava Core | Weak recolor | Irregular emissive molten seams |
| Prism | Weak recolor | Six pearl facets and a spectrum ring |
| The Void | Weak recolor | Twin orbital horizons and small satellites |

Classic, Neon, and Fire intentionally remain recognizable soccer-ball variations. All other Rare, Epic, and Legendary items use a named distinct concept. Attachments are presentation-only, live below `NetboundBallVisualAttachments`, use shared cached resources, and declare a maximum `0.66` visual radius. The authoritative sphere mesh, `0.49` collision radius, `0.43` mass, touch selection, scoring, and shot tuning are unchanged.

## Trails

The existing bounded 16-point trail architecture already provides shape as well as color variation: spheres, bubbles, paper strips, rectangular chalk, pixel blocks, prisms, and speed-tapered comet points. Low quality remains capped at eight points. No trail allocates an unbounded sample list.

## Goal Effects

Every effect now fills a meaningful portion of the giant white goal:

- Classic Flash: yellow/white radial bars plus one broad pulse.
- Confetti: a wide multi-color paper shower.
- Shockwave: two held cyan arena pulses.
- Supporter Burst: teal/gold radial pieces plus a pulse.
- Victory Ribbons: long coral/yellow/white strips.
- Color Splash: large flattened aqua/blue paint shapes.
- Pocket Fireworks: three clustered starburst origins plus a delayed ring.
- Goal Portal: three held violet/cyan/pink rings.

Effects are unshaded and depth-safe against the translucent net, last approximately `0.5-1.4` seconds depending on Reduced Motion, and clean up before result actions are obstructed. High quality uses at most 38 pieces; Low quality uses at most 20 descendants; Goal Portal is the only three-root effect.

## Visual Review

First review weaknesses:

1. The Locker ball occupied too little of the preview.
2. Small facets disappeared at phone distance.
3. Goal pieces read as distant specks and ring alpha faded too early.

Corrections:

1. Ball preview now uses a close inspection camera and hides the irrelevant dummy goal.
2. Facets/fins were enlarged within the same declared visual bound.
3. Goal pieces were scaled for the production camera, rings were thickened, and ring alpha is held until the final 35% of the tween.

Representative final captures are under `artifacts/content-expansion/cosmetics/`, including `cosmetics_ball_candy_final.png`, `cosmetics_ball_comet_final.png`, `cosmetics_ball_cloud_final.png`, `cosmetics_ball_prism_final.png`, `cosmetics_ball_void_final.png`, and `goal_*_final.png` for all eight goal effects. Occasional black rectangles in macOS Metal readback are capture artifacts; clean frames were used for visual decisions where available.
