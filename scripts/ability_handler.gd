extends Node

@export var ability_container: AbilityContainer
@export var button_container: HBoxContainer

var ability_button_mapping = {}


func _ready() -> void:
	for button: AbilityButton in button_container.get_children():
		var button_idx: int = button.get_index()
		var ability: Ability = ability_container.abilities[button_idx]
		button.pressed.connect(_on_ability_button_pressed.bind(ability.ability_name))
		ability_button_mapping[ability.ability_name] = button


func _on_ability_button_pressed(ability_name: String) -> void:
	ability_container.try_activate(ability_name)


func _on_ability_container_cooldown_start(ability: Ability) -> void:
	var button = ability_button_mapping[ability.ability_name]
	button.start_cooldown(ability)


func _on_ability_container_cooldown_end(ability: Ability) -> void:
	var button = ability_button_mapping[ability.ability_name]
	button.stop_cooldown()
