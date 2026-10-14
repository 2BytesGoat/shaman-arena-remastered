extends GdUnitTestSuite


func _make_unit() -> Unit:
	var scene: PackedScene = load("res://src/player/player.tscn")
	var unit := scene.instantiate() as Unit
	unit.set_physics_process(false)
	add_child(unit)
	unit.get_node("StateMachine").set_physics_process(false)
	unit.apply_loadout(_picks(["fireball", "smoke"]))
	auto_free(unit)
	await get_tree().process_frame
	return unit


func _picks(names: Array) -> Array[Ability]:
	var picks: Array[Ability] = []
	for name in names:
		picks.append(load("res://src/resources/abilities/%s_ability.tres" % name))
	return picks


func _ability(unit: Unit, ability_id: StringName) -> BaseAbility:
	for ability in unit.ability_slots:
		if ability.ability_name == ability_id:
			return ability as BaseAbility
	return null


func test_initial_state_plays_idle() -> void:
	var unit: Unit = await _make_unit()
	assert_str(unit.state_machine.state.name).is_equal("Idle")
	assert_str(String(unit.animation_player.current_animation)).is_equal("Idle")


func test_move_direction_transitions_idle_to_move() -> void:
	var unit: Unit = await _make_unit()
	unit.move_direction = Vector2.RIGHT
	unit.state_machine.state.physics_update(1.0 / 60.0)
	assert_str(unit.state_machine.state.name).is_equal("Move")
	assert_str(String(unit.animation_player.current_animation)).is_equal("Move")


func test_settled_velocity_transitions_move_to_idle() -> void:
	var unit: Unit = await _make_unit()
	unit.state_machine.transition_to("Move")
	assert_str(String(unit.animation_player.current_animation)).is_equal("Move")
	unit.move_direction = Vector2.ZERO
	unit.velocity = Vector2.ZERO
	unit.state_machine.state.physics_update(1.0 / 60.0)
	assert_str(unit.state_machine.state.name).is_equal("Idle")


func test_aim_state_locks_position() -> void:
	var unit: Unit = await _make_unit()
	unit.velocity = Vector2(140.0, 0.0)
	var fireball := _ability(unit, &"Fireball")
	unit.state_machine.transition_to("Aim", {"slot": 1, "ability": fireball})
	assert_bool(unit.aiming).is_true()
	assert_vector(unit.velocity).is_equal(Vector2.ZERO)
	unit.state_machine.transition_to("Idle")
	assert_bool(unit.aiming).is_false()


func test_cast_plays_type_slot_scaled_to_delay_and_abort_resets() -> void:
	var unit: Unit = await _make_unit()
	var fireball := _ability(unit, &"Fireball")
	assert_int(unit.try_cast(fireball, Vector2.RIGHT)).is_equal(RuntimeAbility.ABILITY_EVENT_TYPE_ACTIVATED_DURATION_STARTED)
	assert_str(String(unit.animation_player.current_animation)).is_equal("CastOffensive")
	assert_float(unit.animation_player.speed_scale).is_equal_approx(2.0, 0.001)
	assert_bool(unit.try_abort_cast(fireball)).is_true()
	assert_str(String(unit.animation_player.current_animation)).is_equal("Idle")
	assert_float(unit.animation_player.speed_scale).is_equal(1.0)


func test_smoke_cast_uses_flavor_clip() -> void:
	var unit: Unit = await _make_unit()
	var smoke := _ability(unit, &"Smoke")
	assert_int(unit.try_cast(smoke, Vector2.RIGHT)).is_equal(RuntimeAbility.ABILITY_EVENT_TYPE_ACTIVATED_DURATION_STARTED)
	assert_str(String(unit.animation_player.current_animation)).is_equal("CastSmoke")
	assert_float(unit.animation_player.speed_scale).is_equal_approx(1.0, 0.001)


func test_player_palette_applies_configured_colors() -> void:
	var unit: Unit = await _make_unit()
	var material := unit.material as ShaderMaterial
	assert_object(material).is_not_null()
	var expected := PackedColorArray(Constants.player_colors["player_0"])
	assert_bool(material.get_shader_parameter("to_colors") == expected).is_true()


func test_second_player_gets_its_own_palette() -> void:
	var scene: PackedScene = load("res://src/player/player.tscn")
	var unit := scene.instantiate() as Unit
	unit.PLAYER_CONTROLLER = 1
	unit.set_physics_process(false)
	add_child(unit)
	auto_free(unit)
	await get_tree().process_frame
	var material := unit.material as ShaderMaterial
	var expected := PackedColorArray(Constants.player_colors["player_1"])
	assert_bool(material.get_shader_parameter("to_colors") == expected).is_true()


func test_hit_state_locks_and_releases_on_animation_finish() -> void:
	var unit: Unit = await _make_unit()
	unit.take_hit(null, 1.0, 0.0, Vector2.RIGHT)
	assert_str(unit.state_machine.state.name).is_equal("Hit")
	assert_bool(unit.hit_locked).is_true()
	assert_str(String(unit.animation_player.current_animation)).is_equal("Hit")
	unit.state_machine.state._on_animation_player_animation_finished(&"Hit")
	assert_str(unit.state_machine.state.name).is_equal("Idle")
	assert_bool(unit.hit_locked).is_false()


func test_lethal_hit_transitions_to_death_animation() -> void:
	var unit: Unit = await _make_unit()
	unit.take_hit(null, 100.0, 0.0, Vector2.RIGHT)
	assert_bool(unit.player_dead).is_true()
	assert_str(unit.state_machine.state.name).is_equal("Dead")
	assert_str(String(unit.animation_player.current_animation)).is_equal("Death")


func test_lethal_hit_during_hit_state_transitions_to_death_animation() -> void:
	var unit: Unit = await _make_unit()
	unit.take_hit(null, 1.0, 0.0, Vector2.RIGHT)
	assert_str(unit.state_machine.state.name).is_equal("Hit")
	unit.take_hit(null, 9.0, 0.0, Vector2.RIGHT)
	assert_bool(unit.player_dead).is_true()
	assert_str(unit.state_machine.state.name).is_equal("Dead")
	assert_str(String(unit.animation_player.current_animation)).is_equal("Death")
