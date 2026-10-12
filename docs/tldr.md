# Shaman Arena — TL;DR of findings

**Project**: Godot 4.6 (Forward Plus, Jolt) remake of the Warlock Brawl gameplay loop: knock enemies off a shrinking arena into lava; accumulated damage increases knockback; gold between rounds buys spells/passives.

## The addons (OctoD's "Godot Gameplay Systems", MIT, C++ GDExtensions)

GAS-*inspired*, not a port. Docs: OctoD's GitHub repos (USAGE.md for abilities, docs/ for attributes).

### godot-gameplay-abilities
Ability lifecycle only — no effects, no tags.

- **Ability** — scriptable `Resource` (blueprint of an ability)
- **AbilityContainer** — node that holds and runs abilities; attaches to any node
- **RuntimeAbility** — runtime instance created when an ability is added to a container

State machine: granted → active → duration_active → cooldown_active → ended, plus
**blocked** (stun/silence) and **revoked** (loadout swap / shop).

- Virtuals: `_can_be_activated` (conditions), `_should_*` (auto-behavior per frame),
  `_on_activate` / `_on_end` / `_on_grant` / `_on_revoke` / `_on_tick`, `_get_cooldown` / `_get_duration`
- Container API: `try_activate / try_block / try_end / try_grant / try_revoke`,
  `is_ability_*`, `add_ability`, `remove_ability`, `find_ability`, `get_runtime_abilities`
- Signals: `ability_activated`, `ability_granted`, `ability_revoked`, `ability_blocked`,
  `ability_unblocked`, `ability_ended`, `cooldown_start`, `cooldown_end`, ...
- `_on_tick` overrides the whole default duration/cooldown/per-frame logic — use with care

### godot_gameplay_attributes
Attributes + buffs, fully decoupled from the ability system.

- **AttributeContainer** — node; computes and exposes attribute values
- **AttributeSet** — defines which attributes a container has; supports derived attributes
  (computed from other attributes)
- **AttributeBuff** — transient or permanent; duration, stacking, uniqueness;
  `_applies_to` / `_operate` hooks can touch many attributes at once
- **AttributeOperation** — ADD / SUBTRACT / MULTIPLY / DIVIDE / SET
  (statics: `add`, `subtract`, `multiply`, `divide`, `percentage`, `forcefully_set_value`)
- Signals: `attribute_changed`, `buff_applied`, `buff_removed`, `buff_enqueued`,
  `buff_dequed`, `buff_time_elapsed` / `buff_time_updated`
- Damage pattern: a buff subtracting from Health; container ticks buff durations
  (manual ticking available via `manual_ticking` + `set_tick`)

There is also a separate `godot-gameplay-tags` repo (Rust) — not installed here.

## Current code (pre-rewrite)

- `scenes/player/player.gd` — `Unit` extends `CharacterBody2D`; movement, `cast_direction`,
  aim sprite turn smoothing; generic `StateMachine` with idle/move/cast/chanel/damaged/dead —
  cast, chanel, damaged, dead are empty stubs
- `resources/abilities/base_ability_resource.gd` — `extends Ability`; fake cast time via
  tween delay in `_on_activate`, custom `cast_spell()` hook; MAX_DISTANCE / DURATION /
  COOLDOWN / TYPE vars; Blink (instant teleport) and Fireball (spawns projectile scene)
- `scenes/abilities/fireball_scene.gd` — moves in a straight line; exported DAMAGE /
  KNOCKBACK exist but are unused; no collision, damage or knockback yet
- `resources/abilities/ability_handler.gd` + `ui/player/ability_button.gd` — buttons call
  `try_activate`, cooldown UI polls a Timer wired to `cooldown_start` / `ability_ended`
- `player.tscn` — AttributeContainer (MaxHealth, Health) + AbilityContainer (Blink only)

## Mapping Warlock mechanics onto the addons

| Warlock concept | Mapping |
| --- | --- |
| Spell cooldown | GGAS `cooldown_active` state (`_get_cooldown`) |
| Cast time / channel | GGAS `duration_active` state (`_get_duration`) |
| Stun / silence | `try_block(ability)` |
| Shop / loadout swap between rounds | `try_revoke` + `try_grant` (+ `add_ability`) |
| Damage points accumulated | Attribute (derived) incremented by a DamageBuff |
| Knockback strength | spells read target attribute via `get_attribute_value_by_name` |
| DoTs, temporary buffs | transient `AttributeBuff` with duration |
| Items (boots/rings) | derived attributes or permanent buffs |
| Health | Attribute + DamageBuff (SUBTRACT) |

## Not yet implemented

- Collision, damage, knockback for projectiles
- Damage-points → knockback-strength pipeline
- Arena shrink, lava, falling detection, elimination
- Rounds (FAA/teams), gold economy, shop UI (drag_and_drop addon already present for it)
- Cast/Chanel/Damaged/Dead state logic