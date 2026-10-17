extends GdUnitTestSuite


func _make_unit(controller := 0) -> Unit:
	var scene: PackedScene = load("res://src/player/player.tscn")
	var unit := scene.instantiate() as Unit
	unit.set_physics_process(false)
	add_child(unit)
	unit.PLAYER_CONTROLLER = controller
	auto_free(unit)
	return unit


func _health_bar(unit: Unit) -> HealthBar:
	return unit.get_node_or_null("HealthBar") as HealthBar


func test_bar_exists_outside_the_flip_subtree_and_keeps_the_poc_geometry() -> void:
	var unit := _make_unit()
	await get_tree().process_frame
	var bar := _health_bar(unit)
	assert_object(bar).is_not_null()
	assert_bool(bar.is_visible_in_tree()).is_true()
	assert_bool(unit.visuals.get_node("Flippable").is_ancestor_of(bar)).is_false()
	assert_vector(bar.position).is_equal_approx(Vector2(-32.0, -48.0), Vector2(0.01, 0.01))
	assert_vector(bar.size).is_equal_approx(Vector2(64.0, 16.0), Vector2(0.01, 0.01))


func test_bar_starts_full_and_scales_to_max_health() -> void:
	var unit := _make_unit()
	await get_tree().process_frame
	var bar := _health_bar(unit)
	var max_health: float = unit.attribute_container.get_attribute_value_by_name(
		AttributeNames.MAX_HEALTH
	)
	assert_float(bar.max_value).is_equal(max_health)
	assert_float(bar.value).is_equal(max_health)


func test_damage_drains_the_bar_proportionally() -> void:
	var unit := _make_unit()
	await get_tree().process_frame
	var bar := _health_bar(unit)
	var damage := bar.max_value * 0.25
	unit.take_hit(null, damage, 0.0, Vector2.RIGHT)
	assert_float(bar.value).is_equal_approx(bar.max_value - damage, 0.001)
	assert_float(bar.value).is_equal_approx(
		unit.attribute_container.get_attribute_value_by_name(AttributeNames.HEALTH), 0.001
	)


func test_lethal_damage_empties_the_bar_and_respawn_refills_it() -> void:
	var unit := _make_unit()
	await get_tree().process_frame
	var bar := _health_bar(unit)
	unit.take_hit(null, bar.max_value + 1.0, 0.0, Vector2.RIGHT)
	assert_bool(unit.player_dead).is_true()
	assert_float(bar.value).is_equal(0.0)
	unit.respawn()
	assert_bool(unit.player_dead).is_false()
	assert_float(bar.value).is_equal(bar.max_value)
