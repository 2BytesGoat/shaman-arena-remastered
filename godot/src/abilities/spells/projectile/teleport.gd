class_name Teleport extends ProjectileSpell


func _exit_tree() -> void:
	if is_instance_valid(source):
		source.global_position = global_position
