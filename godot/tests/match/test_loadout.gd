extends GdUnitTestSuite

const AbilityPaths := preload("res://tests/support/ability_paths.gd")


func _ability(name: String) -> Ability:
	return load(AbilityPaths.path(name))


func test_pick_up_to_six_spells() -> void:
	var loadout := Loadout.new()
	for name in ["fireball", "boomerang", "meteor", "smoke", "teleport", "blink"]:
		assert_bool(loadout.pick(_ability(name))).is_true()
	assert_int(loadout.picks.size()).is_equal(Loadout.MAX_SPELLS)
	assert_bool(loadout.is_full()).is_true()


func test_seventh_pick_is_rejected() -> void:
	var loadout := Loadout.new()
	for name in ["fireball", "boomerang", "meteor", "smoke", "teleport", "blink"]:
		loadout.pick(_ability(name))
	assert_bool(loadout.pick(_ability("anivia_wall"))).is_false()
	assert_int(loadout.picks.size()).is_equal(Loadout.MAX_SPELLS)


func test_duplicate_pick_is_rejected() -> void:
	var loadout := Loadout.new()
	assert_bool(loadout.pick(_ability("fireball"))).is_true()
	assert_bool(loadout.pick(_ability("fireball"))).is_false()
	assert_int(loadout.picks.size()).is_equal(1)


func test_toggle_removes_and_frees_a_slot() -> void:
	var loadout := Loadout.new()
	for name in ["fireball", "boomerang", "meteor", "smoke", "teleport", "blink"]:
		loadout.pick(_ability(name))
	loadout.toggle(_ability("smoke"))
	assert_bool(loadout.has(_ability("smoke"))).is_false()
	assert_bool(loadout.is_full()).is_false()
	assert_bool(loadout.pick(_ability("anivia_wall"))).is_true()
	assert_int(loadout.picks.size()).is_equal(Loadout.MAX_SPELLS)


func test_unpick_missing_returns_false() -> void:
	var loadout := Loadout.new()
	assert_bool(loadout.unpick(_ability("fireball"))).is_false()


func test_null_cannot_be_picked() -> void:
	var loadout := Loadout.new()
	assert_bool(loadout.pick(null)).is_false()
	assert_int(loadout.picks.size()).is_equal(0)


func test_clear_empties_the_loadout() -> void:
	var loadout := Loadout.new()
	loadout.pick(_ability("fireball"))
	loadout.clear()
	assert_int(loadout.picks.size()).is_equal(0)


func test_from_class_seeds_the_basic_spells() -> void:
	var basics: Array[Ability] = [_ability("fireball"), _ability("smoke")]
	var character_class := CharacterClass.new()
	character_class.basic_spells = basics
	var loadout := Loadout.from_class(character_class)
	assert_array(loadout.picks).contains_exactly(basics)


func test_from_null_class_is_an_empty_pool() -> void:
	assert_int(Loadout.from_class(null).picks.size()).is_equal(0)


func test_from_class_copies_so_the_pool_cannot_mutate_the_class() -> void:
	var basics: Array[Ability] = [_ability("fireball")]
	var character_class := CharacterClass.new()
	character_class.basic_spells = basics
	var loadout := Loadout.from_class(character_class)
	loadout.pick(_ability("smoke"))
	assert_int(character_class.basic_spells.size()).is_equal(1)


func test_basic_spells_count_toward_the_pool_cap() -> void:
	var basics: Array[Ability] = [_ability("fireball"), _ability("smoke")]
	var character_class := CharacterClass.new()
	character_class.basic_spells = basics
	var loadout := Loadout.from_class(character_class)
	for name in ["boomerang", "meteor", "teleport", "blink"]:
		assert_bool(loadout.pick(_ability(name))).is_true()
	assert_bool(loadout.is_full()).is_true()
	assert_bool(loadout.pick(_ability("anivia_wall"))).is_false()
