extends GdUnitTestSuite

const AbilityPaths := preload("res://tests/support/ability_paths.gd")


func _make_unit(names: Array = ["fireball", "smoke"], controller_type := Unit.ControllerType.NONE) -> Unit:
	var scene: PackedScene = load("res://src/player/player.tscn")
	var unit := scene.instantiate() as Unit
	unit.controller_type = controller_type
	unit.set_physics_process(false)
	add_child(unit)
	unit.get_node("StateMachine").set_physics_process(false)
	unit.apply_loadout(_picks(names))
	unit.is_match_ready = true
	auto_free(unit)
	await get_tree().process_frame
	return unit


func _picks(names: Array) -> Array[Ability]:
	var picks: Array[Ability] = []
	for name in names:
		picks.append(load(AbilityPaths.path(name)))
	return picks


func _ability(unit: Unit, ability_id: StringName) -> BaseAbility:
	for ability in unit.ability_slots:
		if ability.ability_name == ability_id:
			return ability as BaseAbility
	return null


func test_none_controller_creates_no_controller() -> void:
	var unit := await _make_unit()
	assert_object(unit.controller).is_null()
	assert_object(unit.get_node_or_null("LocalPlayerController")).is_null()


func test_local_controller_is_a_child_of_the_unit() -> void:
	var unit := await _make_unit(["fireball"], Unit.ControllerType.LOCAL)
	assert_bool(unit.controller is LocalPlayerController).is_true()
	assert_object(unit.controller.unit).is_same(unit)
	assert_int(unit.controller.player_index).is_equal(unit.PLAYER_CONTROLLER)
	assert_object(unit.controller.get_parent()).is_same(unit)


func test_controller_type_none_removes_controller() -> void:
	var unit := await _make_unit(["fireball"], Unit.ControllerType.LOCAL)
	unit.controller_type = Unit.ControllerType.NONE
	await get_tree().process_frame
	assert_object(unit.controller).is_null()
	assert_object(unit.get_node_or_null("LocalPlayerController")).is_null()


func test_local_controller_reads_its_own_player_index() -> void:
	var unit := await _make_unit()
	unit.set_controller(LocalPlayerController.new(unit, 1))
	Input.action_press("player_1_left")
	unit.controller.update(1.0 / 60.0)
	Input.action_release("player_1_left")
	assert_vector(unit.move_direction).is_equal(Vector2.LEFT)


func test_local_controller_ignores_other_player_actions() -> void:
	var unit := await _make_unit()
	unit.set_controller(LocalPlayerController.new(unit, 0))
	Input.action_press("player_1_left")
	unit.controller.update(1.0 / 60.0)
	Input.action_release("player_1_left")
	assert_vector(unit.move_direction).is_equal(Vector2.ZERO)


func test_set_move_input_sets_direction_and_remembers_facing() -> void:
	var unit := await _make_unit()
	unit.set_move_input(Vector2(0.0, 1.0))
	assert_vector(unit.move_direction).is_equal(Vector2.DOWN)
	assert_vector(unit.facing_direction()).is_equal(Vector2.DOWN)
	unit.set_move_input(Vector2.ZERO)
	assert_vector(unit.move_direction).is_equal(Vector2.ZERO)
	assert_vector(unit.facing_direction()).is_equal(Vector2.DOWN)


func test_move_input_is_ignored_while_aiming() -> void:
	var unit := await _make_unit()
	unit.request_cast(0)
	assert_str(unit.state_machine.state.name).is_equal("Aim")
	unit.set_move_input(Vector2.RIGHT)
	assert_vector(unit.move_direction).is_equal(Vector2.ZERO)


func test_set_aim_input_ignores_zero_and_updates_angle() -> void:
	var unit := await _make_unit()
	unit.set_aim_input(Vector2(0.0, 1.0))
	assert_vector(unit.cast_direction).is_equal(Vector2.DOWN)
	assert_float(unit.cast_angle).is_equal_approx(PI / 2.0, 0.001)
	unit.set_aim_input(Vector2.ZERO)
	assert_vector(unit.cast_direction).is_equal(Vector2.DOWN)
	unit.set_aim_input(Vector2(0.1, 0.0))
	assert_vector(unit.cast_direction).is_equal(Vector2.RIGHT)
	assert_float(unit.cast_angle).is_equal_approx(0.0, 0.001)


func test_local_controller_applies_stick_deadzone() -> void:
	var unit := await _make_unit()
	unit.set_controller(LocalPlayerController.new(unit, 0))
	Input.action_press("player_0_left", 0.1)
	unit.controller.update(1.0 / 60.0)
	Input.action_release("player_0_left")
	assert_vector(unit.move_direction).is_equal(Vector2.ZERO)
	Input.action_press("player_0_left")
	unit.controller.update(1.0 / 60.0)
	Input.action_release("player_0_left")
	assert_vector(unit.move_direction).is_equal(Vector2.LEFT)


func test_request_cast_enters_aim_with_slot() -> void:
	var unit := await _make_unit(["smoke", "fireball"])
	unit.request_cast(1)
	assert_str(unit.state_machine.state.name).is_equal("Aim")
	assert_bool(unit.aiming).is_true()
	assert_int(unit.aiming_slot).is_equal(1)


func test_instant_spell_fires_on_press_without_aim() -> void:
	var unit := await _make_unit(["smoke", "fireball"])
	var smoke := _ability(unit, &"Smoke")
	unit.request_cast(0)
	assert_bool(unit.aiming).is_false()
	assert_int(unit.aiming_slot).is_equal(-1)
	assert_str(unit.state_machine.state.name).is_equal("Idle")
	assert_bool(unit.ability_container.is_ability_active(smoke)).is_true()
	assert_str(String(unit.animation_player.current_animation)).is_equal("CastSmoke")


func test_instant_spell_casts_in_facing_direction() -> void:
	var unit := await _make_unit(["blink", "fireball"])
	var blink := _ability(unit, &"Blink")
	unit.set_move_input(Vector2.LEFT)
	var start := unit.global_position
	unit.request_cast(0)
	var expected := start + Vector2.LEFT * BlinkAbility.MAX_DISTANCE
	assert_float(unit.global_position.distance_to(expected)).is_equal_approx(0.0, 0.01)
	assert_bool(unit.aiming).is_false()
	assert_bool(unit.ability_container.is_ability_cooldown_active(blink)).is_true()


func test_request_cast_ignored_during_active_windup() -> void:
	var unit := await _make_unit()
	var fireball := _ability(unit, &"Fireball")
	assert_int(unit.try_cast(fireball, Vector2.RIGHT)).is_equal(RuntimeAbility.ABILITY_EVENT_TYPE_ACTIVATED_DURATION_STARTED)
	unit.request_cast(0)
	assert_bool(unit.ability_container.is_ability_active(fireball)).is_true()
	assert_bool(unit.aiming).is_false()
	assert_str(unit.state_machine.state.name).is_equal("Idle")
	assert_str(String(unit.animation_player.current_animation)).is_equal("CastOffensive")


func test_request_cast_ignored_while_on_cooldown() -> void:
	var unit := await _make_unit(["blink"])
	var blink := _ability(unit, &"Blink")
	unit.try_cast(blink, Vector2.RIGHT)
	assert_bool(unit.ability_container.is_ability_cooldown_active(blink)).is_true()
	unit.request_cast(0)
	assert_bool(unit.aiming).is_false()
	assert_str(unit.state_machine.state.name).is_equal("Idle")


func test_release_request_is_ignored_when_not_aiming() -> void:
	var unit := await _make_unit()
	unit.request_release()
	assert_bool(unit.release_cast_requested).is_false()


func test_release_request_casts_and_leaves_aim() -> void:
	var unit := await _make_unit()
	var fireball := _ability(unit, &"Fireball")
	unit.request_cast(0)
	unit.request_release()
	assert_bool(unit.release_cast_requested).is_true()
	unit.state_machine.state.physics_update(1.0 / 60.0)
	assert_bool(unit.ability_container.is_ability_active(fireball)).is_true()
	assert_str(unit.state_machine.state.name).is_equal("Idle")
	assert_bool(unit.aiming).is_false()
	assert_int(unit.aiming_slot).is_equal(-1)
	assert_bool(unit.consume_release_request()).is_false()
