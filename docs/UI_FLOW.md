# Netbound UI Flow

Phase 5 introduces the production app shell at `res://app/netbound_app.tscn`.

## Startup Flow

```text
Startup
-> Main Menu
-> Play/Continue, Level Select, Store, Settings, or Cosmetics
-> Gameplay Level
-> Success/Failure Result
-> Next Level, Play Again, Try Again, Level Select, Store, or Main Menu
```

`NetboundApp` owns navigation. It loads production levels by `LevelRegistry` ID and never guesses paths from strings.

Phase 7 adds lightweight motion to this flow. The production UI art-direction pass applies the shared Trajectory Playground system through `NetboundUITheme`, route/target components, and edge-aligned gameplay overlays. Reduced Motion skips directional/scale tweens, and animations do not block input or own navigation decisions.

## Screen Responsibilities

### Main Menu

- Shows the Netbound title, Play/Continue, Level Select, Cosmetics, Store, Settings, and a subtle build label.
- Starts the lightweight menu music loop through `AudioService`.
- Resolves Play/Continue from `SaveService`:
  - first unlocked incomplete level
  - highest unlocked level if unlocked levels are complete but later levels remain locked
  - Level Select when all 20 levels are complete
- Cosmetics opens the Phase 6 cosmetic selection screen.
- Store opens the Phase 8 simulated monetization screen.

### Level Select

- Builds exactly 20 connected route markers from `LevelRegistry` in a vertically scrollable, responsive progression grid.
- Reads unlocks, completion, stars, fewest shots, and total stars from `SaveService`.
- Locked markers are disabled and use a geometric lock state.
- The current marker uses signal yellow; complete markers use warm paper/success accents.
- Unlocked markers load the registered production scene.

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
- Newly unlocked cosmetics from the actual progression update appear in a compact unlock section.
- Arcade Coin rewards appear only after the saved completion and show completion, first-clear, new-star, and personal-best components.
- Result labels/buttons reveal with a short stagger unless Reduced Motion is enabled.
- Next Level is enabled only if a valid registered next level is unlocked.
- Level 20 disables Next Level and displays an all-levels-complete message.
- Failure shows Out of Shots and does not mutate progression.
- Failure offers a dominant free `Try Again`; there is no rewarded extra-shot action.
- `Reset Ball` stays within the current run and preserves shots used. `Restart Level`/`Try Again` abandons the run and starts at zero.
- Success and failure use right-edge score rails so gameplay context remains visible.

### Store

- Store is reachable from Main Menu and from locked supporter cosmetics in the Cosmetics screen.
- Store shows Remove Ads, Starter Pack, Restore Purchases, owned states, unavailable states, pending state, and concise status feedback.
- Store shows Arcade Coin/Net Token balances, five simulated Token packs, and the optional daily rewarded-Token action.
- Store uses simulated providers only in development builds and labels the build accordingly.
- Release-mode builds disable simulated providers and show offline/unavailable messaging until real SDKs are integrated in a later phase.
- Remove Ads disables interstitials but keeps voluntary rewarded-Token ads available.
- Starter Pack includes Remove Ads, Supporter Ball/Trail/Goal Effect, 2,500 Coins, and 300 Tokens; currency grants once.
- Purchase/restore failures return control immediately and do not corrupt save data.

### Cosmetics

- Category tabs switch between Balls, Trails, and Goal Effects.
- Rarity and ownership filters support a 38-item launch catalog.
- The large preview uses a dedicated lightweight `SubViewport`; it does not load a production level.
- Compact cut-corner item markers can always be previewed.
- The large focused detail panel shows description, unlock requirement, and Equip state without repeating that copy in every catalog item.
- Locked items cannot be equipped.
- Coin items purchase immediately when affordable; Token items require confirmation.
- Insufficient funds never changes ownership or selection.
- Supporter cosmetics show the Starter Pack requirement and can open Store while locked.
- Previewing a locked item does not mutate save data.
- Unlocked items can be equipped with the Equip button and save immediately.
- One selected cosmetic is stored per category.
- The preview goal remains white for every goal-effect selection; celebration color is visual-only and appears around it.
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
- Level Select uses a vertically scrollable connected route grid. Level 01 is visible on entry and Level 20 remains reachable at every supported landscape size.
- Cosmetics uses touch-sized tabs, a horizontal scroll strip, and a separate Equip button to avoid accidental selection while scrolling.
- Automated Phase 9 checks cover representative landscape phone/tablet aspect ratios with simulated safe-area margins.
- Native-canvas visual stress captures cover `1280x720`, `1600x720`, `1920x864`, `2340x1080`, `1024x768`, and `1366x1024`; production scaling and safe areas are verified separately.
- Physical iOS/Android safe-area validation is still required before release submission.
