extends GdUnitTestSuite

const AbilityPaths := preload("res://tests/support/ability_paths.gd")


func test_wizard_loads_with_fireball_and_smoke_as_basics() -> void:
	var wizard := load("res://src/resources/classes/wizard.tres") as CharacterClass
	assert_object(wizard).is_not_null()
	assert_str(wizard.display_name).is_equal("Wizard")
	assert_array(wizard.basic_spells).contains_exactly([
		load(AbilityPaths.path("fireball")),
		load(AbilityPaths.path("smoke")),
	])
