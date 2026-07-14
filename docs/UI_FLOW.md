# Netbound UI Flow

Phase 5 introduces the production app shell at `res://app/netbound_app.tscn`.

## Startup Flow

```text
Startup
-> Main Menu
-> Play/Continue or Level Select
-> Gameplay Level
-> Success/Failure Result
-> Next Level, Retry, Level Select, or Main Menu
```

`NetboundApp` owns navigation. It loads production levels by `LevelRegistry` ID and never guesses paths from strings.

Phase 7 adds lightweight motion to this flow. Main screens fade in, modal overlays fade/scale in, buttons give a small press response, and result contents reveal quickly. Reduced Motion skips these tweens, and animations do not block input or own navigation decisions.

## Screen Responsibilities

### Main Menu

- Shows the Netbound title, Play/Continue, Level Select, Cosmetics, Settings, and a subtle build label.
- Starts the lightweight menu music loop through `AudioService`.
- Resolves Play/Continue from `SaveService`:
  - first unlocked incomplete level
  - highest unlocked level if unlocked levels are complete but later levels remain locked
  - Level Select when all 10 levels are complete
- Cosmetics opens the Phase 6 cosmetic selection screen.

### Level Select

- Builds exactly 10 cards from `LevelRegistry`.
- Reads unlocks, completion, stars, fewest shots, and total stars from `SaveService`.
- Locked cards are disabled and display the unlock requirement.
- Unlocked cards load the registered production scene.

### Gameplay

- The app shell loads a level scene under `LevelRoot`.
- The level keeps shooting, reset, goal detection, shot limits, and progression recording.
- The app enables external navigation UI mode, which hides legacy win/fail panels and the old Retry Level HUD button.
- The app-level Pause button remains available during gameplay.

### Pause

- Pause sets `SceneTree.paused = true`; app UI is `PROCESS_MODE_ALWAYS`.
- Resume clears pause and restores the current level state.
- Restart calls the level's authoritative retry path.
- Level Select and Main Menu unload the level after cancelling stale callbacks.
- Settings can be opened from Pause and returns to the pause overlay.

### Settings

- Settings apply immediately through `SaveService`, `AudioService`, and `HapticsService`.
- Master, Music, SFX, Haptics, Reduced Motion, and Camera Effects are player-facing controls.
- Developer Debug remains debug-build-only.

### Results

- Level completion is recorded by `SaveService` before the result overlay appears.
- Success shows level name, run stars, shots used, par, total stars, best result comparison, and unlock messages.
- Newly unlocked cosmetics from the actual progression update appear in a compact unlock section.
- Result labels/buttons reveal with a short stagger unless Reduced Motion is enabled.
- Next Level is enabled only if a valid registered next level is unlocked.
- Level 10 disables Next Level and displays an all-levels-complete message.
- Failure shows Out of Shots and does not mutate progression.

### Cosmetics

- Category tabs switch between Balls, Trails, and Goal Effects.
- The large preview uses a dedicated lightweight `SubViewport`; it does not load a production level.
- Item cards can always be previewed.
- Locked item cards show their gameplay requirement and cannot be equipped.
- Previewing a locked item does not mutate save data.
- Unlocked items can be equipped with the Equip button and save immediately.
- One selected cosmetic is stored per category.
- Back returns to the previous menu or pause overlay.

## Back And Escape

- Main Menu: Back/Escape does nothing.
- Level Select: Back/Escape returns to Main Menu.
- Settings or Cosmetics: Back/Escape returns to the previous menu or pause overlay.
- Gameplay: Back/Escape opens Pause.
- Pause: Back/Escape resumes gameplay.
- Result Screen: Back/Escape returns to Level Select.

## Motion Rules

- Major screens use a short fade-in.
- Pause and result overlays use a short fade plus panel scale.
- Buttons use a brief press scale with audio/haptics feedback.
- Reduced Motion makes screen changes effectively immediate.
- Active tweens are killed when screens or gameplay overlays are cleared.
- Navigation remains guarded by `navigation_in_progress`; tweens do not add a second navigation lock.

## Responsive Layout

- Screens use full-rect anchors, containers, scroll views, and conservative margins.
- Buttons and level cards use touch-sized minimums.
- Level Select adjusts grid columns based on viewport width.
- Cosmetics uses touch-sized tabs, scrollable item cards, and a separate Equip button to avoid accidental selection while scrolling.
- Physical iOS/Android safe-area validation is still required in Phase 8.
