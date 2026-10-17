class_name AbilityHandler extends Node

@export var ability_container: AbilityContainer
@export var button_container: HBoxContainer
@export var ability_button_scene: PackedScene

var ability_buttons := {}


func _ready() -> void:
	rebuild(ability_container.get_initial_abilities())
	ability_container.cooldown_start.connect(_on_ability_container_cooldown_start)
	ability_container.cooldown_end.connect(_on_ability_container_cooldown_end)
	ability_container.ability_ended.connect(_on_ability_container_ability_ended)


func rebuild(abilities: Array[Ability]) -> void:
	for child in button_container.get_children():
		button_container.remove_child(child)
		child.queue_free()
	ability_buttons.clear()
	for ability in abilities:
		var button := ability_button_scene.instantiate() as AbilityButton
		button_container.add_child(button)
		button.setup(ability)
		ability_buttons[ability] = button
	for _index in Loadout.CONSUMABLE_SLOTS:
		var button := ability_button_scene.instantiate() as AbilityButton
		button_container.add_child(button)
		button.setup_empty()


func _on_ability_container_cooldown_start(ability: Ability) -> void:
	if ability_buttons.has(ability):
		(ability_buttons[ability] as AbilityButton).start_cooldown(ability_container.get_runtime_ability(ability))


func _on_ability_container_cooldown_end(ability: Ability) -> void:
	_stop_cooldown(ability)


func _on_ability_container_ability_ended(ability: Ability) -> void:
	_stop_cooldown(ability)


func _stop_cooldown(ability: Ability) -> void:
	if ability_buttons.has(ability):
		(ability_buttons[ability] as AbilityButton).stop_cooldown()
