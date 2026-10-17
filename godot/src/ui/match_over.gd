class_name MatchOver extends CanvasLayer

@export var message_label: Label
@export var restart_button: Button

var _restarting := false


func _ready() -> void:
	visible = false
	restart_button.pressed.connect(_restart)


## Shows the win banner; the optional score is appended when a rounds match ends.
func show_winner(player_number: int, rounds_won := 0, rounds_lost := 0) -> void:
	message_label.text = "PLAYER %d WINS" % (player_number + 1)
	if rounds_won > 0:
		message_label.text += " %d-%d" % [rounds_won, rounds_lost]
	visible = true
	restart_button.grab_focus()


func _process(_delta: float) -> void:
	if not visible:
		return
	if (
		Input.is_action_just_pressed("ui_accept")
		or Input.is_action_just_pressed("player_0_ui_accept")
		or Input.is_action_just_pressed("player_1_ui_accept")
	):
		_restart()


func _restart() -> void:
	if _restarting:
		return
	_restarting = true
	get_tree().reload_current_scene()
