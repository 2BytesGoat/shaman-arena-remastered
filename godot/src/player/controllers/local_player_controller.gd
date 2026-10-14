class_name LocalPlayerController extends PlayerController

const STICK_DEADZONE := 0.2

var player_index: int


func _init(new_unit: Unit, new_player_index: int) -> void:
	super(new_unit)
	player_index = new_player_index


func action_name(suffix: String) -> StringName:
	return StringName("player_%d_%s" % [player_index, suffix])


func spell_action(slot: int) -> StringName:
	return action_name("spell_%d" % slot)


func update(_delta: float) -> void:
	var stick := Vector2(
		Input.get_axis(action_name("left"), action_name("right")),
		Input.get_axis(action_name("up"), action_name("down"))
	)
	if stick.length() <= STICK_DEADZONE:
		stick = Vector2.ZERO
	unit.set_move_input(stick)
	unit.set_aim_input(stick)
	for slot in mini(unit.ability_slots.size(), Unit.MAX_SPELL_SLOTS):
		if Input.is_action_just_pressed(spell_action(slot)):
			unit.request_cast(slot)
			break
	if unit.aiming_slot >= 0 and Input.is_action_just_released(spell_action(unit.aiming_slot)):
		unit.request_release()
