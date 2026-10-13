class_name Smoke extends SpellScene


func cast(cast_source: Unit, _direction: Vector2) -> void:
	source = cast_source
	global_position = cast_source.global_position


func _on_sprite_2d_animation_finished() -> void:
	queue_free()
