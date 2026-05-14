class_name FireballAbility extends Ability

const ABILITY_NAME := "FireballAbiliy"

var DURATION = 0
var COOLDOWN = 1
var MAX_DISTANCE = 300
var ABILITY_SCENE = preload("res://scenes/abilities/fireball_scene.tscn")


func _init(_ability_name = ABILITY_NAME):
	ability_name = _ability_name


func cast_spell(ability_container):
	var unit: Unit = ability_container.get_parent()
	var spell = ABILITY_SCENE.instantiate()
	ability_container.get_owner().add_child(spell)
	spell.global_position = unit.global_position
	spell.cast(unit, unit.cast_direction)


func _on_activate(ability_container: AbilityContainer, _runtime_ability: RuntimeAbility) -> void:
	var tween = ability_container.create_tween()
	tween.tween_callback(func():
		cast_spell(ability_container)  # fires exactly when cast bar ends
	).set_delay(DURATION)


func _get_duration(_ability_container: AbilityContainer) -> float:
	return DURATION


func _get_cooldown(_ability_container: AbilityContainer) -> float:
	return COOLDOWN
