extends GdUnitTestSuite


func _make_panel(controller := 0) -> SpellSelect:
	var panel := load("res://src/ui/spell_select.tscn").instantiate() as SpellSelect
	panel.player_controller = controller
	add_child(panel)
	auto_free(panel)
	return panel


func test_focus_moves_within_grid() -> void:
	assert_int(SpellSelect.move_focus(0, Vector2i.RIGHT, 4, 7)).is_equal(1)
	assert_int(SpellSelect.move_focus(3, Vector2i.RIGHT, 4, 7)).is_equal(3)
	assert_int(SpellSelect.move_focus(0, Vector2i.DOWN, 4, 7)).is_equal(4)
	assert_int(SpellSelect.move_focus(3, Vector2i.DOWN, 4, 7)).is_equal(3)
	assert_int(SpellSelect.move_focus(0, Vector2i.LEFT, 4, 7)).is_equal(0)
	assert_int(SpellSelect.move_focus(4, Vector2i.UP, 4, 7)).is_equal(0)
	assert_int(SpellSelect.move_focus(5, Vector2i.RIGHT, 4, 7)).is_equal(6)


func test_focus_guards_empty_catalogue() -> void:
	assert_int(SpellSelect.move_focus(0, Vector2i.RIGHT, 4, 0)).is_equal(0)


func test_catalogue_builds_buttons_and_slots() -> void:
	var panel: SpellSelect = _make_panel()
	await get_tree().process_frame
	assert_int(panel._buttons.size()).is_equal(panel.catalogue.size())
	assert_int(panel._slot_icons.size()).is_equal(Loadout.MAX_SPELLS + Loadout.CONSUMABLE_SLOTS)


func test_accept_toggles_pick() -> void:
	var panel: SpellSelect = _make_panel()
	await get_tree().process_frame
	panel.handle_accept()
	assert_bool(panel.loadout.has(panel.catalogue[0])).is_true()
	assert_str(panel.hint_label.text).is_equal("PICK 1/6")
	panel.handle_accept()
	assert_bool(panel.loadout.has(panel.catalogue[0])).is_false()
	assert_str(panel.hint_label.text).is_equal("PICK 0/6")


func test_sixth_pick_completes_and_locks_the_panel() -> void:
	var panel: SpellSelect = _make_panel()
	await get_tree().process_frame
	var completed: Array = []
	panel.loadout_complete.connect(
		func(controller: int, picks: Array[Ability]) -> void: completed.append([controller, picks])
	)
	panel.handle_accept()
	panel.move_focus_by(Vector2i.DOWN)
	panel.handle_accept()
	panel.move_focus_by(Vector2i.RIGHT)
	panel.handle_accept()
	panel.move_focus_by(Vector2i.RIGHT)
	panel.handle_accept()
	panel.move_focus_by(Vector2i.UP)
	panel.handle_accept()
	panel.move_focus_by(Vector2i.LEFT)
	panel.handle_accept()
	assert_bool(panel._locked).is_true()
	assert_bool(panel.visible).is_false()
	assert_int(completed.size()).is_equal(1)
	assert_int(completed[0][0]).is_equal(0)
	assert_int((completed[0][1] as Array[Ability]).size()).is_equal(Loadout.MAX_SPELLS)
	panel.handle_accept()
	assert_int(completed.size()).is_equal(1)


func test_cancel_removes_last_pick() -> void:
	var panel: SpellSelect = _make_panel()
	await get_tree().process_frame
	panel.handle_accept()
	panel.move_focus_by(Vector2i.RIGHT)
	panel.handle_accept()
	panel.handle_cancel()
	assert_int(panel.loadout.picks.size()).is_equal(1)
	assert_bool(panel.loadout.has(panel.catalogue[0])).is_true()
	assert_bool(panel.loadout.has(panel.catalogue[1])).is_false()


func test_panel_color_follows_player() -> void:
	var panel: SpellSelect = _make_panel(1)
	await get_tree().process_frame
	assert_str(panel.title_label.text).is_equal("PLAYER 2")
