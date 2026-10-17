class_name HealthBar extends ProgressBar

@export var attribute_container: AttributeContainer


func _ready() -> void:
	attribute_container.attribute_changed.connect(_on_attribute_changed)
	_sync()


func _on_attribute_changed(attribute: Variant, _previous_value: float, _new_value: float) -> void:
	if attribute == null:
		return
	var attribute_name := String(attribute.get_attribute_name())
	if attribute_name != AttributeNames.HEALTH and attribute_name != AttributeNames.MAX_HEALTH:
		return
	_sync()


## Reads the container instead of tracking deltas: spawn/respawn (`InitializeAttributes`) and
## hits (`HealthDamage`, later the lava DoT) all arrive through `attribute_changed`.
func _sync() -> void:
	max_value = attribute_container.get_attribute_value_by_name(AttributeNames.MAX_HEALTH)
	value = attribute_container.get_attribute_value_by_name(AttributeNames.HEALTH)
