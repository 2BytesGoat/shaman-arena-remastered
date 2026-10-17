extends GdUnitTestSuite

const AbilityPaths := preload("res://tests/support/ability_paths.gd")


class FakeAbility extends BaseAbility:
	pass


func _fake_ability(ability_id: StringName, type: BaseAbility.SpellType, cast_animation := &"") -> FakeAbility:
	var ability := FakeAbility.new()
	ability.ability_name = ability_id
	ability.TYPE = type
	ability.CAST_ANIMATION = cast_animation
	return ability


func _make_animations(clips: Array[StringName]) -> AnimationPlayer:
	var animations: AnimationPlayer = auto_free(AnimationPlayer.new())
	add_child(animations)
	var library := AnimationLibrary.new()
	for clip in clips:
		var animation := Animation.new()
		animation.length = 0.6
		library.add_animation(clip, animation)
	animations.add_animation_library(&"", library)
	return animations


func test_default_cast_animation_maps_type_to_slot() -> void:
	assert_str(String(BaseAbility.default_cast_animation(BaseAbility.SpellType.OFFENSIVE))).is_equal("CastOffensive")
	assert_str(String(BaseAbility.default_cast_animation(BaseAbility.SpellType.DEFENSIVE))).is_equal("CastDefensive")
	assert_str(String(BaseAbility.default_cast_animation(BaseAbility.SpellType.UTILITY))).is_equal("CastUtility")


func test_flavor_clip_wins_when_the_character_has_it() -> void:
	var animations := _make_animations([&"CastDefensive", &"CastSmoke"])
	var smoke := _fake_ability(&"Smoke", BaseAbility.SpellType.DEFENSIVE, &"CastSmoke")
	assert_str(String(BaseAbility.resolve_cast_animation(smoke, animations))).is_equal("CastSmoke")


func test_flavor_clip_falls_back_to_type_slot() -> void:
	var animations := _make_animations([&"CastDefensive"])
	var smoke := _fake_ability(&"Smoke", BaseAbility.SpellType.DEFENSIVE, &"CastSmoke")
	assert_str(String(BaseAbility.resolve_cast_animation(smoke, animations))).is_equal("CastDefensive")


func test_missing_slot_returns_empty() -> void:
	var animations := _make_animations([&"Idle"])
	var fireball := _fake_ability(&"Fireball", BaseAbility.SpellType.OFFENSIVE)
	assert_str(String(BaseAbility.resolve_cast_animation(fireball, animations))).is_equal("")


func test_speed_scale_fills_the_cast_delay() -> void:
	assert_float(BaseAbility.cast_animation_speed(0.6, 0.3)).is_equal_approx(2.0, 0.001)
	assert_float(BaseAbility.cast_animation_speed(1.2, 1.2)).is_equal_approx(1.0, 0.001)


func test_speed_scale_guards_instant_casts_and_empty_clips() -> void:
	assert_float(BaseAbility.cast_animation_speed(0.6, 0.0)).is_equal(1.0)
	assert_float(BaseAbility.cast_animation_speed(0.0, 0.5)).is_equal(1.0)


func test_smoke_ability_requests_cast_smoke_clip() -> void:
	var smoke: BaseAbility = load(AbilityPaths.path("smoke"))
	assert_str(String(smoke.CAST_ANIMATION)).is_equal("CastSmoke")


func _make_unit() -> Unit:
	var scene: PackedScene = load("res://src/player/player.tscn")
	var unit := scene.instantiate() as Unit
	unit.set_physics_process(false)
	add_child(unit)
	unit.get_node("StateMachine").set_physics_process(false)
	auto_free(unit)
	await get_tree().process_frame
	return unit


func test_sheet_implements_every_required_slot() -> void:
	var unit: Unit = await _make_unit()
	var missing: Array[String] = []
	for slot: StringName in AnimationSlots.REQUIRED:
		if not unit.animation_player.has_animation(slot):
			missing.append(String(slot))
	assert_array(missing).is_empty()


func test_cast_deferred_slots_are_implemented() -> void:
	var unit: Unit = await _make_unit()
	for slot: StringName in AnimationSlots.CAST_DEFERRED:
		assert_bool(unit.animation_player.has_animation(slot)).is_true()


func test_locomotion_state_nodes_are_named_after_their_slots() -> void:
	var unit: Unit = await _make_unit()
	var state_slots: Array[StringName] = [
		AnimationSlots.IDLE, AnimationSlots.MOVE, AnimationSlots.AIM,
		AnimationSlots.HIT, AnimationSlots.DEAD,
	]
	for slot: StringName in state_slots:
		assert_object(unit.state_machine.get_node_or_null(String(slot))).is_not_null()
		assert_bool(unit.animation_player.has_animation(slot)).is_true()


func test_one_shot_slots_do_not_loop() -> void:
	var unit: Unit = await _make_unit()
	var one_shot: Array[StringName] = [
		AnimationSlots.HIT, AnimationSlots.DEAD,
		AnimationSlots.CAST_OFFENSIVE, AnimationSlots.CAST_DEFENSIVE, AnimationSlots.CAST_UTILITY,
	]
	for slot: StringName in one_shot:
		assert_int(unit.animation_player.get_animation(slot).loop_mode).is_equal(Animation.LOOP_NONE)
