extends GdUnitTestSuite


func _spawn_unit() -> Unit:
	var unit := (load("res://src/player/player.tscn") as PackedScene).instantiate() as Unit
	add_child(unit)
	auto_free(unit)
	return unit


func _health(unit: Unit) -> float:
	return unit.attribute_container.get_attribute_value_by_name(AttributeNames.HEALTH)


func test_lava_ticks_due_counts_whole_intervals() -> void:
	assert_int(Unit.lava_ticks_due(0.0, 1.0)).is_equal(0)
	assert_int(Unit.lava_ticks_due(0.99, 1.0)).is_equal(0)
	assert_int(Unit.lava_ticks_due(1.0, 1.0)).is_equal(1)
	assert_int(Unit.lava_ticks_due(3.5, 1.0)).is_equal(3)
	assert_int(Unit.lava_ticks_due(5.0, 0.0)).is_equal(0)


func test_no_burn_while_out_of_the_lava() -> void:
	var unit := _spawn_unit()
	unit.update_lava_burn(Unit.LAVA_TICK_INTERVAL * 3.0)
	assert_float(_health(unit)).is_equal(100.0)


func test_burn_ticks_health_once_per_interval() -> void:
	var unit := _spawn_unit()
	unit.lava_contacts = 1
	unit.update_lava_burn(Unit.LAVA_TICK_INTERVAL - 0.1)
	assert_float(_health(unit)).is_equal(100.0)
	unit.update_lava_burn(0.2)
	assert_float(_health(unit)).is_equal(100.0 - Unit.LAVA_DAMAGE_PER_TICK)


func test_leaving_the_lava_resets_the_burn_clock() -> void:
	var unit := _spawn_unit()
	unit.lava_contacts = 1
	unit.update_lava_burn(Unit.LAVA_TICK_INTERVAL - 0.1)
	unit.lava_contacts = 0
	unit.update_lava_burn(0.2)
	# The partial second spent in the lava must not carry over into the next visit.
	unit.lava_contacts = 1
	unit.update_lava_burn(0.2)
	assert_float(_health(unit)).is_equal(100.0)


func test_lethal_burn_kills_through_the_attribute_signal() -> void:
	var unit := _spawn_unit()
	unit.lava_contacts = 1
	for _tick in 4:
		unit.update_lava_burn(Unit.LAVA_TICK_INTERVAL)
	assert_bool(unit.player_dead).is_true()
	assert_float(_health(unit)).is_equal(0.0)
	# A corpse still overlapping the lava takes nothing further.
	unit.update_lava_burn(Unit.LAVA_TICK_INTERVAL)
	assert_float(_health(unit)).is_equal(0.0)
