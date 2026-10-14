class_name PlayerVisuals extends Node

@export var unit: Unit


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
	if unit.aim_sprite == null:
		return
	var difference := wrapf(unit.cast_angle - unit.aim_sprite.rotation, -PI, PI)
	unit.aim_sprite.rotation += clampf(
		difference, -Unit.TURN_ACCELERATION * delta, Unit.TURN_ACCELERATION * delta
	)
