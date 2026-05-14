class_name BlinkAbility extends Ability

const ABILITY_NAME := "BlinkAbility"
var MAX_DISTANCE = 300
var DURATION = 0
var COOLDOWN = 5


func _init(_ability_name = ABILITY_NAME):
	ability_name = _ability_name


func _on_activate(ability_container: AbilityContainer, _runtime_ability: RuntimeAbility) -> void:
	var unit: Unit = ability_container.get_parent()
	var dst_point = unit.global_position + unit.cast_direction * MAX_DISTANCE
	unit.global_position = dst_point


func _get_duration(_ability_container: AbilityContainer) -> float:
	return DURATION


func _get_cooldown(_ability_container: AbilityContainer) -> float:
	return COOLDOWN
