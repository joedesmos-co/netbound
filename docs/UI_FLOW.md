# Netbound UI Flow

Phase 5 introduces the production app shell at `res://app/netbound_app.tscn`.

## Startup Flow

```text
Startup
-> Main Menu
-> Play/Continue, Level Select, Store, Settings, or Cosmetics
-> Gameplay Level
-> Success/Failure Result
-> Next Level, Rewarded Continue, Retry, Level Select, Store, or Main Menu
```

`NetboundApp` owns navigation. It loads production levels by `LevelRegistry` ID and never guesses paths from strings.

Phase 7 adds lightweight motion to this flow. Main screens fade in, modal overlays fade/scale in, buttons give a small press response, and result contents reveal quickly. Reduced Motion skips these tweens, and animations do not block input or own navigation decisions.

## Screen Responsibilities

### Main Menu

- Shows the Netbound title, Play/Continue, Level Select, Cosmetics, Store, Settings, and a subtle build label.
- Starts the lightweight menu music loop through `AudioService`.
- Resolves Play/Continue from `SaveService`:
  - first unlocked incomplete level
  - highest unlocked level if unlocked levels are complete but later levels remain locked
  - Level Select when all 10 levels are complete
- Cosmetics opens the Phase 6 cosmetic selection screen.
- Store opens the Phase 8 simulated monetization screen.

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
- Master, Music, SFX, Haptics, Reduced Motion, Camera Effects, and Quality are player-facing controls.
- Quality choices are Auto, Low, Medium, and High. They only affect presentation budgets.
- Developer Debug remains development-build-only and is hidden when the runtime is in release mode.

### Results

- Level completion is recorded by `SaveService` before the result overlay appears.
- Success shows level name, run stars, shots used, par, total stars, best result comparison, and unlock messages.
- If a rewarded continue was used, success states that the run is capped at one star.
- Newly unlocked cosmetics from the actual progression update appear in a compact unlock section.
- Result labels/buttons reveal with a short stagger unless Reduced Motion is enabled.
- Next Level is enabled only if a valid registered next level is unlocked.
- Level 10 disables Next Level and displays an all-levels-complete message.
- Failure shows Out of Shots and does not mutate progression.
- Failure may offer “Watch Ad for 1 Extra Shot” when the simulated ad provider is available, the player has no shots remaining, and no rewarded continue has been used for the current attempt.
- Rewarded continue is optional, grants exactly one shot after a completed provider callback, returns to READY, and never blocks Retry/Level Select/Main Menu.

### Store

- Store is reachable from Main Menu and from locked supporter cosmetics in the Cosmetics screen.
- Store shows Remove Ads, Starter Pack, Restore Purchases, owned states, unavailable states, pending state, and concise status feedback.
- Store uses simulated providers only in development builds and labels the build accordingly.
- Release-mode builds disable simulated providers and show offline/unavailable messaging until real SDKs are integrated in a later phase.
- Remove Ads disables interstitials but keeps voluntary rewarded continues available.
- Starter Pack includes Remove Ads plus Supporter Ball, Supporter Trail, and Supporter Goal Effect.
- Purchase/restore failures return control immediately and do not corrupt save data.

### Cosmetics

- Category tabs switch between Balls, Trails, and Goal Effects.
- The large preview uses a dedicated lightweight `SubViewport`; it does not load a production level.
- Item cards can always be previewed.
- Locked item cards show their gameplay requirement and cannot be equipped.
- Supporter cosmetics show the Starter Pack requirement and can open Store while locked.
- Previewing a locked item does not mutate save data.
- Unlocked items can be equipped with the Equip button and save immediately.
- One selected cosmetic is stored per category.
- Back returns to the previous menu or pause overlay.

## Back And Escape

- Main Menu: Back/Escape does nothing.
- Level Select: Back/Escape returns to Main Menu.
- Settings, Cosmetics, or Store: Back/Escape returns to the previous menu or pause overlay.
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
- Main Menu, Level Select, Settings, Cosmetics, Store, Pause, Results, and Gameplay HUD now read safe-area margins from `MobileRuntimeService`.
- The fallback safe margin is `28px`; device safe-area values are used when available.
- Buttons and level cards use touch-sized minimums.
- Level Select adjusts grid columns based on viewport width.
- Cosmetics uses touch-sized tabs, scrollable item cards, and a separate Equip button to avoid accidental selection while scrolling.
- Automated Phase 9 checks cover representative landscape phone/tablet aspect ratios with simulated safe-area margins.
- Physical iOS/Android safe-area validation is still required before release submission.
