# Decisions

Named design decisions, with context, so later milestones don't undo them by accident.
Referenced from `plan.md` as `D-001`, `D-002`, …

## D-001 — Attacker-applies hit pipeline ("the attack deals the damage")

- **Status:** accepted (M1)
- **Date:** 2026-10-13

**Context.** The POC applied damage victim-side: every Unit's Hurtbox listened for
`area_entered`, read `DAMAGE`/`KNOCKBACK` off whatever area touched it (duck typing via
`area.get()`), then called its own `take_hit`. "Effect" scenes doubled as damaging
hitboxes, so damage values lived on animation scenes and the attacker never knew it hit.

**Decision.** Damage is applied by the attacker — the moving or lingering Area2D. Spell
and effect areas detect the victim's Hurtbox and call `victim.take_hit(...)` themselves
through `HitArea.apply(attacker, target, source, damage, knockback)`. The Hurtbox keeps
only its collision layer (the thing attacks detect) and holds no damage logic. Effect
scenes stay visual + hitbox in one node (POC parity), but damage ownership is
attacker-side.

**Consequences.**

- One place decides a hit happened, so attacker-side reactions (hit procs, counting;
  M4+ and the M5.5 `DamagePoints` work) have a home.
- No duck typing: only a real `Unit` ever reaches `take_hit`.
- Attacking areas must mask the hurtbox layer (1); the hurtbox no longer monitors
  anything and is no longer wired to a signal.
- POC parity kept deliberately, including the direct-contact double application
  (Fireball 10 + explosion 5/KB 175, Boomerang 7 + effect 7/KB 150), smoke spawning at the
  caster's position after its 1.2 s cast delay, and the meteor telegraph's 0/KB 100 push.
  Don't "fix" these without a new decision.
- Verified by an A/B headless probe (identical damage/knockback/lifetime traces before and
  after, modulo 1 physics frame).

**References.** `godot/src/abilities/hit_area.gd`,
`godot/src/abilities/spells/spell_scene.gd`, `godot/src/abilities/effects/effect.gd`,
`godot/src/player/player.gd`.

## D-002 — Spell naming & structure vocabulary (WC3/LoL model)

- **Status:** accepted (M1)
- **Date:** 2026-10-13

**Context.** M4 grows the spell list to WC3/League-like ground (channels, auras, toggles,
statuses), but the M1 names didn't scale: `DamageBuff` reads as "damage-up" while it
actually deals damage; `SpellType.SMOKE` is a spell name inside a category enum;
`SpellScene` mixed projectile movement with static fields and walls. The full vocabulary
is in `spells.md`.

**Decided**

- **Buff/Debuff are reserved for *lasting* statuses** (WC3/LoL meaning); an instant hit is
  plain damage. `DamageBuff` → **`HealthDamage`** (Health−N via `AttributeBuff`);
  `InitializeAttributesBuff` → **`InitializeAttributes`** (an initializer, not a status).
- **Four axes for every spell**: Cast / Delivery / Impact / Status — each value has a
  fixed home in code (`CAST_MODE`, `SpellScene` subclasses, `Effect` scenes, statuses).
- **Second-member rule**: archetype base classes are extracted only when the second spell
  of that archetype exists. Projectile qualified immediately (4 members) →
  **`ProjectileSpell` extracted**; Field (Smoke) and Wall (AniviaWall) wait.
- **Reserved vocabulary is reused, never synonym-drifted** (Channel/Toggle/Aura/Passive,
  Field/Aura/Beam/Summon, Hit/Explosion/Push/Pull/Chain, `...Buff`/`...Debuff`).
- **`SpellType` is a category, not a spell**: `OFFENSIVE/DEFENSIVE/UTILITY`; `SMOKE`
  removed, Smoke is `DEFENSIVE`.
- **Catalogue stays current** — every new spell adds a row to `spells.md`.

**Not doing**

- Renaming `MeteorIncoming` (single telegraph — second-member rule), and splitting out
  `src/attributes/status/` (single status so far).

**Tradeoff.** WC3 calls negative statuses "Buffs" too; we follow LoL's Buff/Debuff split
because it reads unambiguously to newcomers, which is the stated naming priority.

**References.** `docs/spells.md`, `godot/src/abilities/spells/projectile_spell.gd`,
`godot/src/attributes/health_damage.gd`.

## D-003 — Basic attack: per-shaman ability, loadout-picked, empowerable

- **Status:** accepted (documentation; implementation not scheduled yet)
- **Date:** 2026-10-14

**Context.** A 7-champion League corpus audit (`python/out/audit.md`) showed 4 of 7
champions depend on basic-attack modifiers (Udyr's stances, Kled W, Riven P, Shaco P,
Jhin P) while the game has no basic-attack system at all — no attack timer, weapon, or
on-attack event. Options weighed: a universal 7th button (breaks the 6 spells +
2 consumables = 8-button panel), an auto-attack with no button (adds a sustained-DPS
layer the spell-only arena never had), redesigning attack-modifier kits into direct
effects, or making the attack an ordinary ability.

**Decision.** The basic attack is a per-character ability
(`<shaman>_attack_ability.tres`) — melee or ranged, `Instant` (tap, fires in facing) or
`Aimed` (hold/release) by character design. It is picked in the loadout like any other
spell (one of the 6 slots), so `controls.md` needs no new button or input rule.
Empowerments are `<What>Buff`s whose stacks are the remaining empowered attacks,
consumed at the attack's cast site — no generic trigger system is needed for this
family.

**Consequences.**

- `controls.md` unchanged; the HUD treats the attack as a normal slot.
- Selection (M3) must signal that empower spells do nothing without the Attack pick
  (grey-out + hint).
- Attacks flow through D-001 and feed `DamagePoints`, so they interact with M5.5
  knockback scaling — decide at tuning time whether attack hits count fully, partially,
  or not at all.
- No new spell-scene archetype yet: the melee strike scene waits for its second member
  (second-member rule) before a base class is extracted (a slash spell is the likely
  second: Broken-Wings-style).
- Where empower charges live (Unit-side state vs querying `AttributeContainer`) is an
  implementation choice; the documented vocabulary stays "Buff with stacks" regardless.

**Not doing.** Auto-attack without a button; a universal always-equipped attack button;
separately pickable melee/ranged variants (melee vs ranged is character identity).

**References.** `docs/spells.md` (Core words: Attack), `python/out/audit.md`,
`godot/src/abilities/base_ability.gd`, `godot/src/player/player.gd`.

## D-004 — Cast abort ("cancel") rules

- **Status:** accepted (M2)
- **Date:** 2026-10-14

**Context.** A released cast could not be taken back: `cooldown_start` (which spawns the
spell) fires at the end of the GGAS duration, and nothing interrupted it — not hits, not
even death (a corpse would still fire its pending spell). LoL-style move-to-cancel was
considered, but in this single-stick scheme the stick already steers the cast during the
delay (owner change), so "movement" cannot be told apart from steering without an
angle-threshold heuristic.

**Decision.** Three abort paths, all **free** (no cooldown — a cancelled cast is as if it
was never cast):

- **Re-press** the same spell button during its cast delay → aborts. Uses
  `AbilityContainer.try_end` (probed: fires `ability_ended` without `cooldown_start`,
  leaves no cooldown, immediately re-activatable). Cancel-only — no auto re-aim, so a
  quick release after the abort cannot chain into a tap-cast.
- **Taking a hit** during the cast delay aborts it too — unless the spell is flagged
  `UNINTERRUPTIBLE` (Smoke), which ignores hits and re-presses; only death stops it.
- **Death** aborts every pending cast (`_die`, flag ignored; `_on_spell_cooldown_start`
  also guards `player_dead`).

The stick never cancels; it only steers.

**Consequences.**

- Mashing a spell button aborts your own cast (double-tap = cancel) — accepted trade-off.
- "Uninterruptible" joins the `spells.md` vocabulary; future spells must choose the flag
  deliberately.
- Free aborts make feints cheap by design; commitment comes from letting the delay
  finish, not from cooldown.

**Not doing.** Stick-flick cancel gesture; abort on a *different* spell's press (parked —
it currently starts aiming the new spell while the old cast still lands); any cooldown
cost for aborts.

**References.** `godot/src/player/player.gd`, `godot/src/abilities/base_ability.gd`,
`godot/tests/m2/test_cast_abort.gd`.
