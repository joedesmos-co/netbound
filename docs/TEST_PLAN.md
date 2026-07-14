# Netbound Test Plan

Phase 0 documents the current baseline. Later phases should turn this into an automated regression suite that validates the real production scene and input path.

## Baseline Environment

- Godot: `/Users/ryland/Downloads/Godot.app/Contents/MacOS/Godot`
- Required version: `4.7.stable.official.5b4e0cb0f`
- Project path: `/Users/ryland/Documents/NetBound/game`
- Current main scene: `res://levels/level_01.tscn`

## Phase 0 Commands And Outcomes

Version:

```sh
/Users/ryland/Downloads/Godot.app/Contents/MacOS/Godot --version
```

Outcome: passed, `4.7.stable.official.5b4e0cb0f`.

Import:

```sh
/Users/ryland/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/ryland/Documents/NetBound/game --import
```

Outcome: passed.

Configured scene startup:

```sh
/Users/ryland/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/ryland/Documents/NetBound/game --quit-after 5
```

Outcome: passed. Startup emitted debug logs but no errors.

Parser check:

```sh
for f in $(find scripts -type f -name '*.gd' | sort); do
  /Users/ryland/Downloads/Godot.app/Contents/MacOS/Godot \
    --headless \
    --path /Users/ryland/Documents/NetBound/game \
    --check-only \
    --script "res://${f}"
done
```

Outcome: all `.gd` files passed.

External debug scripts:

```sh
for f in $(find scripts/debug -type f -name '*.gd' | sort); do
  /Users/ryland/Downloads/Godot.app/Contents/MacOS/Godot \
    --headless \
    --path /Users/ryland/Documents/NetBound/game \
    --script "res://${f}"
done
```

Outcome: all scripts exited with code `0`.

Important caveat: these scripts are not all production-path tests. Several call private methods, manually mutate physics state, or use older impulse assumptions. Their pass criteria currently allow unacceptable lob peaks around `47` to `51` world units.

## Existing Debug Scripts

- `verify_airborne_external.gd`
- `verify_arcade_redesign_external.gd`
- `verify_goal_detection_external.gd`
- `verify_goal_scale_external.gd`
- `verify_level01_external.gd`
- `verify_loft_external.gd`
- `verify_release_path_external.gd`
- `verify_release_shot_external.gd`
- `verify_reset_external.gd`
- `verify_shot_order_external.gd`
- `verify_trajectory_external.gd`

Keep these as historical probes until Phase 1 replaces or supplements them with production-path regression tests.

## Phase 1 Required Regression Coverage

Automated coverage should validate:

- Initial launch.
- Launch after manual Reset Ball.
- Launch after Retry Level.
- Launch after goal.
- Launch after auto-reset.
- Ground shot.
- Driven shot.
- Air shot.
- Full lob.
- Straight shot.
- Mild curve.
- Extreme curve.
- Final-shot goal.
- Final-shot miss.
- Stale timer after goal.
- Ball never remaining frozen in READY state.
- One valid shot consumes exactly one attempt.
- Invalid gestures consume no attempts.
- Manual Reset Ball does not refund a shot.
- Retry Level restores all attempts.

## Trajectory Acceptance Targets

Approximate peak height above field:

- Ground skim: `0.5` to `0.8`.
- Driven shot: `1.0` to `2.0`.
- Normal air shot: `3` to `7`.
- Full lob: `10` to `18`.

Current baseline failure evidence:

- Full lob peaks around `47` to `51`.
- Current debug tests still pass those values, so their expectations must be tightened.

## Curve Acceptance Targets

The suite should measure and categorize total heading change:

- Straight: negligible.
- Bend: `10` to `20` degrees.
- Wild: `25` to `45` degrees.
- Extreme: `50` to `75` degrees.

No shot should turn more than about `80` degrees from its original heading.

## Manual Gameplay Checklist

Until touch automation exists, manually verify:

- Swipe starts only on or near the ball.
- The ball broadly travels where the swipe points.
- Short and long swipes have readable power difference.
- Upward swipes produce distinct but controlled height.
- Downward/flat swipes stay low.
- Curve gestures bend clearly without reversing unpredictably.
- Manual Reset Ball works during and after a shot.
- Retry Level restores all attempts.
- Goal has priority over final-shot failure.
- Miss auto-reset is understandable.
- Camera keeps representative high and curved shots readable.
- Debug labels and logs are disabled in normal player mode after Phase 1 cleanup.

## Runtime Output Policy

Unexpected parser errors, runtime errors, warnings, or console spam should fail the phase being worked on. Expected gameplay conditions should not use `push_error()`.
