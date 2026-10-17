class_name MeteorIncoming extends Effect

@export var Meteor: PackedScene


func _on_expiry_timer_timeout() -> void:
	var strike := Utils.instantiate_object_in_scene(Meteor, global_position) as Effect
	if strike != null:
		strike.source = source
		strike.hits_self = hits_self
	queue_free()
