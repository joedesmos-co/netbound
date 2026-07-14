# Netbound Audio

Phase 7 adds a complete original procedural audio layer. No external or copyrighted samples are used.

## Generation

Source generator:

- `tools/generate_netbound_audio.py`

The script creates deterministic mono 44.1 kHz WAV files under:

- `game/audio/generated/`

The sounds are synthesized from sine/square tones, shaped noise, envelopes, and simple musical intervals. They are normalized to avoid clipping.

## Buses

Runtime bus layout:

```text
Master
├── Music
├── SFX
└── UI -> SFX
```

`AudioService` creates missing buses at startup and applies saved volume settings:

- `master_volume` -> `Master`
- `music_volume` -> `Music`
- `sfx_volume` -> `SFX` and `UI`

## Assets

UI:

- `ui_tap.wav`
- `ui_confirm.wav`
- `ui_back.wav`
- `ui_locked.wav`
- `ui_tab.wav`

Gameplay:

- `aim_start.wav`
- `shot_weak.wav`
- `shot_release.wav`
- `shot_strong.wav`
- `impact_ground.wav`
- `impact_obstacle.wav`
- `impact_bounce.wav`
- `impact_post.wav`
- `hazard_cue.wav`
- `near_miss.wav`
- `goal_scored.wav`

Results:

- `result_success.wav`
- `result_star.wav`
- `result_failure.wav`
- `cosmetic_unlock.wav`

Music/Ambience:

- `music_menu_loop.wav`
- `music_gameplay_loop.wav`
- `music_final_loop.wav`

## AudioService API

Autoload:

- `/root/AudioService`

Important methods:

- `apply_settings_from_save(save_service)`
- `play_music(music_id)`
- `stop_music()`
- `play_ui(sound_id, volume_scale)`
- `play_sfx(sound_id, volume_scale, pitch_scale)`
- `play_shot(power_ratio)`
- `play_impact(kind, strength)`
- `cleanup_scene_audio()`
- `handle_app_backgrounded()`
- `handle_app_foregrounded()`
- `validate_assets()`
- `get_registered_sound_ids()`

## Runtime Rules

- One reusable music player.
- Ten reusable SFX players.
- Four reusable UI players.
- No new `AudioStreamPlayer` is created per sound event.
- Rapid impacts are cooldown-protected.
- Scene navigation stops one-shot audio.
- App backgrounding stops one-shot audio and pauses the reusable music player.
- App foregrounding resumes the existing music player instead of creating a duplicate.
- Music changes by replacing the reusable music stream.
- Zero volume settings set buses to silence.

## Verification

`verify_phase7_presentation_external.gd` validates:

- expected buses exist
- expected generated assets resolve
- player pool counts are bounded
- volume settings affect buses
- music transitions reuse the music player
- impact cooldown prevents spam
- haptics setting is respected
