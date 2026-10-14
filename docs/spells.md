---
title: Spells — Naming & Structure
tags: [godot, gameplay, spells, abilities, naming, conventions]
related:
  - "[[plan]]"
  - "[[decisions]]"
  - "[[controls]]"
search_terms: [spells, abilities, naming, convention, buff, debuff, aura, channel, toggle, projectile, field, wall, effect, health damage, attack, basic attack, restore, heal, warcraft, league]
---

# Spells — Naming & Structure

The vocabulary and structure for everything a shaman casts. The mental model is Warcraft
III's abilities/buffs plus League of Legends' ability/status vocabulary, filtered for
readability first: a newcomer should understand a call site without knowing the lore.
Decisions behind this are recorded in [[decisions]] (D-002).

## Core words

- **Ability** — the castable definition: icon, cast mode, cast delay, cooldown, and the
  spell scene it spawns. A GGAS resource (`BaseAbility` + `*_ability.tres`).
- **Attack** — a shaman's basic strike. Per-character (melee or ranged, `Instant` or
  `Aimed` by design), picked in the loadout like any other spell, and the host for
  on-hit empowerments (D-003).
- **Spell** — the world object an ability spawns (projectile, field, wall…). Lives in
  `src/abilities/spells/`, base class `SpellScene`.
- **Effect** — an impact or telegraph scene: visuals first, doubles as a hitbox per
  D-001. Lives in `src/abilities/effects/`, base class `Effect`.
- **Damage** — an instant health loss. **Not** a buff or debuff; applied via
  `HealthDamage`.
- **Restore** — an instant health gain, the counterpart of Damage. **Not** a buff or
  debuff; applied via `HealthRestore`.
- **Buff / Debuff** — a *lasting* status attached to a unit (WC3/LoL meaning): it helps
  or hinders. Duration and stacks are configuration, never part of the name.
- **Crowd control (CC)** — a debuff that removes control (stun, root, silence…). Still
  named `...Debuff`.
- **Uninterruptible** — a cast that cannot be aborted: hits and spell-button re-presses do
  not stop it; only death does. `BaseAbility.UNINTERRUPTIBLE` (currently Smoke only, D-004).

## The four axes

Every spell is a combination of four independent axes:

| Axis | Values | Code home |
|---|---|---|
| **Cast** | Instant, Aimed, Unit, Channel, Toggle, Aura, Autocast, Passive | `BaseAbility.CAST_MODE` (Instant/Aimed implemented) |
| **Delivery** | Self, Projectile, Field, Wall, Aura, Beam, Summon | `SpellScene` subclasses |
| **Impact** | Hit (damage), Explosion, Push, Pull, Chain, None | `Effect` scenes via `HitArea.apply` (D-001) |
| **Status** | none, Buff, Debuff (duration and stacks are configuration; instant is *not* a status) | `AttributeBuff` subclasses in `src/attributes/` |

## Naming rules

1. **Abilities** — player-facing name in `ability_name`; files `<name>_ability.tres`.
   Cast-mode behaviors only when a mode needs code: `ChanneledAbility`, `AuraAbility`,
   `ToggleAbility`, `PassiveAbility`.
2. **Spell scenes** — a concrete script is named after the spell (`Fireball`, `Smoke`).
   A spell with no behavior of its own uses its archetype class directly
   (Boomerang is a plain `ProjectileSpell` scene).
3. **Archetype bases** — `ProjectileSpell`, `FieldSpell`, `AuraSpell`, `WallSpell`,
   `BeamSpell`; introduced only on the second member (see below).
4. **Impact / telegraph scenes** — `<Spell><Role>` ending in `Effect` for the impact
   family (`ExplosionEffect`, `PushEffect`, `MeteorExplosion`). The first telegraph keeps
   its POC name until a second one exists.
5. **Statuses** — `<What>Buff` / `<What>Debuff` (`FrostArmorBuff`, `SlowDebuff`,
   `BurnDebuff`). Auras share their status (`DevotionAura` → `DevotionAuraBuff`).
6. **Instant effects** — `HealthDamage` subtracts Health, `HealthRestore` adds it;
   nothing else. Neither is ever called a buff or debuff.
7. **Initializers aren't statuses** — `InitializeAttributes`.
8. **Attacks** — a character's basic attack is an ability like any other
   (`<shaman>_attack_ability.tres`; the scene is named after the strike, e.g.
   `ArcaneBolt`, `StaffSwing`). Empowering spells are `<What>Buff`s whose stacks are the
   remaining empowered attacks (D-003).

Current file/class map:

| Layer | Files |
|---|---|
| Abilities | `src/abilities/base_ability.gd` (`BaseAbility`), `src/resources/abilities/*_ability.tres` |
| Spells | `spell_scene.gd` (`SpellScene`), `projectile_spell.gd` (`ProjectileSpell`), `fireball.gd`, `teleport.gd` |
| Field / Wall | `smoke.gd` (`Smoke`), `anivia_wall.gd` (`AniviaWall`) — still on `SpellScene` until a second member |
| Effects | `effect.gd` (`Effect`) + the effect scenes |
| Statuses | `health_damage.gd` (`HealthDamage`), `initialize_attributes.gd` (`InitializeAttributes`) |

## Second-member rule

Don't invent an archetype base class for a single spell — with one sample you can't tell
shared behavior from the incidental. Extract the base when the **second** spell of that
archetype exists, then make both extend it.

- **Projectile** — Fireball, Boomerang, Meteor, Teleport → `ProjectileSpell` exists.
- **Field** — Smoke only → wait for the second (e.g. Blizzard).
- **Wall** — AniviaWall only → wait.
- **Aura / Beam / Summon** — none yet → names reserved.
- **Telegraphs** — MeteorIncoming is the only one → keeps its name for now.
- **`src/attributes/status/` folder** — split it out when the second status exists.

## Reserved vocabulary — always reuse, never invent a synonym

- **Cast:** Instant, Aimed, Unit, Channel, Toggle, Aura, Autocast, Passive
- **Delivery:** Projectile, Field, Wall, Aura, Beam, Summon
- **Impact:** Hit, Explosion, Push, Pull, Chain
- **Status:** Buff, Debuff (CC is a Debuff); instant damage is `HealthDamage`, not a status

When a new spell needs a value that doesn't exist here, add it to this list first — the
vocabulary grows deliberately, not ad hoc.

## Spell catalogue

Current spells:

| Spell | Cast | Delivery | Impact | Status |
|---|---|---|---|---|
| Blink | Instant | Self | — | — |
| Fireball | Aimed | Projectile | Hit + ExplosionEffect | — |
| Boomerang | Aimed | Projectile (returns) | Hit + BoomerangEffect | — |
| Meteor | Aimed | Projectile | MeteorIncoming → MeteorExplosion | — |
| Smoke | Instant (self) | Field | Hit on entry | — |
| Teleport | Aimed | Projectile | Self reposition | — |
| Anivia Wall | Aimed | Wall | Blocker (despawns on contact) | — |

*Smoke is **Uninterruptible** — hits and re-presses cannot abort its cast (D-004).*

Reference spells these conventions must cover (WC3 / LoL), for M4 and later:

| Spell | Cast | Delivery | Impact | Status |
|---|---|---|---|---|
| Blizzard | Aimed + Channel | Field | tick damage | optional SlowDebuff |
| Starfall | Channel | Aura (around caster) | tick damage | — |
| Frost Armor | Unit (Autocast) | Unit | — | FrostArmorBuff |
| Devotion Aura | Aura (passive) | Aura | refresh | DevotionAuraBuff |
| Polymorph | Unit | Self | — | PolymorphDebuff (CC) |
| Immolation | Toggle | Aura | ticks | BurnDebuff |
| Chain Lightning | Unit | — | Chain | — |

## Naming a new spell — checklist

1. Fill in the four axes. If a value is missing from the reserved vocabulary, add it to
   this doc first.
2. Ability resource: `<name>_ability.tres`.
3. Spell scene: script named after the spell; an archetype base only on the second
   member (rule above).
4. Impact scenes: `<Spell><Role>Effect`.
5. Statuses: `<What>Buff` / `<What>Debuff`; instant damage is `HealthDamage`.
6. Add a row to the catalogue table.
7. If the spell establishes a new convention, add a [[decisions]] entry.

## See also

- [[decisions]] — D-001 attacker-applies hit pipeline, D-002 this vocabulary,
  D-003 basic attack model
- [[plan]] — M1 spell core, M4 rest of the spells
- [[controls]] — input model (aim/tap casting)
