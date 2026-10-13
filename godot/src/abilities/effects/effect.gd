class_name Effect extends Area2D

@export var KNOCKBACK: float = 100.0
@export var DAMAGE: float = 0.0

var source: Unit


func _on_explosion_effect_animation_finished() -> void:
	queue_free()
