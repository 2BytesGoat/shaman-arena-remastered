extends Node

@export var ability_container: AbilityContainer
@export var button_container: HBoxContainer

var ability_button_mapping = {}


func _ready() -> void:
	for abutton: AbilityButton in button_container.get_children():
		var button_idx: int = abutton.get_index()
		var ability: Ability = ability_container.abilities[button_idx]
		abutton.button.pressed.connect(_on_ability_button_pressed.bind(ability.ability_name))
		ability_button_mapping[ability.ability_name] = abutton


func _on_ability_button_pressed(ability_name: String) -> void:
	var abutton: AbilityButton = ability_button_mapping[ability_name]
	abutton.button.disabled = true
	ability_container.try_activate(ability_name)


func _on_ability_container_cooldown_start(ability: Ability) -> void:
	var abutton = ability_button_mapping[ability.ability_name]
	abutton.start_cooldown(ability)


func _on_ability_container_ability_ended(ability: Ability) -> void:
	var abutton = ability_button_mapping[ability.ability_name]
	abutton.stop_cooldown()
	abutton.button.disabled = false
