extends GdUnitTestSuite

const AbilityPaths := preload("res://tests/support/ability_paths.gd")

## Test fixture: a short beat keeps the suite fast, and the beat tests still run when the
## game's beat is disabled for development (`death_slowmo_duration = 0`).
const BEAT_DURATION := 0.15


func _pick_one(panel: SpellSelect) -> void:
	panel.handle_accept()


## Polls in real time so slow-motion frames can't stall the wait.
func _await_true(check: Callable, timeout := 2.0) -> void:
	var deadline := Time.get_ticks_msec() + int(timeout * 1000.0)
	while not check.call() and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame


func _started_main() -> Node:
	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(main)
	auto_free(main)
	await get_tree().process_frame
	var manager := main.get_node("MatchManager") as MatchManager
	# Flow tests skip the KO beat; dedicated tests arm it explicitly.
	manager.death_slowmo_duration = 0.0
	for panel in manager.selection_panels():
		_pick_one(panel)
		await get_tree().process_frame
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
	assert_int(first.ability_slots.size()).is_equal(3)
	await get_tree().process_frame
	_pick_one(panels[1])
	assert_int(manager.phase).is_equal(MatchManager.MatchPhase.RUNNING)
	assert_bool(first.is_match_ready).is_true()
	assert_bool(second.is_match_ready).is_true()
	assert_int(second.ability_slots.size()).is_equal(3)
	assert_bool((main.get_node("SelectionLayer") as CanvasLayer).visible).is_false()


func test_players_draft_one_after_the_other() -> void:
	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(main)
	auto_free(main)
	await get_tree().process_frame
	var manager := main.get_node("MatchManager") as MatchManager
	var panels := manager.selection_panels()
	assert_bool(panels[0].visible).is_true()
	assert_int(panels[0].offers.size()).is_equal(SpellDraw.OFFER_COUNT)
	assert_bool(panels[1].visible).is_false()
	assert_bool(panels[1].offers.is_empty()).is_true()
	_pick_one(panels[0])
	assert_int(manager.phase).is_equal(MatchManager.MatchPhase.SELECTING)
	assert_bool(panels[0].visible).is_false()
	# The next turn only opens on the next frame, so no input can leak across panels.
	assert_bool(panels[1].visible).is_false()
	await get_tree().process_frame
	assert_bool(panels[1].visible).is_true()
	assert_int(panels[1].offers.size()).is_equal(SpellDraw.OFFER_COUNT)
	_pick_one(panels[1])
	assert_int(manager.phase).is_equal(MatchManager.MatchPhase.RUNNING)


func test_shared_accept_only_drafts_the_active_player() -> void:
	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(main)
	auto_free(main)
	await get_tree().process_frame
	var manager := main.get_node("MatchManager") as MatchManager
	var panels := manager.selection_panels()
	# The dev keyboard shares Enter between both accept actions; one physical press must
	# still only draft for the player whose turn it is.
	Input.action_press("player_0_ui_accept")
	Input.action_press("player_1_ui_accept")
	await get_tree().process_frame
	Input.action_release("player_0_ui_accept")
	Input.action_release("player_1_ui_accept")
	assert_int(manager.player_for(0).ability_slots.size()).is_equal(3)
	assert_int(manager.phase).is_equal(MatchManager.MatchPhase.SELECTING)
	assert_bool(panels[1].visible).is_true()
	# Player 2 has drafted nothing yet — their pool still holds only the basics.
	assert_int(panels[1].loadout.picks.size()).is_equal(2)


func test_inactive_player_cannot_draft_out_of_turn() -> void:
	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(main)
	auto_free(main)
	await get_tree().process_frame
	var manager := main.get_node("MatchManager") as MatchManager
	var panels := manager.selection_panels()
	# Player 2 mashes accept while player 1 is still choosing: nothing may happen.
	Input.action_press("player_1_ui_accept")
	await get_tree().process_frame
	Input.action_release("player_1_ui_accept")
	assert_int(manager.phase).is_equal(MatchManager.MatchPhase.SELECTING)
	assert_bool(panels[0].visible).is_true()
	assert_int(panels[0].loadout.picks.size()).is_equal(2)
	assert_bool(panels[1].visible).is_false()
	assert_int(panels[1].loadout.picks.size()).is_equal(2)
	assert_int(manager.player_for(1).ability_slots.size()).is_equal(0)


func test_gameplay_controls_are_frozen_while_drafting() -> void:
	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(main)
	auto_free(main)
	await get_tree().process_frame
	var manager := main.get_node("MatchManager") as MatchManager
	var first := manager.player_for(0)
	assert_bool(first.is_match_ready).is_false()
	var start := first.global_position
	Input.action_press("player_0_left")
	for _frame in 3:
		await get_tree().physics_frame
	Input.action_release("player_0_left")
	assert_bool(first.global_position.is_equal_approx(start)).is_true()


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


func test_wizard_basics_are_owned_and_never_offered() -> void:
	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(main)
	auto_free(main)
	await get_tree().process_frame
	var manager := main.get_node("MatchManager") as MatchManager
	manager.death_slowmo_duration = 0.0
	var panels := manager.selection_panels()
	var first := manager.player_for(0)
	var fireball: Ability = load(AbilityPaths.path("fireball"))
	var smoke: Ability = load(AbilityPaths.path("smoke"))
	# Match-start hand: 7 catalogue spells − 2 basics = 5 candidates, all shown.
	assert_int(panels[0].offers.size()).is_equal(SpellDraw.OFFER_COUNT)
	assert_bool(panels[0].offers.has(fireball)).is_false()
	assert_bool(panels[0].offers.has(smoke)).is_false()
	_pick_one(panels[0])
	assert_bool(first.ability_slots.has(fireball)).is_true()
	assert_bool(first.ability_slots.has(smoke)).is_true()
	assert_int(first.ability_slots.size()).is_equal(3)
	await get_tree().process_frame
	_pick_one(panels[1])
	assert_int(manager.phase).is_equal(MatchManager.MatchPhase.RUNNING)
	# A per-death hand keeps excluding the basics and everything already owned.
	first.take_hit(manager.player_for(1), 100.0, 0.0, Vector2.RIGHT)
	assert_int(panels[0].offers.size()).is_equal(4)
	assert_bool(panels[0].offers.has(fireball)).is_false()
	assert_bool(panels[0].offers.has(smoke)).is_false()


func test_round_death_sends_the_loser_to_draft_then_respawns_both() -> void:
	var main: Node = await _started_main()
	var manager := main.get_node("MatchManager") as MatchManager
	var panels := manager.selection_panels()
	var first := manager.player_for(0)
	var second := manager.player_for(1)
	second.global_position += Vector2(60.0, -25.0)
	second.take_hit(first, 3.0, 0.0, Vector2.RIGHT)
	first.global_position += Vector2(-40.0, 30.0)
	first.take_hit(second, 100.0, 0.0, Vector2.RIGHT)
	assert_int(manager.phase).is_equal(MatchManager.MatchPhase.ROUND_OVER)
	assert_int(manager.round_wins_for(1)).is_equal(1)
	assert_bool(second.is_match_ready).is_false()
	assert_bool((main.get_node("SelectionLayer") as CanvasLayer).visible).is_true()
	assert_bool(panels[0].visible).is_true()
	assert_bool(panels[1].visible).is_false()
	# 7 catalogue spells − 2 basics − 1 match-start pick = 4 candidates.
	assert_int(panels[0].offers.size()).is_equal(4)
	for offer in panels[0].offers:
		assert_bool(first.ability_slots.has(offer)).is_false()
	_pick_one(panels[0])
	assert_int(manager.phase).is_equal(MatchManager.MatchPhase.ROUND_OVER)
	await get_tree().process_frame
	assert_int(manager.phase).is_equal(MatchManager.MatchPhase.RUNNING)
	assert_bool(first.player_dead).is_false()
	assert_bool(second.player_dead).is_false()
	assert_bool(first.global_position.is_equal_approx(first.spawn_position)).is_true()
	assert_bool(second.global_position.is_equal_approx(second.spawn_position)).is_true()
	assert_float(
		first.attribute_container.get_attribute_value_by_name(AttributeNames.HEALTH)
	).is_equal(10.0)
	assert_float(
		second.attribute_container.get_attribute_value_by_name(AttributeNames.HEALTH)
	).is_equal(10.0)
	assert_int(first.ability_slots.size()).is_equal(4)
	assert_bool(first.is_match_ready).is_true()
	assert_bool(second.is_match_ready).is_true()
	assert_bool((main.get_node("SelectionLayer") as CanvasLayer).visible).is_false()
	assert_bool(panels[0].visible).is_false()
	# Fresh-round damage accumulates from full health, not from the corpse value.
	second.take_hit(first, 4.0, 0.0, Vector2.RIGHT)
	assert_float(
		second.attribute_container.get_attribute_value_by_name(AttributeNames.HEALTH)
	).is_equal(6.0)


func test_round_death_of_player_two_sends_player_two_to_draft() -> void:
	var main: Node = await _started_main()
	var manager := main.get_node("MatchManager") as MatchManager
	var panels := manager.selection_panels()
	manager.player_for(1).take_hit(manager.player_for(0), 100.0, 0.0, Vector2.RIGHT)
	assert_int(manager.phase).is_equal(MatchManager.MatchPhase.ROUND_OVER)
	assert_int(manager.round_wins_for(0)).is_equal(1)
	assert_bool(panels[0].visible).is_false()
	assert_bool(panels[1].visible).is_true()
	assert_int(panels[1].offers.size()).is_equal(4)
	_pick_one(panels[1])
	await get_tree().process_frame
	assert_int(manager.phase).is_equal(MatchManager.MatchPhase.RUNNING)
	assert_int(manager.player_for(1).ability_slots.size()).is_equal(4)


func test_death_beat_delays_the_selection_screen_until_the_death_clip_ends() -> void:
	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(main)
	auto_free(main)
	await get_tree().process_frame
	var manager := main.get_node("MatchManager") as MatchManager
	# Short fixture beat (see `BEAT_DURATION`); the scale assertions read the manager's own
	# tuning, so retuning the exports never breaks this test.
	manager.death_slowmo_duration = BEAT_DURATION
	var panels := manager.selection_panels()
	var layer := main.get_node("SelectionLayer") as CanvasLayer
	_pick_one(panels[0])
	await get_tree().process_frame
	_pick_one(panels[1])
	assert_int(manager.phase).is_equal(MatchManager.MatchPhase.RUNNING)
	manager.player_for(0).take_hit(manager.player_for(1), 100.0, 0.0, Vector2.RIGHT)
	# KO: the world slows down, but the selection screen must not cover the death.
	assert_int(manager.phase).is_equal(MatchManager.MatchPhase.ROUND_OVER)
	assert_float(Engine.get_time_scale()).is_equal_approx(manager.death_slowmo_scale, 0.0001)
	assert_bool(layer.visible).is_false()
	assert_bool(panels[0].visible).is_false()
	assert_bool(panels[0]._drafting).is_false()
	# The beat ends only when the death clip does; then the loser's hand is up.
	var panel_drafting := func() -> bool: return panels[0]._drafting
	await _await_true(panel_drafting, manager.death_slowmo_duration + 2.0)
	assert_float(Engine.get_time_scale()).is_equal(1.0)
	assert_bool(layer.visible).is_true()
	assert_bool(panels[0].visible).is_true()
	assert_int(panels[0].offers.size()).is_equal(4)
	assert_int(panels[0].loadout.picks.size()).is_equal(3)
	# The draft still resolves normally and time stays at normal speed.
	_pick_one(panels[0])
	await get_tree().process_frame
	assert_int(manager.phase).is_equal(MatchManager.MatchPhase.RUNNING)
	assert_float(Engine.get_time_scale()).is_equal(1.0)


func test_match_point_beat_delays_the_winner_banner() -> void:
	var main: Node = await _started_main()
	var manager := main.get_node("MatchManager") as MatchManager
	var panels := manager.selection_panels()
	var loser := manager.player_for(0)
	var winner := manager.player_for(1)
	# Four quick losses get us to match point (the beat is off in `_started_main`).
	for _round in MatchManager.ROUNDS_TO_WIN - 1:
		loser.take_hit(winner, 100.0, 0.0, Vector2.RIGHT)
		assert_int(manager.phase).is_equal(MatchManager.MatchPhase.ROUND_OVER)
		if panels[0].can_start_draft():
			_pick_one(panels[0])
		await get_tree().process_frame
		assert_int(manager.phase).is_equal(MatchManager.MatchPhase.RUNNING)
	assert_int(manager.round_wins_for(1)).is_equal(MatchManager.ROUNDS_TO_WIN - 1)
	var overlay := main.get_node("MatchOverLayer") as MatchOver
	# Arm the beat for the final KO only (short fixture). This test covers the
	# beat-on-match-point branch; the scale assertions read the manager's own tuning.
	manager.death_slowmo_duration = BEAT_DURATION
	manager.death_slowmo_on_match_point = true
	loser.take_hit(winner, 100.0, 0.0, Vector2.RIGHT)
	assert_int(manager.phase).is_equal(MatchManager.MatchPhase.GAME_OVER)
	assert_bool(overlay.visible).is_false()
	assert_float(Engine.get_time_scale()).is_equal_approx(manager.death_slowmo_scale, 0.0001)
	var banner_visible := func() -> bool: return overlay.visible
	await _await_true(banner_visible, manager.death_slowmo_duration + 2.0)
	assert_float(Engine.get_time_scale()).is_equal(1.0)
	assert_bool(overlay.visible).is_true()
	assert_str(overlay.message_label.text).is_equal("PLAYER 2 WINS 5-0")


func test_match_over_after_five_round_wins() -> void:
	var main: Node = await _started_main()
	var manager := main.get_node("MatchManager") as MatchManager
	var panels := manager.selection_panels()
	var loser := manager.player_for(0)
	var winner := manager.player_for(1)
	# Losses 1–3 draft cards until the pool caps out (2 basics + start pick + 3 cards).
	for _round in 3:
		loser.take_hit(winner, 100.0, 0.0, Vector2.RIGHT)
		assert_int(manager.phase).is_equal(MatchManager.MatchPhase.ROUND_OVER)
		_pick_one(panels[0])
		await get_tree().process_frame
		assert_int(manager.phase).is_equal(MatchManager.MatchPhase.RUNNING)
	assert_int(loser.ability_slots.size()).is_equal(Loadout.MAX_SPELLS)
	assert_bool(panels[0].can_start_draft()).is_false()
	# Loss 4: the pool is full, so the round resumes without a draft.
	loser.take_hit(winner, 100.0, 0.0, Vector2.RIGHT)
	assert_int(manager.phase).is_equal(MatchManager.MatchPhase.ROUND_OVER)
	assert_bool(panels[0].visible).is_false()
	await get_tree().process_frame
	assert_int(manager.phase).is_equal(MatchManager.MatchPhase.RUNNING)
	# Loss 5 ends the match.
	loser.take_hit(winner, 100.0, 0.0, Vector2.RIGHT)
	var overlay := main.get_node("MatchOverLayer") as MatchOver
	assert_int(manager.phase).is_equal(MatchManager.MatchPhase.GAME_OVER)
	assert_int(manager.round_wins_for(1)).is_equal(MatchManager.ROUNDS_TO_WIN)
	assert_int(manager.round_wins_for(0)).is_equal(0)
	assert_bool(overlay.visible).is_true()
	assert_str(overlay.message_label.text).is_equal("PLAYER 2 WINS 5-0")
	assert_bool(loser.is_match_ready).is_false()


func test_full_pool_skips_the_round_draft() -> void:
	var main: Node = await _started_main()
	var manager := main.get_node("MatchManager") as MatchManager
	var panels := manager.selection_panels()
	var loser := manager.player_for(0)
	for ability in panels[0].catalogue:
		panels[0].loadout.pick(ability)
	assert_bool(panels[0].loadout.is_full()).is_true()
	loser.apply_loadout(panels[0].loadout.picks)
	loser.take_hit(manager.player_for(1), 100.0, 0.0, Vector2.RIGHT)
	assert_int(manager.phase).is_equal(MatchManager.MatchPhase.ROUND_OVER)
	assert_bool(panels[0].visible).is_false()
	await get_tree().process_frame
	assert_int(manager.phase).is_equal(MatchManager.MatchPhase.RUNNING)
	assert_int(loser.ability_slots.size()).is_equal(Loadout.MAX_SPELLS)
