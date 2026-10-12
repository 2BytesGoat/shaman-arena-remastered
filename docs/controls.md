# Shaman Arena — Controls (arcade-first)

Designed for an arcade cabinet: **one analog stick + one button per spell**, no twin-stick.
Desktop keyboard/gamepad bindings exist for development; the arcade panel overrides them later.

## The stick

| Context | Stick behavior |
| --- | --- |
| Free (no spell button held) | Movement (accel/decel with friction) |
| Spell button held (AIMED spell) | **Aim** — shaman locks position, velocity zeroed; stick drives `cast_direction`; aim sprite follows with turn-smoothing |
| Spell button held (INSTANT spell, held) | Same aim mode (re-aim before release) |
| While on cooldown | Spell button ignored (GGAS `cooldown_active` blocks activation) |

Deadzone handling: stick input below deadzone → keep **last nonzero direction**
(never snap aim to zero when returning the stick to center).

## Spell buttons (max 6 spells + 2 consumables per player)

| Gesture | Result |
| --- | --- |
| Press + hold on AIMED spell | Enter aim mode; stick steers aim; HUD button shows spell highlighted |
| Release (after hold) | Cast using current `cast_direction`; GGAS duration (cast delay) plays out; cooldown starts |
| Press + release < ~150ms (tap) on AIMED spell | Still counts as a cast — uses current facing direction |
| Press + release < ~150ms (tap) on INSTANT spell | Instant cast using **current facing** (e.g., Blink) |
| Press on CONSUMABLE slot | Use item (reserved — content later; consumable uses revoke/consume on activation) |
| Press while casting/windup | Queued? **No** — ignored for now (no input buffering in v1) |

- Hold duration has **no charge effect** — it is purely aiming/channel time.
- One physical button maps to one loadout slot; slots are 0–5 spells, 6–7 consumables.
- Loadout is chosen pre-match (spell selection screen, M3).

## Match flow

1. Menu/title → spell selection (stick-driven focus, per player) → both ready gates the match
2. Match runs on the shrinking arena until elimination → win screen → restart

## HUD (non-interactive on cabinet)

- Per-slot cooldown indicators (GGAS `cooldown_start`/`cooldown_end` signals), icon + fill
- Health/damage accumulation display (from M5.5, per-player)
- **Version label** fixed bottom-left of the game viewport (from `application/config/version`)

## Dev fallback bindings (bound in `project.godot`, dev-only)

| Action group | P0 keyboard | P0 pad 0 | P1 keyboard | P1 pad 1 |
| --- | --- | --- | --- | --- |
| Move | WASD | left stick | arrows | left stick |
| Spells 0–5 | `1` `2` `3` `4` `5` `6` | A, B, X, Y, LB, RB | `U` `I` `O` `P` `L` `K` | A, B, X, Y, LB, RB |
| Consumables 0–1 | `Q` / `E` | RT / LT (triggers) | `J` / `H` | RT / LT (triggers) |
| Taunt | `Z` | dpad-down | `X` | dpad-down |
| UI nav | WASD / dpad | dpad | arrows / dpad | dpad |
| UI accept / cancel | `Enter` / `Esc` | A / B | `Enter` / `Esc` | A / B |

- These exist only for editor testing; the arcade layout (single stick + 8 buttons + start)
  gets defined and mapped when the cabinet spec is finalized.

## Open items

- Exact arcade panel layout (which physical button = which slot)
- Any input buffering for cast during windup (deferred, v1 ignores)
- Player 3+ expansion (bindings already use per-player prefixes; layers support player_0..3)