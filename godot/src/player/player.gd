class_name Unit extends CharacterBody2D

signal player_died(player_number: int)

const MOVE_MAX_SPEED := 140.0
const MOVE_ACCELERATION := 345.0
const MOVE_FRICTION := 690.0
const TURN_ACCELERATION := 15.0
const STICK_DEADZONE := 0.2
const SPELL_SPAWN_OFFSET := 360.0
const MAX_SPELL_SLOTS := 7

@export var aim_sprite: Sprite2D
@export var attribute_container: AttributeContainer
@export var ability_container: AbilityContainer
@export var PLAYER_CONTROLLER := 0
@export var max_health := 10.0

@onready var state_machine: StateMachine = $StateMachine
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var flippable: Node2D = $Flippable

var move_direction := Vector2.ZERO
var cast_direction := Vector2.RIGHT
var cast_angle := 0.0
var aiming := false
var hit_locked := false
var player_dead := false
var facing_scale := 1.0

var ability_slots: Array[Ability] = []
var _last_move_direction := Vector2.RIGHT


func _ready() -> void:
	ability_slots = ability_container.get_initial_abilities()
	attribute_container.apply_buff(InitializeAttributes.new(max_health))
	attribute_container.attribute_changed.connect(_on_attribute_changed)
	ability_container.cooldown_start.connect(_on_spell_cooldown_start)
	_apply_player_palette()


func _physics_process(delta: float) -> void:
	if player_dead:
		return
	_update_move_direction()
	_apply_movement(delta)
	update_cast_direction()
	_update_facing()
	if not aiming and not hit_locked:
		_handle_spell_input()
	_update_aim_sprite(delta)


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


static func facing_sign(direction: Vector2, current: float) -> float:
	if is_zero_approx(direction.x):
		return current
	return signf(direction.x)


static func step_velocity(current: Vector2, direction: Vector2, delta: float) -> Vector2:
	if direction != Vector2.ZERO:
		return current.move_toward(direction * MOVE_MAX_SPEED, MOVE_ACCELERATION * delta)
	return current.move_toward(Vector2.ZERO, MOVE_FRICTION * delta)


func play_locomotion_animation(animation_name: StringName) -> void:
	if _is_spell_windup_active():
		return
	animation_player.speed_scale = 1.0
	animation_player.play(animation_name)


func try_cast(ability: Ability, direction: Vector2) -> int:
	cast_direction = direction
	cast_angle = direction.angle()
	var result := ability_container.try_activate(ability)
	if result == RuntimeAbility.ABILITY_EVENT_TYPE_ACTIVATED_DURATION_STARTED:
		_play_cast_animation(ability, direction)
	return result


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
	_abort_active_casts()
	if damage > 0.0:
		attribute_container.apply_buff(HealthDamage.new(damage))
		if player_dead:
			return
	velocity += impact_direction * knockback
	hit_locked = true
	state_machine.transition_to("Hit")


static func is_lethal(attribute_name: String, new_value: float) -> bool:
	return attribute_name == AttributeNames.HEALTH and new_value <= 0.0


static func is_cast_interruptible(ability: Ability) -> bool:
	return not (ability is BaseAbility) or not (ability as BaseAbility).UNINTERRUPTIBLE


func try_abort_cast(ability: Ability, ignore_uninterruptible := false) -> bool:
	if not ability_container.is_ability_active(ability):
		return false
	if not ignore_uninterruptible and not is_cast_interruptible(ability):
		return false
	ability_container.try_end(ability)
	_stop_cast_animation()
	return true


func _abort_active_casts(ignore_uninterruptible := false) -> void:
	for ability in ability_slots:
		try_abort_cast(ability, ignore_uninterruptible)


func _play_cast_animation(ability: Ability, direction: Vector2) -> void:
	if not (ability is BaseAbility):
		return
	var base_ability := ability as BaseAbility
	if base_ability.CAST_DELAY <= 0.0:
		return
	var clip := BaseAbility.resolve_cast_animation(base_ability, animation_player)
	if clip == &"":
		return
	animation_player.speed_scale = BaseAbility.cast_animation_speed(
		animation_player.get_animation(clip).length,
		base_ability.CAST_DELAY
	)
	animation_player.play(clip)
	facing_scale = facing_sign(direction, facing_scale)
	flippable.scale.x = facing_scale


func _stop_cast_animation() -> void:
	animation_player.speed_scale = 1.0
	animation_player.play(&"Idle")


func _update_facing() -> void:
	var direction := cast_direction if aiming else _last_move_direction
	facing_scale = facing_sign(direction, facing_scale)
	flippable.scale.x = facing_scale


func _apply_player_palette() -> void:
	var palette: Array = Constants.player_colors.get("player_%d" % PLAYER_CONTROLLER, [])
	if palette.is_empty() or not (material is ShaderMaterial):
		return
	(material as ShaderMaterial).set_shader_parameter("to_colors", PackedColorArray(palette))


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
	velocity = step_velocity(velocity, move_direction, delta)
	move_and_slide()


func _handle_spell_input() -> void:
	for slot in mini(ability_slots.size(), MAX_SPELL_SLOTS):
		if not Input.is_action_just_pressed(spell_action(slot)):
			continue
		var ability := ability_slots[slot]
		if ability_container.is_ability_active(ability):
			try_abort_cast(ability)
			return
		if ability_container.is_ability_cooldown_active(ability):
			return
		state_machine.transition_to("Aim", {"slot": slot, "ability": ability})
		return


func _is_spell_windup_active() -> bool:
	for runtime_ability in ability_container.get_runtime_abilities():
		if runtime_ability.is_active():
			return true
	return false


func _on_spell_cooldown_start(ability: Ability) -> void:
	if player_dead:
		return
	if ability is BaseAbility:
		(ability as BaseAbility).cast(self, cast_direction)
	_stop_cast_animation()


func _on_attribute_changed(attribute: Variant, _previous_value: float, new_value: float) -> void:
	if attribute == null:
		return
	if is_lethal(String(attribute.get_attribute_name()), new_value):
		_die()


func _die() -> void:
	if player_dead:
		return
	player_dead = true
	_abort_active_casts(true)
	state_machine.transition_to("Dead")
	player_died.emit(PLAYER_CONTROLLER)
