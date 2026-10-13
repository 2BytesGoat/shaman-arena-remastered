extends GdUnitTestSuite


class TestSpell extends Ability:
	func _init() -> void:
		ability_name = &"TestSpell"

	func _get_duration(_ability_container: AbilityContainer) -> float:
		return 0.1

	func _get_cooldown(_ability_container: AbilityContainer) -> float:
		return 0.1


class InstantSpell extends Ability:
	func _init() -> void:
		ability_name = &"InstantSpell"

	func _get_cooldown(_ability_container: AbilityContainer) -> float:
		return 1.0


func test_duration_then_cooldown_then_ended() -> void:
	var container: AbilityContainer = auto_free(AbilityContainer.new())
	add_child(container)
	var ability := TestSpell.new()
	container.add_ability(ability)
	var events: Array[String] = []
	container.ability_activated.connect(func(_ability: Ability) -> void: events.append("activated"))
	container.cooldown_start.connect(func(_ability: Ability) -> void: events.append("cooldown_start"))
	container.ability_ended.connect(func(_ability: Ability) -> void: events.append("ended"))

	assert_int(container.try_activate(ability)).is_equal(RuntimeAbility.ABILITY_EVENT_TYPE_ACTIVATED_DURATION_STARTED)
	assert_int(container.try_activate(ability)).is_equal(RuntimeAbility.ABILITY_EVENT_TYPE_REFUSED_TO_ACTIVATE_IS_DURATION_ACTIVE)

	var frames := 0
	while not container.is_ability_cooldown_active(ability) and frames < 30:
		await get_tree().physics_frame
		frames += 1
	assert_bool(container.is_ability_cooldown_active(ability)).is_true()
	assert_int(container.try_activate(ability)).is_equal(RuntimeAbility.ABILITY_EVENT_TYPE_REFUSED_TO_ACTIVATE_IS_COOLING_DOWN)

	while container.is_ability_cooldown_active(ability) and frames < 60:
		await get_tree().physics_frame
		frames += 1
	await get_tree().physics_frame
	assert_bool(container.is_ability_cooldown_active(ability)).is_false()
	assert_array(events).contains(["activated", "cooldown_start", "ended"])
	assert_str(events[0]).is_equal("activated")
	assert_str(events[1]).is_equal("cooldown_start")
	assert_str(events[-1]).is_equal("ended")


func test_instant_ability_starts_cooldown_synchronously() -> void:
	var container: AbilityContainer = auto_free(AbilityContainer.new())
	add_child(container)
	var ability := InstantSpell.new()
	container.add_ability(ability)
	var started := [false]
	container.cooldown_start.connect(func(_ability: Ability) -> void: started[0] = true)

	assert_int(container.try_activate(ability)).is_equal(RuntimeAbility.ABILITY_EVENT_TYPE_ACTIVATED_COOLDOWN_STARTED)
	assert_bool(started[0]).is_true()
	assert_bool(container.is_ability_active(ability)).is_false()
	assert_bool(container.is_ability_cooldown_active(ability)).is_true()
