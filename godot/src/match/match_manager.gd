class_name MatchManager extends Node

enum MatchPhase {
	SELECTING,
	RUNNING,
	ROUND_OVER,
	GAME_OVER
}

## Round wins needed to take the match.
const ROUNDS_TO_WIN := 5

signal phase_changed(phase: MatchPhase)

@export var selection_layer: CanvasLayer
@export var match_over: MatchOver
## Arena (M5/D-019): reset and restart its shrink every time the match enters RUNNING;
## stop it whenever the match leaves RUNNING (drafts, KO beat, game over).
@export var arena: Arena
@export var skip_selection := false
@export var default_loadout: Array[Ability] = []
@export var character_class: CharacterClass
## KO beat (D-014): real seconds of world slow motion after a death, before the loser's
## draft or the winner banner opens. 0 disables the beat (flow tests, fast dev checks).
@export var death_slowmo_duration := 1.0
## Engine time scale while the KO beat runs (1 = normal speed).
@export var death_slowmo_scale := 0.5
## Whether the match-ending death also plays the beat before the winner banner.
@export var death_slowmo_on_match_point := true

var phase := MatchPhase.SELECTING

var _players: Array[Unit] = []
var _ready_players: Array[Unit] = []
var _round_wins := {}


func _ready() -> void:
	_players = _collect_players()
	for player in _players:
		player.player_died.connect(_on_player_died)
	for panel in selection_panels():
		panel.loadout_complete.connect(_on_loadout_complete)
	_assign_character_classes()
	if skip_selection:
		_start_with_default_loadout()
	else:
		_lock_players()
		_set_selection_visible(true)
		_begin_next_draft()


## Every seat plays the match's `character_class` for now: the class seeds each draft pool
## with its basic spells and is stored on the unit for future stats/passives. A class-select
## screen later only changes this function (D-013).
func _assign_character_classes() -> void:
	for player in _players:
		player.character_class = character_class
	for panel in selection_panels():
		panel.set_class(character_class)


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
	if phase != MatchPhase.SELECTING and phase != MatchPhase.ROUND_OVER:
		return
	var player := player_for(controller)
	if player == null:
		return
	player.apply_loadout(picks)
	if phase == MatchPhase.ROUND_OVER:
		# The loser's card is in; the next round opens on the next frame so the accept
		# press can't leak into anything else.
		_resume_after_round.call_deferred()
		return
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
	_lock_players()
	var winner := player_for(1 - player_number)
	if winner == null:
		_set_phase(MatchPhase.GAME_OVER)
		return
	_round_wins[winner.PLAYER_CONTROLLER] = round_wins_for(winner.PLAYER_CONTROLLER) + 1
	var match_point := round_wins_for(winner.PLAYER_CONTROLLER) >= ROUNDS_TO_WIN
	_set_phase(MatchPhase.GAME_OVER if match_point else MatchPhase.ROUND_OVER)
	# The KO beat holds the draft/banner back until the death clip has played out (D-014).
	if death_slowmo_duration > 0.0 and (not match_point or death_slowmo_on_match_point):
		await _play_death_beat(player_for(player_number))
	if match_point:
		if match_over != null:
			match_over.show_winner(
				winner.PLAYER_CONTROLLER,
				round_wins_for(winner.PLAYER_CONTROLLER),
				round_wins_for(player_number)
			)
		return
	_begin_round_draft(player_for(player_number))


## The KO beat (D-014): the world drops into slow motion around the death, then time
## returns to normal and the rest of the loser's `Dead` clip plays out. Only after that do
## the loser's draft — or the winner banner — take the screen.
func _play_death_beat(loser: Unit) -> void:
	Engine.time_scale = death_slowmo_scale
	# Unscaled timer: the beat is real seconds while the world crawls.
	await get_tree().create_timer(death_slowmo_duration, true, false, true).timeout
	Engine.time_scale = 1.0
	if loser != null and loser.animation_player.is_playing():
		await loser.animation_player.animation_finished


## Round wins for one controller (0 when none yet).
func round_wins_for(controller: int) -> int:
	return _round_wins.get(controller, 0)


## Between rounds the loser drafts one extra spell; the next round starts when it lands.
## Drafts that could never complete (full pool, nothing left to offer) are skipped.
func _begin_round_draft(loser: Unit) -> void:
	var panel: SpellSelect = null
	if loser != null:
		panel = _panel_for(loser)
	if panel == null or not panel.can_start_draft():
		_resume_after_round.call_deferred()
		return
	_set_selection_visible(true)
	panel.start_draft()


## Starts the next round: everyone respawns at their spawn point, full health, unlocked.
func _resume_after_round() -> void:
	if phase != MatchPhase.ROUND_OVER:
		return
	_set_selection_visible(false)
	for player in _players:
		player.respawn()
		player.is_match_ready = true
	_set_phase(MatchPhase.RUNNING)


func _panel_for(player: Unit) -> SpellSelect:
	for panel in selection_panels():
		if panel.player_controller == player.PLAYER_CONTROLLER:
			return panel
	return null


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
	if arena != null:
		if phase == MatchPhase.RUNNING:
			arena.reset()
			arena.start_shrink()
		else:
			arena.stop_shrink()
	phase_changed.emit(phase)


func _exit_tree() -> void:
	# Safety: a freed or reloaded manager must never leave a session stuck in slow motion.
	Engine.time_scale = 1.0
