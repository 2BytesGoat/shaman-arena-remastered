extends GdUnitTestSuite


func _make_curve() -> Curve:
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.0))
	curve.add_point(Vector2(1.0, 1.0))
	return curve


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
	var unit_scene: PackedScene = load("res://src/player/player.tscn")
	var unit := unit_scene.instantiate() as Unit
	unit.set_physics_process(false)
	add_child(unit)
	auto_free(unit)
	await get_tree().process_frame
	var spell_scene: PackedScene = load("res://src/abilities/spells/projectile/fireball.tscn")
	var fireball := spell_scene.instantiate() as SpellScene
	fireball.set_physics_process(false)
	add_child(fireball)
	auto_free(fireball)
	fireball.source = unit
	fireball._on_area_entered(unit.get_node("Hurtbox") as Area2D)
	assert_bool(fireball.is_queued_for_deletion()).is_false()
	assert_float(unit.attribute_container.get_attribute_value_by_name(AttributeNames.HEALTH)).is_equal(10.0)
