class_name IdleState extends State


func physics_update(_delta: float) -> void:
	if owner.move_direction:
		state_machine.transition_to("Move")
