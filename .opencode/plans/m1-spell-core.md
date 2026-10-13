# M1 — Spell logic core + 6 spells (v0.1.0) — execution plan

Approved decisions (user, 2026-10-13):

- Cast completion hook: `AbilityContainer.cooldown_start` (fires at end of GGAS duration / synchronously for instant casts). Correct the `_on_end` wording in `docs/plan.md`.
- Dev loadout: all 7 abilities (6 M1 spells + Blink) on both players, mapped to keyboard numbers 1–7 for now (`player_0_spell_0..6`; P1 gets a 7th dev key). UI/limits fixed later.
- Knockback: flat impulse + brief input lock (Damaged state, ~0.2 s).
- Delivery: user asked to just commit; no PR workflow from the agent. NOTE: no milestone branch exists — only `main`. Confirm branch at commit time (see Open item).

## Repo state

- Remastered on `main` = Phase 0 done (`v0.0.1`). Skeleton: Blink+Fireball GGAS abilities, clickable Timer-polling HUD, stub states, no collision/hurtbox/damage.
- POC at `../Shamans` (all spell/effect scenes + values read).
- Installed GGAS = 1.0.0rc1-era build (verified against upstream source): lifecycle activate → duration (windup) → cooldown → ended; `_on_end` fires after cooldown; `cooldown_start` fires at end of windup and synchronously when duration == 0.
- Assets already copied to `godot/assets/` (spells, effects, UI icons, terrain + `.import`s). No scripts/scenes written yet — plan mode blocked edits after the copy.

## Files

Core:

- `godot/src/common/utils.gd` — add `instantiate_object_in_scene(scene, pos)` (POC helper).
- `godot/src/common/source_filter.gd` — `class_name SourceFilter`; static `ignores(source, area)` (own hurtbox via parent check, own Spell/Explosion via `source` match).
- `godot/src/abilities/base_spell.gd` — `class_name BaseSpell extends Ability`; `SpellType`, `CastMode {INSTANT, AIMED}`, exports `ICON/TYPE/CAST_MODE/CAST_DELAY/COOLDOWN/SPELL_SCENE`; `_get_duration`→CAST_DELAY, `_get_cooldown`→COOLDOWN; `cast(unit, direction)` spawns scene at `unit.spell_spawn_position(direction)`.
- `godot/src/abilities/blink_spell.gd` — `class_name BlinkSpell extends BaseSpell`; overrides `cast` (instant teleport, MAX_DISTANCE 300).
- `godot/src/spells/spell_scene.gd` — `class_name SpellScene extends Area2D`; `MAX_SPEED/KNOCKBACK/DAMAGE/on_hit_effect/velocity_curve`, `source: Unit`, `cast_direction`; `sample_time()`, `speed_at(t)` (testable), `_physics_process` move, `_on_move` hook, `_on_timer_timeout`/`_on_area_entered` → `_on_hit` (spawn effect + free, source-immunity).
- `godot/src/effects/effect.gd` — `class_name Effect extends Area2D`; `KNOCKBACK/DAMAGE/source`; `_on_explosion_effect_animation_finished` frees.
- `godot/src/attributes/attribute_names.gd`, `damage_buff.gd`, `initialize_attributes_buff.gd` (AttributeBuff SUBTRACT / forcefully set MaxHealth+Health).

Spells (scripts + ported POC scenes, values from POC `.tscn`):

- `src/spells/{fireball,boomerang,meteor,smoke,teleport,anivia_wall}.gd/.tscn`, `boomerang_speed_curve.tres`.
- Values: fireball 0.3/300/KB0/10/3 s + grow; boomerang 0.2/350/0/7/7 s (curve 1→−1.5); meteor 0.15/900/9 s → MeteorIncoming 1.25 s → MeteorExplosion 250/15; smoke self AoE r96 1.2 s KB200/10/5 s; teleport 0.1/600/6 s (blink on expiry); wall layer 64 mask 31, 0.2 s, 13 s cd, 4 s life; Blink INSTANT 5 s cd.

Effects (POC ports, audio removed — M6): `effect.tscn`, `explosion_effect.tscn`, `boomerang_effect.tscn`, `push_effect.tscn`, `teleport_effect.tscn`, `meteor_incoming.gd/.tscn` (`Meteor` export → timer spawns strike), `meteor_explosion.tscn`.

Unit/UI:

- `src/player/player.gd` (`Unit`): movement in `_physics_process` (POC tuning 140/345/690), aim sprite smoothing, `spell_spawn_position`, `facing_direction`, `update_cast_direction`, `try_cast`, press detection on `player_X_spell_0..6` (cooldown/active gated), hurtbox `area_entered` → `take_hit`, `_on_attribute_changed` → `is_lethal` → Dead + `player_died`, `_on_spell_cooldown_start` → `BaseSpell.cast(self, cast_direction)`.
- `src/player/states/aim_state.gd` (`is_tap < 0.15 s`), `damaged_state.gd` (0.2 s input lock), `idle_state.gd`/`move_state.gd` transitions only (movement moved to Unit); delete `channel_state.gd`.
- `src/player/player.tscn`: + CollisionShape2D (20×20, pos 0,6), + Hurtbox Area2D (layer 1, mask 48), states Aim/Damaged/Dead (+Cast stub), 7 ability `.tres` sub-resources, signals wired; HUD buttons built at runtime.
- `src/abilities/{blink,fireball,boomerang,meteor,smoke,teleport,anivia_wall}_spell.tres`.
- `src/abilities/ability_handler.gd` + `src/ui/ability_button.gd/.tscn`: icon + cooldown fill driven by `cooldown_start`/`cooldown_end` (+ `ability_ended` reset; rc1 may skip `cooldown_end` when it lands exactly on 0).
- `main.tscn`: two players for hit testing.
- Delete: `base_ability_resource.gd`, `blink_ability.gd`, `fireball_ability.gd`, `base_ability_scene.gd`, `fireball_scene.gd/.tscn`, `channel_state.gd`; rework rather than keep.

Input/docs/config:

- `project.godot`: add `player_0_spell_6` (key 7), `player_1_spell_6` (dev key); bump `config/version` → `0.1.0`.
- `docs/controls.md`: note M1 dev 7th-slot bindings.
- `docs/plan.md`: tick M1 checkboxes, fix `_on_end` wording to `cooldown_start`.

Tests (`godot/tests/m1/`):

- `test_damage_buff.gd` (subtract Health, lethal predicate).
- `test_ability_lifecycle.gd` (duration→cooldown→ended signals, cooldown gating, synchronous `cooldown_start` for duration 0).
- `test_spell_scene.gd` (`speed_at` at 0.5/1.0, source-immunity predicate).
- `test_cast_input.gd` (tap/hold threshold).
- Update `tests/phase0/test_phase0.gd` version assertion to `0.1.0`.

Verification:

- `godot --headless --import .` then `godot --headless -s addons/gdUnit4/bin/GdUnitCmdTool.gd -a tests -c --ignoreHeadlessMode -rd tests/reports` (binary from opencode.json).
- Smoke-run `main.tscn` headless for parse errors.
- Manual (user): tap Blink uses facing; hold-aim locks movement; HUD ticks; six spells match POC.

## Open item

No branch other than `main` exists (`git reflog` shows only main). User said "i already made a new branch". Confirm at commit time whether to commit on main or create a milestone branch.
