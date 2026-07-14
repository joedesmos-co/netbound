# Netbound UI Art Direction

Audit date: 2026-07-14  
Production viewport baseline: `1280x720`  
Direction: **Trajectory Editorial**

## Current UI Audit

The Phase 5-9 interface is functionally complete, but its visual language is not connected strongly enough to Netbound's play. The production shell builds most controls directly in `netbound_app.gd` and relies on default Godot control styling.

Primary weaknesses:

- Main Menu is a centered stack of equal rectangular buttons. The goal and ball backdrop says soccer, but the interface composition does not inherit the route, target, or movement language.
- Level Select presents progression as a store-like card grid. Number, name, mechanic, state, stars, par, best, and unlock copy compete inside every card.
- Gameplay HUD uses a wide Reset button, centered shots text, full-width power bar, and outlined tutorial copy. The controls look independent from the world and consume too much upper-left space.
- Pause, success, and failure are centered generic modals with several visually equal actions. Gameplay context remains visible but is not used compositionally.
- Cosmetics has a useful live 3D preview, but the preview is framed like a dashboard panel and the catalog is a dense list of multiline buttons.
- Store products read like multiline database rows. Settings stretches controls across the viewport and has no meaningful grouping.
- Default control chrome makes primary, secondary, locked, selected, owned, and unavailable states too similar.
- Typography relies mainly on size. There is no display face, numerical style, consistent metadata treatment, or controlled use of case.
- Motion is a general fade plus per-button fade. It does not communicate route direction, physical impact, or state change.
- The palette has several unrelated bright colors inherited from gameplay and cosmetics, without a disciplined shell accent.

Baseline captures:

- `docs/ui_art_direction/before/main_menu_1280x720.png`
- `docs/ui_art_direction/before/level_select_fresh_1280x720.png`
- `docs/ui_art_direction/before/level_select_partial_1280x720.png`
- `docs/ui_art_direction/before/gameplay_hud_1280x720.png`
- `docs/ui_art_direction/before/pause_1280x720.png`
- `docs/ui_art_direction/before/success_1280x720.png`
- `docs/ui_art_direction/before/failure_1280x720.png`
- `docs/ui_art_direction/before/cosmetics_fresh_1280x720.png`
- `docs/ui_art_direction/before/cosmetics_unlocked_1280x720.png`
- `docs/ui_art_direction/before/store_1280x720.png`
- `docs/ui_art_direction/before/settings_1280x720.png`
- `docs/ui_art_direction/before/level_10_result_1280x720.png`

## Explored Directions

### 1. Matchday Editorial

Modern sports graphics: oversized condensed type, cropped numerals, asymmetric composition, hard color fields, field notation, and poster-like negative space.

Strengths:

- Strong first impression and excellent screenshot legibility.
- Typography can create identity without heavy image assets.
- Naturally supports level numbers, par, stars, and results.

Risks:

- A pure poster treatment can overpower the 3D playfield.
- Repeated oversized type can make secondary screens noisy.
- Static composition alone does not express curve and trajectory.

### 2. Training Rig

Arcade equipment and sports hardware: painted markings, rubber surfaces, scoreboard digits, mesh, labels, strong borders, and tactile slab controls.

Strengths:

- Controls feel physical and trustworthy.
- Mechanic labels and compact numerical displays fit naturally.
- Works well for Pause, Settings, and Store states.

Risks:

- Too much texture becomes skeuomorphic and busy on phones.
- Hardware motifs can make the product feel heavy rather than playful.
- Literal equipment styling can age quickly.

### 3. Trajectory Atlas

Netbound's shot language becomes the interface: arcs, target rings, impact points, path nodes, curve traces, and spatial progression.

Strengths:

- Recognizable as Netbound even without the title.
- Route lines can communicate progression and selection rather than decorate.
- Procedural vector-like drawing stays sharp and inexpensive on mobile.
- Extends naturally into aiming, HUD notation, screen transitions, and result reveals.

Risks:

- A pure technical diagram can feel clinical or futuristic.
- Too many thin lines would hurt small-screen contrast.
- Curves must represent real navigation or gameplay meaning.

## Chosen Direction

**Trajectory Editorial** uses Trajectory Atlas as the structural system, Matchday Editorial for hierarchy, and a restrained amount of Training Rig tactility for buttons and score notation.

The mixture is intentionally unequal:

- 70% trajectory and target geometry
- 20% editorial sports typography and composition
- 10% tactile equipment treatment

Rationale:

- The route, arc, and target are specific to Netbound's core interaction.
- Condensed display typography gives the shell confidence without requiring decorative art.
- Hard-edged, shallow controls feel physical while avoiding dashboard cards, glass, and casino styling.
- The system can be produced with fonts, flat colors, line drawing, and small reusable controls that fit the mobile renderer budget.

### Playful Calibration

Netbound is a fun arcade game, not a solemn sports utility. The system should therefore feel lively and slightly cartoony while keeping its hierarchy precise.

- Target nodes are chunky and graphic rather than thin technical diagram points.
- Trajectory arcs can overshoot, rebound, and snap into place with controlled exaggeration.
- The wordmark may use the ball, goal opening, or a curved strike as part of its silhouette.
- Primary controls compress and recover like physical arcade buttons.
- Result stars land with a short punch rather than a formal broadcast dissolve.
- Empty space and alignment remain intentional so the playfulness never turns into clutter.
- The tone is bold and mischievous, not childish, toy-like, or mascot-driven.

## Visual System

### Color

Core shell palette:

| Token | Hex | Purpose |
| --- | --- | --- |
| `ink` | `#081218` | Primary background and modal shade |
| `field_ink` | `#102A27` | Secondary field-derived surface |
| `surface` | `#162329` | Interactive surface and panel structure |
| `surface_high` | `#22343A` | Hover, focus, and selected surface |
| `chalk` | `#F4F2E8` | Primary text and goal-line marks |
| `muted` | `#9AA9A7` | Secondary text and inactive route lines |
| `signal` | `#F2D22E` | Signature accent, primary action, active trajectory |
| `success` | `#69DB7C` | Completion, earned stars, unlocked route |
| `failure` | `#FF665E` | Failure, unavailable action, warning |
| `locked` | `#526166` | Locked/disabled state |
| `curve` | `#4BC7D8` | Gameplay curve notation only |

Rules:

- `signal` is the only general shell accent.
- `success`, `failure`, and `curve` communicate specific state; they are not general decoration.
- Gameplay cosmetics may retain their authored colors inside previews and play, but shell chrome stays neutral.
- Panels use flat colors. Gradients are not part of the shell system.

### Typography

Bundled type family:

- Liberation Sans Narrow Bold: wordmark, display titles, level numbers, star totals, result callouts.
- Liberation Sans Bold: buttons, section labels, selected states.
- Liberation Sans Regular: body, metadata, requirements, settings labels.

Roles:

| Role | Treatment |
| --- | --- |
| Wordmark | Condensed bold, uppercase, 88-112 px, compact two-line composition when useful |
| Screen title | Condensed bold, uppercase, 42-52 px |
| Result display | Condensed bold, uppercase, 64-84 px |
| Section heading | Bold, uppercase, 14-16 px, signal color |
| Body | Regular, 17-20 px, chalk |
| Metadata | Regular, 14-17 px, muted |
| Numerical/stat | Condensed bold, 22-34 px, tabular visual rhythm |
| Button | Bold, 17-24 px, short labels |

Typography rules:

- Display type carries identity; decoration stays restrained.
- Metadata is never allowed to compete with the action label.
- Uppercase is reserved for display, section labels, and short state words.
- Copy remains factual and brief.

### Spacing

Base unit: `4 px`.

Scale: `4, 8, 12, 16, 24, 32, 48, 64`.

- Touch controls: minimum `52 px`, primary actions `64-88 px`.
- Standard safe content inset starts at the existing runtime safe margin and adds `16-24 px` only when composition needs it.
- Dense metadata uses `8-12 px` separation.
- Major composition groups use `24-48 px` separation.

### Shape Language

- Default corner radius: `2 px`.
- Large panel radius: `0-4 px`; panels are structural bands or rails, not floating cards.
- Primary action: solid signal slab with one clipped/angled visual edge where practical.
- Secondary action: ink/surface fill, 2 px chalk or muted border, strong pressed state.
- Quiet action: no panel until hover/focus; underline or leading rule communicates interactivity.
- Selection: signal leading bar plus target-ring marker.
- Locked: reduced contrast plus geometric lock mark; do not rely on opacity alone.
- Progress: connected target nodes, not generic progress bars.
- Large target rings and route markers may use mildly exaggerated proportions for a friendly arcade silhouette.

### Iconography

- One geometric line language based on arcs, posts, target rings, and simple equipment marks.
- Stroke weight is visually consistent at `2-3 px`.
- Icons communicate familiar commands; decorative symbols are not added to labels.
- No emoji, arbitrary Unicode symbols, mixed icon packs, or novelty badges.
- Stars are drawn as geometry rather than text glyphs.

### Motion

- Screen entrance: `140-180 ms`, short directional translation plus opacity.
- Navigation transition: trajectory sweep or fast flat fade, `120-180 ms`.
- Button press: immediate `2-4%` compression and recovery, `80-110 ms`.
- Route selection: target ring locks onto the selected marker, `120-160 ms`.
- Result reveal: heading, stat line, stars, then primary action; total under `650 ms`.
- Unlock: one route segment and marker change state; no generic sparkle burst.
- Reduced Motion: remove translation, scale, stagger, and sweeps; state changes remain immediate and readable.

Motion must never own navigation state, alter gameplay timing, or leave controls disabled.

## Screen Composition Rules

### Main Menu

- Asymmetric split: wordmark/trajectory composition on the left, actions on the right.
- Play/Continue is the only dominant action.
- Level Select and Cosmetics are strong secondary actions.
- Store and Settings are quiet utility actions.
- The trajectory background aims toward the action rail, giving composition a gameplay purpose.

### Level Select

- Levels form one connected route that snakes through the viewport.
- Each marker prioritizes level number, name, state, stars, par, and best in that order.
- Locked markers remain legible but visually recede.
- Completed route segments use success color; the current playable segment uses signal.

### Gameplay HUD

- Shots remain at the upper edge in compact scoreboard notation.
- Reset and Pause become small edge actions.
- Tutorial copy sits on a short field-marking rail and disappears when not needed.
- Power uses a bounded trajectory meter near the bottom edge, not a full-width dark bar.
- No panel covers the ball, target, or intended route.

### Results And Pause

- Use an edge rail rather than an unrelated centered app modal.
- Preserve gameplay context on the opposite side.
- One action is dominant; alternatives are grouped as quiet secondary actions.
- Stars and shots are graphic stats, not prose paragraphs.

### Cosmetics, Store, Settings

- Cosmetics gives the live preview at least half of the visual emphasis.
- Store uses two honest product blocks with restrained action hierarchy.
- Settings is grouped into Audio and Play Feel, using compact rows and no promotional decoration.

## Responsive Behavior

- The system is container-driven and uses the existing safe-area service.
- Wide phones use asymmetric two-column compositions.
- Tablet and 4:3 layouts preserve hierarchy by narrowing action rails and allowing route/settings content to use additional rows.
- Level routes change column count while retaining sequential connections.
- Secondary screens scroll only when their content cannot maintain 52 px touch targets.
- No per-resolution absolute coordinate tables are permitted.

Target visual checks:

- `1280x720`
- `1600x720`
- `1920x864`
- `2340x1080`
- `1024x768`
- `1366x1024`

## Rejected Ideas

- Glass panels: unrelated to the physical, direct shooting interaction and weak against varied level backgrounds.
- Neon-everywhere cyber arcade: competes with cosmetic colors and later-level lighting.
- Full industrial texture pass: adds asset cost and visual noise without improving state communication.
- Poster-only editorial screens: strong individually but too static and disconnected across navigation.
- Generic card grids: make levels and cosmetics feel like inventory/store data.
- Gradient surfaces, bloom halos, floating particles, and abstract diagonal stripes: decoration without useful state or gameplay meaning.
- Excessive pills and large rounded rectangles: conflict with the precise target/field geometry.

## Anti-AI-Slop Review

Every retained visual must answer at least one question:

- What is the primary action?
- Where am I in the route?
- What is selected, locked, complete, owned, or unavailable?
- How does this relate to a shot, arc, target, field, or result?
- Does it improve mobile readability or touch confidence?

Elements that cannot answer one of those questions are removed.
