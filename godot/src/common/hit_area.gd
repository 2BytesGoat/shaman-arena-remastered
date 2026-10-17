class_name HitArea


## Applies one attacker-side hit (D-001). `hits_self` opts an impact into hitting the unit that
## cast it; the default keeps `SourceFilter`'s self-immunity. Returns false only when a self-hit
## was rejected, so callers keep their own reaction to the contact (despawn, effects) unchanged.
static func apply(
	attacker: Area2D,
	target: Area2D,
	source: Unit,
	damage: float,
	knockback: float,
	hits_self := false
) -> bool:
	if not hits_self and SourceFilter.ignores(source, target):
		return false
	var victim := target.get_parent() as Unit
	if victim != null:
		victim.take_hit(
			source, damage, knockback, attacker.global_position.direction_to(victim.global_position)
		)
	return true
