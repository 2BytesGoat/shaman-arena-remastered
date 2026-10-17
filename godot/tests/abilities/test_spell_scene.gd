extends GdUnitTestSuite


func _make_curve() -> Curve:
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.0))
	curve.add_point(Vector2(1.0, 1.0))
	return curve


func _make_unit() -> Unit:
	var unit_scene: PackedScene = load("res://src/player/player.tscn")
	var unit := unit_scene.instantiate() as Unit
	unit.set_physics_process(false)
	add_child(unit)
	auto_free(unit)
	await get_tree().process_frame
	return unit


func _instantiate_spell(path: String) -> SpellScene:
	var spell := (load(path) as PackedScene).instantiate() as SpellScene
	spell.set_physics_process(false)
	add_child(spell)
	auto_free(spell)
	return spell


## `Utils` parents spawned scenes to the tree root when there is no current scene (tests).
func _await_spawned(type: Variant) -> Node:
	for _attempt in 5:
		var spawned: Node = null
		for child in get_tree().root.get_children():
			if is_instance_of(child, type):
				spawned = child
		if spawned != null:
			return spawned
		await get_tree().process_frame
	return null


func _health(unit: Unit) -> float:
	return unit.attribute_container.get_attribute_value_by_name(AttributeNames.HEALTH)


func test_speed_at_samples_velocity_curve() -> void:
	var spell: ProjectileSpell = auto_free(ProjectileSpell.new())
	spell.MAX_SPEED = 200.0
	spell.velocity_curve = _make_curve()
	assert_float(spell.speed_at(0.0)).is_equal_approx(0.0, 1.0)
	assert_float(spell.speed_at(0.5)).is_equal_approx(100.0, 5.0)
	assert_float(spell.speed_at(1.0)).is_equal_approx(200.0, 5.0)


func test_speed_at_without_curve_returns_max_speed() -> void:
	var spell: ProjectileSpell = auto_free(ProjectileSpell.new())
	spell.MAX_SPEED = 300.0
	assert_float(spell.speed_at(0.5)).is_equal(300.0)


func test_source_filter_ignores_own_spell() -> void:
	var unit: Unit = auto_free(Unit.new())
	var spell: SpellScene = auto_free(SpellScene.new())
	spell.add_to_group(&"Spell")
	spell.source = unit
	assert_bool(SourceFilter.ignores(unit, spell)).is_true()


func test_source_filter_allows_other_players_spell() -> void:
	var unit: Unit = auto_free(Unit.new())
	var other_unit: Unit = auto_free(Unit.new())
	var spell: SpellScene = auto_free(SpellScene.new())
	spell.add_to_group(&"Spell")
	spell.source = other_unit
	assert_bool(SourceFilter.ignores(unit, spell)).is_false()


func test_source_filter_ignores_own_hurtbox() -> void:
	var unit: Unit = auto_free(Unit.new())
	var hurtbox: Area2D = auto_free(Area2D.new())
	unit.add_child(hurtbox)
	assert_bool(SourceFilter.ignores(unit, hurtbox)).is_true()


func test_source_filter_allows_plain_area() -> void:
	var unit: Unit = auto_free(Unit.new())
	var area: Area2D = auto_free(Area2D.new())
	assert_bool(SourceFilter.ignores(unit, area)).is_false()


func test_spell_touching_own_hurtbox_does_not_despawn() -> void:
	var unit := await _make_unit()
	var fireball := _instantiate_spell("res://src/abilities/spells/projectile/fireball.tscn")
	fireball.source = unit
	fireball._on_area_entered(unit.get_node("Hurtbox") as Area2D)
	assert_bool(fireball.is_queued_for_deletion()).is_false()
	assert_float(_health(unit)).is_equal(100.0)


func test_self_hitting_abilities_are_flagged() -> void:
	for path in ["fireball", "boomerang", "meteor"]:
		var ability: BaseAbility = load(
			"res://src/resources/abilities/projectile/%s_ability.tres" % path
		)
		assert_bool(ability.HITS_SELF).is_true()


func test_smoke_and_teleport_stay_self_immune() -> void:
	var smoke: BaseAbility = load("res://src/resources/abilities/field/smoke_ability.tres")
	var teleport: BaseAbility = load(
		"res://src/resources/abilities/projectile/teleport_ability.tres"
	)
	assert_bool(smoke.HITS_SELF).is_false()
	assert_bool(teleport.HITS_SELF).is_false()


func test_self_hitting_ability_hurts_its_caster() -> void:
	var unit := await _make_unit()
	var ability: BaseAbility = load(
		"res://src/resources/abilities/projectile/fireball_ability.tres"
	)
	ability.cast(unit, Vector2.RIGHT)
	var spell: SpellScene = await _await_spawned(SpellScene)
	assert_object(spell).is_not_null()
	if spell == null:
		return
	auto_free(spell)
	assert_bool(spell.hits_self).is_true()
	spell._on_area_entered(unit.get_node("Hurtbox") as Area2D)
	assert_bool(spell.is_queued_for_deletion()).is_true()
	assert_float(_health(unit)).is_equal(100.0 - spell.DAMAGE)
	# The on-hit effect keeps the same rule, so the whole impact chain can hurt the caster.
	var effect := await _await_spawned(Effect)
	assert_object(effect).is_not_null()
	if effect != null:
		auto_free(effect)
		assert_bool(effect.hits_self).is_true()


func test_smoke_never_hurts_its_caster() -> void:
	var unit := await _make_unit()
	var ability: BaseAbility = load("res://src/resources/abilities/field/smoke_ability.tres")
	ability.cast(unit, Vector2.ZERO)
	var smoke: SpellScene = await _await_spawned(SpellScene)
	assert_object(smoke).is_not_null()
	if smoke == null:
		return
	auto_free(smoke)
	assert_bool(smoke.hits_self).is_false()
	smoke._on_area_entered(unit.get_node("Hurtbox") as Area2D)
	assert_float(_health(unit)).is_equal(100.0)
	assert_vector(unit.velocity).is_equal(Vector2.ZERO)
	assert_bool(unit.hit_locked).is_false()
	assert_bool(smoke.is_queued_for_deletion()).is_false()


func test_meteor_telegraph_passes_the_flag_to_its_strike() -> void:
	var unit := await _make_unit()
	var telegraph := (
		load("res://src/abilities/effects/telegraph/meteor_incoming.tscn") as PackedScene
	).instantiate() as Effect
	add_child(telegraph)
	auto_free(telegraph)
	telegraph.source = unit
	telegraph.hits_self = true
	telegraph._on_expiry_timer_timeout()
	var strike := await _await_spawned(Effect)
	assert_object(strike).is_not_null()
	if strike == null:
		return
	auto_free(strike)
	assert_bool(strike.hits_self).is_true()
	assert_object(strike.source).is_same(unit)


func test_teleport_effect_is_pure_vfx() -> void:
	var effect := (
		load("res://src/abilities/effects/impact/teleport_effect.tscn") as PackedScene
	).instantiate() as Effect
	auto_free(effect)
	assert_bool(effect.monitoring).is_false()
	assert_int(effect.collision_layer).is_equal(0)
	assert_float(effect.KNOCKBACK).is_equal(0.0)
