class_name SpellSelect extends MarginContainer

signal loadout_complete(player_controller: int, picks: Array[Ability])

@export var player_controller := 0
@export var catalogue: Array[Ability] = []
@export var title_label: Label
@export var cards: HBoxContainer
@export var slots_container: HBoxContainer
@export var hint_label: Label
@export var spell_button_scene: PackedScene

var loadout := Loadout.new()
var focus_index := 0
var offers: Array[Ability] = []

var _card_buttons: Array[SpellSelectButton] = []
var _slot_icons: Array[TextureRect] = []
var _drafting := false
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	title_label.text = "PLAYER %d IS DRAFTING" % (player_controller + 1)
	title_label.add_theme_color_override("font_color", _player_color())
	_rng.randomize()
	_build_slots()
	visible = false


func _process(_delta: float) -> void:
	if not _drafting:
		return
	if Input.is_action_just_pressed(action("ui_left")):
		move_focus_by(-1)
	elif Input.is_action_just_pressed(action("ui_right")):
		move_focus_by(1)
	elif Input.is_action_just_pressed(action("ui_accept")):
		handle_accept()


func action(suffix: String) -> StringName:
	return StringName("player_%d_%s" % [player_controller, suffix])


## Rolls a fresh hand of offers and takes over the screen. The panel starts idle and
## hidden; `MatchManager` calls this on the player's turn — player 1 first, then player 2
## at match start, and the loser after every round.
func start_draft() -> void:
	offers = SpellDraw.draw_offers(catalogue, SpellDraw.OFFER_COUNT, loadout.picks, _rng)
	focus_index = 0
	_drafting = true
	visible = true
	_build_cards()
	_update_visuals()


## Seeds the pool with the class's basic spells. Call before the first
## `start_draft()`: the basics are ordinary owned spells, so no hand ever offers them.
func set_class(character_class: CharacterClass) -> void:
	loadout = Loadout.from_class(character_class)


## False when a draft could never complete — the pool is full or the catalogue has nothing
## left to offer ("NO SPELLS AVAILABLE"). The round flow skips those drafts.
func can_start_draft() -> bool:
	return not loadout.is_full() and SpellDraw.has_offers(catalogue, loadout.picks)


static func move_focus(index: int, step: int, count: int) -> int:
	if count <= 0:
		return 0
	return clampi(index + step, 0, count - 1)


func move_focus_by(step: int) -> void:
	focus_index = move_focus(focus_index, step, _card_buttons.size())
	_update_visuals()


func handle_accept() -> void:
	if not _drafting or offers.is_empty():
		return
	if not loadout.pick(offers[focus_index]):
		return
	_update_visuals()
	_complete()


func _complete() -> void:
	_drafting = false
	loadout_complete.emit(player_controller, loadout.picks.duplicate())
	visible = false


func _build_cards() -> void:
	for child in cards.get_children():
		cards.remove_child(child)
		child.queue_free()
	_card_buttons.clear()
	for ability in offers:
		var button := spell_button_scene.instantiate() as SpellSelectButton
		cards.add_child(button)
		button.setup(ability)
		_card_buttons.append(button)


func _build_slots() -> void:
	for _index in Loadout.MAX_SPELLS:
		var slot := Panel.new()
		slot.custom_minimum_size = Vector2(48, 48)
		var icon := TextureRect.new()
		icon.set_anchors_preset(Control.PRESET_FULL_RECT)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(icon)
		slots_container.add_child(slot)
		_slot_icons.append(icon)


func _update_visuals() -> void:
	for index in _card_buttons.size():
		_card_buttons[index].set_focused(index == focus_index and _drafting)
	for index in _slot_icons.size():
		var texture: Texture2D = null
		if index < loadout.picks.size() and loadout.picks[index] is BaseAbility:
			texture = (loadout.picks[index] as BaseAbility).ICON
		_slot_icons[index].texture = texture
	hint_label.text = "NO SPELLS AVAILABLE" if offers.is_empty() else "CHOOSE A SPELL"


func _player_color() -> Color:
	var palette: Array = Constants.palette_for(player_controller)
	if palette.is_empty():
		return Color.WHITE
	return palette[0]
