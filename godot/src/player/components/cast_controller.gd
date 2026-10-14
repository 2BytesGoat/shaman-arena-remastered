class_name CastController extends Node

@export var unit: Unit


func try_cast(ability: Ability, direction: Vector2) -> int:
	unit.cast_direction = direction
	unit.cast_angle = direction.angle()
	var result := unit.ability_container.try_activate(ability)
	if result == RuntimeAbility.ABILITY_EVENT_TYPE_ACTIVATED_DURATION_STARTED:
		_play_cast_animation(ability, direction)
	return result


func update_direction() -> void:
	var stick := Vector2(
		Input.get_axis(unit.action_name("left"), unit.action_name("right")),
		Input.get_axis(unit.action_name("up"), unit.action_name("down"))
	)
	if stick.length() > Unit.STICK_DEADZONE:
		unit.cast_direction = stick.normalized()
		unit.cast_angle = unit.cast_direction.angle()


func handle_spell_input() -> void:
	for slot in mini(unit.ability_slots.size(), Unit.MAX_SPELL_SLOTS):
		if not Input.is_action_just_pressed(unit.spell_action(slot)):
			continue
		var ability := unit.ability_slots[slot]
		if unit.ability_container.is_ability_active(ability):
			try_abort_cast(ability)
			return
		if unit.ability_container.is_ability_cooldown_active(ability):
			return
		unit.state_machine.transition_to("Aim", {"slot": slot, "ability": ability})
		return


static func is_cast_interruptible(ability: Ability) -> bool:
	return not (ability is BaseAbility) or not (ability as BaseAbility).UNINTERRUPTIBLE


func try_abort_cast(ability: Ability, ignore_uninterruptible := false) -> bool:
	if not unit.ability_container.is_ability_active(ability):
		return false
	if not ignore_uninterruptible and not is_cast_interruptible(ability):
		return false
	unit.ability_container.try_end(ability)
	stop_cast_animation()
	return true


func abort_active_casts(ignore_uninterruptible := false) -> void:
	for ability in unit.ability_slots:
		try_abort_cast(ability, ignore_uninterruptible)


func is_windup_active() -> bool:
	for runtime_ability in unit.ability_container.get_runtime_abilities():
		if runtime_ability.is_active():
			return true
	return false


func on_spell_cooldown_start(ability: Ability) -> void:
	if unit.player_dead:
		return
	if ability is BaseAbility:
		(ability as BaseAbility).cast(unit, unit.cast_direction)
	stop_cast_animation()


func _play_cast_animation(ability: Ability, direction: Vector2) -> void:
	if not (ability is BaseAbility):
		return
	var base_ability := ability as BaseAbility
	if base_ability.CAST_DELAY <= 0.0:
		return
	var clip := BaseAbility.resolve_cast_animation(base_ability, unit.animation_player)
	if clip == &"":
		return
	unit.animation_player.speed_scale = BaseAbility.cast_animation_speed(
		unit.animation_player.get_animation(clip).length,
		base_ability.CAST_DELAY
	)
	unit.animation_player.play(clip)
	unit.facing_scale = Unit.facing_sign(direction, unit.facing_scale)
	unit.flippable.scale.x = unit.facing_scale


func stop_cast_animation() -> void:
	unit.animation_player.speed_scale = 1.0
	unit.animation_player.play(&"Idle")
