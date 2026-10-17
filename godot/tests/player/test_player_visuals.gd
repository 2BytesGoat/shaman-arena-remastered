extends GdUnitTestSuite

const AbilityPaths := preload("res://tests/support/ability_paths.gd")


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


func test_play_defers_locomotion_but_not_oneshots_while_casting() -> void:
	var unit := _make_unit()
	await get_tree().process_frame
	var smoke: BaseAbility = load(AbilityPaths.path("smoke"))
	var picks: Array[Ability] = [smoke]
	unit.apply_loadout(picks)
	unit.ability_container.try_activate(smoke)
	assert_bool(unit.cast_handler.is_windup_active()).is_true()

	unit.visuals.play(&"Hit")
	assert_str(String(unit.animation_player.current_animation)).is_equal("Hit")

	unit.visuals.play(&"Idle")
	assert_str(String(unit.animation_player.current_animation)).is_equal("Hit")

	unit.try_abort_cast(smoke, true)
	unit.visuals.play(&"Idle")
	assert_str(String(unit.animation_player.current_animation)).is_equal("Idle")


func test_aim_pose_defers_to_an_active_cast_and_returns_on_abort() -> void:
	var unit := _make_unit()
	await get_tree().process_frame
	var smoke: BaseAbility = load(AbilityPaths.path("smoke"))
	var picks: Array[Ability] = [smoke]
	unit.apply_loadout(picks)
	unit.try_cast(smoke, Vector2.RIGHT)
	assert_str(String(unit.animation_player.current_animation)).is_equal("CastSmoke")

	unit.state_machine.transition_to("Aim", {"slot": 0, "ability": smoke})
	assert_str(String(unit.animation_player.current_animation)).is_equal("CastSmoke")

	assert_bool(unit.try_abort_cast(smoke, true)).is_true()
	assert_str(String(unit.animation_player.current_animation)).is_equal("Aim")


func test_aim_sprite_smoothing_is_rate_limited() -> void:
	var unit := _make_unit()
	await get_tree().process_frame
	unit.cast_angle = PI / 2.0
	unit.visuals.aim_sprite.rotation = 0.0
	unit.visuals.update_aim_sprite(0.001)
	assert_float(unit.visuals.aim_sprite.rotation).is_between(0.0001, PlayerVisuals.AIM_TURN_SPEED * 0.001 + 0.0001)


func test_spell_spawn_position_is_the_aim_icons_drawn_position() -> void:
	var unit := _make_unit()
	await get_tree().process_frame
	var sprite := unit.visuals.aim_sprite
	assert_bool(unit.spell_spawn_position().is_equal_approx(sprite.to_global(sprite.offset))).is_true()
	assert_bool(unit.spell_spawn_position().is_equal_approx(unit.global_position)).is_false()


func test_spell_spawn_position_orbits_with_the_aim_icon() -> void:
	var unit := _make_unit()
	await get_tree().process_frame
	unit.visuals.aim_sprite.rotation = 0.0
	var right := unit.spell_spawn_position() - unit.global_position
	unit.visuals.aim_sprite.rotation = PI / 2.0
	var down := unit.spell_spawn_position() - unit.global_position
	assert_bool(down.is_equal_approx(right.rotated(PI / 2.0))).is_true()
