extends Node

func get_mouse_global_position():
	var viewport = get_viewport()
	var mouse_pos = viewport.get_mouse_position()
	return viewport.get_canvas_transform().affine_inverse() * mouse_pos
