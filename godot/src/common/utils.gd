extends Node


func get_mouse_global_position():
	var viewport = get_viewport()
	var mouse_pos = viewport.get_mouse_position()
	return viewport.get_canvas_transform().affine_inverse() * mouse_pos


func instantiate_object_in_scene(scene: PackedScene, global_position: Vector2) -> Node:
	var current_scene := get_tree().current_scene
	var instance := scene.instantiate()
	current_scene.call_deferred("add_child", instance)
	instance.global_position = global_position
	return instance
