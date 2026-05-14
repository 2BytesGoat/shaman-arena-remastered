class_name BaseAbilityScene extends Node

@export var MAX_SPEED: float = 0.0
@export var KNOCKBACK: float = 0.0
@export var DAMAGE: float = 0.0

@export var on_hit_effect: PackedScene
@export var velocity_curve: Curve

var cast_source
var cast_direction


func cast(_source: Unit, _direction: Vector2) -> void:
	pass
