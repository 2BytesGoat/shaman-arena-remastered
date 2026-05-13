class_name BlinkAbility extends Ability

const ABILITY_NAME := "BlinkAbility"
var MAX_DISTANCE = 300
var COOLDOWN = 10

#signal cooldown_started
#signal ability_ended


func _init(_ability_name = ABILITY_NAME):
	ability_name = _ability_name


func _on_activate(ability_container: AbilityContainer, _runtime_ability: RuntimeAbility) -> void:
	var unit = ability_container.get_parent()
	var mouse_distance = unit.global_position.distance_to(Utils.get_mouse_global_position())
	var cast_distance = min(mouse_distance, MAX_DISTANCE)
	var dst_point = unit.global_position + Vector2(cos(unit.cast_angle), sin(unit.cast_angle)) * cast_distance
	unit.global_position = dst_point

func _get_cooldown(_ability_container: AbilityContainer) -> float:
	return COOLDOWN
