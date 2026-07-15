# Netbound Economy

Netbound's economy is local, offline-first, and cosmetic-only. It never changes shooting, collision, scoring, level access, obstacle timing, star rules, or camera behavior.

## Ownership

- `WalletService` is the only authority that grants or spends currency.
- `SaveService` owns normalized persistence and atomic writes.
- `CosmeticRegistry` owns acquisition type and price metadata.
- `MonetizationService` validates simulated ad/purchase callbacks before asking `WalletService` to fulfill them.
- `NetboundApp` displays balances and sends intents; UI code never edits balances directly.

## Currencies

### Arcade Coins

Arcade Coins are earned through successful play:

| Event | Coins |
| --- | ---: |
| Every completed run | 100 |
| First completion of a level | 150 bonus |
| Each newly earned best star | 75 |
| Improved fewest-shots personal best | 50 |

Failure, Retry, Reset Ball, auto-reset, and reopening a result screen grant nothing. Completion rewards are derived from the authoritative `ProgressionUpdate` after the result is accepted by `SaveService`. A rewarded-continue completion still follows the existing one-star cap.

### Net Tokens

Net Tokens come from optional simulated products or completed rewarded ads:

- One completed rewarded Token ad grants `2` Tokens.
- At most `5` rewarded Token ads and `10` free Tokens may be claimed per local calendar day.
- Cancelled, failed, unavailable, duplicate, or stale callbacks grant nothing.
- Remove Ads and Starter Pack do not disable voluntary rewarded Token ads.
- Local clock rollback blocks new daily claims until the saved date is reached again.

The daily rule is intentionally local-only. It is suitable for an offline prototype but is not a secure anti-tamper system.

## Cosmetic Acquisition Mix

The 38-item catalog intentionally mixes free progression and optional premium acquisition:

| Acquisition | Count | Share |
| --- | ---: | ---: |
| Direct level/star gameplay unlock | 10 | 26.3% |
| Arcade Coin purchase | 12 | 31.6% |
| Net Token purchase | 8 | 21.1% |
| Supporter entitlement | 3 | 7.9% |
| Major star achievement | 2 | 5.3% |
| Default | 3 | 7.9% |

Arcade Coins are gameplay-earned, so more than half the catalog is obtainable without a real-money purchase. Creative high-tier rewards remain available through gameplay: Galaxy, Champion, Gold, Rainbow, Confetti, and Shockwave are not Token purchases. `trail_comet` moved from a 60-Token price to `6,500` Arcade Coins to strengthen the mid-game free route; existing ownership remains monotonic.

The 20-level expansion preserves this catalog and every price. New levels create additional completion, first-clear, star, and genuine personal-best Coin opportunities through the same idempotent reward ledgers. The maximum route total is now 60 stars, while existing 6-30 star cosmetic thresholds intentionally remain approachable early/mid-route goals.

## Wallet API

Primary autoload: `/root/WalletService`, class `NetboundWalletService`.

Important methods:

- `get_coin_balance()`
- `get_token_balance()`
- `grant_coins(amount, reason, transaction_id)`
- `grant_tokens(amount, reason, transaction_id)`
- `spend_coins(amount, reason)`
- `spend_tokens(amount, reason)`
- `can_afford_coins(amount)`
- `can_afford_tokens(amount)`
- `process_level_completion_rewards(update)`
- `get_rewarded_token_status(local_date)`
- `claim_rewarded_token_ad(transaction_id, local_date)`
- `purchase_cosmetic(cosmetic_id)`
- `fulfill_starter_pack_bonus()`
- `has_processed_transaction(transaction_id)`

Balances are integers clamped to `0..2,000,000,000`. Negative, malformed, or missing saved balances normalize to zero.

## Transaction Safety

Every external grant carries a stable transaction ID. Completed IDs are persisted before a callback can be fulfilled again.

- Level rewards use per-run and per-milestone IDs.
- Cosmetic purchases use `cosmetic_purchase:<cosmetic_id>`.
- Rewarded ads reserve a wallet sequence ID before the ad request.
- Simulated Token products use their provider transaction ID.
- Starter Pack currency uses `starter_pack_bonus_v1`.
- Duplicate provider callbacks and app-resume callbacks are ignored.
- Cosmetic ownership and its currency deduction are committed through one `SaveService.commit_cosmetic_purchase()` write.
- Level completion snapshots progression, cosmetic, and wallet state before the final write. A failed write restores the entire snapshot and clears unsaved reward fields from the result update.

Processed IDs are bounded to the most recent `2048`; developer transaction history is bounded to `64`. These bounds prevent unbounded save growth. Without a server, receipt ledger, or signed local storage, they are reliability guards rather than fraud prevention.

## Result Flow

1. Gameplay creates a completed `LevelResult`.
2. `SaveService.record_level_result()` normalizes progression and builds `ProgressionUpdate`.
3. `WalletService.process_level_completion_rewards()` applies only newly eligible rewards.
4. Progression and economy are atomically saved before the result UI appears.
5. The success rail displays the actual Coin breakdown and resulting balance.

If step 4 fails, the in-memory transaction is rolled back. The result rail shows `SAVE FAILED // PROGRESS NOT RECORDED` and does not advertise an uncommitted Coin reward or new best.

This ordering prevents a result overlay from inventing rewards or replaying a grant.

## Starter Pack

The simulated Starter Pack grants:

- Remove Ads entitlement
- Supporter Ball, Supporter Trail, and Supporter Burst
- `2,500` Arcade Coins
- `300` Net Tokens

Permanent entitlement and cosmetics restore. Bonus currency is consumable fulfillment and is granted once only; Restore Purchases never repeats it. Loading an older save that already owns the Starter Pack reconciles the one-time bonus once through the same transaction ID.

## Save Migration

Economy data uses save version `2`. A version `1` save receives zero currency balances and valid empty economy collections. Existing completed levels, stars, and personal bests are seeded into reward-history fields so migration cannot retroactively duplicate first-completion, star, or personal-best rewards.

Corrupt saves still follow the existing backup/corrupt-copy recovery path. Unknown or invalid cosmetic purchases are discarded during normalization.

## Developer Utilities

`WalletService.reset_wallet_for_development()` resets balances and reward ledgers. Simulated providers can force success, failure, delay, duplicate callback, and transaction IDs in external test scripts. These controls are not shown in normal production UI and never run automatically.

## Deferred Integration

Real Apple/Google billing, receipt validation, server authority, cloud reconciliation, trusted time, real ad SDKs, consent SDKs, analytics, and account systems remain intentionally deferred. See `docs/CURRENCY_PRODUCTS.md` for product mappings and `docs/MONETIZATION.md` for provider policy.

## Player-Feel Invariance

The rewarded extra-shot continue was retired because a free level restart already
provides the honest recovery path. This changes no wallet rule: failure, Reset Ball,
Restart Level, and Try Again grant no Coins or Tokens. Voluntary rewarded Token ads
remain available in Store and retain their daily/idempotency limits. Version-2 save
normalization keeps the legacy result field for compatibility, but it no longer
changes stars, completion rewards, or result presentation.
