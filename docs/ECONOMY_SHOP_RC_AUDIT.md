# Netbound Economy And Shop Release-Candidate Audit

Date: July 14, 2026
Baseline: `0aefe15` (`feat: add Netbound cosmetic economy and shop`)
Godot: `4.7.stable.official.5b4e0cb0f`

## July 15 Content-Expansion Addendum

The 20-level expansion does not change wallet amounts, product IDs, prices, acquisition methods, transaction bounds, entitlement semantics, or save version. It adds additional legitimate play-earned completion/star/personal-best opportunities through the existing idempotent ledgers.

An isolated pre-expansion version-2 fixture verifies that completed Level 10 progress unlocks Level 11 while preserving its 30 stars, `4,321` Coins, `87` Tokens, selected/unlocked cosmetics, and reward-history fields. No retroactive Coin grant is created. The catalog remains exactly 38 items with the documented `10/12/8/3/2/3` acquisition distribution.

## Recommendation

The local, simulated economy is ready for physical-device beta testing. No wallet, progression-reward, cosmetic-purchase, save-recovery, Store lifecycle, or Low-quality catalog blocker remains in the local provider architecture.

This is not approval for public billing. Real Apple/Google billing, receipts, refunds, pending/deferred transactions, trusted time, production ad providers, and upload signing remain intentionally unimplemented.

## Production Defects Found And Fixed

| Severity | Defect | Root cause | Resolution |
| --- | --- | --- | --- |
| High | A failed level-completion save left earned Coins, progression, stars, unlocks, and processed reward IDs mutated in memory. | Completion assembled progression and economy before the final atomic write but retained that assembled state when the write failed. | `SaveService.record_level_result()` now snapshots the normalized save transaction, restores it on failure, clears unsaved reward/unlock fields, and reports `save_succeeded = false`. |
| Medium | Insufficient-funds feedback immediately reverted to `PREVIEW ONLY`. | The purchase handler set the status before rebuilding the cosmetic preview, whose normal state refresh overwrote it. | Purchase status is now applied after the refresh, so failure and purchase feedback remain visible. |
| Medium | Direct Result-to-Store navigation retained the completed production level behind the Store. | `show_store()` did not leave gameplay except indirectly through other navigation paths. | Store entry unloads the current level outside the intentional Pause-to-Store path. |
| Documentation | The insufficient-funds screenshot showed the overwritten status. | Evidence predated the status fix. | `docs/economy_review/cosmetics_insufficient_1280x720.png` was recaptured from the production UI and isolated save. |

## Wallet And Results

Verified through `NetboundApp`, `LevelController`, production swipe input, swept goal scoring, and `SaveService`:

- Fresh save starts at `0` Arcade Coins and `0` Net Tokens.
- Failure, auto-reset, Reset Ball, Retry, and reopened result overlays grant no Coins.
- A real Level 01 production completion grants exactly `475`: finish `100`, first clear `150`, and three new stars `225`.
- A two-shot first clear grants only the eligible first-clear/star/finish values.
- A genuine one-shot personal-best improvement grants `50` once and only once.
- A rewarded-continue completion remains capped at one star.
- Coin balance, reward components, first-clear label, new-star label, personal-best label, and result balance match the committed `ProgressionUpdate`.
- A failed completion save rolls all wallet and progression state back and displays `SAVE FAILED // PROGRESS NOT RECORDED`; it does not display a Coin reward.
- Balances are integer-clamped to `0..2,000,000,000` and survive disk reload.

## Rewarded Token Ads

Verified with the simulated provider and stable transaction IDs:

- Completed rewarded Token ad grants exactly `2` Tokens.
- Cancel, failure, offline/unavailable provider, stale callback, and duplicate callback grant zero.
- Daily limits are exactly five completed rewarded Token ads and ten free Tokens per saved local day.
- A later local date resets the allowance; a clock rollback blocks claims until the saved date is reached.
- Remove Ads does not disable voluntary rewarded ads.
- The limitation remains local-only and is not an anti-tamper system.

## Cosmetic Shop

- The authoritative registry contains exactly 38 unique entries: 18 balls, 12 trails, and 8 goal effects.
- All acquisition methods and all 20 currency prices were checked against the committed catalog.
- Coin purchases deduct once; Token purchases require confirmation; duplicate taps cannot double-purchase.
- Insufficient funds are visible and leave balances unchanged.
- Progression, achievement, supporter, and future items cannot be bought through a currency path.
- Preview and touch-drag scrolling do not spend, equip, or mutate ownership.
- Purchased items become owned immediately, cannot be purchased again, and remain equipable after reload.
- Rarity and ownership filters produce the expected catalog subsets and do not rebuild during idle frames.
- All 38 cosmetics preview and apply at Low quality without changing ball mass, collision radius, launch-speed tuning, scoring, or goal geometry.

## Products And Starter Pack

Verified simulated Token products:

| Product | Tokens |
| --- | ---: |
| `netbound_tokens_100` | 100 |
| `netbound_tokens_275` | 275 |
| `netbound_tokens_600` | 600 |
| `netbound_tokens_1300` | 1,300 |
| `netbound_tokens_3000` | 3,000 |

- Invalid products grant nothing.
- Duplicate transaction IDs cannot regrant consumable Tokens.
- Processed transaction IDs remain bounded to 2,048 and transaction history to 64.
- Token consumables are excluded from restore.
- Delayed duplicate callbacks remain safe after Store-to-Main-Menu navigation and simulated background/foreground transitions.
- Release mode disables simulated purchasing and shows factual unavailable/offline messaging without development prices.
- Starter Pack grants Remove Ads, all three Supporter cosmetics, 2,500 Coins, and 300 Tokens once.
- Restore reapplies permanent ownership but never repeats Starter Pack currency.

## Save Version 2

Verified cases:

- fresh version 2 save;
- version 1 migration with completed progress and seeded anti-duplication reward ledgers;
- partially malformed version 2 data;
- negative and oversized balances;
- invalid selected, unlocked, and purchased cosmetic IDs;
- oversized processed transaction and history arrays;
- corrupted primary with a valid backup;
- simulated interrupted direct grant, cosmetic purchase, and level-completion writes.

All recover without a crash or duplicated reward. A migrated completed Level 01 replay receives only the normal `100` completion reward, not retroactive first-clear or star rewards.

## Performance Evidence

The dedicated audit warms every cosmetic before measuring:

- cosmetic preview nodes: `150 -> 150` across a second full 38-item pass;
- cosmetic preview resources: `65 -> 65`;
- 90 idle frames: no node or resource growth;
- five Store -> Gameplay -> Result -> Store cycles: exactly `83` nodes every cycle;
- the same five cycles: exactly `108` resources every cycle;
- Low-quality trail limit: 8 points;
- cosmetic goal transient groups: at most 2 roots and 26 descendants, then zero after cleanup.

These are desktop/headless safety results, not physical mobile GPU, thermal, or frame-pacing claims.

## Verification Matrix

Primary audit script:

```sh
/Users/ryland/Documents/Godot.app/Contents/MacOS/Godot \
  --headless --path /Users/ryland/Documents/NetBound/game \
  --script res://scripts/debug/verify_economy_rc_external.gd
```

Final local matrix:

- headless import: passed;
- configured production startup: passed;
- strict parser sweep: `65/65`;
- direct production level startup: `10/10`;
- external regression scripts: `24/24`;
- Phase 1 through Phase 9, economy, UI art direction, and integrated final flow: passed;
- unexpected parser/runtime error, warning, or leak matches: zero;
- import/parser/level/full-matrix logs: `/tmp/netbound-economy-rc-audit.Atr1Sp`;
- final exact-working-tree 24-suite rerun logs: `/tmp/netbound-economy-rc-final.L10aXP`;
- `git diff --check`: passed before commit.

The configured app also launched visibly on `Metal 4.0 - Forward Mobile` using the Apple M4 renderer.

## Android Export Evidence

Temporary artifacts: `/tmp/netbound-economy-rc-exports.K4Gwqw`

- Debug APK: passed, approximately 28 MB, SHA-256 `eb33e3a48d598e1ed5d048fa323e5c1a22b0bc121e975d068e58f57748270cd5`.
- APK metadata: `com.netbound.game`, version `0.9.0` code `9`, min SDK 24, target SDK 36.
- APK signing: Android debug certificate, v2/v3 verified.
- Debug AAB clean rerun: passed, approximately 28 MB, SHA-256 `758fdcfd25eb88be7ab362b3aa93c881f27bd77088b8ae6419b1d4d518637050`.
- AAB archive integrity: passed.
- AAB remains unsigned locally, as expected; a real upload key is still required.
- `aapt2` still reports the previously documented non-fatal missing prebuilt-template `themed_icon.xml` entry. The actual adaptive launcher icon resolves, but physical launcher inspection remains required.

## Visible Evidence

Reviewed production captures under `docs/economy_review/`:

- insufficient funds;
- Coin and Token purchase states;
- Token confirmation;
- empty, unavailable, successful, failed, daily-limit, restored, and Starter-owned Store states;
- first-clear reward breakdown.

The refreshed insufficient-funds capture shows `NOT ENOUGH CURRENCY` without changing the wallet.

## Remaining Physical And Platform Checks

- Touch-scroll comfort and accidental-tap resistance on a real phone and tablet.
- App kill during delayed provider callbacks and during an atomic save write.
- Wallet and Shop readability under platform font scaling, OLED/LCD variation, and real safe areas.
- Low-quality cosmetic frame pacing, thermal behavior, and GPU memory on low/mid-range Android hardware.
- iOS backgrounding and process termination on signed hardware.
- Real purchase pending/deferred/cancel/refund/restore behavior after SDK selection.
- Receipt validation, trusted time, account/store reconciliation, consent, and privacy requirements.
- Android upload signing and Apple Team/provisioning.
