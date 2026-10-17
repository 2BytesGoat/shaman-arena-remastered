# Shaman Arena — Controls (arcade-first)

Designed for an arcade cabinet: **one analog stick + one button per spell**, no twin-stick.
Desktop keyboard/gamepad bindings exist for development; the arcade panel overrides them later.

## The stick

| Context | Stick behavior |
| --- | --- |
| Free (no spell button held) | Movement (accel/decel with friction); the aim indicator also keeps following the stick, so a held cast starts already aligned |
| Spell button held (AIMED spell) | **Aim** — shaman locks position, velocity zeroed; stick drives `cast_direction`; aim sprite follows with turn-smoothing |
| Spell button pressed (INSTANT spell) | **No aim phase** — the spell already fired on press; holding/releasing does nothing |
| While on cooldown | Spell button ignored (GGAS `cooldown_active` blocks activation) |

Deadzone handling: stick input below deadzone → keep **last nonzero direction**
(never snap aim to zero when returning the stick to center).

Cast direction is refreshed every frame while alive: a released aimed cast keeps steering
with the stick through its cast delay (deliberate — windup jukes), and the aim indicator
always trails the stick.

## Spell buttons (max 6 spells per player)

| Gesture | Result |
| --- | --- |
| Press + hold on AIMED spell | Enter aim mode; stick steers aim; HUD button shows spell highlighted |
| Release (after hold) | Cast using current `cast_direction`; GGAS duration (cast delay) plays out; cooldown starts |
| Press + release < ~150ms (tap) on AIMED spell | Still counts as a cast — uses current facing direction |
| Press on INSTANT spell | Fires immediately using **current facing** (Blink; Smoke ignores direction); no aim, release does nothing |
| Press the same spell during its cast delay | **Aborts the cast** — free, no cooldown; press again to cast anew (D-004) |
| Taking a hit during a cast delay | Aborts the cast — unless the spell is **Uninterruptible** (Smoke); death always aborts |

- Hold duration has **no charge effect** — it is purely aiming/channel time.
- One physical button maps to one pool slot; a player holds up to 6 spells.
- The pool is drafted on the pre-match draft screen (below).

## Spell draft (pre-match)

- Both players draft at the same time on one screen (one panel per player, stacked).
- Each panel offers **5 random spells** as a card row — never a duplicate, and never a
  spell the player already owns (Rounds-style, D-011).
- Stick drives the focus cursor across the cards (left/right only); accept **commits the
  focused card** to the player's pool. There is no un-pick and no re-roll.
- A committed pick readies that player; when all players are ready the match starts and
  the panel locks. A match therefore starts with **1 spell per player** — later deaths
  draft more cards (rounds work, not wired yet).
- The strip under the cards shows the 6 pool slots filling up as drafts land.

## Match flow

1. Spell draft: both players commit one card each (stick-driven focus, per player);
   all players ready → match starts with their drafted spell
2. Match runs until elimination → match-over banner (placeholder until M5 replaces it with
   the real win screen) → accept/button restarts

## HUD (non-interactive on cabinet)

- Per-slot cooldown indicators (GGAS `cooldown_start`/`cooldown_end` signals), icon + fill
- One button per owned spell (starts at 1, grows with the pool — rebuilt after every
  draft); consumable/item slots are not part of the game yet
- Player 1 HUD sits bottom-left, Player 2 bottom-right
- Health/damage accumulation display (from M5.5, per-player)
- **Version label** fixed bottom-left of the game viewport (from `application/config/version`)

## Dev fallback bindings (bound in `project.godot`, dev-only)

| Action group | P0 keyboard | P0 pad 0 | P1 keyboard | P1 pad 1 |
| --- | --- | --- | --- | --- |
| Move | ↑ ↓ ← → | left stick | WASD | left stick |
| Spells 0–5 | `1` `2` `3` `4` `5` `6` | A, B, X, Y, LB, RB | `U` `I` `O` `P` `L` `K` | A, B, X, Y, LB, RB |
| Taunt | `Z` | dpad-down | `X` | dpad-down |
| UI nav | WASD / dpad | dpad | arrows / dpad | dpad |
| UI accept / cancel | `Enter` / `Esc` | A / B | `Enter` / `Esc` | A / B |

- These exist only for editor testing; the arcade layout (single stick + 6 spell buttons +
  start) gets defined and mapped when the cabinet spec is finalized.
- `player_0` is the owner's dev seat: arrows to move + `1`–`6` to cast (owner decision, 2026-10-14).
- **Keyboard ghosting**: `player_0`'s arrows + `1`–`6` is a 3-key combo; some membrane
  keyboards drop the up/down key while Right + a spell are held, so right diagonals can't
  aim while left-side combos work (confirmed on the owner's keyboard, 2026-10-14). Use a
  pad for faithful spell testing — the arcade panel is unaffected.
- `player_1` keyboard bindings are **throwaway** — the owner rarely controls player 2, so no
  parity or maintenance promise for them (owner decision, 2026-10-14).
- The M1 7th dev slot (`7` / `M`) is retired: a player's pool holds up to 6 spells, filled
  by the pre-match draft. `MatchManager.skip_selection` (main scene) applies a dev default
  loadout for fast editor testing.

## Open items

- Exact arcade panel layout (which physical button = which slot)
- Any input buffering for cast during windup (deferred, v1 ignores)
- Pressing a *different* spell during a cast delay starts aiming it while the in-flight cast
  still lands (pre-existing; parked, revisit with M4)
- Dev single-keyboard: both players' UI accept share `Enter` (cancel `Esc`), so a keyboard
  accept commits a pick on both panels at once — pads are the supported way to draft for
  two players on one machine
- Reserved item buttons: the `player_N_consumable_0/1` actions still exist but have no
  gameplay until the item work lands (D-011)
- Player 3+ expansion (bindings already use per-player prefixes; layers support player_0..3)