class_name DeadState extends State


func enter(_msg := {}) -> void:
	owner.move_direction = Vector2.ZERO
	owner.velocity = Vector2.ZERO
	owner.animation_player.speed_scale = 1.0
	owner.animation_player.play(&"Death")
