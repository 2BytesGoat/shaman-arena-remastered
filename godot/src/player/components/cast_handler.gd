class_name CastHandler extends Node

@export var unit: Unit


func try_cast(ability: Ability, direction: Vector2) -> int:
	unit.cast_direction = direction
	unit.cast_angle = direction.angle()
	var result := unit.ability_container.try_activate(ability)
	if result == RuntimeAbility.ABILITY_EVENT_TYPE_ACTIVATED_DURATION_STARTED:
		_play_cast_animation(ability, direction)
	return result


static func is_cast_interruptible(ability: Ability) -> bool:
	return not (ability is BaseAbility) or not (ability as BaseAbility).UNINTERRUPTIBLE


func try_abort_cast(ability: Ability, ignore_uninterruptible := false) -> bool:
	if not unit.ability_container.is_ability_active(ability):
		return false
	if not ignore_uninterruptible and not is_cast_interruptible(ability):
		return false
	unit.ability_container.try_end(ability)
	unit.visuals.reassert_animation()
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
	unit.visuals.reassert_animation()


func _play_cast_animation(ability: Ability, direction: Vector2) -> void:
	if not (ability is BaseAbility):
		return
	var base_ability := ability as BaseAbility
	if base_ability.CAST_DELAY <= 0.0:
		return
	var clip := BaseAbility.resolve_cast_animation(base_ability, unit.animation_player)
	if clip == &"":
		return
	unit.visuals.play_cast(clip, base_ability.CAST_DELAY)
	unit.facing_scale = Unit.facing_sign(direction, unit.facing_scale)
	unit.visuals.set_facing(unit.facing_scale)
