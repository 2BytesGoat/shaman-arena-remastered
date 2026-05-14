class_name BlinkAbility extends BaseAbilityResource


func _init():
	ability_name = "BlinkAbility"
	MAX_DISTANCE = 300
	DURATION = 0
	COOLDOWN = 5


func cast_spell(ability_container):
	var unit: Unit = ability_container.get_parent()
	var dst_point = unit.global_position + unit.cast_direction * MAX_DISTANCE
	unit.global_position = dst_point
