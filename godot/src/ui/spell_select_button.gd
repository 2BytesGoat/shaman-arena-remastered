class_name SpellSelectButton extends Panel

@export var icon_rect: TextureRect
@export var name_label: Label
@export var focus_rect: Control

var ability: Ability


func setup(value: Ability) -> void:
	ability = value
	if ability is BaseAbility:
		icon_rect.texture = (ability as BaseAbility).ICON
	name_label.text = String(ability.ability_name) if ability != null else ""


func set_focused(value: bool) -> void:
	focus_rect.visible = value
