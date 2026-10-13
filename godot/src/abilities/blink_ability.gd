class_name BlinkAbility extends BaseAbility

const MAX_DISTANCE := 300.0


func cast(unit: Unit, direction: Vector2) -> void:
	unit.global_position += direction * MAX_DISTANCE
