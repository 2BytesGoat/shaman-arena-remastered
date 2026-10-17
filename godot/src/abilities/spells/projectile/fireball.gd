class_name Fireball extends ProjectileSpell


func _on_move(time: float) -> void:
	var sprite_scale := minf(time * 5.0, 1.0)
	scale = Vector2(sprite_scale, sprite_scale)
