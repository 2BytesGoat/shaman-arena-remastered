class_name HealthDamage extends AttributeBuff

@export var damage: float = 1.0


func _init(_damage: float = 1.0) -> void:
	damage = _damage
	attribute_name = AttributeNames.HEALTH
	operation = AttributeOperation.subtract(damage)
