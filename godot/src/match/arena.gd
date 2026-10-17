class_name Arena extends TileMapLayer

## Circular shrinking arena (POC `tilemap_arena.gd` port): the play floor is a circle of
## 16 px tiles and everything outside it is animated magma. Shrinking repaints only the ring
## that changed, and `reset()` restores the starting circle (the match loop calls it once per
## round, D-019).

signal radius_changed(radius: int)

enum CellKind { FLOOR, EDGE, LAVA }

const FLOOR_SOURCE := 0
const FLOOR_ATLAS := Vector2i(1, 0)
const EDGE_SOURCE := 0
const EDGE_ATLAS := Vector2i(5, 0)
const LAVA_SOURCE := 1
const LAVA_ATLAS := Vector2i(0, 0)

## Tiles of magma painted beyond the starting circle. The POC filled its whole 300×300 grid;
## this bound sits well past any camera view (the zoom floor is 0.5× the base zoom) and keeps
## scene load and tests cheap.
const FIELD_MARGIN := 64

## Play-circle radius in tiles at match start (POC: 50 tiles ≈ 800 px).
@export var start_radius := 50
## Width of the dark warning band between the floor and the magma (tiles).
@export var edge_thickness := 1
## Seconds between shrink steps (POC: 3 s per tile).
@export var shrink_interval := 3.0

var current_radius := 0

var _shrink_timer: Timer


func _ready() -> void:
	_shrink_timer = Timer.new()
	_shrink_timer.name = "ShrinkTimer"
	_shrink_timer.wait_time = shrink_interval
	_shrink_timer.one_shot = false
	_shrink_timer.timeout.connect(shrink)
	add_child(_shrink_timer)
	_paint_field()
	reset()


## POC cell rules: floor inside the circle, then (after a shrink) one tile of warning band,
## then magma. `edge_thickness` 0 is the initial map: floor straight to magma.
static func classify(dist_sq: int, radius: int, edge_thickness: int) -> CellKind:
	if dist_sq < radius * radius:
		return CellKind.FLOOR
	var band := radius + edge_thickness
	if edge_thickness > 0 and dist_sq <= band * band:
		return CellKind.EDGE
	return CellKind.LAVA


## Back to the match-start circle. Stops the shrink timer; the match loop restarts it.
func reset() -> void:
	stop_shrink()
	current_radius = start_radius
	_paint_circle(0)
	radius_changed.emit(current_radius)


## One shrink step: the circle loses a tile and only the changed ring is repainted.
func shrink() -> void:
	if current_radius <= 0:
		stop_shrink()
		return
	current_radius -= 1
	_paint_circle(edge_thickness)
	radius_changed.emit(current_radius)


func start_shrink() -> void:
	_shrink_timer.start()


func stop_shrink() -> void:
	_shrink_timer.stop()


func is_shrinking() -> bool:
	return not _shrink_timer.is_stopped()


func _paint_field() -> void:
	var limit := start_radius + FIELD_MARGIN
	for y in range(-limit, limit + 1):
		for x in range(-limit, limit + 1):
			set_cell(Vector2i(x, y), LAVA_SOURCE, LAVA_ATLAS)


## Repaints the square that contains the current circle (plus warning band and one ring of
## magma). Cells farther out were painted once by `_paint_field` and never change.
func _paint_circle(edge: int) -> void:
	var limit := current_radius + edge + 1
	for y in range(-limit, limit + 1):
		for x in range(-limit, limit + 1):
			var coords := Vector2i(x, y)
			var kind := classify(x * x + y * y, current_radius, edge)
			if kind == CellKind.FLOOR:
				set_cell(coords, FLOOR_SOURCE, FLOOR_ATLAS)
			elif kind == CellKind.EDGE:
				set_cell(coords, EDGE_SOURCE, EDGE_ATLAS)
			else:
				set_cell(coords, LAVA_SOURCE, LAVA_ATLAS)
