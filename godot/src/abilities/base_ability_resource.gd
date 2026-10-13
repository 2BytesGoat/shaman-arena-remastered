class_name BaseAbilityResource extends Ability

enum ABILITY_TYPES {
	OFFENSIVE,
	DEFENSIVE,
	UTILITY,
	SMOKE
}

var MAX_DISTANCE = 300
var DURATION = 0
var COOLDOWN = 5
var TYPE = ABILITY_TYPES.SMOKE


func _init():
	ability_name = "BaseAbility"


func cast_spell(_ability_container: AbilityContainer):
	pass


func _on_activate(ability_container: AbilityContainer, _runtime_ability: RuntimeAbility) -> void:
	var tween = ability_container.create_tween()
	tween.tween_callback(func():
		cast_spell(ability_container)  # fires exactly when cast bar ends
	).set_delay(DURATION)


func _get_duration(_ability_container: AbilityContainer) -> float:
	return DURATION


func _get_cooldown(_ability_container: AbilityContainer) -> float:
	return COOLDOWN
