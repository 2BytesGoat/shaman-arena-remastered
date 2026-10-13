class_name SpellScene extends Area2D

@export var MAX_SPEED: float = 0.0
@export var KNOCKBACK: float = 0.0
@export var DAMAGE: float = 0.0

@export var on_hit_effect: PackedScene
@export var velocity_curve: Curve

var source: Unit
var cast_direction := Vector2.ZERO

@onready var timer: Timer = get_node_or_null("Timer")


func cast(cast_source: Unit, direction: Vector2) -> void:
	source = cast_source
	cast_direction = direction
	rotation = direction.angle()


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


func _on_timer_timeout() -> void:
	_on_hit()


func _on_area_entered(area: Area2D) -> void:
	if SourceFilter.ignores(source, area):
		return
	_on_hit()


func _on_hit() -> void:
	if on_hit_effect != null:
		var effect := Utils.instantiate_object_in_scene(on_hit_effect, global_position) as Effect
		effect.source = source
	queue_free()
