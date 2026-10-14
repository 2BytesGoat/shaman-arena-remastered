extends GdUnitTestSuite


class FakeAbility extends BaseAbility:
	var cast_called := false

	func cast(_unit: Unit, _direction: Vector2) -> void:
		cast_called = true


func _make_unit(at := Vector2(100.0, 0.0)) -> Unit:
	var scene: PackedScene = load("res://src/player/player.tscn")
	var unit := scene.instantiate() as Unit
	unit.set_physics_process(false)
	add_child(unit)
	unit.global_position = at
	unit.apply_loadout(_picks(["fireball", "smoke"]))
	auto_free(unit)
	return unit


func _picks(names: Array) -> Array[Ability]:
	var picks: Array[Ability] = []
	for name in names:
		picks.append(load("res://src/resources/abilities/%s_ability.tres" % name))
	return picks


func _ability(unit: Unit, ability_id: StringName) -> BaseAbility:
	for ability in unit.ability_slots:
		if ability.ability_name == ability_id:
			return ability as BaseAbility
	return null


func _activate(unit: Unit, ability: Ability) -> void:
	assert_int(unit.ability_container.try_activate(ability)).is_equal(RuntimeAbility.ABILITY_EVENT_TYPE_ACTIVATED_DURATION_STARTED)


func test_try_end_during_windup_cancels_without_cooldown() -> void:
	var unit := _make_unit()
	await get_tree().process_frame
	var fireball := _ability(unit, &"Fireball")
	var events: Array[String] = []
	unit.ability_container.cooldown_start.connect(func(_a: Ability) -> void: events.append("cooldown_start"))
	unit.ability_container.ability_ended.connect(func(_a: Ability) -> void: events.append("ended"))
	_activate(unit, fireball)

	assert_bool(unit.try_abort_cast(fireball)).is_true()
	assert_bool(unit.ability_container.is_ability_active(fireball)).is_false()
	assert_bool(unit.ability_container.is_ability_cooldown_active(fireball)).is_false()
	assert_array(events).contains(["ended"])
	assert_bool(events.has("cooldown_start")).is_false()
	assert_int(unit.ability_container.try_activate(fireball)).is_equal(RuntimeAbility.ABILITY_EVENT_TYPE_ACTIVATED_DURATION_STARTED)


func test_try_abort_inactive_ability_returns_false() -> void:
	var unit := _make_unit()
	await get_tree().process_frame
	var fireball := _ability(unit, &"Fireball")
	assert_bool(unit.try_abort_cast(fireball)).is_false()


func test_interruptibility_flags() -> void:
	var fireball: BaseAbility = load("res://src/resources/abilities/fireball_ability.tres")
	var smoke: BaseAbility = load("res://src/resources/abilities/smoke_ability.tres")
	assert_bool(CastHandler.is_cast_interruptible(fireball)).is_true()
	assert_bool(CastHandler.is_cast_interruptible(smoke)).is_false()
	assert_bool(CastHandler.is_cast_interruptible(BaseAbility.new())).is_true()


func test_hit_aborts_interruptible_windup() -> void:
	var unit := _make_unit()
	await get_tree().process_frame
	var fireball := _ability(unit, &"Fireball")
	_activate(unit, fireball)

	unit.take_hit(null, 1.0, 0.0, Vector2.ZERO)
	assert_bool(unit.ability_container.is_ability_active(fireball)).is_false()
	assert_bool(unit.ability_container.is_ability_cooldown_active(fireball)).is_false()
	assert_float(unit.attribute_container.get_attribute_value_by_name(AttributeNames.HEALTH)).is_equal(9.0)
	assert_bool(unit.hit_locked).is_true()


func test_hit_does_not_abort_uninterruptible_smoke() -> void:
	var unit := _make_unit()
	await get_tree().process_frame
	var smoke := _ability(unit, &"Smoke")
	_activate(unit, smoke)

	unit.take_hit(null, 1.0, 0.0, Vector2.ZERO)
	assert_bool(unit.ability_container.is_ability_active(smoke)).is_true()
	assert_bool(unit.ability_container.is_ability_cooldown_active(smoke)).is_false()
	assert_float(unit.attribute_container.get_attribute_value_by_name(AttributeNames.HEALTH)).is_equal(9.0)


func test_try_abort_refuses_uninterruptible_unless_forced() -> void:
	var unit := _make_unit()
	await get_tree().process_frame
	var smoke := _ability(unit, &"Smoke")
	_activate(unit, smoke)

	assert_bool(unit.try_abort_cast(smoke)).is_false()
	assert_bool(unit.ability_container.is_ability_active(smoke)).is_true()
	assert_bool(unit.try_abort_cast(smoke, true)).is_true()
	assert_bool(unit.ability_container.is_ability_active(smoke)).is_false()
	assert_bool(unit.ability_container.is_ability_cooldown_active(smoke)).is_false()


func test_death_aborts_uninterruptible_cast() -> void:
	var unit := _make_unit()
	await get_tree().process_frame
	var smoke := _ability(unit, &"Smoke")
	_activate(unit, smoke)

	unit.take_hit(null, 100.0, 0.0, Vector2.ZERO)
	assert_bool(unit.player_dead).is_true()
	assert_bool(unit.ability_container.is_ability_active(smoke)).is_false()
	assert_bool(unit.ability_container.is_ability_cooldown_active(smoke)).is_false()
	assert_str(unit.state_machine.state.name).is_equal("Dead")


func test_cooldown_start_guard_skips_spawn_when_dead() -> void:
	var unit := _make_unit()
	await get_tree().process_frame
	var fake := FakeAbility.new()

	unit.player_dead = true
	unit.cast_handler.on_spell_cooldown_start(fake)
	assert_bool(fake.cast_called).is_false()

	unit.player_dead = false
	unit.cast_handler.on_spell_cooldown_start(fake)
	assert_bool(fake.cast_called).is_true()
