---
title: Spells — Naming & Structure
tags: [godot, gameplay, spells, abilities, naming, conventions]
related:
  - "[[plan]]"
  - "[[decisions]]"
  - "[[controls]]"
search_terms: [spells, abilities, naming, convention, buff, debuff, aura, channel, toggle, projectile, field, wall, deployable, turret, effect, health damage, attack, basic attack, restore, heal, warcraft, league]
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
- **Spell** — the world object an ability spawns (projectile, field, deployable…). Lives in
  `src/abilities/spells/<delivery>/`, base class `SpellScene`.
- **Effect** — an impact or telegraph scene: visuals first, doubles as a hitbox per
  D-001. Impacts live in `src/abilities/effects/impact/` (base class `Effect`, base scene
  `effects/effect.tscn` at the `effects/` root); telegraphs live in
  `src/abilities/effects/telegraph/`.
- **Deployable** — a placed world object that persists at its spot and can block or act
  (wall, turret, box, ward). Its presence on the field separates it from a **Field**,
  which is an area effect.
- **Damage** — an instant health loss. **Not** a buff or debuff; applied via
  `HealthDamage`.
- **Restore** — an instant health gain, the counterpart of Damage. **Not** a buff or
  debuff; applied via `HealthRestore`.
- **Buff / Debuff** — a *lasting* status attached to a unit (WC3/LoL meaning): it helps
  or hinders. Duration and stacks are configuration, never part of the name.
- **Crowd control (CC)** — a debuff that removes control (stun, root, silence…). Still
  named `...Debuff`.
- **Uninterruptible** — a cast that hits cannot abort; only death stops it.
  `BaseAbility.UNINTERRUPTIBLE` (currently Smoke only, D-004).
- **Self-immunity** — by default an impact never hits the unit that cast it (`SourceFilter`,
  D-001). A spell opts in with `BaseAbility.HITS_SELF`, and the flag is carried through its
  whole impact chain (projectile, on-hit effect, meteor strike); Smoke and Teleport stay
  immune (D-018).
- **Animation slot** — a fixed clip name every character sheet provides (`Idle`,
  `CastOffensive`, …). Abilities select slots, never raw clips; character-flavor clips are
  opt-in via `CAST_ANIMATION` (full contract below, D-005).

## The four axes

Every spell is a combination of four independent axes:

| Axis | Values | Code home |
|---|---|---|
| **Cast** | Instant, Aimed, Unit, Channel, Toggle, Aura, Autocast, Passive | `BaseAbility.CAST_MODE` — `Instant` fires on press (no Aim phase, facing direction); `Aimed` uses press/hold/release |
| **Delivery** | Self, Projectile, Field, Deployable, Aura, Beam, Summon | `SpellScene` subclasses, one folder per value under `spells/` |
| **Impact** | Hit (damage), Explosion, Push, Pull, Chain, None | `Effect` scenes via `HitArea.apply` (D-001) |
| **Status** | none, Buff, Debuff (duration and stacks are configuration; instant is *not* a status) | `AttributeBuff` subclasses in `src/attributes/` |

## Naming rules

1. **Abilities** — player-facing name in `ability_name`; files
   `src/resources/abilities/<delivery>/<name>_ability.tres` (mirrors `spells/`).
   Cast-mode behaviors only when a mode needs code: `ChanneledAbility`, `AuraAbility`,
   `ToggleAbility`, `PassiveAbility`.
2. **Spell scenes** — a concrete script is named after the spell (`Fireball`, `Smoke`).
   A spell with no behavior of its own uses its archetype class directly
   (Boomerang is a plain `ProjectileSpell` scene).
3. **Archetype bases** — `ProjectileSpell`, `FieldSpell`, `DeployableSpell`, `AuraSpell`,
   `BeamSpell`; introduced only on the second member (see below).
4. **Impact / telegraph scenes** — `<Spell><Role>` ending in `Effect` for the impact
   family (`ExplosionEffect`, `PushEffect`, `MeteorExplosion`), filed under `effects/impact/`.
   The first telegraph keeps its POC name until a second one exists, in `effects/telegraph/`.
5. **Statuses** — `<What>Buff` / `<What>Debuff` (`FrostArmorBuff`, `SlowDebuff`,
   `BurnDebuff`). Auras share their status (`DevotionAura` → `DevotionAuraBuff`).
6. **Instant effects** — `HealthDamage` subtracts Health, `HealthRestore` adds it;
   nothing else. Neither is ever called a buff or debuff.
7. **Initializers aren't statuses** — `InitializeAttributes`.
8. **Attacks** — a character's basic attack is an ability like any other
   (`<shaman>_attack_ability.tres`; the scene is named after the strike, e.g.
   `ArcaneBolt`, `StaffSwing`). Empowering spells are `<What>Buff`s whose stacks are the
   remaining empowered attacks (D-003). The money wizard's Attack is **Smoke**.

Current file/class map:

| Layer | Files |
|---|---|
| Abilities | `src/abilities/base_ability.gd` (`BaseAbility`), `src/resources/abilities/<delivery>/*_ability.tres` (mirrors the spell folders) |
| Spell bases | `src/abilities/spell_scene.gd` + `spell_scene.tscn` (`SpellScene`), `src/abilities/projectile_spell.gd` (`ProjectileSpell`) |
| Projectiles | `src/abilities/spells/projectile/` — `fireball.gd/.tscn`, `boomerang.tscn`, `meteor.tscn`, `teleport.gd/.tscn` |
| Field | `src/abilities/spells/field/smoke.gd/.tscn` (`Smoke`) — still on `SpellScene` until a second member |
| Deployables | `src/abilities/spells/deployable/anivia_wall.gd/.tscn` (`AniviaWall`) — still on `SpellScene` until a second member |
| Self | `src/abilities/spells/self/blink_ability.gd` (`BlinkAbility`) — no scene; the ability's `cast()` is the whole spell |
| Effects | `src/abilities/effects/impact/` — `effect.gd` / `effect.tscn` base at the `effects/` root + the impact scenes |
| Telegraphs | `src/abilities/effects/telegraph/` — `meteor_incoming.gd/.tscn` (`MeteorIncoming`) |
| Statuses | `health_damage.gd` (`HealthDamage`), `initialize_attributes.gd` (`InitializeAttributes`) |

## Character animation slots

Every character sheet ships a fixed set of `AnimationPlayer` clips — the **slots** (D-005).
Abilities select slots, never raw clips, so a shaman without a given pose degrades to the
generic slot instead of breaking. The slot names live in code as constants in
`AnimationSlots` (`godot/src/common/animation_slots.gd`), pinned by
`godot/tests/abilities/test_animation_slots.gd`.

| Slot | Playback | Selected by | Money wizard |
|---|---|---|---|
| `Idle` / `Move` | loop | state machine | yes |
| `Aim` | static hold | aiming (`AimState`) | yes |
| `Hit` | one-shot | hit reaction (`HitState`) | yes |
| `Dead` | one-shot | match flow (M5) | yes |
| `CastOffensive` | one-shot, speed-scaled | `TYPE == OFFENSIVE` | yes |
| `CastDefensive` | one-shot, speed-scaled | `TYPE == DEFENSIVE` | yes |
| `CastUtility` | one-shot, speed-scaled | `TYPE == UTILITY` | yes |
| `Attack` | one-shot, speed-scaled | basic attack ability (D-003) | reserved (M4) |
| `Channel` | loop | channeled casts (M4) | reserved |
| `Taunt` | one-shot | taunt button (M6, optional) | yes |

- **Speed-scaled** = `speed_scale = clip.length / CAST_DELAY`, so the pose fills the GGAS
  cast duration exactly; `CAST_DELAY == 0` (Blink) plays nothing for now.
- **Flavor clips** — `BaseAbility.CAST_ANIMATION` may name a character-specific clip
  (Smoke → `CastSmoke`, the 1.2 s pose). Resolution at cast time: flavor clip *if this
  character's sheet has it* → else the slot for `TYPE` → else `push_warning` + `Idle`.
- Frames live on `PlayerVisuals/Flippable/PlayerSprite`; facing flips via the `Flippable` node's scale, never baked
  into the sheet.

## Second-member rule

Don't invent an archetype base class for a single spell — with one sample you can't tell
shared behavior from the incidental. Extract the base when the **second** spell of that
archetype exists, then make both extend it.

Folders don't follow the second-member rule: concrete spells are filed by Delivery value
(`spells/projectile/`, `spells/field/`, `spells/deployable/`, `spells/self/`) as soon as they exist,
and archetype base classes live one level up at `src/abilities/` root. A one-member folder
(Field, Deployable) is expected — that's where the second member lands, at which point the base
class (`FieldSpell`, `DeployableSpell`, …) appears next to `projectile_spell.gd`. Ability
resources mirror the same folders under `src/resources/abilities/` (a spell's tuning resources,
like Boomerang's speed curve, live with its ability resource).

- **Projectile** — Fireball, Boomerang, Meteor, Teleport (`spells/projectile/`) → `ProjectileSpell` exists.
- **Field** — Smoke only (`spells/field/`) → wait for the second (e.g. Blizzard).
- **Deployable** — AniviaWall only (`spells/deployable/`) → wait for the second (turret, box, ward…).
- **Self** — Blink only (`spells/self/`) — an ability script, not a scene; waits for a second
  self-cast ability before any base is extracted.
- **Aura / Beam / Summon** — none yet → names reserved.
- **Telegraphs** — MeteorIncoming is the only one (`effects/telegraph/`) → keeps its name for now.
- **`src/attributes/status/` folder** — split it out when the second status exists.

## Reserved vocabulary — always reuse, never invent a synonym

- **Cast:** Instant, Aimed, Unit, Channel, Toggle, Aura, Autocast, Passive
- **Delivery:** Projectile, Field, Deployable, Aura, Beam, Summon
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
| Anivia Wall | Aimed | Deployable (wall) | Blocker (despawns on contact) | — |

*Smoke is **Uninterruptible** — hits cannot abort its cast (D-004). It is
also the money wizard's Attack ability (D-003).*

*`CAST_MODE` is branched on in `Unit.request_cast`: `Instant` spells (Blink, Smoke) cast the
moment the button goes down — no Aim phase, direction is the current facing (`Smoke.cast()`
ignores it) — while `Aimed` spells keep the press/hold/release flow, where the ~150 ms tap
threshold picks facing vs stick direction.*

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
   this doc first. The cast animation slot follows from `TYPE` automatically — set
   `CAST_ANIMATION` only to request a character-flavor clip.
2. Ability resource: `<name>_ability.tres`.
3. Spell scene: script named after the spell under `spells/<delivery>/`; an archetype base only
   on the second member (rule above). A self-cast spell with no scene (Blink) files its ability
   script under `spells/self/` instead.
4. Impact scenes: `<Spell><Role>Effect`.
5. Statuses: `<What>Buff` / `<What>Debuff`; instant damage is `HealthDamage`.
6. Add a row to the catalogue table.
7. If the spell establishes a new convention, add a [[decisions]] entry.

## See also

- [[decisions]] — D-001 attacker-applies hit pipeline, D-002 this vocabulary,
  D-003 basic attack model, D-004 cast-abort rules, D-005 animation slots,
  D-006 match flow & loadout selection
- [[plan]] — M1 spell core, M2 movement polish, M4 rest of the spells
- [[controls]] — input model (aim/tap casting)
