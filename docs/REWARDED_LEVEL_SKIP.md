# Rewarded Level Skip

## Purpose

Netbound offers one optional recovery path for a player who is repeatedly unable
to clear an unlocked level. After five consumed shots resolve without a goal in
the current app session, the next failure result may offer:

- `WATCH & SKIP`: watch a voluntary rewarded ad and clear with one star.
- `KEEP TRYING`: restart the level immediately and for free.

The offer never interrupts aiming, ball movement, Pause, goal feedback, or
navigation. It is hidden before eligibility and hidden whenever the rewarded-ad
provider is unavailable.

## Failed-Shot Eligibility

`LevelController` emits `shot_resolved_without_goal(level_id, shot_id)` only when
a valid production shot consumed an attempt and its authoritative miss path
resolved. `NetboundApp` owns a session-only counter keyed by level ID.

The counter:

- starts at zero for each app instance;
- increments once per resolved, consumed miss;
- survives Reset Ball, Restart Level, and switching away and back;
- ignores invalid/cancelled gestures, debug launches, successful shots, stale
  callbacks, and shots on a completed level;
- is cleared by a normal or assisted completion;
- is not written to save data.

Eligibility begins at five misses and remains until completion or app exit. The
offer is evaluated only while building the natural failure result.

## Assisted-Clear Transaction

`SaveService.record_assisted_clear(level_id, definition, fulfillment_id)` is the
only progression mutation for this flow. A successful transaction atomically:

- marks the level completed;
- stores it in `assisted_levels`;
- sets best stars to at least one without lowering an existing result;
- unlocks the registered next level;
- evaluates normal total-star cosmetic milestones;
- stores a bounded fulfillment ID and saves immediately.

It deliberately does not call `WalletService`, create a fewest-shots record, add
the level to `normal_completed_levels`, grant Coins or Tokens, or award more than
one star. A failed write restores the complete pre-transaction save snapshot.

Assisted Level 20 uses the same positive result rail, but says `ROUTE OPEN!`,
shows one star and no best-shot record, and asks for a replay rather than claiming
a perfect finale completion.

## Normal Replay

A later authoritative completion uses the unchanged normal result flow. It:

- removes the level from `assisted_levels`;
- adds it to `normal_completed_levels`;
- records a real fewest-shots result;
- can improve the level to two or three stars;
- grants legitimate completion, first-normal-clear, star, and personal-best
  rewards through the existing idempotent wallet ledgers.

Previously earned stars never decrease. A normal completion that wins a race
with a pending ad makes the later assisted fulfillment a no-op.

## Callback Safety

Each request includes the target level and a unique
`assisted_clear:<level>:<app_instance>:<sequence>` fulfillment ID. The existing
`MonetizationService` validates request IDs and suppresses duplicate provider
callbacks before `SaveService` applies the bounded persistent fulfillment guard.

- Earned success is the only callback that can grant progression.
- Cancel, failure, and unavailable outcomes change nothing.
- A delayed earned callback may safely save its original level after navigation,
  Restart, or Pause/Resume, but it never replaces the player's current screen.
- Remove Ads and Starter Pack disable forced interstitials, not voluntary Token
  ads or the voluntary level-skip ad.
- Release mode exposes no simulated ad as a real advertisement; without a real
  provider, the offer remains hidden and the game stays fully playable.

## Save Compatibility

Save version remains `2`. The progression dictionary gained optional fields:

- `normal_completed_levels`
- `assisted_levels`
- `assisted_fulfillment_ids` (bounded to 256)

Older version-2 saves do not contain assisted clears, so normalization seeds
`normal_completed_levels` from their existing `completed_levels`. Existing
progression, stars, best shots, wallet balances, cosmetics, entitlements, and
reward ledgers remain unchanged.

## UI States

- Before five misses: ordinary `TRY AGAIN` failure rail; no ad copy.
- Eligible and provider available: compact `STUCK?` band with `WATCH & SKIP`;
  yellow `KEEP TRYING` remains dominant.
- Pending: the ad button reads `WATCHING...` and only that action is disabled.
- Cancel/failure: concise status confirms nothing changed.
- Assisted success: positive green, one star, no Coin panel, no new-best claim,
  next-level action where one exists.

## Verification

Focused regression:

```sh
/Users/ryland/Documents/Godot.app/Contents/MacOS/Godot \
  --headless --path game \
  --script res://scripts/debug/verify_rewarded_level_skip_external.gd
```

Visual evidence is stored in `artifacts/rewarded-level-skip/`. These captures use
isolated saves and the external capture harness; no test fixture is connected to
production scenes.

Final local outcome:

- Godot import and configured startup: passed.
- Strict parser sweep: `73/73`.
- Direct production scene startup: `20/20`.
- Retained external regression scripts: `31/31`.
- Production mouse-swipe completion routes: `20/20`; Level 20 entry remained `right`.
- Android debug APK and isolated-template AAB exports: passed.
- APK SHA-256: `50bd47b3b17d75209fe9d6e299c9dd5131429014701210f95a4a2ffc3eca4673`.
- AAB SHA-256: `dc16a6378411a36b872fc6e001d675c62e302b8558dbe625ea3b181d286bfd38`.
- Godot warning/error/leak matches: zero.

Evidence paths:

- regression logs: `/tmp/netbound-rewarded-skip-regressions.YAYfIr`
- engine logs: `/tmp/netbound-rewarded-skip-engine.MmUluk`
- level startup logs: `/tmp/netbound-rewarded-skip-levels.NwlgXd`
- exports and validation logs: `/tmp/netbound-rewarded-level-skip-exports`
- failure/result captures: `artifacts/rewarded-level-skip/after/ui/`
- tablet/wide-phone captures: `artifacts/rewarded-level-skip/after/responsive/`

Physical-device checks still required after a real ad provider exists:

- touch comfort and copy readability around every safe-area shape;
- provider overlay cancellation, app background/resume, and delayed callbacks;
- network loss during an ad and process termination immediately after reward;
- platform policy review for rewarded completion language and placement.
