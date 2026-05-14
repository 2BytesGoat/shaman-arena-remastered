class_name Unit extends CharacterBody2D

@export var aim_sprite: Sprite2D

const SPEED = 250.0
const FRICTION = 850.0
const JUMP_VELOCITY = -400.0
const TURN_ACCELERATION = 15

var move_direction = Vector2.ZERO
var cast_direction = Vector2.RIGHT
var cast_angle = 0.0


func _physics_process(delta: float) -> void:
	var x_direction := Input.get_axis("ui_left", "ui_right")
	var y_direction := Input.get_axis("ui_up", "ui_down")
	move_direction = Vector2(x_direction, y_direction).normalized()
	
	update_cast_angle()
	update_facing_direction(delta)


func update_cast_angle():
	#cast_angle = (Utils.get_mouse_global_position() - global_position).angle()
	if move_direction != Vector2.ZERO:
		cast_direction = move_direction
		cast_angle = move_direction.angle()


func update_facing_direction(delta):
	var diff = wrapf(cast_angle - aim_sprite.rotation, -PI, PI)
	aim_sprite.rotation += clamp(
		diff,
		-TURN_ACCELERATION * delta,
		TURN_ACCELERATION * delta
	)
