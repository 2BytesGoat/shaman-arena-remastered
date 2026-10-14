class_name IdleState extends State


func enter(_msg := {}) -> void:
	owner.visuals.play(self.name)


func physics_update(_delta: float) -> void:
	if owner.move_direction != Vector2.ZERO:
		state_machine.transition_to(AnimationSlots.MOVE)
