class_name MoveState extends State


func physics_update(delta: float) -> void:
	if owner.move_direction:
		owner.velocity = owner.move_direction * owner.SPEED
	else:
		owner.velocity = owner.velocity.move_toward(Vector2.ZERO, owner.FRICTION * delta)
	
	owner.move_and_slide()
	
	if owner.velocity == Vector2.ZERO:
		state_machine.transition_to("Idle")
