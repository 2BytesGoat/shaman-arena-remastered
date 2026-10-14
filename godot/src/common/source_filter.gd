class_name SourceFilter


static func ignores(source: Variant, area: Area2D) -> bool:
	if source == null or area == null or not is_instance_valid(source):
		return false
	if area.get_parent() == source:
		return true
	if area is SpellScene or area is Effect:
		return area.source == source
	return false
