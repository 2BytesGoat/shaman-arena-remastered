extends Node

@export var ability_container: AbilityContainer


func _on_blink_button_pressed() -> void:
	ability_container.try_activate("BlinkAbility")
