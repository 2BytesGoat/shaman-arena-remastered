class_name DeadState extends State


func enter(_msg := {}) -> void:
	owner.move_direction = Vector2.ZERO
	owner.velocity = Vector2.ZERO
