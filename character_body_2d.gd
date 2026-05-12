class_name Unit extends CharacterBody2D

@export var aim_sprite: Sprite2D

const SPEED = 250.0
const FRICTION = 850.0
const JUMP_VELOCITY = -400.0
const TURN_ACCELERATION = 300

var cast_angle = 0.0


func _physics_process(delta: float) -> void:
	cast_angle = (Utils.get_mouse_global_position() - global_position).angle()
	
	## Add the gravity.
	#if not is_on_floor():
		#velocity += get_gravity() * delta
#
	## Handle jump.
	#if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		#velocity.y = JUMP_VELOCITY

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var x_direction := Input.get_axis("ui_left", "ui_right")
	var y_direction := Input.get_axis("ui_up", "ui_down")
	var direction := Vector2(x_direction, y_direction).normalized()
	if direction:
		velocity = direction * SPEED
	else:
		velocity = velocity.move_toward(Vector2.ZERO, FRICTION * delta)

	move_and_slide()
	update_facing_direction(delta)


func update_facing_direction(delta):
	var diff = wrapf(cast_angle - aim_sprite.rotation, -PI, PI)
	aim_sprite.rotation += clamp(
		diff,
		-TURN_ACCELERATION * delta,
		TURN_ACCELERATION * delta
	)
