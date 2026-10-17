extends GdUnitTestSuite


func _pick_one(panel: SpellSelect) -> void:
	panel.handle_accept()


func _started_main() -> Node:
	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(main)
	auto_free(main)
	await get_tree().process_frame
	var manager := main.get_node("MatchManager") as MatchManager
	for panel in manager.selection_panels():
		_pick_one(panel)
	assert_int(manager.phase).is_equal(MatchManager.MatchPhase.RUNNING)
	return main


func test_picking_both_players_starts_the_match() -> void:
	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(main)
	auto_free(main)
	await get_tree().process_frame
	var manager := main.get_node("MatchManager") as MatchManager
	var panels := manager.selection_panels()
	assert_int(panels.size()).is_equal(2)
	assert_int(manager.phase).is_equal(MatchManager.MatchPhase.SELECTING)
	var first := manager.player_for(0)
	var second := manager.player_for(1)
	assert_object(first).is_not_null()
	assert_object(second).is_not_null()
	_pick_one(panels[0])
	assert_int(manager.phase).is_equal(MatchManager.MatchPhase.SELECTING)
	assert_int(first.ability_slots.size()).is_equal(1)
	_pick_one(panels[1])
	assert_int(manager.phase).is_equal(MatchManager.MatchPhase.RUNNING)
	assert_bool(first.is_match_ready).is_true()
	assert_bool(second.is_match_ready).is_true()
	assert_int(second.ability_slots.size()).is_equal(1)
	assert_bool((main.get_node("SelectionLayer") as CanvasLayer).visible).is_false()


func test_players_get_local_controllers_from_the_scene() -> void:
	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(main)
	auto_free(main)
	await get_tree().process_frame
	var manager := main.get_node("MatchManager") as MatchManager
	for controller_index in 2:
		var unit := manager.player_for(controller_index)
		assert_bool(unit.controller is LocalPlayerController).is_true()
		assert_object(unit.controller.unit).is_same(unit)
		assert_int(unit.controller.player_index).is_equal(controller_index)
		assert_object(unit.controller.get_parent()).is_same(unit)


func test_death_shows_match_over_for_the_winner() -> void:
	var main: Node = await _started_main()
	var manager := main.get_node("MatchManager") as MatchManager
	manager.player_for(0).take_hit(manager.player_for(1), 100.0, 0.0, Vector2.RIGHT)
	var overlay := main.get_node("MatchOverLayer") as MatchOver
	assert_int(manager.phase).is_equal(MatchManager.MatchPhase.GAME_OVER)
	assert_bool(overlay.visible).is_true()
	assert_str(overlay.message_label.text).is_equal("PLAYER 2 WINS")
	assert_bool(manager.player_for(1).is_match_ready).is_false()


func test_death_of_player_two_shows_player_one_as_winner() -> void:
	var main: Node = await _started_main()
	var manager := main.get_node("MatchManager") as MatchManager
	manager.player_for(1).take_hit(manager.player_for(0), 100.0, 0.0, Vector2.RIGHT)
	var overlay := main.get_node("MatchOverLayer") as MatchOver
	assert_str(overlay.message_label.text).is_equal("PLAYER 1 WINS")
