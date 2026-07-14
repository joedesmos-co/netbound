# Netbound Quality Settings

Phase 9 adds presentation-only quality tiers. They are not gameplay difficulty settings.

## Save Field

`SaveService.settings.quality_tier`

Valid values:

- `auto`
- `low`
- `medium`
- `high`

Missing or invalid values normalize to `auto`. No save-version bump was required because this is an optional settings key in save version `1`.

## Effective Tier

`MobileRuntimeService` resolves:

- `auto` on mobile feature builds -> `medium`
- `auto` on desktop development builds -> `high`
- explicit `low`, `medium`, `high` -> that tier

## Budgets

Low:

- decorative geometry off
- contact shadow off
- dynamic shadows off
- trail point limit `8`
- particle multiplier `0.45`

Medium:

- decorative geometry on
- contact shadow on
- dynamic shadows off
- trail point limit `12`
- particle multiplier `0.7`

High:

- decorative geometry on
- contact shadow on
- dynamic shadows on
- trail point limit `16`
- particle multiplier `1.0`

## Non-Negotiables

Quality settings must never alter:

- launch speed
- elevation mapping
- curve math
- ball mass
- collision shapes
- damping
- shot limits
- obstacle timing
- goal detection
- progression
- star ratings
- cosmetic unlock requirements
- monetization rewards

`verify_phase9_mobile_external.gd` records gameplay signatures before and after quality changes to guard this boundary.
