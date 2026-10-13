class_name SpellScene extends Area2D

@export var KNOCKBACK: float = 0.0
@export var DAMAGE: float = 0.0

@export var on_hit_effect: PackedScene

var source: Unit
var cast_direction := Vector2.ZERO

@onready var timer: Timer = get_node_or_null("Timer")


func cast(cast_source: Unit, direction: Vector2) -> void:
	source = cast_source
	cast_direction = direction
	rotation = direction.angle()


func _on_timer_timeout() -> void:
	_on_hit()


func _on_area_entered(area: Area2D) -> void:
	if SourceFilter.ignores(source, area):
		return
	HitArea.apply(self, area, source, DAMAGE, KNOCKBACK)
	_on_hit()


func _on_hit() -> void:
	if on_hit_effect != null:
		var effect := Utils.instantiate_object_in_scene(on_hit_effect, global_position) as Effect
		effect.source = source
	queue_free()
