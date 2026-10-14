# Shaman Arena — Controls (arcade-first)

Designed for an arcade cabinet: **one analog stick + one button per spell**, no twin-stick.
Desktop keyboard/gamepad bindings exist for development; the arcade panel overrides them later.

## The stick

| Context | Stick behavior |
| --- | --- |
| Free (no spell button held) | Movement (accel/decel with friction); the aim indicator also keeps following the stick, so a held cast starts already aligned |
| Spell button held (AIMED spell) | **Aim** — shaman locks position, velocity zeroed; stick drives `cast_direction`; aim sprite follows with turn-smoothing |
| Spell button held (INSTANT spell, held) | Same aim mode (re-aim before release) |
| While on cooldown | Spell button ignored (GGAS `cooldown_active` blocks activation) |

Deadzone handling: stick input below deadzone → keep **last nonzero direction**
(never snap aim to zero when returning the stick to center).

Cast direction is refreshed every frame while alive: a released cast keeps steering with the
stick through its cast delay (deliberate — windup jukes), and the aim indicator always trails
the stick.

## Spell buttons (max 6 spells + 2 consumables per player)

| Gesture | Result |
| --- | --- |
| Press + hold on AIMED spell | Enter aim mode; stick steers aim; HUD button shows spell highlighted |
| Release (after hold) | Cast using current `cast_direction`; GGAS duration (cast delay) plays out; cooldown starts |
| Press + release < ~150ms (tap) on AIMED spell | Still counts as a cast — uses current facing direction |
| Press + release < ~150ms (tap) on INSTANT spell | Instant cast using **current facing** (e.g., Blink) |
| Press on CONSUMABLE slot | Use item (reserved — content later; consumable uses revoke/consume on activation) |
| Press the same spell during its cast delay | **Aborts the cast** — free, no cooldown; press again to aim anew (D-004) |
| Taking a hit during a cast delay | Aborts the cast — unless the spell is **Uninterruptible** (Smoke); death always aborts |

- Hold duration has **no charge effect** — it is purely aiming/channel time.
- One physical button maps to one loadout slot; slots are 0–5 spells, 6–7 consumables.
- Loadout is chosen on the pre-match selection screen (below).

## Spell selection (pre-match)

- Both players pick at the same time on one screen (one panel per player, stacked).
- Stick drives the focus cursor over the spell grid; accept toggles the focused spell into
  the next free slot (accept again un-picks it; cancel removes the last pick).
- Picking the **6th** spell readies that player (POC parity — no separate ready button);
  when all players are ready the match starts and the panel locks.
- Loadout is exactly 6 spells (slots 0–5) + 2 reserved consumable slots (6–7, empty for
  now — see M4).
- **Uninterruptible** spells (Smoke) ignore hits and re-presses once released; only death
  stops them (D-004). The stick never cancels a cast — it only steers.
- Mashing a spell button therefore aborts your own cast (double-tap = cancel) — accepted
  trade-off for the free re-press abort.

## Match flow

1. Selection screen: both players pick their 6 spells (stick-driven focus, per player);
   all players ready → match starts
2. Match runs until elimination → match-over banner (placeholder until M5 replaces it with
   the real win screen) → accept/button restarts

## HUD (non-interactive on cabinet)

- Per-slot cooldown indicators (GGAS `cooldown_start`/`cooldown_end` signals), icon + fill
- 8 slots per player: 6 spells + 2 empty consumable placeholders (rebuilt after selection)
- Player 1 HUD sits bottom-left, Player 2 bottom-right
- Health/damage accumulation display (from M5.5, per-player)
- **Version label** fixed bottom-left of the game viewport (from `application/config/version`)

## Dev fallback bindings (bound in `project.godot`, dev-only)

| Action group | P0 keyboard | P0 pad 0 | P1 keyboard | P1 pad 1 |
| --- | --- | --- | --- | --- |
| Move | ↑ ↓ ← → | left stick | WASD | left stick |
| Spells 0–5 | `1` `2` `3` `4` `5` `6` | A, B, X, Y, LB, RB | `U` `I` `O` `P` `L` `K` | A, B, X, Y, LB, RB |
| Consumables 0–1 | `Q` / `E` | RT / LT (triggers) | `J` / `H` | RT / LT (triggers) |
| Taunt | `Z` | dpad-down | `X` | dpad-down |
| UI nav | WASD / dpad | dpad | arrows / dpad | dpad |
| UI accept / cancel | `Enter` / `Esc` | A / B | `Enter` / `Esc` | A / B |

- These exist only for editor testing; the arcade layout (single stick + 8 buttons + start)
  gets defined and mapped when the cabinet spec is finalized.
- `player_0` is the owner's dev seat: arrows to move + `1`–`6` to cast (owner decision, 2026-10-14).
- `player_1` keyboard bindings are **throwaway** — the owner rarely controls player 2, so no
  parity or maintenance promise for them (owner decision, 2026-10-14).
- The M1 7th dev slot (`7` / `M`) is retired: the loadout is exactly 6 spells +
  2 consumables, enforced by the M3 selection flow. `MatchManager.skip_selection` (main
  scene) applies a dev default loadout for fast editor testing.

## Open items

- Exact arcade panel layout (which physical button = which slot)
- Any input buffering for cast during windup (deferred, v1 ignores)
- Pressing a *different* spell during a cast delay starts aiming it while the in-flight cast
  still lands (pre-existing; parked, revisit with M4)
- Dev single-keyboard: both players' UI accept share `Enter` (cancel `Esc`), so keyboard
  selection toggles both panels at once — pads are the supported way to pick for two
  players on one machine
- Player 3+ expansion (bindings already use per-player prefixes; layers support player_0..3)