extends GdUnitTestSuite


func _make_victim(at: Vector2) -> Unit:
	var scene: PackedScene = load("res://src/player/player.tscn")
	var victim := scene.instantiate() as Unit
	victim.set_physics_process(false)
	add_child(victim)
	victim.global_position = at
	auto_free(victim)
	return victim


func test_apply_damages_unit_and_knocks_it_back() -> void:
	var victim := _make_victim(Vector2(100.0, 0.0))
	await get_tree().process_frame
	var attacker: Area2D = auto_free(Area2D.new())
	add_child(attacker)
	var hurtbox: Area2D = victim.get_node("Hurtbox")
	HitArea.apply(attacker, hurtbox, null, 3.0, 50.0)
	assert_float(victim.attribute_container.get_attribute_value_by_name(AttributeNames.HEALTH)).is_equal(7.0)
	assert_float(victim.velocity.x).is_equal_approx(50.0, 0.1)
	assert_float(victim.velocity.y).is_equal_approx(0.0, 0.1)
	assert_bool(victim.hit_locked).is_true()
	assert_str(victim.state_machine.state.name).is_equal("Hit")


func test_apply_ignores_own_hurtbox() -> void:
	var victim := _make_victim(Vector2(100.0, 0.0))
	await get_tree().process_frame
	var hurtbox: Area2D = victim.get_node("Hurtbox")
	HitArea.apply(hurtbox, hurtbox, victim, 5.0, 100.0)
	assert_float(victim.attribute_container.get_attribute_value_by_name(AttributeNames.HEALTH)).is_equal(10.0)
	assert_vector(victim.velocity).is_equal(Vector2.ZERO)


func test_apply_ignores_area_without_unit_parent() -> void:
	var attacker: Area2D = auto_free(Area2D.new())
	add_child(attacker)
	var marker: Node2D = auto_free(Node2D.new())
	add_child(marker)
	var area: Area2D = auto_free(Area2D.new())
	marker.add_child(area)
	HitArea.apply(attacker, area, null, 5.0, 100.0)
	assert_bool(is_instance_valid(area)).is_true()
