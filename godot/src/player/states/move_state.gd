class_name MoveState extends State


func physics_update(_delta: float) -> void:
	if owner.move_direction == Vector2.ZERO and owner.velocity == Vector2.ZERO:
		state_machine.transition_to("Idle")
