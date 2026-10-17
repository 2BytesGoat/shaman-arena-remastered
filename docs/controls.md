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
always trails the stick. Spells spawn from the aim icon's drawn position (offset included),
so the muzzle always matches the indicator; the stick only steers the flight direction.

## Spell buttons (max 6 spells per player)

| Gesture | Result |
| --- | --- |
| Press + hold on AIMED spell | Enter aim mode; stick steers aim; HUD button shows spell highlighted |
| Release (after hold) | Cast using current `cast_direction`; GGAS duration (cast delay) plays out; cooldown starts |
| Press + release < ~150ms (tap) on AIMED spell | Still counts as a cast — uses current facing direction |
| Press on INSTANT spell | Fires immediately using **current facing** (Blink; Smoke ignores direction); no aim, release does nothing |
| Press the same spell during its cast delay | Ignored — the released cast commits and fires (D-016) |
| Taking a hit during a cast delay | Aborts the cast — unless the spell is **Uninterruptible** (Smoke); death always aborts |

- Hold duration has **no charge effect** — it is purely aiming/channel time.
- One physical button maps to one pool slot; a player holds up to 6 spells (class basics
  included).
- The pool starts from the class basics and is drafted on the spell draft screen (below).

## Spell draft (match start + rounds)

- Players draft **one after the other on a single screen**: player 1's panel first, then
  player 2's. The header names the active drafter; the other panel is hidden and ignores
  input.
- The active panel offers **5 random spells** as a card row — never a duplicate, and never
  a spell the player already owns (Rounds-style, D-011).
- Stick drives the focus cursor across the cards (left/right only); accept **commits the
  focused card** to the player's pool. There is no un-pick and no re-roll.
- Both seats play the **Wizard**: Fireball and Smoke are basic spells seeded into the pool
  before the first draft, so no hand — match start or per-death — ever offers them (D-013).
  The match-start hand is the 5 spells left in the catalogue.
- A committed pick readies that player; when all players are ready the match starts and
  the selection layer closes. A match starts with **3 spells per player** (2 basics + 1
  drafted).
- When a round ends (a player dies), the **KO plays out first**: the world drops into slow
  motion for a moment and the loser's death clip finishes before the selection screen
  appears (D-014). Then the **loser drafts one more spell** the same way — fresh offers,
  their whole pool excluded — and the next round starts as soon as it is committed. The
  pool caps at 6 spells including the basics, so once it is full later loss-drafts are
  skipped and the round just resumes.
- Between rounds both players respawn at their starting spots with full health and **every
  spell off cooldown** (D-015); spell pools are kept.
- Gameplay is frozen while a draft is up: units ignore movement and cast input, and only
  the current drafter's panel accepts input, so nobody can act behind the card screen.
- The strip under the cards shows the 6 pool slots: the basics already in place, then the
  drafted cards filling the rest.

## Match flow

1. Spell draft: player 1 commits a card, then player 2 (one panel at a time, stick-driven
   focus per player); all players ready → match starts with the class basics plus their
   drafted spell
2. A death ends the round: the survivor scores it, the KO plays in slow motion while the
   death clip finishes, then the loser drafts one more card (same panel flow, gameplay
   stays frozen for everyone)
3. Committed card → both players respawn at their spawn points, full health, every spell
   off cooldown, next round
4. First to 5 round wins → the final KO plays the same slow-motion beat → match-over
   banner ("PLAYER X WINS x-y") → accept/button restarts from the draft

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
| UI nav | WASD | dpad / left stick | arrows | dpad / left stick |
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
  by the class basics plus draft picks. `MatchManager.skip_selection` (main scene) applies
  a dev default loadout for fast editor testing.

## Open items

- Exact arcade panel layout (which physical button = which slot)
- Any input buffering for cast during windup (deferred, v1 ignores)
- Pressing a *different* spell during a cast delay starts aiming it while the in-flight cast
  still lands (pre-existing; parked, revisit with M4)
- Dev single-keyboard: both players' UI accept share `Enter` (cancel `Esc`); drafting is
  sequential, so one keyboard can drive both turns — pads are the supported way for two
  players on one machine
- Reserved item buttons: the `player_N_consumable_0/1` actions still exist but have no
  gameplay until the item work lands (D-011)
- Player 3+ expansion (bindings already use per-player prefixes; layers support player_0..3)