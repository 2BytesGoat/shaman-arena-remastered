extends GdUnitTestSuite


func test_press_shorter_than_threshold_is_a_tap() -> void:
	assert_bool(AimState.is_tap(0.0)).is_true()
	assert_bool(AimState.is_tap(0.1)).is_true()


func test_press_at_or_longer_than_threshold_is_a_hold() -> void:
	assert_bool(AimState.is_tap(AimState.TAP_THRESHOLD)).is_false()
	assert_bool(AimState.is_tap(0.5)).is_false()


func test_spell_six_dev_actions_exist() -> void:
	assert_bool(InputMap.has_action("player_0_spell_6")).is_true()
	assert_bool(InputMap.has_action("player_1_spell_6")).is_true()
