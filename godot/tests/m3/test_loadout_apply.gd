extends GdUnitTestSuite

const AbilityPaths := preload("res://tests/support/ability_paths.gd")


func _picks(names: Array) -> Array[Ability]:
	var picks: Array[Ability] = []
	for name in names:
		picks.append(load(AbilityPaths.path(name)))
	return picks


func _make_unit() -> Unit:
	var scene: PackedScene = load("res://src/player/player.tscn")
	var unit := scene.instantiate() as Unit
	unit.set_physics_process(false)
	add_child(unit)
	auto_free(unit)
	return unit


func _runtime_names(unit: Unit) -> Array[String]:
	var names: Array[String] = []
	for runtime in unit.ability_container.get_runtime_abilities():
		names.append(String(runtime.get_ability().ability_name))
	names.sort()
	return names


func _hud(unit: Unit) -> HBoxContainer:
	return unit.get_node("CanvasLayer/MarginContainer/HBoxContainer")


func test_unit_starts_without_abilities_before_selection() -> void:
	var unit := _make_unit()
	await get_tree().process_frame
	assert_int(unit.ability_slots.size()).is_equal(0)
	assert_int(unit.ability_container.get_runtime_abilities().size()).is_equal(0)
	assert_int(_hud(unit).get_child_count()).is_equal(0)


func test_apply_loadout_grants_picks_and_rebuilds_hud() -> void:
	var unit := _make_unit()
	await get_tree().process_frame
	var applied_calls := [0]
	unit.loadout_applied.connect(func() -> void: applied_calls[0] += 1)
	unit.apply_loadout(_picks(["fireball", "smoke"]))
	assert_array(_runtime_names(unit)).contains_exactly(["Fireball", "Smoke"])
	assert_int(unit.ability_slots.size()).is_equal(2)
	assert_bool(unit.ability_container.is_ability_granted(unit.ability_slots[0])).is_true()
	assert_bool(unit.ability_container.is_ability_granted(unit.ability_slots[1])).is_true()
	assert_int(unit.ability_handler.ability_buttons.size()).is_equal(2)
	assert_int(_hud(unit).get_child_count()).is_equal(2)
	assert_int(applied_calls[0]).is_equal(1)


func test_reapplying_replaces_previous_loadout() -> void:
	var unit := _make_unit()
	await get_tree().process_frame
	var fireball: Ability = load(AbilityPaths.path("fireball"))
	unit.apply_loadout(_picks(["fireball", "smoke"]))
	unit.apply_loadout(_picks(["teleport"]))
	assert_array(_runtime_names(unit)).contains_exactly(["Teleport"])
	assert_bool(unit.ability_container.has_ability(fireball)).is_false()
	assert_bool(unit.ability_container.is_ability_granted(fireball)).is_false()
	assert_int(unit.ability_slots.size()).is_equal(1)
	assert_int(_hud(unit).get_child_count()).is_equal(1)


func test_apply_loadout_skips_duplicates_and_nulls() -> void:
	var unit := _make_unit()
	await get_tree().process_frame
	var picks := _picks(["fireball"])
	picks.append(picks[0])
	picks.append(null)
	unit.apply_loadout(picks)
	assert_int(unit.ability_slots.size()).is_equal(1)
	assert_int(_hud(unit).get_child_count()).is_equal(1)


func test_apply_loadout_preserves_pick_order() -> void:
	var unit := _make_unit()
	await get_tree().process_frame
	unit.apply_loadout(_picks(["smoke", "fireball", "teleport"]))
	assert_str(String(unit.ability_slots[0].ability_name)).is_equal("Smoke")
	assert_str(String(unit.ability_slots[1].ability_name)).is_equal("Fireball")
	assert_str(String(unit.ability_slots[2].ability_name)).is_equal("Teleport")
