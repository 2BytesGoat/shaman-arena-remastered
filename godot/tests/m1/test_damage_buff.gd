extends GdUnitTestSuite


func _make_container() -> AttributeContainer:
	var max_health := Attribute.new()
	max_health.attribute_name = AttributeNames.MAX_HEALTH
	var health := Attribute.new()
	health.attribute_name = AttributeNames.HEALTH
	var attribute_set := AttributeSet.new()
	attribute_set.attributes = [max_health, health]
	var container := AttributeContainer.new()
	container.attribute_set = attribute_set
	add_child(container)
	container.apply_buff(InitializeAttributesBuff.new(100.0))
	return container


func test_initialize_buff_sets_health_and_max_health() -> void:
	var container := _make_container()
	assert_float(container.get_attribute_value_by_name(AttributeNames.HEALTH)).is_equal(100.0)
	assert_float(container.get_attribute_value_by_name(AttributeNames.MAX_HEALTH)).is_equal(100.0)


func test_damage_buff_subtracts_health() -> void:
	var container := _make_container()
	container.apply_buff(DamageBuff.new(30.0))
	assert_float(container.get_attribute_value_by_name(AttributeNames.HEALTH)).is_equal(70.0)


func test_repeated_damage_buffs_accumulate() -> void:
	var container := _make_container()
	container.apply_buff(DamageBuff.new(30.0))
	container.apply_buff(DamageBuff.new(50.0))
	assert_float(container.get_attribute_value_by_name(AttributeNames.HEALTH)).is_equal(20.0)


func test_damage_buff_can_reach_lethal_value() -> void:
	var container := _make_container()
	container.apply_buff(DamageBuff.new(120.0))
	var health: float = container.get_attribute_value_by_name(AttributeNames.HEALTH)
	assert_bool(Unit.is_lethal(AttributeNames.HEALTH, health)).is_true()


func test_lethal_predicate_ignores_other_attributes_and_positive_health() -> void:
	assert_bool(Unit.is_lethal(AttributeNames.HEALTH, 1.0)).is_false()
	assert_bool(Unit.is_lethal(AttributeNames.MAX_HEALTH, 0.0)).is_false()
