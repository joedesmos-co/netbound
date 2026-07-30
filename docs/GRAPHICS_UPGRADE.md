# Netbound Graphics Upgrade

Date: 2026-07-29
Scope: world-aware environment presentation without gameplay changes

## Goals

- Make Training Yard, Street Arcade, and Stadium Showdown visually distinct.
- Improve lighting, skies, nets, materials, and backdrop depth.
- Keep mobile budgets bounded and quality tiers presentation-only.

## Systems Touched

- `scripts/presentation/level_visual_polish.gd`
- `scripts/levels/world_catalog.gd`
- Course art remains `scripts/presentation/arcade_course_art.gd`

## Lighting

- Filmic tonemap with gentle per-world exposure.
- Soft directional shadows with world-specific sun angles.
- Higher ambient fill so blacks stay readable on OLED.
- Goal frames remain white with restrained emission; celebration still flashes green.

## Skies And Backgrounds

- Training Yard: bright practice sky, distant fence, two banners, sideline cones.
- Street Arcade: warmer/dusk court skies, one wall stripe, low court rails.
- Stadium Showdown: deeper arena sky, side seating wings, two flags, wide floodlights.

All backdrop pieces are visual-only and disabled on Low when decorative geometry is off.
Obstacle faces were decluttered in `docs/VISUAL_DECLUTTER_AUDIT.md` without changing colliders.

## Materials

Shared StandardMaterial3D language per world:

- Field greens with readable chalk lines
- Coral/navy training equipment through course art
- Higher-alpha nets for side-entry readability
- Metal/canvas/rubber roughness splits preserved by archetype

## Quality Scaling

| Tier | Decorative deck | Contact shadow | Dynamic shadows | Course detail |
| --- | --- | --- | --- | --- |
| Low | off | off | off | essential faces only |
| Medium | on | on | off | essential + limited detail |
| High | on | on | on | full detail |

Gameplay signatures remain identical across tiers.

## Verification Focus

Representative levels: 01, 10, 11, 20, 21, 25, 30
Checks: collider alignment, white frames, net readability, node budgets, no per-frame material allocation.
