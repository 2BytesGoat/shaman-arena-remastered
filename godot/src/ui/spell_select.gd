class_name SpellSelect extends MarginContainer

signal loadout_complete(player_controller: int, picks: Array[Ability])

const GRID_COLUMNS := 4
const TOTAL_SLOTS := Loadout.MAX_SPELLS + Loadout.CONSUMABLE_SLOTS

@export var player_controller := 0
@export var catalogue: Array[Ability] = []
@export var title_label: Label
@export var grid: GridContainer
@export var slots_container: HBoxContainer
@export var hint_label: Label
@export var spell_button_scene: PackedScene

var loadout := Loadout.new()
var focus_index := 0

var _buttons: Array[SpellSelectButton] = []
var _slot_icons: Array[TextureRect] = []
var _locked := false


func _ready() -> void:
	title_label.text = "PLAYER %d" % (player_controller + 1)
	title_label.add_theme_color_override("font_color", _player_color())
	grid.columns = GRID_COLUMNS
	_build_grid()
	_build_slots()
	_update_visuals()


func _process(_delta: float) -> void:
	if _locked or not visible:
		return
	if Input.is_action_just_pressed(action("ui_left")):
		move_focus_by(Vector2i.LEFT)
	elif Input.is_action_just_pressed(action("ui_right")):
		move_focus_by(Vector2i.RIGHT)
	elif Input.is_action_just_pressed(action("ui_up")):
		move_focus_by(Vector2i.UP)
	elif Input.is_action_just_pressed(action("ui_down")):
		move_focus_by(Vector2i.DOWN)
	elif Input.is_action_just_pressed(action("ui_accept")):
		handle_accept()
	elif Input.is_action_just_pressed(action("ui_cancel")):
		handle_cancel()


func action(suffix: String) -> StringName:
	return StringName("player_%d_%s" % [player_controller, suffix])


func set_locked(value: bool) -> void:
	_locked = value


static func move_focus(index: int, direction: Vector2i, columns: int, count: int) -> int:
	if count <= 0:
		return 0
	var row := index / columns
	var column := index % columns
	if direction.x != 0:
		var target := index + direction.x
		var target_column := column + direction.x
		if target_column >= 0 and target_column < columns and target < count:
			return target
		return index
	if direction.y == 0:
		return index
	var target_row := row + direction.y
	var target := target_row * columns + column
	if target_row >= 0 and target < count:
		return target
	return index


func move_focus_by(direction: Vector2i) -> void:
	focus_index = move_focus(focus_index, direction, GRID_COLUMNS, _buttons.size())
	_update_visuals()


func handle_accept() -> void:
	if _locked or _buttons.is_empty():
		return
	loadout.toggle(_buttons[focus_index].ability)
	_update_visuals()
	if loadout.is_full():
		_complete()


func handle_cancel() -> void:
	if _locked or loadout.picks.is_empty():
		return
	loadout.unpick(loadout.picks[-1])
	_update_visuals()


func _complete() -> void:
	_locked = true
	loadout_complete.emit(player_controller, loadout.picks.duplicate())
	visible = false


func _build_grid() -> void:
	for ability in catalogue:
		var button := spell_button_scene.instantiate() as SpellSelectButton
		grid.add_child(button)
		button.setup(ability)
		_buttons.append(button)


func _build_slots() -> void:
	for index in TOTAL_SLOTS:
		var slot := Panel.new()
		slot.custom_minimum_size = Vector2(48, 48)
		if index >= Loadout.MAX_SPELLS:
			slot.modulate = Color(1.0, 1.0, 1.0, 0.35)
		var icon := TextureRect.new()
		icon.set_anchors_preset(Control.PRESET_FULL_RECT)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(icon)
		slots_container.add_child(slot)
		_slot_icons.append(icon)


func _update_visuals() -> void:
	for index in _buttons.size():
		_buttons[index].set_focused(index == focus_index and not _locked)
		_buttons[index].set_picked(loadout.has(_buttons[index].ability))
	for index in _slot_icons.size():
		var texture: Texture2D = null
		if index < loadout.picks.size() and loadout.picks[index] is BaseAbility:
			texture = (loadout.picks[index] as BaseAbility).ICON
		_slot_icons[index].texture = texture
	hint_label.text = "PICK %d/%d" % [loadout.picks.size(), Loadout.MAX_SPELLS]


func _player_color() -> Color:
	var palette: Array = Constants.player_colors.get("player_%d" % player_controller, [])
	if palette.is_empty():
		return Color.WHITE
	return palette[0]
