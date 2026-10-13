extends CanvasLayer


func _ready() -> void:
	layer = 100
	var label := Label.new()
	label.text = "v%s" % str(ProjectSettings.get_setting("application/config/version", "0.0.0"))
	label.modulate = Color(1.0, 1.0, 1.0, 0.55)
	label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	label.offset_left = 8.0
	label.offset_top = -30.0
	label.offset_bottom = -8.0
	add_child(label)