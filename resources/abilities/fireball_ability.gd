class_name FireballAbility extends BaseAbilityResource

var ABILITY_SCENE = preload("res://scenes/abilities/fireball_scene.tscn")


func _init():
	ability_name = "FireballAbiliy"
	MAX_DISTANCE = 300
	DURATION = 0
	COOLDOWN = 5
	TYPE = ABILITY_TYPES.OFFENSIVE


func cast_spell(ability_container):
	var unit: Unit = ability_container.get_parent()
	var spell = ABILITY_SCENE.instantiate()
	ability_container.get_owner().add_child(spell)
	spell.global_position = unit.global_position
	spell.cast(unit, unit.cast_direction)
