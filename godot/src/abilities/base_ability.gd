class_name BaseAbility extends Ability

enum SpellType {
	OFFENSIVE,
	DEFENSIVE,
	UTILITY
}

enum CastMode {
	INSTANT,
	AIMED
}

@export var ICON: Texture2D
@export var TYPE: SpellType = SpellType.OFFENSIVE
@export var CAST_MODE: CastMode = CastMode.AIMED
@export var CAST_DELAY: float = 0.0
@export var COOLDOWN: float = 5.0
@export var SPELL_SCENE: PackedScene
@export var UNINTERRUPTIBLE: bool = false
@export var CAST_ANIMATION: StringName = &""


static func default_cast_animation(type: SpellType) -> StringName:
	match type:
		SpellType.OFFENSIVE:
			return &"CastOffensive"
		SpellType.DEFENSIVE:
			return &"CastDefensive"
		SpellType.UTILITY:
			return &"CastUtility"
	return &""


static func resolve_cast_animation(ability: BaseAbility, animations: AnimationPlayer) -> StringName:
	if ability == null or animations == null:
		return &""
	if ability.CAST_ANIMATION != &"" and animations.has_animation(ability.CAST_ANIMATION):
		return ability.CAST_ANIMATION
	var slot := default_cast_animation(ability.TYPE)
	if animations.has_animation(slot):
		return slot
	if ability.CAST_ANIMATION != &"":
		push_warning("Character is missing '%s' and slot '%s' for %s." % [ability.CAST_ANIMATION, slot, ability.ability_name])
	else:
		push_warning("Character is missing required cast slot '%s'." % slot)
	return &""


static func cast_animation_speed(clip_length: float, cast_delay: float) -> float:
	if cast_delay <= 0.0 or clip_length <= 0.0:
		return 1.0
	return clip_length / cast_delay


func cast(unit: Unit, direction: Vector2) -> void:
	if SPELL_SCENE == null:
		return
	var spell := Utils.instantiate_object_in_scene(SPELL_SCENE, unit.spell_spawn_position(direction)) as SpellScene
	spell.cast(unit, direction)


func _get_duration(_ability_container: AbilityContainer) -> float:
	return CAST_DELAY


func _get_cooldown(_ability_container: AbilityContainer) -> float:
	return COOLDOWN
