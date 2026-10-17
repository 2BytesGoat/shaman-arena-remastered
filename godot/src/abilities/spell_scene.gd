class_name SpellScene extends Area2D

@export var KNOCKBACK: float = 0.0
@export var DAMAGE: float = 0.0

@export var on_hit_effect: PackedScene

var source: Unit
var cast_direction := Vector2.ZERO
## Set by the casting ability (`BaseAbility.HITS_SELF`); carried to every impact scene the spell
## spawns, so a spell that can hurt its caster hurts through its whole chain (D-018).
var hits_self := false

@onready var expiry_timer: Timer = get_node_or_null("ExpiryTimer")


func cast(cast_source: Unit, direction: Vector2) -> void:
	source = cast_source
	cast_direction = direction
	rotation = direction.angle()


func _on_expiry_timer_timeout() -> void:
	_on_hit()


func _on_area_entered(area: Area2D) -> void:
	if HitArea.apply(self, area, source, DAMAGE, KNOCKBACK, hits_self):
		_on_hit()


func _on_hit() -> void:
	if on_hit_effect != null:
		var effect := Utils.instantiate_object_in_scene(on_hit_effect, global_position) as Effect
		if effect != null:
			effect.source = source
			effect.hits_self = hits_self
	queue_free()
