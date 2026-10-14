extends GdUnitTestSuite


func _make_unit(controller := 0) -> Unit:
	var scene: PackedScene = load("res://src/player/player.tscn")
	var unit := scene.instantiate() as Unit
	unit.set_physics_process(false)
	add_child(unit)
	unit.PLAYER_CONTROLLER = controller
	auto_free(unit)
	return unit


func test_visuals_owns_sprite_subtree() -> void:
	var unit := _make_unit()
	await get_tree().process_frame
	assert_bool(unit.visuals is PlayerVisuals).is_true()
	assert_bool(unit.visuals is Node2D).is_true()
	assert_object(unit.visuals.get_node_or_null("Flippable/PlayerSprite")).is_not_null()
	assert_object(unit.visuals.get_node_or_null("Flippable/LargeShadow")).is_not_null()
	assert_object(unit.visuals.get_node_or_null("AimSprite")).is_not_null()


func test_aim_sprite_is_outside_flip_node() -> void:
	var unit := _make_unit()
	await get_tree().process_frame
	var flippable := unit.visuals.get_node("Flippable")
	assert_bool(flippable.is_ancestor_of(unit.visuals.get_node("AimSprite"))).is_false()


func test_set_facing_flips_only_the_sprite_subtree() -> void:
	var unit := _make_unit()
	await get_tree().process_frame
	unit.visuals.set_facing(-1.0)
	assert_float(unit.visuals.flippable.scale.x).is_equal(-1.0)
	assert_float(unit.visuals.aim_sprite.scale.x).is_equal_approx(0.1, 0.001)


func test_animation_track_paths_resolve() -> void:
	var unit := _make_unit()
	await get_tree().process_frame
	var unresolved: Array[String] = []
	var count := 0
	for library_name in unit.animation_player.get_animation_library_list():
		var library := unit.animation_player.get_animation_library(library_name)
		for animation_name in library.get_animation_list():
			var animation := library.get_animation(animation_name)
			for track in animation.get_track_count():
				count += 1
				var path := animation.track_get_path(track)
				var node_path := NodePath(path.get_concatenated_names())
				if unit.get_node_or_null(node_path) == null:
					unresolved.append("%s/%s: %s" % [library_name, animation_name, path])
	assert_int(count).is_greater(0)
	assert_array(unresolved).is_empty()


func test_palette_applies_player_colors() -> void:
	var unit := _make_unit(1)
	await get_tree().process_frame
	unit.visuals.apply_palette()
	var material := unit.material as ShaderMaterial
	assert_object(material).is_not_null()
	assert_object(material.get_shader_parameter("to_colors")).is_not_null()
	assert_int(Array(material.get_shader_parameter("to_colors")).size()).is_greater(0)


func test_aim_sprite_smoothing_is_rate_limited() -> void:
	var unit := _make_unit()
	await get_tree().process_frame
	unit.cast_angle = PI / 2.0
	unit.visuals.aim_sprite.rotation = 0.0
	unit.visuals.update_aim_sprite(0.001)
	assert_float(unit.visuals.aim_sprite.rotation).is_between(0.0001, Unit.TURN_ACCELERATION * 0.001 + 0.0001)
