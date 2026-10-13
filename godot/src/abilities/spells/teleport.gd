class_name Teleport extends SpellScene


func _exit_tree() -> void:
	if source != null:
		source.global_position = global_position
