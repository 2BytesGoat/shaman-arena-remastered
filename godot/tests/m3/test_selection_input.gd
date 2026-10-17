extends GdUnitTestSuite


func _make_panel(controller := 0) -> SpellSelect:
	var panel := load("res://src/ui/spell_select.tscn").instantiate() as SpellSelect
	panel.player_controller = controller
	add_child(panel)
	auto_free(panel)
	return panel


func test_focus_moves_within_the_card_row() -> void:
	assert_int(SpellSelect.move_focus(0, 1, 5)).is_equal(1)
	assert_int(SpellSelect.move_focus(4, 1, 5)).is_equal(4)
	assert_int(SpellSelect.move_focus(2, -1, 5)).is_equal(1)
	assert_int(SpellSelect.move_focus(0, -1, 5)).is_equal(0)


func test_focus_guards_an_empty_row() -> void:
	assert_int(SpellSelect.move_focus(0, 1, 0)).is_equal(0)


func test_draft_offers_five_distinct_catalogue_spells() -> void:
	var panel: SpellSelect = _make_panel()
	await get_tree().process_frame
	assert_int(panel.offers.size()).is_equal(SpellDraw.OFFER_COUNT)
	assert_int(panel._card_buttons.size()).is_equal(SpellDraw.OFFER_COUNT)
	var seen := {}
	for offer in panel.offers:
		assert_bool(panel.catalogue.has(offer)).is_true()
		assert_bool(seen.has(offer)).is_false()
		seen[offer] = true


func test_slot_strip_shows_the_six_spell_slots() -> void:
	var panel: SpellSelect = _make_panel()
	await get_tree().process_frame
	assert_int(panel._slot_icons.size()).is_equal(Loadout.MAX_SPELLS)


func test_left_right_moves_focus_across_offers() -> void:
	var panel: SpellSelect = _make_panel()
	await get_tree().process_frame
	panel.move_focus_by(1)
	assert_int(panel.focus_index).is_equal(1)
	panel.move_focus_by(-1)
	panel.move_focus_by(-1)
	assert_int(panel.focus_index).is_equal(0)
	panel.focus_index = SpellDraw.OFFER_COUNT - 1
	panel.move_focus_by(1)
	assert_int(panel.focus_index).is_equal(SpellDraw.OFFER_COUNT - 1)


func test_accept_commits_the_focused_card_once() -> void:
	var panel: SpellSelect = _make_panel()
	await get_tree().process_frame
	var completed: Array = []
	panel.loadout_complete.connect(
		func(controller: int, picks: Array[Ability]) -> void: completed.append([controller, picks])
	)
	panel.move_focus_by(1)
	panel.handle_accept()
	assert_bool(panel._locked).is_true()
	assert_bool(panel.visible).is_false()
	assert_int(panel.loadout.picks.size()).is_equal(1)
	assert_object(panel.loadout.picks[0]).is_same(panel.offers[1])
	assert_int(completed.size()).is_equal(1)
	assert_int(completed[0][0]).is_equal(0)
	assert_int((completed[0][1] as Array[Ability]).size()).is_equal(1)
	panel.handle_accept()
	assert_int(panel.loadout.picks.size()).is_equal(1)
	assert_int(completed.size()).is_equal(1)


func test_accept_without_offers_stays_open() -> void:
	var panel := load("res://src/ui/spell_select.tscn").instantiate() as SpellSelect
	panel.catalogue.clear()
	add_child(panel)
	auto_free(panel)
	await get_tree().process_frame
	assert_bool(panel.offers.is_empty()).is_true()
	assert_str(panel.hint_label.text).is_equal("NO SPELLS AVAILABLE")
	panel.handle_accept()
	assert_bool(panel._locked).is_false()
	assert_bool(panel.visible).is_true()
	assert_int(panel.loadout.picks.size()).is_equal(0)


func test_panel_color_follows_player() -> void:
	var panel: SpellSelect = _make_panel(1)
	await get_tree().process_frame
	assert_str(panel.title_label.text).is_equal("PLAYER 2")
