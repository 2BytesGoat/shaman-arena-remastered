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


func cast(unit: Unit, direction: Vector2) -> void:
	if SPELL_SCENE == null:
		return
	var spell := Utils.instantiate_object_in_scene(SPELL_SCENE, unit.spell_spawn_position(direction)) as SpellScene
	spell.cast(unit, direction)


func _get_duration(_ability_container: AbilityContainer) -> float:
	return CAST_DELAY


func _get_cooldown(_ability_container: AbilityContainer) -> float:
	return COOLDOWN
