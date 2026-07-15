# Netbound

Netbound is an offline arcade trick-shot soccer game built with Godot 4.7. The current production slice contains twenty authored levels, arcade front/side-net scoring, swipe-driven shot height and curve, local progression, a 38-item cosmetic economy, settings, simulated development-only monetization flows, an optional five-miss assisted level clear, and mobile export presets.

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

The script uses isolated save paths and covers fresh launch, failure, free Try Again, scoring, progression, cosmetic selection, settings, pause/resume, and relaunch persistence.

## Documentation

- Final audit: `docs/FINAL_RC_AUDIT.md`
- Player-feel audit: `docs/PLAYER_FEEL_AUDIT.md`
- Environment art: `docs/ENVIRONMENT_ART.md`
- Rewarded level skip: `docs/REWARDED_LEVEL_SKIP.md`
- Level clarity audit: `docs/LEVEL_CLARITY_AUDIT.md`
- Content expansion: `docs/CONTENT_EXPANSION.md`
- Cosmetic visual audit: `docs/COSMETIC_VISUAL_AUDIT.md`
- Test matrix: `docs/TEST_PLAN.md`
- Local exports: `docs/LOCAL_BUILD_STATUS.md`
- Export setup: `docs/EXPORT_SETUP.md`
- Physical-device checklist: `docs/MOBILE_RELEASE_CHECKLIST.md`

Local automated and export validation is complete. Physical iOS and Android device testing is still required before public distribution.
