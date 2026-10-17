extends GdUnitTestSuite


func test_press_shorter_than_threshold_is_a_tap() -> void:
	assert_bool(AimState.is_tap(0.0)).is_true()
	assert_bool(AimState.is_tap(0.1)).is_true()


func test_press_at_or_longer_than_threshold_is_a_hold() -> void:
	assert_bool(AimState.is_tap(AimState.TAP_THRESHOLD)).is_false()
	assert_bool(AimState.is_tap(0.5)).is_false()


func test_loadout_slot_actions_exist() -> void:
	for player: int in [0, 1]:
		for slot: int in Loadout.MAX_SPELLS:
			assert_bool(InputMap.has_action("player_%d_spell_%d" % [player, slot])).is_true()
		assert_bool(InputMap.has_action("player_%d_spell_6" % player)).is_false()
