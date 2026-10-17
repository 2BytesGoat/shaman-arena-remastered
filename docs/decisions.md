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

**References.** `godot/src/common/hit_area.gd`,
`godot/src/abilities/spell_scene.gd`, `godot/src/abilities/effects/effect.gd`,
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

**References.** `docs/spells.md`, `godot/src/abilities/projectile_spell.gd`,
`godot/src/attributes/health_damage.gd`.

**Addendum (2026-10-17, folder grouping).** Spells are filed one folder per Delivery value under
`src/abilities/spells/` — `projectile/`, `field/`, `deployable/`, `self/` — while the archetype
base classes stay at `src/abilities/` root (`spell_scene.gd`, `projectile_spell.gd`). Folders are
created on the **first** member; the second-member rule still governs only the base class.
Effect scenes mirror the shape: base `effect.gd`/`effect.tscn` at the `effects/` root, impacts in
`effects/impact/`, telegraphs in `effects/telegraph/`; ability resources mirror the spell tree
under `src/resources/abilities/<delivery>/`; `hit_area.gd` moved to `src/common/`
(next to `source_filter.gd`), and `ability_handler.gd` to `src/player/components/`.
Delivery value **`Wall` → `Deployable`**: "wall" named one shape of the family, which is really
"things you place down" (wall, turret, box, ward). AniviaWall's own name and class are unchanged;
its future archetype base is `DeployableSpell`.

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

**Addendum (2026-10-14).** The money wizard's Attack ability is **Smoke**; its 1.2 s pose
becomes the sheet's `CastBase` clip (rename of `CastSmoke`, planned — D-005).

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
| `Aim` | static hold | aiming (`AimState`) |
| `Hit` | one-shot | hit reaction (`HitState`) |
| `Dead` | one-shot | match flow (M5) |
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
- M2 ports all POC clips (Dead and Taunt included) but wires only the state and cast slots;
  Dead wiring lands with the match flow (M3, D-006), Taunt with M6.
- The slot names are also the vocabulary future character sheets are authored against.

**Amendment (2026-10-14, trigger pass).** Playback is one generic entry point,
`PlayerVisuals.play(clip)` (DJR parity: states pass their own name — `play(self.name)`;
`DeadState` names `&"Dead"`). The windup priority lives in `play`: clips in
`CAST_DEFERRED` (`Idle`, `Move`, `Aim`) are deferred while `is_windup_active()`, one-shot
slots override the cast clip. The cast slot speed is always derived, never passed:
`PlayerVisuals.play_cast(clip, cast_delay)` applies
`BaseAbility.cast_animation_speed(clip.length, CAST_DELAY)`. When a cast releases playback,
`CastHandler` calls `PlayerVisuals.reassert_animation()`, which replays the current state's
clip if its name is in `CAST_DEFERRED` — one-shot states (Hit/Dead) are excluded, so a
force-aborted cast can no longer stomp a hit reaction. New slots need no `PlayerVisuals`
changes — a state calling `play(&"Attack")` is the whole wiring.

**Amendment 2 (2026-10-14, constants pass).** The slot names now live in
**`AnimationSlots`** (`godot/src/common/animation_slots.gd`, a `class_name` constants
holder — the `AttributeNames` pattern, not the autoload): cast slots, `CAST_DEFERRED`, and
the `REQUIRED` set. The death slot is canonically **`Dead`** — state node, clip, and
constant agree, so `DeadState` keeps the uniform `play(self.name)` (this supersedes the
table's original `Death` name). `godot/tests/m2/test_animation_slots.gd` pins the contract:
required slots exist on the wizard sheet, the deferred slots are implemented, the
locomotion state nodes are named after their clips, and one-shot slots don't loop.

**Planned (not yet applied).** Smoke is the money wizard's Attack (D-003), so its 1.2 s
flavour clip `CastSmoke` will be renamed **`CastBase`** — the sheet's required base cast
pose (`AnimationSlots.CAST_BASE` joins `REQUIRED`). Resolution is unchanged (the pose is
still named via `CAST_ANIMATION`), and the reserved `Attack` slot stays reserved for
D-003's ability wiring. Prioritised in `docs/plan.md` (M4); nothing implemented yet.

**Not doing.** Per-spell animation enums; auto-generated animation tables; instant-cast poses
(revisit with Blink in M4).

**References.** `docs/spells.md` (Character animation slots),
`godot/src/common/animation_slots.gd`, `godot/src/abilities/base_ability.gd`,
`godot/src/player/player.gd`, `godot/tests/m2/test_animation_slots.gd`.

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
- Death plays the `Dead` clip: the Dead state resets `speed_scale` and plays it (POC
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
| Smoke | 16 | 1 | yes | hits players on entry only; despawns on its sprite finish (inherited ExpiryTimer is unwired) |
| Teleport / Meteor (cast) | 0 (base) | 15 (base) | no | values inherited from `spell_scene.tscn`; contact handling intentionally unwired — both resolve via ExpiryTimer |
| MeteorIncoming telegraph | 16 | 95 | **no** | contact values exist but are inert (D-001 correction); ExpiryTimer spawns the strike |
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
`godot/src/abilities/spells/*/*.tscn`, `godot/src/abilities/effects/`,
`godot/src/player/player.tscn`.

## D-008 — Player presentation components own their nodes (M3)

- **Status:** accepted (M3)
- **Date:** 2026-10-14

**Context.** The M3 cleanup split `Unit` (`player.gd`) into `CastController` and
`PlayerVisuals` child nodes. The first cut of `PlayerVisuals` owned no nodes — it reached into
the unit's children through the parent, reading as ceremony: a "visuals" node containing no
visuals. M4 adds more spells and animations, so fixing the shape now is cheaper than renaming
animation track paths later.

**Decision.**

- `PlayerVisuals` is a `Node2D` that **owns the sprite subtree it is named for**:
  `PlayerVisuals/Flippable/{PlayerSprite,LargeShadow}` and `PlayerVisuals/AimSprite`.
  The `AnimationPlayer` tracks resolve through it
  (`PlayerVisuals/Flippable/PlayerSprite:frame`).
- The **`AimSprite` must stay outside `Flippable`**: it is positioned by
  `offset = Vector2(360, 0)` + rotation, and a facing flip (`scale.x = -1`) would mirror its
  world position to the wrong side while facing left.
- `CastController` stays a controller-style node (owns no nodes, acts via `@export unit`),
  matching the existing `AbilityHandler` and `StateMachine` precedents. Components are for
  logic with its own state; a pass-through that only forwards calls is not worth a node.
  **Amendment (2026-10-14):** renamed **`CastHandler`** and reduced to cast execution only
  when the input layer landed — see D-009.
- `facing_scale` stays a `Unit` variable (read by cast and locomotion); the flip is applied
  through `PlayerVisuals.set_facing()`.
- **Amendment (2026-10-14, presentation pass):** animation playback moved behind
  `PlayerVisuals` — states and `CastHandler` no longer touch the `AnimationPlayer` directly.
  The node stays a child of `Unit` so the track paths are untouched; the "deferred clips yield
  to an active cast windup" priority lives in `PlayerVisuals.play`. `Unit.TURN_ACCELERATION` →
  `PlayerVisuals.AIM_TURN_SPEED` (only the aim sprite read it). See D-005's trigger amendment
  for the generic `play`/`play_cast`/`reassert_animation` model.

**Consequences.** Restructuring the sprite subtree means rewriting those track paths by hand
in the `.tscn`; the resolution test `godot/tests/m3/test_player_visuals.gd` catches mistakes
(wrong track paths silently no-op at runtime). The POC's `Flippable` node is kept as a nested
node so sprite transforms stay unchanged.

**References.** `godot/src/player/player.tscn`, `godot/src/player/components/player_visuals.gd`,
`godot/src/player/components/cast_handler.gd`, `godot/tests/m3/test_player_visuals.gd`.

## D-009 — Controllers own input, Unit owns intents (controller slot)

- **Status:** accepted (refactor branch)
- **Date:** 2026-10-14

**Context.** `CastController` was added in the M3 cleanup to hold cast lifecycle glue, but it
also read the global `Input` singleton for aim steering and spell presses (`update_direction`,
`handle_spell_input`), while two more input reads lived outside it (`Unit._update_move_direction`
for movement, `AimState.physics_update` for the spell release). Three local-input sites, no seam:
an AI or network-driven player would have to fake `Input` actions, and there was no swappable
"controller" despite the name. The sibling project DragonJumpRemastered is the pattern to follow:
`PlayerCharacterController` base → `PlayerOneController`/`PlayerAITrainingController`, a
`ControllerContainer` slot on the player, and a `NONE` controller type for tests/replay.

**Decision.**

- Input sources become **controller nodes** in `src/player/controllers/`:
  `PlayerController` (base, `unit` injected) and `LocalPlayerController` — the only class in the
  game that reads `Input`. Future `AI`/`Remote` controllers subclass the base and call the same
  intent API.
- `Unit` owns a controller slot: `enum ControllerType { NONE, LOCAL }`,
  `@export controller_type` factory + `set_controller()` (the controller becomes a direct child
  of the Unit). `NONE` (default in `player.tscn`) creates no controller so tests/replay drive the
  Unit directly; `main.tscn` sets `LOCAL`.
- Controllers send **intents**, the Unit decides legality: `set_move_input(dir)`,
  `set_aim_input(dir)`, `request_cast(slot)`, `request_release()` (consumed by `AimState` via
  `consume_release_request()`). Active-cast abort, cooldown checks, the Aim transition and the
  tap/hold decision stay unit/state-side. Intents are plain data, so a network layer can carry
  them later.
- `Unit` drives the tick (`controller.update(delta)` at the top of `_physics_process`; no
  `_physics_process` on controllers) so tests that disable unit physics stay deterministic.
- `CastController` → **`CastHandler`**, reduced to cast execution
  (`try_cast`/abort/windup/cooldown-spawn/cast animation). `Unit.try_cast`/`try_abort_cast`
  forwarders remain.

**Addendum (2026-10-14).** `ControllerContainer` was dropped: with a single `controller`
reference on the Unit, a container node was one noun for one child. `LocalPlayerController`
now owns its **input index** (`player_index`): it builds the `player_N_*` action names itself
and the factory passes `PLAYER_CONTROLLER`, so the unit's seat stays identity (palette, HUD,
winner) while an explicit index can differ for tests / a future join flow. The action-name
helpers moved off `Unit` with it — they had no other user.

**Addendum 2 (2026-10-14, input-shaping pass).** The stick deadzone moved into
`LocalPlayerController` (applied once to the raw stick before both move and aim intents): it is
input-hardware shaping, not intent legality — and the unit-side check only covered aim, so
sub-deadzone drift normalised to a full-speed walk. `Unit.set_aim_input` keeps a zero-guard
only. `StateMachine._unhandled_input` → `State.handle_input` stays as the state-machine
pattern's input hook even though no state consumes it.

**Consequences.**

- The input surface is one class; movement/aim/press/release can no longer drift apart.
- Tests exercise intents directly (no real `Input`); the suite stays logic-first.
- A bot is `ControllerType.AI` + an `AIPlayerController` calling the same four intent methods;
  netplay is a remote controller receiving the same payloads.
- Pressing a spell freezes position one frame earlier than before (Aim enter precedes
  `move_and_slide`); the controller checks release only for `aiming_slot`, so releasing another
  slot while aiming behaves as before.

**Not doing.** Command objects (DJR's `Command` + inner `Params` are thin wrappers over one
intent call — worth adding only when queued/replayed intents exist); seat-per-class controllers
(`PlayerOneController`/`PlayerTwoController`): one class per input **kind**, one instance per
seat — a subclass per seat duplicates logic and explodes `ControllerType` once AI/Remote seats
arrive (DJR only ever shipped one local seat); a second exported index on `Unit` (the factory
derives `player_index` from `PLAYER_CONTROLLER`, an explicit override is code-only); AI/Remote
controller classes before their milestone; input buffering (still parked in `controls.md`).

**References.** `godot/src/player/player.gd`,
`godot/src/player/controllers/player_controller.gd`,
`godot/src/player/controllers/local_player_controller.gd`,
`godot/src/player/states/aim_state.gd`, `godot/src/player/components/cast_handler.gd`,
`godot/tests/m3/test_player_controller.gd`.

## D-010 — Instant spells cast on press (no Aim phase)

- **Status:** accepted
- **Date:** 2026-10-17

**Context.** `CAST_MODE` (Instant/Aimed) was declared on every ability but never read — all
spells, Blink and Smoke included, went through the same press/hold/release Aim flow, even
though Smoke is self-centered and Blink only needs the facing direction. Wiring the INSTANT
tap-cast was parked on the M4 list; it landed early.

**Decision.**

- `Unit.request_cast` branches on `CAST_MODE`: an `Instant` ability casts immediately on
  press (`try_cast(ability, facing_direction())`) and never enters `AimState`; `Aimed`
  abilities keep the press/hold/release flow. Controllers are unchanged — they still send
  the same intents (D-009).
- Blink and Smoke are `Instant` (Blink already was; Smoke is re-classified in its `.tres`).
- `CAST_DELAY` is untouched: Smoke keeps its 1.2 s `CastSmoke` windup (Uninterruptible,
  D-004) — the field still lands at the end of the GGAS duration. The ~150 ms tap threshold
  remains for aimed casts (tap → facing, hold → stick).

**Consequences.**

- Instant spells fire on button-down; holding/releasing does nothing, so Blink always casts
  toward the current facing.
- No Aim enter means no instant position freeze for instant casts; with Smoke's windup the
  movement input is dropped instead and the unit decelerates.
- The aim-indicator / HUD-highlight phase only ever appears for aimed spells.

**References.** `godot/src/player/player.gd`,
`godot/src/resources/abilities/self/blink_ability.tres`,
`godot/src/resources/abilities/field/smoke_ability.tres`,
`godot/src/player/states/aim_state.gd`, `godot/tests/m3/test_player_controller.gd`.

## D-011 — Rounds-style spell draft (match start)

- **Status:** accepted (demo iteration)
- **Date:** 2026-10-17

**Context.** The M3 selection screen (D-006) showed the whole catalogue as a grid and
auto-readied at 6 picks (POC parity). The demo wants the Rounds feel instead: a small
random hand, one committed choice, a pool that grows as matches play out.

**Decision.**

- Match start = one draft per player: **5 random distinct offers**, one **committed** pick
  that goes into the pool. No un-pick, no re-roll (Rounds-style); cancel has no binding.
- Offers never repeat within a hand and never include a spell the player already owns
  (`SpellDraw`, RNG injected so seeded tests are deterministic).
- Players draft **sequentially on one shared screen** — player 1's panel first, then
  player 2's; `MatchManager` starts each turn via `SpellSelect.start_draft()` while the
  other panels stay hidden and ignore input. The pools are independent — the same spell
  can be offered to (and taken by) both.
- The turn hand-off happens on the next frame (`call_deferred`), so the shared dev accept
  press that ends one draft can't be consumed by the next player's panel in the same
  frame. Gameplay stays locked for the whole draft sequence, and each panel only accepts
  input while it is the active drafter.
- The pool cap stays `Loadout.MAX_SPELLS = 6`. The HUD renders one button per owned spell
  and grows with the pool; the draft screen shows the 6 pool slots filling up.
- Consumable/item slots are **removed for now**: no HUD placeholders, no reserved slots in
  the draft strip, `CONSUMABLE_SLOTS` constants gone. The reserved
  `player_N_consumable_0/1` input actions stay in `project.godot` (inert) until the item
  work lands.
- `SpellSelect.start_draft()` is the re-entry point for the **per-death draft** ("loser
  drafts a card"): it re-rolls offers and takes the screen; the pick flow is unchanged.
  Wiring it needs the rounds loop — deferred, because today the first death ends the match.

**Consequences.**

- A match starts with 1 spell per player; with no rounds yet, per-death drafts can't fire,
  so the demo match is 1 spell each, first death ends it.
- `MatchManager` now drives the draft turns (one panel at a time, controller order) on top
  of the old ready-gate; the rounds milestone will reuse that turn machinery for the
  post-death draft.
- D-006's "auto-ready at 6 picks" and the 6 + 2 slot limit are superseded at draft time;
  the pool itself keeps the 6-spell cap.

**References.** `godot/src/match/spell_draw.gd`, `godot/src/ui/spell_select.gd`,
`godot/src/match/match_manager.gd`, `godot/tests/m3/test_spell_draw.gd`,
`godot/tests/m3/test_selection_input.gd`.
