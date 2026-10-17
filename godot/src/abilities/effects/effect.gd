class_name Effect extends Area2D

@export var KNOCKBACK: float = 100.0
@export var DAMAGE: float = 0.0

var source: Unit
## Copied from the spell that spawned it (`SpellScene.hits_self`); false keeps self-immunity.
var hits_self := false


func _on_area_entered(area: Area2D) -> void:
	HitArea.apply(self, area, source, DAMAGE, KNOCKBACK, hits_self)


func _on_explosion_effect_animation_finished() -> void:
	queue_free()
