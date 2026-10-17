class_name MatchManager extends Node

enum MatchPhase {
	SELECTING,
	RUNNING,
	GAME_OVER
}

signal phase_changed(phase: MatchPhase)

@export var selection_layer: CanvasLayer
@export var match_over: MatchOver
@export var skip_selection := false
@export var default_loadout: Array[Ability] = []

var phase := MatchPhase.SELECTING

var _players: Array[Unit] = []
var _ready_players: Array[Unit] = []


func _ready() -> void:
	_players = _collect_players()
	for player in _players:
		player.player_died.connect(_on_player_died)
	for panel in selection_panels():
		panel.loadout_complete.connect(_on_loadout_complete)
	if skip_selection:
		_start_with_default_loadout()
	else:
		_lock_players()
		_set_selection_visible(true)
		_begin_next_draft()


func player_for(controller: int) -> Unit:
	for player in _players:
		if player.PLAYER_CONTROLLER == controller:
			return player
	return null


func selection_panels() -> Array[SpellSelect]:
	var panels: Array[SpellSelect] = []
	if selection_layer == null:
		return panels
	_collect_panels(selection_layer, panels)
	return panels


func _collect_panels(node: Node, panels: Array[SpellSelect]) -> void:
	for child in node.get_children():
		if child is SpellSelect:
			panels.append(child)
		else:
			_collect_panels(child, panels)


func _collect_players() -> Array[Unit]:
	var players: Array[Unit] = []
	for node in get_tree().get_nodes_in_group(Unit.PLAYERS_GROUP):
		if node is Unit:
			players.append(node)
	players.sort_custom(func(a: Unit, b: Unit) -> bool: return a.PLAYER_CONTROLLER < b.PLAYER_CONTROLLER)
	return players


func _on_loadout_complete(controller: int, picks: Array[Ability]) -> void:
	if phase != MatchPhase.SELECTING:
		return
	var player := player_for(controller)
	if player == null:
		return
	player.apply_loadout(picks)
	_mark_ready(player)
	if phase == MatchPhase.SELECTING and _next_draft_panel() != null:
		# Deferred: the accept press that just ended this player's draft must not be
		# readable by the next player's panel in the same frame.
		_begin_next_draft.call_deferred()


## The next player due to draft, in controller order, or null when everyone is ready.
func _next_draft_panel() -> SpellSelect:
	var panels := selection_panels()
	panels.sort_custom(
		func(a: SpellSelect, b: SpellSelect) -> bool:
			return a.player_controller < b.player_controller
	)
	for panel in panels:
		var player := player_for(panel.player_controller)
		if player != null and not _ready_players.has(player):
			return panel
	return null


## Drafts run one at a time on the shared screen: the next player rolls their offers and
## takes the screen while the others stay hidden. A draft also implies locked controls —
## nobody can act in the arena while cards are up.
func _begin_next_draft() -> void:
	_lock_players()
	var panel := _next_draft_panel()
	if panel != null:
		panel.start_draft()


func _mark_ready(player: Unit) -> void:
	if phase != MatchPhase.SELECTING or _ready_players.has(player):
		return
	_ready_players.append(player)
	if _players.is_empty() or _ready_players.size() < _players.size():
		return
	_start_match()


func _on_player_died(player_number: int) -> void:
	if phase != MatchPhase.RUNNING:
		return
	_set_phase(MatchPhase.GAME_OVER)
	_lock_players()
	if match_over != null:
		var winner := player_for(1 - player_number)
		if winner != null:
			match_over.show_winner(winner.PLAYER_CONTROLLER)


func _start_with_default_loadout() -> void:
	if default_loadout.is_empty():
		push_warning("MatchManager.skip_selection is on but default_loadout is empty.")
	for player in _players:
		player.apply_loadout(default_loadout)
	_start_match()


func _start_match() -> void:
	_set_phase(MatchPhase.RUNNING)
	for player in _players:
		player.is_match_ready = true
	_set_selection_visible(false)


func _lock_players() -> void:
	for player in _players:
		player.is_match_ready = false


func _set_selection_visible(value: bool) -> void:
	if selection_layer != null:
		selection_layer.visible = value


func _set_phase(value: MatchPhase) -> void:
	if phase == value:
		return
	phase = value
	phase_changed.emit(phase)
