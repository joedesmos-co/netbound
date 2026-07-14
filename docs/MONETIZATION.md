# Netbound Monetization

Phase 8 adds a simulated, player-friendly monetization layer. It does not integrate real ad SDKs, purchase SDKs, analytics, online accounts, cloud saves, or consent dialogs.

## Principles

- All 10 levels remain completeable without paying or watching ads.
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

Entitlements:

- `entitlement_remove_ads`
- `entitlement_starter_pack`

Starter Pack grants:

- Remove Ads entitlement
- `ball_supporter`
- `trail_supporter`
- `goal_supporter`

Purchases and restores are idempotent. Duplicate provider callbacks cannot grant twice because request IDs are consumed once.

## Rewarded Continue

Failure result may show “Watch Ad for 1 Extra Shot”.

Rules:

- voluntary only
- one use per failed attempt
- only when the level is in `FAILED` with no shots remaining
- provider must report completion
- cancel/failure grants nothing
- stale callbacks after navigation are ignored by level instance ID
- reward grants exactly one shot and returns the level to `READY`
- no shot refund, no physics change, no direct save mutation before completion

Ad-continued completion rule:

- completion can unlock the next level
- stars for that run are capped at `1`
- previous better stars remain unchanged

## Interstitial Policy

Interstitials are centralized in `MonetizationService`.

Current policy:

- never during gameplay, aiming, or failure
- only after completed-result navigation contexts
- requires at least 3 completed levels in the save
- requires 3 completed-level events in the current session
- max one per app session
- minimum time spacing
- disabled by Remove Ads or Starter Pack
- provider unavailable/offline skips silently and navigation continues

## Store UI

`NetboundApp` owns the Store screen.

Store includes:

- Remove Ads card
- Starter Pack card
- Restore Purchases
- owned state
- unavailable/offline state
- purchase-in-progress state
- success/failure feedback
- Back button

The Cosmetics screen may preview supporter items while locked and shows an Open Store button for locked entitlement cosmetics. It does not contain purchase logic.

## Save Integration

`SaveService` stores the `monetization` dictionary in save version `1`:

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

## Verification

Primary Phase 8 verifier:

- `res://scripts/debug/verify_phase8_monetization_external.gd`

It covers provider guards, entitlements, migration, rewarded continue, duplicate callbacks, interstitial policy, Store UI, offline behavior, supporter cosmetics, and all production level startups.

Physical mobile checks still required:

- real offline app relaunch persistence
- touch comfort for Store and failure-result ad button
- purchase/ad UI platform compliance after real SDK selection
- receipt validation strategy
- consent/privacy requirements
