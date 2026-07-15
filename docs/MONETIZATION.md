# Netbound Monetization

Phase 8 adds a simulated, player-friendly monetization layer. It does not integrate real ad SDKs, purchase SDKs, analytics, online accounts, cloud saves, or consent dialogs.

## Principles

- All 20 levels remain completable without paying or watching ads.
- Offline progression, stars, settings, cosmetics, and core play remain available.
- Monetization never changes shot power, elevation, curve, ball physics, collision, goal detection, level difficulty, level access, or obstacle timing.
- Providers never mutate gameplay directly; `MonetizationService` validates callbacks and `SaveService` persists entitlements.

## Architecture

Autoload:

- `/root/MonetizationService`

Provider interfaces:

- `res://scripts/monetization/ad_provider.gd`
- `res://scripts/monetization/purchase_provider.gd`

Simulated providers:

- `res://scripts/monetization/simulated_ad_provider.gd`
- `res://scripts/monetization/simulated_purchase_provider.gd`

Main service methods:

- `request_rewarded_ad(context, metadata)`
- `request_interstitial(context)`
- `purchase_remove_ads()`
- `purchase_starter_pack()`
- `restore_purchases()`
- `has_entitlement(entitlement_id)`
- `is_rewarded_ad_available()`
- `should_show_interstitial(context)`
- `record_level_completion_for_ads()`

Semantic signals include rewarded start/complete/fail, reward granted, interstitial shown, purchase start/complete/fail, purchases restored, and entitlement changed.

## Products And Entitlements

Products:

- `netbound_remove_ads`
- `netbound_starter_pack`
- five consumable Token packs defined by `NetboundCurrencyProductRegistry`

Entitlements:

- `entitlement_remove_ads`
- `entitlement_starter_pack`

Starter Pack grants:

- Remove Ads entitlement
- `ball_supporter`
- `trail_supporter`
- `goal_supporter`
- 2,500 Arcade Coins once
- 300 Net Tokens once

Purchases and restores are idempotent. Duplicate provider callbacks cannot grant twice because request IDs and provider transaction IDs are consumed once. Token packs are consumable and never restored. Starter Pack currency is a one-time fulfillment; Restore reapplies only permanent ownership.

## Rewarded Net Tokens

`Try Again` is free and immediately starts a fresh run. Netbound never offers a
rewarded extra shot.

Voluntary rewarded ads remain available in the Store for Net Tokens:

- a completed provider callback grants exactly two Tokens
- cancel/failure grants nothing
- request IDs and wallet reward keys prevent duplicate grants
- local daily caps remain authoritative
- Remove Ads does not disable this voluntary reward
- offline/unavailable providers leave gameplay and free restart usable

## Rewarded Level Skip

After five consumed misses on an uncleared level in one app session, a failure
result may offer a separate voluntary `rewarded_level_skip` request. A confirmed
reward asks `SaveService` to record an assisted clear with one star. It grants no
Coins, Tokens, normal completion, or best-shot record. Cancel, failure,
unavailable, duplicate, and conflicting late callbacks grant nothing.

Every request carries a unique fulfillment ID. Provider request deduplication is
followed by a bounded persistent fulfillment ledger in progression. Remove Ads
and Starter Pack do not disable this voluntary choice. Release mode keeps the
offer hidden while only the simulated provider exists. See
`docs/REWARDED_LEVEL_SKIP.md` for the complete transaction and callback contract.

## Interstitial Policy

Interstitials are centralized in `MonetizationService`.

Current policy:

- never during gameplay, aiming, or failure
- only after completed-result navigation contexts
- never appears during the first 3 completed levels
- requires at least 4 completed levels in the save
- requires 3 completed-level events in the current session
- maximum 2 per app session
- minimum 8-minute spacing
- disabled by Remove Ads or Starter Pack
- provider unavailable/offline skips silently and navigation continues

## Store UI

`NetboundApp` owns the Store screen.

Store includes:

- Remove Ads card
- Starter Pack card
- Restore Purchases
- Coin/Token wallet balances
- five simulated Token packs
- optional rewarded Token ad with daily status
- owned state
- unavailable/offline state
- purchase-in-progress state
- success/failure feedback
- Back button

The Cosmetics screen doubles as the cosmetic Shop. It previews all items, filters by rarity/ownership, confirms Token spending, and sends purchase intent to `WalletService`. It never mutates balances itself.

## Save Integration

`SaveService` stores permanent monetization state plus the version `2` economy ledger. See `docs/ECONOMY.md` and `docs/SAVE_FORMAT.md`.

- `entitlements`
- product records under `purchases`
- local config placeholders under `config`

Config placeholders:

- `ads_enabled`
- `purchases_enabled`
- `child_directed_treatment`
- `privacy_consent_status`
- `personalized_ads_allowed`

These fields are readiness hooks only. Phase 8 collects no data and shows no legal consent dialogs.

## Simulated Provider Controls

Development/test methods:

- `configure_simulated_ads(available, rewarded_mode, interstitial_mode, delay_frames, duplicate_callback)`
- `configure_simulated_purchases(available, purchase_mode, restore_mode, delay_frames, duplicate_callback)`
- `set_simulated_restore_products(product_ids)`
- `reset_session_frequency_for_tests()`

Modes support success, cancel/failure, unavailable, delay, and duplicate callbacks. These controls are not exposed in normal production UI.

## Phase 9 Release-Mode Guard

Phase 9 keeps monetization architecture local/simulated but separates development and release behavior:

- Android/iOS export presets tag development builds with `netbound_development`.
- Android/iOS export presets tag release builds with `netbound_release`.
- `MobileRuntimeService` detects release mode and calls `MonetizationService.set_release_mode_enabled(true)`.
- Release mode clears active simulated requests and makes rewarded ads, interstitials, and purchases unavailable.
- Store UI remains reachable but shows unavailable/offline messaging until real SDKs are intentionally integrated in a later phase.
- No real ad SDK, purchase SDK, analytics SDK, consent SDK, online account, or cloud service is integrated in Phase 9.

## Verification

Primary Phase 8 verifier:

- `res://scripts/debug/verify_phase8_monetization_external.gd`

It covers provider guards, entitlements, migration, free failure restart, rewarded Tokens, duplicate callbacks, interstitial policy, Store UI, offline behavior, supporter cosmetics, and all production level startups.

Physical mobile checks still required:

- real offline app relaunch persistence
- touch comfort for Store rewarded-Token controls and failure `Try Again`
- purchase/ad UI platform compliance after real SDK selection
- receipt validation strategy
- consent/privacy requirements
