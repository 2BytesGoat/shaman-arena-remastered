class_name Unit extends CharacterBody2D

signal player_died(player_number: int)
signal loadout_applied

const PLAYERS_GROUP := &"players"

const MOVE_MAX_SPEED := 140.0
const MOVE_ACCELERATION := 345.0
const MOVE_FRICTION := 690.0
const SPELL_SPAWN_OFFSET := 360.0
const MAX_SPELL_SLOTS := Loadout.MAX_SPELLS
const CONSUMABLE_SLOTS := Loadout.CONSUMABLE_SLOTS

enum ControllerType { NONE, LOCAL }

@export var attribute_container: AttributeContainer
@export var ability_container: AbilityContainer
@export var PLAYER_CONTROLLER := 0
@export var controller_type: ControllerType = ControllerType.NONE:
	set = _on_controller_type_changed
@export var max_health := 10.0

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

var ability_slots: Array[Ability] = []
var _last_move_direction := Vector2.RIGHT
var _applied_controller_type := -1


func _enter_tree() -> void:
	add_to_group(PLAYERS_GROUP)


func _ready() -> void:
	ability_slots = ability_container.get_initial_abilities()
	attribute_container.apply_buff(InitializeAttributes.new(max_health))
	attribute_container.attribute_changed.connect(_on_attribute_changed)
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


func spell_spawn_position(direction: Vector2) -> Vector2:
	return global_position + direction * SPELL_SPAWN_OFFSET


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
	if ability_container.is_ability_active(ability):
		try_abort_cast(ability)
		return
	if ability_container.is_ability_cooldown_active(ability):
		return
	state_machine.transition_to("Aim", {"slot": slot, "ability": ability})


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
	state_machine.transition_to("Hit")


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
	state_machine.transition_to("Dead")
	player_died.emit(PLAYER_CONTROLLER)
