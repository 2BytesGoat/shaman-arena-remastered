extends GdUnitTestSuite

const AbilityPaths := preload("res://tests/support/ability_paths.gd")


func _picks(names: Array) -> Array[Ability]:
	var picks: Array[Ability] = []
	for name in names:
		picks.append(load(AbilityPaths.path(name)))
	return picks


func _make_unit(controller: int) -> Unit:
	var scene: PackedScene = load("res://src/player/player.tscn")
	var unit := scene.instantiate() as Unit
	unit.PLAYER_CONTROLLER = controller
	unit.set_physics_process(false)
	add_child(unit)
	auto_free(unit)
	return unit


func _make_manager(skip_selection := false, default_loadout: Array[Ability] = []) -> MatchManager:
	var manager := MatchManager.new()
	manager.skip_selection = skip_selection
	manager.default_loadout = default_loadout
	add_child(manager)
	auto_free(manager)
	return manager


func test_match_starts_selecting_and_locked() -> void:
	_make_unit(0)
	_make_unit(1)
	var manager := _make_manager()
	assert_int(manager.phase).is_equal(MatchManager.MatchPhase.SELECTING)
	assert_int(manager._players.size()).is_equal(2)
	for player in manager._players:
		assert_bool(player.is_match_ready).is_false()


func test_one_ready_player_does_not_start() -> void:
	var first := _make_unit(0)
	_make_unit(1)
	var manager := _make_manager()
	manager._on_loadout_complete(0, _picks(["fireball"]))
	assert_int(manager.phase).is_equal(MatchManager.MatchPhase.SELECTING)
	assert_bool(first.is_match_ready).is_false()


func test_all_ready_starts_match_and_unlocks() -> void:
	var first := _make_unit(0)
	var second := _make_unit(1)
	var manager := _make_manager()
	var phases: Array = []
	manager.phase_changed.connect(func(phase: int) -> void: phases.append(phase))
	manager._on_loadout_complete(0, _picks(["fireball"]))
	manager._on_loadout_complete(1, _picks(["smoke"]))
	assert_int(manager.phase).is_equal(MatchManager.MatchPhase.RUNNING)
	assert_array(phases).contains_exactly([MatchManager.MatchPhase.RUNNING])
	assert_bool(first.is_match_ready).is_true()
	assert_bool(second.is_match_ready).is_true()


func test_repeated_loadout_completion_is_counted_once() -> void:
	var first := _make_unit(0)
	var second := _make_unit(1)
	var manager := _make_manager()
	manager._on_loadout_complete(0, _picks(["fireball"]))
	manager._on_loadout_complete(0, _picks(["fireball"]))
	manager._on_loadout_complete(1, _picks(["smoke"]))
	assert_int(manager.phase).is_equal(MatchManager.MatchPhase.RUNNING)
	assert_int(manager._ready_players.size()).is_equal(2)


func test_round_death_locks_players_and_resumes_with_respawns() -> void:
	var first := _make_unit(0)
	var second := _make_unit(1)
	var manager := _make_manager()
	manager._on_loadout_complete(0, _picks(["fireball"]))
	manager._on_loadout_complete(1, _picks(["smoke"]))
	first.global_position += Vector2(40.0, -20.0)
	first.take_hit(null, 100.0, 0.0, Vector2.ZERO)
	assert_int(manager.phase).is_equal(MatchManager.MatchPhase.ROUND_OVER)
	assert_int(manager.round_wins_for(1)).is_equal(1)
	assert_bool(first.player_dead).is_true()
	assert_bool(second.is_match_ready).is_false()
	# No panel exists here, so the round draft is skipped and the round resumes next frame.
	await get_tree().process_frame
	assert_int(manager.phase).is_equal(MatchManager.MatchPhase.RUNNING)
	assert_bool(first.player_dead).is_false()
	assert_bool(first.is_match_ready).is_true()
	assert_bool(second.is_match_ready).is_true()
	assert_bool(first.global_position.is_equal_approx(first.spawn_position)).is_true()
	assert_float(
		first.attribute_container.get_attribute_value_by_name(AttributeNames.HEALTH)
	).is_equal(10.0)


func test_five_round_wins_end_the_match() -> void:
	var first := _make_unit(0)
	var second := _make_unit(1)
	var manager := _make_manager()
	manager._on_loadout_complete(0, _picks(["fireball"]))
	manager._on_loadout_complete(1, _picks(["smoke"]))
	for _round in MatchManager.ROUNDS_TO_WIN - 1:
		first.take_hit(null, 100.0, 0.0, Vector2.ZERO)
		assert_int(manager.phase).is_equal(MatchManager.MatchPhase.ROUND_OVER)
		await get_tree().process_frame
		assert_int(manager.phase).is_equal(MatchManager.MatchPhase.RUNNING)
	first.take_hit(null, 100.0, 0.0, Vector2.ZERO)
	assert_int(manager.phase).is_equal(MatchManager.MatchPhase.GAME_OVER)
	assert_int(manager.round_wins_for(1)).is_equal(MatchManager.ROUNDS_TO_WIN)
	assert_bool(first.is_match_ready).is_false()
	manager._on_loadout_complete(1, _picks(["teleport"]))
	assert_int(manager.phase).is_equal(MatchManager.MatchPhase.GAME_OVER)


func test_skip_selection_applies_default_loadout_and_starts() -> void:
	var first := _make_unit(0)
	var second := _make_unit(1)
	var manager := _make_manager(true, _picks(["fireball", "smoke"]))
	assert_int(manager.phase).is_equal(MatchManager.MatchPhase.RUNNING)
	assert_bool(first.is_match_ready).is_true()
	assert_bool(second.is_match_ready).is_true()
	assert_int(first.ability_slots.size()).is_equal(2)
	assert_int(second.ability_slots.size()).is_equal(2)
