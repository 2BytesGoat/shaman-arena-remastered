class_name Unit extends CharacterBody2D

signal player_died(player_number: int)
signal loadout_applied

const PLAYERS_GROUP := &"players"

const MOVE_MAX_SPEED := 140.0
const MOVE_ACCELERATION := 345.0
const MOVE_FRICTION := 690.0
const MAX_SPELL_SLOTS := Loadout.MAX_SPELLS
## Lava burn: one `HealthDamage` tick per second while the hurtbox overlaps magma. Flat damage
## (`dot` float): no hit state, no cast abort, no knockback.
const LAVA_TICK_INTERVAL := 1.0
const LAVA_DAMAGE_PER_TICK := 25.0

enum ControllerType { NONE, LOCAL }

@export var attribute_container: AttributeContainer
@export var ability_container: AbilityContainer
@export var PLAYER_CONTROLLER := 0
@export var controller_type: ControllerType = ControllerType.NONE:
	set = _on_controller_type_changed
@export var max_health := 100.0

@onready var state_machine: StateMachine = $StateMachine
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var ability_handler: AbilityHandler = $AbilityHandler
@onready var hud_margin: MarginContainer = $CanvasLayer/MarginContainer
@onready var cast_handler: CastHandler = $CastHandler
@onready var visuals: PlayerVisuals = $PlayerVisuals

var controller: PlayerController
var move_direction := Vector2.ZERO
var cast_direction := Vector2.RIGHT
var cast_angle := 0.0
var aiming := false
var aiming_slot := -1
var release_cast_requested := false
var hit_locked := false
var player_dead := false
var is_match_ready := false
var facing_scale := 1.0
var spawn_position := Vector2.ZERO
## Magma tiles currently overlapping the hurtbox; the burn ticks while this is above zero.
var lava_contacts := 0

## Assigned by `MatchManager`; the draft pool is seeded from its basic spells.
var character_class: CharacterClass

var ability_slots: Array[Ability] = []
var _last_move_direction := Vector2.RIGHT
var _applied_controller_type := -1
var _lava_burn_elapsed := 0.0


func _enter_tree() -> void:
	add_to_group(PLAYERS_GROUP)


func _ready() -> void:
	spawn_position = global_position
	ability_slots = ability_container.get_initial_abilities()
	attribute_container.apply_buff(InitializeAttributes.new(max_health))
	attribute_container.attribute_changed.connect(_on_attribute_changed)
	var hurtbox := $Hurtbox as Area2D
	hurtbox.body_entered.connect(_on_hurtbox_body_entered)
	hurtbox.body_exited.connect(_on_hurtbox_body_exited)
	ability_container.cooldown_start.connect(cast_handler.on_spell_cooldown_start)
	visuals.apply_palette()
	visuals.layout_hud()


func _physics_process(delta: float) -> void:
	if player_dead or not is_match_ready:
		return
	if controller:
		controller.update(delta)
	_apply_movement(delta)
	_update_facing()
	visuals.update_aim_sprite(delta)
	update_lava_burn(delta)


## Where spells leave the unit: the aim icon's drawn world position (offset included).
func spell_spawn_position() -> Vector2:
	return visuals.aim_icon_position()


func facing_direction() -> Vector2:
	return _last_move_direction


func can_player_move() -> bool:
	return not aiming and not hit_locked and not cast_handler.is_windup_active()


func set_move_input(direction: Vector2) -> void:
	if not can_player_move():
		move_direction = Vector2.ZERO
		return
	move_direction = direction.normalized()
	if move_direction != Vector2.ZERO:
		_last_move_direction = move_direction


func set_aim_input(direction: Vector2) -> void:
	if direction.is_zero_approx():
		return
	cast_direction = direction.normalized()
	cast_angle = cast_direction.angle()


func request_cast(slot: int) -> void:
	if player_dead or not is_match_ready or aiming or hit_locked:
		return
	if slot < 0 or slot >= mini(ability_slots.size(), MAX_SPELL_SLOTS):
		return
	var ability := ability_slots[slot]
	# A released cast commits: a re-press during the cast delay is ignored.
	if ability_container.is_ability_active(ability):
		return
	if ability_container.is_ability_cooldown_active(ability):
		return
	if ability is BaseAbility and (ability as BaseAbility).CAST_MODE == BaseAbility.CastMode.INSTANT:
		try_cast(ability, facing_direction())
		return
	state_machine.transition_to(AnimationSlots.AIM, {"slot": slot, "ability": ability})


func request_release() -> void:
	if aiming:
		release_cast_requested = true


func consume_release_request() -> bool:
	var requested := release_cast_requested
	release_cast_requested = false
	return requested


func set_controller(new_controller: PlayerController) -> void:
	if not is_node_ready():
		await ready
	if is_instance_valid(controller):
		controller.queue_free()
	controller = new_controller
	if controller:
		add_child(controller)


func _on_controller_type_changed(new_type: ControllerType) -> void:
	controller_type = new_type
	if _applied_controller_type == new_type:
		return
	_applied_controller_type = new_type
	set_controller(_make_controller())


func _make_controller() -> PlayerController:
	match controller_type:
		ControllerType.LOCAL:
			return LocalPlayerController.new(self, PLAYER_CONTROLLER)
	return null


static func facing_sign(direction: Vector2, current: float) -> float:
	if is_zero_approx(direction.x):
		return current
	return signf(direction.x)


static func step_velocity(current: Vector2, direction: Vector2, delta: float) -> Vector2:
	if direction != Vector2.ZERO:
		return current.move_toward(direction * MOVE_MAX_SPEED, MOVE_ACCELERATION * delta)
	return current.move_toward(Vector2.ZERO, MOVE_FRICTION * delta)


func try_cast(ability: Ability, direction: Vector2) -> int:
	return cast_handler.try_cast(ability, direction)


func try_abort_cast(ability: Ability, ignore_uninterruptible := false) -> bool:
	return cast_handler.try_abort_cast(ability, ignore_uninterruptible)


func apply_loadout(picks: Array[Ability]) -> void:
	cast_handler.abort_active_casts(true)
	for ability in ability_slots:
		ability_container.try_revoke(ability)
		ability_container.remove_ability(ability)
	ability_slots.clear()
	for ability in picks:
		if ability == null or ability_slots.has(ability):
			continue
		ability_container.add_ability(ability)
		ability_container.try_grant(ability)
		ability_slots.append(ability)
	ability_handler.rebuild(ability_slots)
	loadout_applied.emit()


## Clears running cooldowns so a fresh round starts with every spell ready. GGAS has
## no direct reset API: `revoke` clears the cooldown/duration timers and emits `cooldown_end`
## (which stops the HUD fill), and `grant` makes the ability castable again. Only cooling
## abilities are touched, so an in-flight cast (duration active) is never silently cancelled.
func reset_ability_cooldowns() -> void:
	for ability in ability_slots:
		if ability_container.is_ability_cooldown_active(ability):
			ability_container.try_revoke(ability)
			ability_container.try_grant(ability)


## Puts the unit back into play for the next round: at its spawn point, full health, idle,
## every spell off cooldown, no lingering lava burn. The spell pool is left alone.
func respawn() -> void:
	player_dead = false
	hit_locked = false
	aiming = false
	aiming_slot = -1
	release_cast_requested = false
	velocity = Vector2.ZERO
	move_direction = Vector2.ZERO
	lava_contacts = 0
	_lava_burn_elapsed = 0.0
	global_position = spawn_position
	attribute_container.apply_buff(InitializeAttributes.new(max_health))
	reset_ability_cooldowns()
	state_machine.transition_to(AnimationSlots.IDLE)


func take_hit(_source: Unit, damage: float, knockback: float, impact_direction: Vector2) -> void:
	if player_dead:
		return
	if damage <= 0.0 and knockback <= 0.0:
		return
	cast_handler.abort_active_casts()
	if damage > 0.0:
		attribute_container.apply_buff(HealthDamage.new(damage))
		if player_dead:
			return
	velocity += impact_direction * knockback
	hit_locked = true
	state_machine.transition_to(AnimationSlots.HIT)


## Lava burn: while alive and the hurtbox overlaps magma, one `HealthDamage`
## every `LAVA_TICK_INTERVAL` seconds. Public so the cadence is unit-testable without
## physics.
func update_lava_burn(delta: float) -> void:
	if player_dead:
		return
	if lava_contacts <= 0:
		_lava_burn_elapsed = 0.0
		return
	_lava_burn_elapsed += delta
	var ticks := lava_ticks_due(_lava_burn_elapsed, LAVA_TICK_INTERVAL)
	if ticks <= 0:
		return
	_lava_burn_elapsed -= float(ticks) * LAVA_TICK_INTERVAL
	attribute_container.apply_buff(HealthDamage.new(LAVA_DAMAGE_PER_TICK * float(ticks)))


## Whole burn ticks owed for `elapsed` seconds of contact (pure: no scene needed).
static func lava_ticks_due(elapsed: float, interval: float) -> int:
	if interval <= 0.0:
		return 0
	return floori(elapsed / interval)


func _on_hurtbox_body_entered(body: Node2D) -> void:
	if body.is_in_group("Lava"):
		lava_contacts += 1


func _on_hurtbox_body_exited(body: Node2D) -> void:
	if body.is_in_group("Lava"):
		lava_contacts = maxi(lava_contacts - 1, 0)


static func is_lethal(attribute_name: String, new_value: float) -> bool:
	return attribute_name == AttributeNames.HEALTH and new_value <= 0.0


func _update_facing() -> void:
	var direction := cast_direction if aiming else _last_move_direction
	facing_scale = facing_sign(direction, facing_scale)
	visuals.set_facing(facing_scale)


func _apply_movement(delta: float) -> void:
	velocity = step_velocity(velocity, move_direction, delta)
	move_and_slide()


func _on_attribute_changed(attribute: Variant, _previous_value: float, new_value: float) -> void:
	if attribute == null:
		return
	if is_lethal(String(attribute.get_attribute_name()), new_value):
		_die()


func _die() -> void:
	if player_dead:
		return
	player_dead = true
	cast_handler.abort_active_casts(true)
	state_machine.transition_to(AnimationSlots.DEAD)
	player_died.emit(PLAYER_CONTROLLER)
