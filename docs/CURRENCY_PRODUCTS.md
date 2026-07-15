# Netbound Currency Products

All product prices in this phase are simulated development labels. They are not App Store or Google Play offers and no real SDK is linked.

## Simulated Token Products

| Product ID | Tokens | Development label | Type | Restorable |
| --- | ---: | --- | --- | --- |
| `netbound_tokens_100` | 100 | DEV $0.99 | Consumable | No |
| `netbound_tokens_275` | 275 | DEV $1.99 | Consumable | No |
| `netbound_tokens_600` | 600 | DEV $3.99 | Consumable | No |
| `netbound_tokens_1300` | 1,300 | DEV $6.99 | Consumable | No |
| `netbound_tokens_3000` | 3,000 | DEV $12.99 | Consumable | No |

`NetboundCurrencyProductRegistry` owns product IDs, Token amounts, sort order, and development labels. The simulated purchase provider supplies callbacks; `MonetizationService` validates the product and callback; `WalletService` performs idempotent fulfillment.

## Permanent Products

| Product ID | Development label | Persistent result | One-time consumable bonus |
| --- | --- | --- | --- |
| `netbound_remove_ads` | DEV $2.99 | Remove Ads entitlement | None |
| `netbound_starter_pack` | DEV $5.99 | Remove Ads, Supporter cosmetics | 2,500 Coins + 300 Tokens |

Restore applies permanent ownership only. Starter Pack currency is never restored or granted twice.

## Initial Cosmetic Catalog

### Balls

| ID | Name | Rarity | Acquisition / Price |
| --- | --- | --- | --- |
| `ball_classic` | Classic | Common | Default |
| `ball_neon` | Neon | Rare | Complete Level 2 |
| `ball_fire` | Fire | Rare | 6 stars |
| `ball_ice` | Ice | Rare | Complete Level 6 |
| `ball_galaxy` | Galaxy | Epic | Complete Level 10 |
| `ball_champion` | Champion | Epic | 27 stars (gameplay unlock) |
| `ball_gold` | Gold | Legendary | 30 stars |
| `ball_supporter` | Supporter | Epic | Starter Pack |
| `ball_candy` | Candy Stripe | Common | 1,000 Coins |
| `ball_mint` | Mint Chip | Common | 1,800 Coins |
| `ball_watermelon` | Watermelon | Common | 2,200 Coins |
| `ball_sunset` | Sunset Pop | Rare | 4,000 Coins |
| `ball_checker` | Checkerboard | Rare | 5,500 Coins |
| `ball_cloud` | Cloud Nine | Epic | 9,000 Coins |
| `ball_comet` | Comet | Rare | 50 Tokens |
| `ball_lava` | Lava Core | Rare | 80 Tokens |
| `ball_prism` | Prism | Epic | 150 Tokens |
| `ball_void` | The Void | Legendary | 320 Tokens |

### Trails

| ID | Name | Rarity | Acquisition / Price |
| --- | --- | --- | --- |
| `trail_none` | None | Common | Default |
| `trail_blue` | Blue Streak | Rare | Complete Level 4 |
| `trail_flame` | Flame | Rare | 12 stars |
| `trail_spark` | Spark | Rare | Complete Level 8 |
| `trail_rainbow` | Rainbow | Epic | 24 stars |
| `trail_supporter` | Supporter Trail | Epic | Starter Pack |
| `trail_chalk` | Chalk Line | Common | 1,200 Coins |
| `trail_bubble` | Bubbles | Common | 2,000 Coins |
| `trail_streamers` | Paper Streamers | Rare | 4,500 Coins |
| `trail_comet` | Comet Tail | Rare | 6,500 Coins |
| `trail_pixel` | Pixel Dash | Epic | 140 Tokens |
| `trail_starfall` | Starfall | Legendary | 300 Tokens |

### Goal Effects

| ID | Name | Rarity | Acquisition / Price |
| --- | --- | --- | --- |
| `goal_classic` | Classic Flash | Common | Default |
| `goal_confetti` | Confetti | Rare | 18 stars |
| `goal_shockwave` | Shockwave | Legendary | 30 stars |
| `goal_supporter` | Supporter Burst | Epic | Starter Pack |
| `goal_ribbons` | Victory Ribbons | Common | 1,800 Coins |
| `goal_splash` | Color Splash | Rare | 5,000 Coins |
| `goal_fireworks` | Pocket Fireworks | Epic | 150 Tokens |
| `goal_portal` | Goal Portal | Legendary | 350 Tokens |

The launch catalog is `38` cosmetics: `18` balls, `12` trails, and `8` goal effects. Every entry has a stable ID, rarity, acquisition type, price/requirement, sort order, preview configuration, and gameplay visual mapping.

## Real Store Integration Points

Future platform adapters must preserve the current service boundary:

1. Replace simulated provider product metadata with verified platform products.
2. Pass platform transaction IDs to `MonetizationService`.
3. Validate receipts before wallet fulfillment.
4. Keep consumables out of Restore Purchases.
5. Restore permanent Remove Ads and Starter Pack ownership only.
6. Keep UI, progression, and gameplay independent from provider classes.

No real billing or ad code exists in this phase.
