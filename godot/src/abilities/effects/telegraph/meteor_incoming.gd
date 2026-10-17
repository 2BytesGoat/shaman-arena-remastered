class_name MeteorIncoming extends Effect

@export var Meteor: PackedScene


func _on_expiry_timer_timeout() -> void:
	var strike := Utils.instantiate_object_in_scene(Meteor, global_position) as Effect
	strike.source = source
	queue_free()
