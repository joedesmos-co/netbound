# Netbound Player-Feel Audit

Audit date: 2026-07-15

## Scope And Baseline

This phase addressed only shot/retry clarity, success audio and color, curve-intent
classification, and production obstacle art. It did not add levels, currency,
cosmetics, online systems, real advertising/billing, analytics, or release-store
work. The existing unstaged `game/project.godot` edit was preserved and excluded
from every phase commit.

Stable contracts retained:

- 20 production levels and their verified swipe solutions
- canonical launch speed/elevation mapping and four shot-height categories
- 1.35-second bounded curve application with a 78-degree maximum heading change
- front, left-side, and right-side arcade goal scoring
- white goal frames and final-shot goal priority
- version-2 save compatibility, stars, progression, wallet, pricing, cosmetics,
  purchase entitlements, and development-only simulated providers

## Shot And Retry Clarity

The rewarded extra-shot continue duplicated the value of the existing free restart
and made failure language less trustworthy. Its player-facing button and gameplay
grant path were removed. Rewarded Token ads remain available in Store, and the old
save/result field is retained only for normalization compatibility.

Current language and behavior:

- `Reset Ball`: returns the ball during the current run; consumed shots stay used.
- `Restart Level`: abandons the run and resets shots used to zero.
- `Try Again`: free failure restart with no ad or currency requirement.
- `Play Again`: completed-level restart.
- HUD: `SHOTS  02 / PAR  03` emphasizes performance instead of scarcity.
- Results: shots used, par, stars, and saved best are separate hierarchy levels.

Regression coverage proves that Reset does not refund a shot, Restart clears the
run, result reopening cannot duplicate rewards, rewarded Tokens still work, and
old version-2 data loads without errors.

## Success Audio And Color

The old goal/result chain had two long, similarly assertive sounds and allowed the
result cue to overlap the immediate goal response. Both generated assets were
re-synthesized with softer attacks, shorter tails, and lower peaks. Result reveal
now follows the goal moment rather than stacking on it.

| Event | Duration | Peak | RMS | Timing |
|---|---:|---:|---:|---|
| Goal confirmation | 0.340 s | -7.13 dBFS | -16.91 dBFS | immediate after authoritative score |
| Result success | 0.580 s | -8.87 dBFS | -18.13 dBFS | 0.350 s after goal presentation |
| Cosmetic unlock | existing bounded cue | existing bounded gain | existing bounded gain | 0.660 s after result start |

The base goal pulse is now low-opacity success green. Physical goal geometry stays
white, stars retain warm yellow, cosmetics keep their own colors, and failure keeps
coral/red. Reduced Motion suppresses the full-screen pulse and uses a concise held
goal-frame response. Audio measurements are in
`artifacts/player-feel/pass2/audio_metrics.txt`.

## Curve Intent

### Root cause

The previous classifier weighted signed turn accumulation and end-shape behavior.
Sparse samples, early hooks, and paths that visibly stayed on one side of the chord
could accumulate opposing segment turns and collapse toward straight. The visible
gesture and launch intent therefore disagreed for deliberate curves.

### Current calculation

One canonical analyzer now:

1. measures every segment against the start-to-end chord
2. integrates positive and negative lateral area with a peak contribution
3. chooses the dominant path side from area plus peak rather than net turn
4. normalizes dominant peak deviation by chord length
5. applies a `max(0.012, 2 px / chord length)` intentional deadzone
6. scales strength by path-side coherence and the existing response exponent
7. sends the same signed curve amount to the single aim line and launch path

Cumulative and signed turn remain diagnostics, not competing launch authority.
Curve runtime, vertical velocity, horizontal speed preservation, and the 78-degree
heading cap are unchanged.

Measured canonical values:

- straight and slight wobble: `0.000000`
- mild left/right: `-0.278656 / +0.278656`
- strong left/right: `-0.709443 / +0.709443`
- start/end hooks: `+0.504192 / +0.504192`
- sparse three-sample curve: `+0.354473`
- proportional short/long curves: `+0.481210 / +0.485443`
- mouse/simulated touch: `+0.334910 / +0.334910`

Full measurements are in `artifacts/player-feel/pass3/curve_metrics.txt`.

## Environment Art

Raw obstacle boxes were replaced by six reusable training-course archetypes:

- padded target blocker
- moving scoreboard panel
- rotating training barrier
- rebound board
- crash-pad stack
- training barricade

The final revision deliberately removed the first draft's mixed-color micro-detail.
All objects now share navy protective frames, off-white canvas, coral safety pads,
teal moving/rebound faces, and yellow motion markings. The inherited off-course red
prototype marker is hidden while its compatibility collider remains intact.

`NetboundArcadeCourseArt` observes existing collision bodies. It hides only their
raw direct box mesh, adds an exact-size visual base and inset details below the same
body, and owns no collider, movement script, tween, physics material, or reset
phase. Full level-by-level replacements are in `docs/ENVIRONMENT_ART.md`.

Measured art budget:

- 35 wrapped production obstacles
- all 6 archetypes represented
- maximum 24 course-art visual nodes in one level
- 7 shared material resources per level
- 0 added collision nodes
- exact `BoxShape3D.size` match for every visual base
- Low quality retains essential object identity and hides secondary details

## Visible Evidence

- Baseline: `artifacts/player-feel/before/`
- HUD, Pause, failure, Store: `artifacts/player-feel/pass1/`
- Goal/result success: `artifacts/player-feel/pass2/final/`
- Straight/mild/strong aim: `artifacts/player-feel/pass3/`
- Environment before/final: `artifacts/player-feel/pass4/`

The final set includes front, left-side, right-side, and Reduced Motion goal states;
Levels 01, 02, 05, 07, 10, 11, 12, 17, 18, and 20; every obstacle archetype; Low
quality; native 1024x768; and native 1600x720.

## Verification Outcome

Godot executable:
`/Users/ryland/Documents/Godot.app/Contents/MacOS/Godot`

Passed locally:

- headless editor import
- configured app startup
- strict parser sweep: `71/71`
- retained external regression scripts: `29/29`
- all 20 production swipe-completion routes
- course-art collision signature and cleanup verification
- Android debug APK export and archive/signature inspection
- Android debug AAB clean export from an isolated template project and archive check

Android artifacts:

| Artifact | Size | SHA-256 |
|---|---:|---|
| `/tmp/netbound-player-feel/netbound-debug.apk` | 28 MB | `81e852b68eaa013f9797053e79a4466cd6c63524eb31212630793bd34ce73a44` |
| `/tmp/netbound-player-feel/netbound-debug.aab` | 28 MB | `f0fadfbbca9f5f36bc3937408feb035e5880e2aed97f82b2c5061ba821d75bd2` |

APK metadata: `com.netbound.game`, version `0.9.0` (`9`), target SDK 36,
ARM64, `VIBRATE` only, debug signed with APK v2/v3. Both ZIP integrity checks pass.
`aapt2` still reports the Android template's optional missing themed-icon reference;
this existing packaging diagnostic did not block export. The AAB template install
run's known editor-shutdown warning was excluded from final evidence by repeating a
clean export after template installation; the clean run exited without warnings.

Representative commands:

```sh
/Users/ryland/Documents/Godot.app/Contents/MacOS/Godot --headless --path game --editor --quit
/Users/ryland/Documents/Godot.app/Contents/MacOS/Godot --headless --path game --quit-after 8
/Users/ryland/Documents/Godot.app/Contents/MacOS/Godot --headless --path game --script res://scripts/debug/verify_player_feel_external.gd
/Users/ryland/Documents/Godot.app/Contents/MacOS/Godot --headless --path game --script res://scripts/debug/verify_environment_art_external.gd
/Users/ryland/Documents/Godot.app/Contents/MacOS/Godot --headless --path game --script res://scripts/debug/verify_phase3_levels_external.gd
/Users/ryland/Documents/Godot.app/Contents/MacOS/Godot --headless --path game --export-debug "Android Debug" /tmp/netbound-player-feel/netbound-debug.apk
```

## Remaining Physical-Device Checks

- listen to goal/result cues repeatedly on phone speakers, wired/Bluetooth
  headphones, and at minimum/maximum practical device volume
- compare slow, fast, short, and long deliberate curves under real finger
  occlusion at 30/60 FPS
- inspect training-equipment silhouettes and white goals at arm's length on narrow
  phones, tablets, OLED, and LCD panels
- confirm Low-quality frame pacing and moving-visual synchronization on low/mid
  Android hardware
- verify safe areas, touch comfort, haptics, audio focus, interruption behavior,
  background/resume, thermal behavior, and battery use

These are not claimed by the local automated or screenshot evidence.
