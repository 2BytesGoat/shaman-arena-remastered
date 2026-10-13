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
