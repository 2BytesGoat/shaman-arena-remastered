class_name InitializeAttributesBuff extends AttributeBuff

@export var max_health: float = 10.0


func _init(_max_health: float = 10.0) -> void:
	max_health = _max_health


func _applies_to(attribute_set: AttributeSet) -> Array[AttributeBase]:
	return [
		attribute_set.find_by_name(AttributeNames.MAX_HEALTH),
		attribute_set.find_by_name(AttributeNames.HEALTH),
	]


func _operate(_values: Array[float], _attribute_set: AttributeSet) -> Array[AttributeOperation]:
	return [
		AttributeOperation.forcefully_set_value(max_health),
		AttributeOperation.forcefully_set_value(max_health),
	]
