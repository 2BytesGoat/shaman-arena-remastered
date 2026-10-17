class_name MatchCamera extends Camera2D

## Match camera: follows the midpoint of the players and zooms out to keep the whole spread
## inside the safe margins. It also zooms back in when the players regroup.

## Fraction of the viewport kept around the players.
@export var safe_margin_ratio := 0.7
## Position smoothing per physics frame.
@export var follow_weight := 0.1
## Zoom smoothing per physics frame.
@export var zoom_weight := 0.5
## Furthest zoom-out, as a fraction of the scene's initial zoom.
@export var min_zoom_ratio := 0.5

var initial_zoom := Vector2.ONE


func _ready() -> void:
	initial_zoom = zoom


func _physics_process(_delta: float) -> void:
	var positions := player_positions()
	if positions.is_empty():
		return
	global_position = global_position.lerp(midpoint_of(positions), follow_weight)
	var ratio := fit_ratio(spread_of(positions), safe_margin(), min_zoom_ratio)
	zoom = zoom.lerp(initial_zoom * ratio, zoom_weight)


## Live world positions of every unit in the match (the camera fits the whole group).
func player_positions() -> Array[Vector2]:
	var positions: Array[Vector2] = []
	for node in get_tree().get_nodes_in_group(Unit.PLAYERS_GROUP):
		if node is Unit:
			positions.append((node as Unit).global_position)
	return positions


## Safe frame around the players, in world units (half the viewport times the safe margin).
func safe_margin() -> Vector2:
	return get_viewport_rect().size / 2.0 * safe_margin_ratio


static func midpoint_of(positions: Array[Vector2]) -> Vector2:
	var sum := Vector2.ZERO
	for position in positions:
		sum += position
	return sum / float(positions.size())


static func spread_of(positions: Array[Vector2]) -> Vector2:
	var min_pos := Vector2.INF
	var max_pos := -Vector2.INF
	for position in positions:
		min_pos.x = minf(min_pos.x, position.x)
		min_pos.y = minf(min_pos.y, position.y)
		max_pos.x = maxf(max_pos.x, position.x)
		max_pos.y = maxf(max_pos.y, position.y)
	return max_pos - min_pos


## Zoom factor that keeps the spread inside `safe_margin`; 1 keeps the initial zoom and the
## result never goes below `min_ratio`. A zero spread (players on top of each other) keeps
## the current framing instead of dividing by zero.
static func fit_ratio(spread: Vector2, safe_margin: Vector2, min_ratio: float) -> float:
	var ratio := 1.0
	if spread.x > 0.0 and safe_margin.x > 0.0:
		ratio = minf(ratio, safe_margin.x / spread.x)
	if spread.y > 0.0 and safe_margin.y > 0.0:
		ratio = minf(ratio, safe_margin.y / spread.y)
	return clampf(ratio, min_ratio, 1.0)
