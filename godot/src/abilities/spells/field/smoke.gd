class_name Smoke extends SpellScene


func cast(cast_source: Unit, _direction: Vector2) -> void:
	source = cast_source
	global_position = cast_source.global_position


func _on_area_entered(area: Area2D) -> void:
	HitArea.apply(self, area, source, DAMAGE, KNOCKBACK)


func _on_sprite_2d_animation_finished() -> void:
	queue_free()
