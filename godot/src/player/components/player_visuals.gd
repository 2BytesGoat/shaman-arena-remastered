class_name PlayerVisuals extends Node2D

const AIM_TURN_SPEED := 15.0
const CAST_DEFERRED_CLIPS := [&"Idle", &"Move", &"Aim"]

@export var unit: Unit

@onready var flippable: Node2D = $Flippable
@onready var aim_sprite: Sprite2D = $AimSprite


func play(clip: StringName) -> void:
	if clip in CAST_DEFERRED_CLIPS and unit.cast_handler.is_windup_active():
		return
	unit.animation_player.speed_scale = 1.0
	unit.animation_player.play(clip)


func play_cast(clip: StringName, cast_delay: float) -> void:
	unit.animation_player.speed_scale = BaseAbility.cast_animation_speed(
		unit.animation_player.get_animation(clip).length, cast_delay
	)
	unit.animation_player.play(clip)


func reassert_animation() -> void:
	var state_name := unit.state_machine.state.name
	if state_name in CAST_DEFERRED_CLIPS:
		play(state_name)


func set_facing(scale: float) -> void:
	flippable.scale.x = scale


func apply_palette() -> void:
	var palette: Array = Constants.player_colors.get("player_%d" % unit.PLAYER_CONTROLLER, [])
	if palette.is_empty() or not (unit.material is ShaderMaterial):
		return
	(unit.material as ShaderMaterial).set_shader_parameter("to_colors", PackedColorArray(palette))


func layout_hud() -> void:
	if unit.PLAYER_CONTROLLER % 2 == 0:
		return
	unit.hud_margin.anchor_left = 1.0
	unit.hud_margin.anchor_right = 1.0
	unit.hud_margin.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	unit.hud_margin.add_theme_constant_override("margin_left", 0)
	unit.hud_margin.add_theme_constant_override("margin_right", 45)


func update_aim_sprite(delta: float) -> void:
	if aim_sprite == null:
		return
	var difference := wrapf(unit.cast_angle - aim_sprite.rotation, -PI, PI)
	aim_sprite.rotation += clampf(
		difference, -AIM_TURN_SPEED * delta, AIM_TURN_SPEED * delta
	)
