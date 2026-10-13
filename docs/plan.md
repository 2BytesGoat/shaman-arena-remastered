# Shaman Arena — Port & Rewrite Plan

Port the full POC from `GianiStatie/Shamans` onto the OctoD gameplay abilities/attributes
addons (GGAS/GGA), arcade-controls first, with an architecture that keeps later systems
(rounds, gold, shop, consumables content) cheap to add.

Control scheme: see [`docs/controls.md`](controls.md). TL;DR — single stick per player;
press+hold a spell button to aim (shaman locks position), release to cast, quick tap for
instant spells; max 6 spells + 2 consumables equipped.

---

## Process

- Each milestone = feature branch → **one separate PR**. Nothing lands on `main` directly.
- Every PR must include:
  - checklist ticks in this file for the milestone
  - a **version bump**, visible in-game (see M0 `VersionLabel`):
    `M1 → v0.1.0`, `M2 → v0.2.0`, `M3 → v0.3.0`, `M4 → v0.4.0`, `M5 → v0.5.0`, `M5.5 → v0.5.1`
  - unit tests (gdUnit4) covering that milestone's new logic
  - the manual verification checklist below ticked off
- CI (`.github/workflows/test.yml`) must be green on every PR — merge gate.
- Repo made **public** (unlimited GitHub Actions minutes).
- One milestone = one user-visible version; keep the game runnable in-editor at every merge.

---

## Phase 0 — Prerequisites (PR #1, version starts at `v0.0.1`)

### Engine
*Godot 4.7 upgrade **deferred to Phase LAST** (user decision — the features flip crashed
their 4.6.3 editor session / got rewritten on save). Dev floor for the entire port is
**4.6.3** (`config/features = ("4.6", "Forward Plus")`). The upgrade itself was already
rehearsed successfully on the official 4.7.2 binary, so the final-phase bump is low-risk.*

### GDExtensions
- [x] Build `gameplay-attributes` for macOS (cloned `OctoD/godot_gameplay_attributes`,
      compiled with scons, vendored into `addons/gameplay-attributes/macos/`,
      `macos.debug.arm64`/`macos.release.arm64` entries added to the `.gdextension`)
      — **built against godot-cpp `godot-4.5-stable`** (repo submodule pins branch 4.4;
      godot-cpp has **no 4.6/4.7 tags or branches** — branch-per-minor stopped at `4.5`,
      so 4.5-stable is the newest reproducible stable snapshot; `compatibility_minimum = 4.4`
      keeps it forward-loadable into 4.6/4.7). Binaries: 408 KB debug + 392 KB release (arm64)
- [x] Verify extensions load from a clean `.godot` (delete & re-import — zero errors on both 4.7.2 and 4.6.3)

### Project config
- [x] Copy project settings from POC: pixel texture filter, `canvas_items` stretch,
      audio bus layout (`default_bus_layout.tres` ported: Master/SFX/Music)
- [x] Port physics layers/groups mapping: player_0..3, projectile, lava, Environment
      (7 named layers, POC-verbatim)
- [x] Define input maps per player (P0 kbd+pad0, P1 kbd+pad1):
      move axes, `spell_0..5`, `consumable_0..1`, taunt, UI navigation —
      19 actions × 2 players; see `docs/controls.md` for the binding table

### Docs, UI, tooling
- [x] Write `docs/controls.md`
- [x] `VersionLabel`: autoload (`scripts/ui/version_label.gd`, CanvasLayer 100, bottom-left)
      reading `application/config/version` — currently `"0.0.1"`
- [x] Vendor gdUnit4 **v6.2.2** into `addons/gdUnit4/` + `tests/phase0` scaffold
      (extension load, version, input maps — 3 tests, all green on 4.7.2;
      note: CmdTool requires `--ignoreHeadlessMode` for headless runs)
- [x] `.github/workflows/test.yml`: ubuntu runner → chickensoft `Setup-Godot` **(4.6.3,
      matching dev editor)** → headless import → gdUnit4 suite → report artifacts;
      runs on push/PR; **green = merge gate**
- [ ] Flip repo to **public** (unlimited Actions minutes) — repo owner action

---

## M1 — Spell logic core + 6 spells → `v0.1.0`

- [x] `BaseAbility extends Ability` (resources live in `src/resources/abilities/`):
      - TYPE enum (OFFENSIVE/DEFENSIVE/UTILITY/SMOKE) → drives cast animation
      - ICON, `CastMode` (INSTANT / AIMED), cast delay → `_get_duration`,
        cooldown → `_get_cooldown` (GGAS native, replaces tween hack in `base_ability_resource.gd`)
      - `AbilityContainer.cooldown_start` spawns the spell scene: it fires at the end of the
        GGAS duration and synchronously for instant casts (the vendored build calls `_on_end`
        only after the cooldown, so the signal is the correct hook)
- [x] `SpellScene extends Area2D` (ported from POC `spell.gd`):
      source Unit, velocity-curve speed, lifespan timer, `on_hit_effect`,
      group ("Spell"/"Explosion") + collision-layer hit detection, source-immunity rule
- [x] `AimState`: enter → velocity zeroed; physics tick reads stick → `cast_direction`,
      aim sprite follows; release → `try_activate`
      Tap flow: press+release < ~150ms → instant/facing cast for INSTANT spells
- [x] `Unit.take_hit(source, damage, knockback, impact_dir)` pipeline:
      DamageBuff (Health↓) → attribute death signal → DeathState.
      Knockback stays FLAT here (Warlock scaling lands in M5.5)
- [x] Port spell implementations (POC parity):
      - [x] Fireball (curve speed, sprite grow, expiry → explosion effect)
      - [x] Boomerang (curve speed out/back)
      - [x] Meteor (projectile → MeteorIncoming effect → meteor strike → explosion)
      - [x] Smoke (self-cast defensive)
      - [x] Teleport (projectile travels, caster blinks to landing point)
      - [x] Anivia Wall (static blocker, despawn on expiry/hit)
- [x] Effect scenes: Effect base (KNOCKBACK/DAMAGE/source), explosion, push, teleport effect
- [x] HUD: per-slot cooldown UI driven by GGAS `cooldown_start`/`cooldown_end`
      (not clickable, arcade HUD; replaces Timer polling)

**Tests (gdUnit4, logic-first):** attribute damage ops (DamageBuff subtracts Health,
death signal on zero), GGAS cooldown/duration lifecycle on a test ability, SpellScene
curve-speed math at t=0.5/1.0, source-immunity predicate, tap-hold threshold decision.
**Verify (manual):** tap-cast Blink uses facing; hold-aim locks movement; cooldown HUD
ticks down; each of the 6 spells behaves like POC.

## M2 — Movement polish → `v0.2.0`

- [ ] Port POC tuning: `MOVE_MAX_SPEED 140`, acceleration `345`, friction `690`,
      velocity `move_toward`, acceleration/deceleration feel on analogue stick
- [ ] Port `money wizard` sprite + AnimationPlayer (Idle/Move/facing flip `Flippable` node)
- [ ] Palette shader port (per-player colors via `Constants` autoload)
- [ ] `HitState` = knockback drift + settle → back to Idle (animation sync)
- [ ] Cast animations per spell TYPE (CastOffensive/CastDefensive/CastSmoke/CastUtility),
      animation speed scaled to cast delay
- [ ] Stick deadzone/aim retention tuning (keep last nonzero direction)
- [ ] Cast marker/aim indicator polish

**Tests:** state machine transitions Idle↔Move↔Aim (mocked input), facing-flip math,
`move_toward` velocity integration. **Verify (manual):** movement feels like POC;
cast/hit animations sync; aim sprite rotation smoothing.

## M3 — Spell selection → `v0.3.0`

- [ ] `MatchManager` (autoload or main-scene node): `SELECTING → RUNNING → GAME_OVER`
      (state machine ready for future rounds/gold without rework)
- [ ] Arcade loadout UI: stick-driven focus navigation, pick up to 6 spells into slots,
      2 reserved consumable slots (empty for now)
- [ ] Selection applies to Unit: `add_ability` + `try_grant` (revoke/replace supported)
- [ ] `spells_are_ready` flow → all players ready → match starts (port of POC ready-gate)
- [ ] HUD spell slots rebuild after selection (icons + cooldowns)

**Tests:** loadout apply → `get_runtime_abilities` contains picks; MAX 6/duplicates
rejection; ready-gate aggregation; SELECTING→RUNNING transition. **Verify (manual):**
full pick flow with stick only; HUD rebuilds; both players ready → match starts.

## M4 — Rest of the spells → `v0.4.0`

- [ ] Hook (POC: fireball params with negative knockback = pull; give it proper behavior)
- [ ] Blink (new-project instant teleport) kept & wired as INSTANT tap-cast
- [ ] Consumable slot architecture (usable items; content later)
- [ ] Balance pass across all spells (damage, cooldowns, curves)

**Tests:** hook pull impulse sign/direction; consumable slots reject spells and vice
versa. **Verify (manual):** each spell slot populated by a selection run (8 slots,
2 empty consumables).

## M5 — Arena shrink → `v0.5.0`

- [ ] Port `tilemap_arena.gd`: circular map mask, shrink timer, redraw only removed ring,
      edge tiles → animated lava (MagmaTileAnimation assets)
- [ ] Lava group → `Unit` DoT: transient DamageBuff ticks while standing on lava
      (replaces POC `dot` float)
- [ ] Match flow closure: lava death / eliminations → win screen ("Player X took a big L"),
      restart button, menu/title scene port
- [ ] Dynamic match camera: midpoint follow + zoom-to-fit with safe margins

**Tests:** circle mask math (inside/edge/outside radius), ring-redraw deltas, DoT tick
applies as attribute buff. **Verify (manual):** survive to shrink phase; lava DoT ticks;
full match → win screen → restart.

### M5.5 — Warlock knockback scaling (first thing after arena) → `v0.5.1`

- [ ] DamagePoints attribute lands on every `take_hit` (added in M1 pipeline)
- [ ] Knockback impulse scaled by victim DamagePoints: `impulse = dir * base * (1 + dp * k)`
- [ ] HUD/tuning to make accumulation visible (damage % feedback)

**Tests:** knockback scaling formula unit tests (dp=0 → base, dp high → amplified),
DamagePoints accrues on repeated hits. **Verify (manual):** repeated damage visibly
launches the victim harder — the Warlock rule.

## M6 — Shelved (do not schedule yet)

- SFX/music/taunts port (all audio assets are in the POC)
- Consumable content (items/effects)
- Rounds & gold economy, shop UI (drag_and_drop addon stays parked for this)
- Win screen polish, bots, player count > 2

---

## Phase LAST — Godot 4.7 engine upgrade (deferred by user)

Runs after all gameplay milestones (M1–M5.5); dev floor until then is 4.6.3.

- [ ] Flip `config/features` → `("4.7", "Forward Plus")` and swap the local
      `/Applications/Godot.app` to a 4.7.x build; re-pin CI to 4.7 (single PR)
- **Already rehearsed 2026-10-12**: project verified fully green on the official
  4.7.2-stable binary (clean `.godot` import, ClassDB probe, gdUnit4 suite) — both GDExtensions
  forward-load fine, so residual risk is low. Watch-out: a 4.7 editor opening/saving this
  project rewrites `config/features` and mismatched caches can crash a 4.6 session —
  keep one engine pinned at a time while this is deferred

---

## Defaults assumed (flag if wrong)

- `Unit` stays the player class name (bot-friendly)
- Old POC visuals ported as intermediate art (money wizard, spell icons)
- P1 keyboard binding parity with POC (arrows), P0 WASD — arcade panels override later
- Godot 4.6.x is the dev floor for the entire port (4.7 upgrade deferred to Phase LAST)

## Risks

- **Engine upgrade — deferred to Phase LAST**: rehearsed green on 4.7.2 binary already
  (import + probe + tests); remaining risk is the local editor-app swap only, plus the
  features-rewrite hazard above while engines are mixed
- GDExtension binaries: attributes must build (Phase 0) before any scene using
  `AttributeContainer` loads; abilities mac path already fixed
- GGAS lifecycle overlaps: aim-hold + tap-cast must not fight `cooldown_active`
  (guard via `is_ability_*` checks in input handler)
- gdUnit4 pinned to v6.2.x (covers 4.6–4.7.1); SceneRunner-style tests can be flaky —
  logic-first tests only, visuals stay on the manual checklists
- POC parity vs new pipelines: flat knockback until M5.5 by design — don't "fix" early
- CI minutes: public repo = unlimited standard minutes; keep headless runs lean (~2–3 min)