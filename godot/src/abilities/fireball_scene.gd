class_name Fireball extends BaseAbilityScene


func cast(source: Unit, direction: Vector2) -> void:
	self.cast_source = source
	self.cast_direction = direction
	self.rotation = cast_direction.angle()


func _physics_process(delta: float) -> void:
	var velocity = cast_direction * MAX_SPEED
	self.global_position += velocity * delta
