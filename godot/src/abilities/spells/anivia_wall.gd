class_name AniviaWall extends SpellScene


func cast(_cast_source: Unit, _direction: Vector2) -> void:
	source = null


func _on_area_entered(_area: Area2D) -> void:
	queue_free()
