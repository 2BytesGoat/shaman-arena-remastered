class_name ProjectileSpell extends SpellScene

@export var MAX_SPEED: float = 0.0
@export var velocity_curve: Curve


func sample_time() -> float:
	if timer == null or timer.wait_time <= 0.0:
		return 0.0
	return clampf(1.0 - timer.time_left / timer.wait_time, 0.0, 1.0)


func speed_at(time: float) -> float:
	if velocity_curve == null:
		return MAX_SPEED
	return MAX_SPEED * velocity_curve.sample(time)


func _physics_process(delta: float) -> void:
	var time := sample_time()
	global_position += cast_direction * speed_at(time) * delta
	_on_move(time)


func _on_move(_time: float) -> void:
	pass
