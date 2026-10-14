extends GdUnitTestSuite


func test_movement_tuning_matches_poc() -> void:
	assert_float(Unit.MOVE_MAX_SPEED).is_equal(140.0)
	assert_float(Unit.MOVE_ACCELERATION).is_equal(345.0)
	assert_float(Unit.MOVE_FRICTION).is_equal(690.0)


func test_acceleration_reaches_max_speed() -> void:
	var velocity := Vector2.ZERO
	for _frame in 30:
		velocity = Unit.step_velocity(velocity, Vector2.RIGHT, 1.0 / 60.0)
	assert_vector(velocity).is_equal(Vector2(Unit.MOVE_MAX_SPEED, 0.0))


func test_friction_brings_full_speed_to_rest() -> void:
	var velocity := Vector2(Unit.MOVE_MAX_SPEED, 0.0)
	for _frame in 15:
		velocity = Unit.step_velocity(velocity, Vector2.ZERO, 1.0 / 60.0)
	assert_vector(velocity).is_equal(Vector2.ZERO)


func test_move_toward_never_overshoots() -> void:
	var velocity := Vector2.ZERO
	for _frame in 120:
		velocity = Unit.step_velocity(velocity, Vector2.LEFT, 1.0 / 60.0)
	assert_float(velocity.length()).is_equal_approx(Unit.MOVE_MAX_SPEED, 0.001)


func test_facing_sign_keeps_last_sign_on_zero_x() -> void:
	assert_float(Unit.facing_sign(Vector2.ZERO, -1.0)).is_equal(-1.0)
	assert_float(Unit.facing_sign(Vector2(0.0, 1.0), 1.0)).is_equal(1.0)
	assert_float(Unit.facing_sign(Vector2(-0.5, 0.2), 1.0)).is_equal(-1.0)
	assert_float(Unit.facing_sign(Vector2(0.5, -0.2), -1.0)).is_equal(1.0)
