extends GdUnitTestSuite


func test_midpoint_averages_the_players() -> void:
	assert_vector(MatchCamera.midpoint_of([Vector2(0.0, 0.0), Vector2(100.0, 50.0)])).is_equal(
		Vector2(50.0, 25.0)
	)


func test_spread_is_the_bounding_box_size() -> void:
	var spread := MatchCamera.spread_of(
		[Vector2(-40.0, 30.0), Vector2(60.0, -25.0), Vector2(20.0, 90.0)]
	)
	assert_vector(spread).is_equal(Vector2(100.0, 115.0))


func test_fit_ratio_keeps_the_initial_zoom_inside_the_margins() -> void:
	var margin := Vector2(400.0, 300.0)
	assert_float(MatchCamera.fit_ratio(Vector2(200.0, 100.0), margin, 0.5)).is_equal(1.0)
	assert_float(MatchCamera.fit_ratio(Vector2(400.0, 100.0), margin, 0.5)).is_equal(1.0)


func test_fit_ratio_zooms_out_proportionally_and_clamps() -> void:
	var margin := Vector2(400.0, 300.0)
	assert_float(MatchCamera.fit_ratio(Vector2(800.0, 100.0), margin, 0.5)).is_equal(0.5)
	assert_float(MatchCamera.fit_ratio(Vector2(1600.0, 100.0), margin, 0.5)).is_equal(0.5)
	# A vertical spread drives the zoom too.
	assert_float(MatchCamera.fit_ratio(Vector2(0.0, 600.0), margin, 0.5)).is_equal(0.5)


func test_fit_ratio_ignores_zero_spread_components() -> void:
	var margin := Vector2(400.0, 300.0)
	assert_float(MatchCamera.fit_ratio(Vector2.ZERO, margin, 0.5)).is_equal(1.0)
	assert_float(MatchCamera.fit_ratio(Vector2(100.0, 0.0), margin, 0.5)).is_equal(1.0)


func test_main_scene_ships_the_match_camera() -> void:
	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(main)
	auto_free(main)
	await get_tree().process_frame
	var camera := main.get_node_or_null("MatchCamera") as MatchCamera
	assert_object(camera).is_not_null()
	assert_bool(camera.enabled).is_true()
	assert_vector(camera.initial_zoom).is_equal(Vector2(2.0, 2.0))
