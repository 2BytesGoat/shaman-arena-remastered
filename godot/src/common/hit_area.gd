class_name HitArea


static func apply(attacker: Area2D, target: Area2D, source: Unit, damage: float, knockback: float) -> void:
	if SourceFilter.ignores(source, target):
		return
	var victim := target.get_parent() as Unit
	if victim == null:
		return
	victim.take_hit(source, damage, knockback, attacker.global_position.direction_to(victim.global_position))
