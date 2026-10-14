extends GdUnitTestSuite


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
	var smoke: BaseAbility = load("res://src/resources/abilities/smoke_ability.tres")
	assert_str(String(smoke.CAST_ANIMATION)).is_equal("CastSmoke")
