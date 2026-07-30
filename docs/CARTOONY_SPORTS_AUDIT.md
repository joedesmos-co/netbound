# Netbound Cartoony Sports Quality Audit

Date: 2026-07-29  
Scope: ball overhaul, tubular goal + woven net reaction, sports materials, secondary motion  
Constraint: presentation-only. Collision radius, shot physics, scoring geometry, and routes unchanged.

## Quality Bar

Netbound should read as a playful animated soccer obstacle course: bright, chunky,
tactile, and readable. This pass raises that bar after declutter without restoring
visual noise.

## Soccer Ball

`CosmeticVisuals` classic / soccer-derived skins now use:

- warmer canvas-white shell with leather-like roughness
- charcoal (not pure black) pentagon panels on icosahedron verts
- slightly raised panel depth for spin readability
- one subtle seam ring on Classic
- unchanged `0.49` collision radius, `0.43` mass, and base `SphereMesh` identity

Menu backdrop Classic ball drawing uses charcoal panels instead of pure black ink fills.

## Goal Frame And Net

Approach chosen for net reaction: **bounded spring-grid on a MultiMesh rope lattice**
(not SoftBody3D). Reasons: localized impact, mobile-safe instance transforms, deterministic
reset, quality-tier density, Reduced Motion short push.

`GoalTarget` now:

- converts the crossbar visual to a tubular `CylinderMesh` (collision box unchanged)
- thickens post/crossbar **visual** radius to `post_radius * 1.18`
- hides flat net boxes and builds woven rear/left/right/top rope panels via `GoalNetArt`
- triggers impact from the ball’s pre-freeze position and velocity after authoritative scoring
- resets net reaction on Retry / Restart / element reset

Quality tiers:

| Tier | Grid density | Behavior |
| --- | --- | --- |
| High | 9×6 | full localized wave |
| Medium | 7×5 | reduced points |
| Low | 5×4 | still reacts, fewer ropes |
| Reduced Motion | short push (~0.45s) | rapid spring return |

## Materials And Secondary Motion

- Course-art materials gain fabric/metal roughness splits (foam soft, navy slightly metallic).
- Goal frame material: painted white metal with stronger fill emission for sky contrast.
- Obstacle wrappers get a short squash tween on impact (visual only, Reduced Motion skipped).

## Collision / Scoring Safety

Verified:

- ball radius/mass unchanged under every ball cosmetic
- goal mouth/interior detector sizes unchanged
- crossbar collision box size unchanged
- net art reports `collision_nodes = 0`
- Phase 3: all 30 routes PASS
- Goal detection / Phase 2 architecture PASS

## Evidence

`artifacts/cartoony-sports/`

- levels: `level_01`, `05`, `11`, `20`, `30`
- ball: locker Classic, aim gameplay
- quality: Low Level 01 / 30
- ui: main menu

## Tests

- `verify_cartoony_sports_external.gd`
- cosmetic quality, goal detection, Phase 2/3/7, env art, world expansion, economy, skip, feel, final RC
- parser sweep 77/77

## Exports

`/tmp/netbound-cartoony-sports-exports-20260729/`

- APK SHA-256 `0ae9a1abfef186d8c9240d00920d3fc6dd0ce11a8a8b331883945f23daa8b759`
- AAB SHA-256 `f408de96e3acce404fc6d13e119f293eb688e6d9de3cd50914f235137aaa8723`

## Remaining Limitations

- Rope lattice is chunky MultiMesh cylinders, not cloth simulation.
- True bevelled obstacle edges would need authored meshes beyond box wrappers.
- Physical-device timing of net reaction and ball spin under real glare still required.
- Net impact capture harness for side-entry still manual / future tooling.
