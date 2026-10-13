class_name Unit extends CharacterBody2D

signal player_died(player_number: int)

const MOVE_MAX_SPEED := 140.0
const MOVE_ACCELERATION := 345.0
const MOVE_FRICTION := 690.0
const TURN_ACCELERATION := 15.0
const STICK_DEADZONE := 0.2
const SPELL_SPAWN_OFFSET := 250.0
const MAX_SPELL_SLOTS := 7

@export var aim_sprite: Sprite2D
@export var attribute_container: AttributeContainer
@export var ability_container: AbilityContainer
@export var PLAYER_CONTROLLER := 0
@export var max_health := 10.0

@onready var state_machine: StateMachine = $StateMachine

var move_direction := Vector2.ZERO
var cast_direction := Vector2.RIGHT
var cast_angle := 0.0
var aiming := false
var hit_locked := false
var player_dead := false

var ability_slots: Array[Ability] = []
var _last_move_direction := Vector2.RIGHT


func _ready() -> void:
	ability_slots = ability_container.get_initial_abilities()
	attribute_container.apply_buff(InitializeAttributes.new(max_health))
	attribute_container.attribute_changed.connect(_on_attribute_changed)
	ability_container.cooldown_start.connect(_on_spell_cooldown_start)


func _physics_process(delta: float) -> void:
	_update_aim_sprite(delta)
	if player_dead:
		return
	_update_move_direction()
	_apply_movement(delta)
	if not aiming and not hit_locked:
		_handle_spell_input()


func action_name(suffix: String) -> StringName:
	return StringName("player_%d_%s" % [PLAYER_CONTROLLER, suffix])


func spell_action(slot: int) -> StringName:
	return action_name("spell_%d" % slot)


func spell_spawn_position(direction: Vector2) -> Vector2:
	return global_position + direction * SPELL_SPAWN_OFFSET


func facing_direction() -> Vector2:
	return _last_move_direction


func can_player_move() -> bool:
	return not aiming and not hit_locked and not _is_spell_windup_active()


func try_cast(ability: Ability, direction: Vector2) -> int:
	cast_direction = direction
	cast_angle = direction.angle()
	return ability_container.try_activate(ability)


func update_cast_direction() -> void:
	var stick := Vector2(
		Input.get_axis(action_name("left"), action_name("right")),
		Input.get_axis(action_name("up"), action_name("down"))
	)
	if stick.length() > STICK_DEADZONE:
		cast_direction = stick.normalized()
		cast_angle = cast_direction.angle()


func take_hit(source: Unit, damage: float, knockback: float, impact_direction: Vector2) -> void:
	if player_dead:
		return
	if damage <= 0.0 and knockback <= 0.0:
		return
	if damage > 0.0:
		attribute_container.apply_buff(HealthDamage.new(damage))
		if player_dead:
			return
	velocity += impact_direction * knockback
	hit_locked = true
	state_machine.transition_to("Damaged")


static func is_lethal(attribute_name: String, new_value: float) -> bool:
	return attribute_name == AttributeNames.HEALTH and new_value <= 0.0


func _update_aim_sprite(delta: float) -> void:
	if aim_sprite == null:
		return
	var difference := wrapf(cast_angle - aim_sprite.rotation, -PI, PI)
	aim_sprite.rotation += clampf(difference, -TURN_ACCELERATION * delta, TURN_ACCELERATION * delta)


func _update_move_direction() -> void:
	if not can_player_move():
		move_direction = Vector2.ZERO
		return
	move_direction = Vector2(
		Input.get_axis(action_name("left"), action_name("right")),
		Input.get_axis(action_name("up"), action_name("down"))
	).normalized()
	if move_direction != Vector2.ZERO:
		_last_move_direction = move_direction


func _apply_movement(delta: float) -> void:
	if move_direction != Vector2.ZERO:
		velocity = velocity.move_toward(move_direction * MOVE_MAX_SPEED, MOVE_ACCELERATION * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, MOVE_FRICTION * delta)
	move_and_slide()


func _handle_spell_input() -> void:
	for slot in mini(ability_slots.size(), MAX_SPELL_SLOTS):
		if not Input.is_action_just_pressed(spell_action(slot)):
			continue
		var ability := ability_slots[slot]
		if ability_container.is_ability_cooldown_active(ability) or ability_container.is_ability_active(ability):
			return
		state_machine.transition_to("Aim", {"slot": slot, "ability": ability})
		return


func _is_spell_windup_active() -> bool:
	for runtime_ability in ability_container.get_runtime_abilities():
		if runtime_ability.is_active():
			return true
	return false


func _on_spell_cooldown_start(ability: Ability) -> void:
	if ability is BaseAbility:
		(ability as BaseAbility).cast(self, cast_direction)


func _on_attribute_changed(attribute: Variant, _previous_value: float, new_value: float) -> void:
	if attribute == null:
		return
	if is_lethal(String(attribute.get_attribute_name()), new_value):
		_die()


func _die() -> void:
	if player_dead:
		return
	player_dead = true
	state_machine.transition_to("Dead")
	player_died.emit(PLAYER_CONTROLLER)
