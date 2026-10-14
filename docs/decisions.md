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
  (Fireball 10 + explosion 5/KB 175, Boomerang 7 + effect 7/KB 150) and smoke spawning at
  the caster's position after its 1.2 s cast delay. Don't "fix" these without a new decision.
- **Correction (2026-10-14).** The meteor telegraph's 0/KB 100 values are *declared but never
  applied* — in the port and in the POC. The POC's `MeteorIncoming` wired `area_entered` to a
  handler its script never defined (dangling connection, no push in play); the port's
  telegraph scene wires no `area_entered` at all. The timer-strike path is the live behavior.
  Wiring telegraph contact (or not) is a gameplay decision left to M4 tuning.
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

**Context.** A 7-champion League corpus audit (private research, not committed to this
public repo) showed 4 of 7
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

**References.** `docs/spells.md` (Core words: Attack), the private champion-corpus audit
(not in repo), `godot/src/abilities/base_ability.gd`, `godot/src/player/player.gd`.

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

## D-005 — Character animation slots (abilities name slots, not clips)

- **Status:** accepted (M2)
- **Date:** 2026-10-14

**Context.** M2 ports the POC player sheet (money wizard): every state and cast played a clip
by name — 4 cast clips picked by the old 4-value type enum, frame tracks hard-wired into the
states. Two things broke that model: D-002 shrank `SpellType` to
`OFFENSIVE/DEFENSIVE/UTILITY` (no more `SMOKE`, so "which cast clip" is no longer readable
from the type alone), and later milestones add content (basic attacks, channels) plus new
characters whose sheets will not all carry the same clips. An ability pointing at a raw clip
name (`CastSmoke`) would break the day a shaman ships without that pose.

**Decision.** Every character sheet provides a fixed set of **animation slots** — the clip
names are the contract:

| Slot | Playback | Selected by |
|---|---|---|
| `Idle` / `Move` | loop | state machine |
| `Hit` | one-shot | hit reaction (`HitState`) |
| `Death` | one-shot | match flow (M5) |
| `CastOffensive` / `CastDefensive` / `CastUtility` | one-shot, speed-scaled to the cast delay | `SpellType` |
| `Attack` | one-shot, speed-scaled | basic attack ability (D-003) |
| `Channel` | loop | channeled casts (M4) |
| `Taunt` | one-shot | taunt button (M6, optional) |

- Abilities reference **slots, never raw clips** — with one deliberate escape hatch:
  `BaseAbility.CAST_ANIMATION` may name a character-flavor clip (Smoke → `CastSmoke`).
- Resolution order at cast time: flavor clip **if this character's `AnimationPlayer` has
  it** → else the slot for `TYPE` → else `push_warning` + `Idle`. A character without the
  flavor clip degrades to the generic slot; no ability edits needed.
- Cast slots play once with `speed_scale = clip.length / CAST_DELAY` (POC formula), filling
  the GGAS duration exactly; `Channel` loops.
- Instant casts (`CAST_DELAY == 0`, Blink) play no cast slot for now.

**Consequences.**

- New characters implement the slots they have; a missing flavor clip falls back
  automatically, a missing required slot is an asset bug surfaced by `push_warning`.
- M2 ports all POC clips (Death and Taunt included) but wires only the state and cast slots;
  Death wiring lands with M5's match flow, Taunt with M6.
- The slot names are also the vocabulary future character sheets are authored against.

**Not doing.** Per-spell animation enums; auto-generated animation tables; an aim pose (the
aim marker carries aiming, POC parity); instant-cast poses (revisit with Blink in M4).

**References.** `docs/spells.md` (Character animation slots),
`godot/src/abilities/base_ability.gd`, `godot/src/player/player.gd`.

## D-006 — Match flow & loadout selection

- **Status:** accepted (M3)
- **Date:** 2026-10-14

**Context.** The POC embedded its selection UI inside each player and auto-finished at 4
picks; `main.gd` counted `spells_are_ready` and set `is_ready` on everyone once all were
in. M3 needs the same for 6 spells + 2 reserved consumables plus a phase machine that
future rounds/gold can extend without rework.

**Decision.**

- `MatchManager` is a **main-scene node** (not an autoload), owning
  `SELECTING → RUNNING → GAME_OVER`: it locks units until RUNNING, freezes them on
  GAME_OVER, and shows a placeholder match-over banner ("PLAYER N WINS", accept/button
  restarts) — the full win screen replaces it in M5.
- Death plays the `Death` clip: the Dead state resets `speed_scale` and plays it (POC
  parity), so a lethal hit never leaves the corpse in the previous pose — including a
  death that lands mid-`Hit`.
- Selection is **auto-ready at 6 picks** (POC parity — no ready button). A picked spell
  can be un-picked before the 6th (accept again); cancel removes the last pick.
- Applying a loadout = `try_revoke` + `remove_ability` for the old set, then
  `add_ability` + `try_grant` for the picks, then a HUD rebuild — the same path a
  shop/loadout swap uses later (`tldr.md` mapping).
- `MatchManager.skip_selection` + `default_loadout` is a dev-only fast path straight to
  RUNNING for editor iteration.

**Consequences.**

- `Unit.is_match_ready` gates movement and casting. Readiness is **manager-side**: the
  `MatchManager` marks a player ready when its selection completes (`loadout_complete`), so
  later loadout writes (e.g. a shop apply) can never ready a player by accident;
  `Unit.loadout_applied` is informational only.
- The 6 + 2 limit is enforced by selection only; the temporary `player_N_spell_6` dev
  action is retired.
- Units start with an empty `AbilityContainer` — every runtime ability comes from the
  loadout, not the scene.

**References.** `godot/src/match/match_manager.gd`, `godot/src/match/loadout.gd`,
`godot/src/ui/spell_select.gd`, `godot/src/ui/match_over.gd`, `godot/src/player/player.gd`,
`godot/src/player/states/dead_state.gd`.

## D-007 — Physics layer contract (2D)

- **Status:** accepted (M3, documentation of the M1/Phase-0 wiring)
- **Date:** 2026-10-14

**Context.** Layer names were ported POC-verbatim in Phase 0, but the actual masks on the
spell/effect/wall scenes were picked per-scene and never written down. Reading a scene file
doesn't tell you why a mask says 95 — and M4 (more spells, consumables) plus M5 (lava,
camera) will copy these numbers unless the intent is recorded.

**Decision.** The mapping below is the contract. Changing any value means changing this
entry and the pinning test `godot/tests/phase0/test_layer_contract.gd`.

**Layers**

| Layer | Name | Who is on it |
|---|---|---|
| 1 | `player_0` | **All players and their Hurtboxes** (every controller, today) |
| 2–4 | `player_1..3` | Reserved — named, but nothing assigns them yet (see caveat) |
| 5 | `projectile` | Spell areas (concrete projectiles) and Effect areas |
| 6 | `lava` | Reserved for M5 |
| 7 | `Environment` | `AniviaWall` area + its `StaticBody2D`; future environment areas |

**Scene masks (verified 2026-10-14)**

| Scene | Layer | Mask | Wires `area_entered`? | Why |
|---|---|---|---|---|
| Player body | 1 | 65 = 1 + 64 | — | collides with the other player's body and walls |
| Hurtbox | 1 | 0 | — | passive target; own hits filtered by `SourceFilter`, not layers |
| Fireball / Boomerang | 16 | 95 = 1–4 + 16 + 64 | yes | players damage; any other area (wall, other spell) despawns + effect |
| Smoke | 16 | 1 | yes | hits players on entry only; despawns on its sprite finish (inherited Timer is unwired) |
| Teleport / Meteor (cast) | 0 (base) | 15 (base) | no | values inherited from `spell_scene.tscn`; contact handling intentionally unwired — both resolve via Timer |
| MeteorIncoming telegraph | 16 | 95 | **no** | contact values exist but are inert (D-001 correction); Timer spawns the strike |
| MeteorExplosion / ExplosionEffect | 16 | 1 | yes (inherited from `effect.tscn`) | 15 dmg / KB 250 and 5 / KB 175 |
| AniviaWall area | 64 | 31 = 1–4 + 16 | yes | despawns when any spell touches it |
| AniviaWall StaticBody | 64 | 15 | — | blocks player movement |

**Consequences.**

- Spells masking layer 16 means **spells collide with each other** (a Fireball hitting a
  Boomerang explodes) — a deliberate consequence of POC parity; don't "fix" it silently.
- Connections are inherited from instanced base scenes (`spell_scene.tscn` declares none;
  `effect.tscn` declares `area_entered`, so all effect scenes get it).
- Effects mask layer 1 only. If players ever move to their named layers 2–4 (4-player
  support), effect masks must widen to 15 or effects will miss players 3/4.
- Layer names live in `project.godot` (`layer_names/2d_physics/layer_N`) and are asserted
  by the contract test.

**Not doing.** Per-player collision layers for the current 2-player build (all players share
layer 1 — friend fire is on by design and `SourceFilter` handles self-immunity);
renumbering the POC layers.

**References.** `godot/project.godot`, `godot/tests/phase0/test_layer_contract.gd`,
`godot/src/abilities/spells/*.tscn`, `godot/src/abilities/effects/*.tscn`,
`godot/src/player/player.tscn`.
