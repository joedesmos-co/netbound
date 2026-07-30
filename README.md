# Netbound

Netbound is an offline arcade trick-shot soccer game built with Godot 4.7. The current production slice contains thirty authored levels across three worlds, arcade front/side-net scoring, swipe-driven shot height and curve, local progression, a 38-item cosmetic economy, settings, simulated development-only monetization flows, an optional five-miss assisted level clear, and mobile export presets.

## Run locally

Open `game/project.godot` in Godot 4.7 stable, or run the configured production scene from the command line:

```sh
/Users/ryland/Documents/Godot.app/Contents/MacOS/Godot --path game
```

The production entry point is `res://app/netbound_app.tscn`.

## Focused release-candidate check

```sh
/Users/ryland/Documents/Godot.app/Contents/MacOS/Godot \
  --headless --path game \
  --script res://scripts/debug/verify_final_rc_flow_external.gd
```

## Documentation

- World art direction: `docs/WORLD_ART_DIRECTION.md`
- Levels 21-30: `docs/LEVELS_21_30.md`
- Graphics upgrade: `docs/GRAPHICS_UPGRADE.md`
- Final audit: `docs/FINAL_RC_AUDIT.md`
- Environment art: `docs/ENVIRONMENT_ART.md`
- Test matrix: `docs/TEST_PLAN.md`
- Physical-device checklist: `docs/MOBILE_RELEASE_CHECKLIST.md`

Local automated and export validation is complete for the thirty-level world expansion. Physical iOS and Android device testing is still required before public distribution.
