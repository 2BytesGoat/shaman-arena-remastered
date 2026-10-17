class_name Arena extends TileMapLayer

## Circular shrinking arena (POC `tilemap_arena.gd` port) on the isometric tile set: the play
## floor is a circle of diamonds and everything outside it is animated liquid (the lava hazard).
## Shrinking repaints only the ring that changed, and `reset()` restores the starting circle
## (the match loop calls it once per round, D-019).

signal radius_changed(radius: int)

enum CellKind { FLOOR, EDGE, LAVA }

const FLOOR_SOURCE := 0
const FLOOR_ATLAS := Vector2i(0, 0)
## Warning band: an alternative of the floor tile (untinted for now, so it draws like the base
## tile until a variant or tint lands on the alternative).
const EDGE_SOURCE := 0
const EDGE_ATLAS := Vector2i(0, 0)
const EDGE_ALTERNATIVE := 1
const LAVA_SOURCE := 2
const LAVA_ATLAS := Vector2i(0, 0)

## The tile set's cell size. The iso grid is staggered (`TileMapLayer.map_to_local`): rows of
## cells sit `HALF_TILE.y` px apart, cells within a row `TILE_SIZE.x` px, and odd rows are
## offset half a cell sideways.
const TILE_SIZE := Vector2i(32, 16)
const HALF_TILE := Vector2i(16, 8)

## Tiles of liquid painted beyond the starting circle. The POC filled its whole 300×300 grid;
## this bound sits well past any camera view (the zoom floor is 0.5× the base zoom) and keeps
## scene load and tests cheap.
const FIELD_MARGIN := 1024

## Play-circle radius in px at match start (the POC: 50 tiles of 16 px).
@export var start_radius := 800
## Width of the warning band between the floor and the liquid, in px (the POC's one tile).
@export var edge_thickness := 16
## How much one shrink step takes off the radius, in px (the POC: one 16 px tile per step).
@export var shrink_step := 16
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


## Cell centre relative to the arena origin, in px: the tile set's staggered iso grid
## (`TileMapLayer.map_to_local`, offset axis horizontal). The arena tests pin it against the
## engine, because the circle mask below only makes sense if it agrees with the cell placement.
static func cell_center(coords: Vector2i) -> Vector2i:
	var row_shift := HALF_TILE.x * (1 + (coords.y & 1))
	return Vector2i(coords.x * TILE_SIZE.x + row_shift, (coords.y + 1) * HALF_TILE.y)


## Squared screen distance of a cell centre from the arena origin, in px². The circle mask runs
## on this instead of a cell-space radius: the iso rows are 8 px apart, so a cell-space circle
## would paint a tall oval on screen instead of the round play area (D-019).
static func screen_dist_sq(coords: Vector2i) -> int:
	var center := cell_center(coords)
	return center.x * center.x + center.y * center.y


## Half-extent, in cells, of the rectangle that contains the screen circle of `radius` px. Cells
## outside it can never be inside the circle, so the repaint loops can stop there.
static func circle_extent(radius: int) -> Vector2i:
	return Vector2i(
		ceili(float(radius) / float(TILE_SIZE.x)) + 1,
		ceili(float(radius) / float(HALF_TILE.y)) + 1
	)


## POC cell rules: floor inside the circle, then (after a shrink) one tile of warning band, then
## liquid. `dist_sq` comes from `screen_dist_sq` (D-019); `edge_thickness` 0 is the initial map:
## floor straight to liquid.
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


## One shrink step: the circle loses `shrink_step` px and only the changed ring is repainted.
func shrink() -> void:
	if current_radius <= 0:
		stop_shrink()
		return
	current_radius = maxi(current_radius - shrink_step, 0)
	_paint_circle(edge_thickness)
	radius_changed.emit(current_radius)


func start_shrink() -> void:
	_shrink_timer.start()


func stop_shrink() -> void:
	_shrink_timer.stop()


func is_shrinking() -> bool:
	return not _shrink_timer.is_stopped()


func _paint_field() -> void:
	var extent := circle_extent(start_radius + FIELD_MARGIN)
	for y in range(-extent.y, extent.y + 1):
		for x in range(-extent.x, extent.x + 1):
			set_cell(Vector2i(x, y), LAVA_SOURCE, LAVA_ATLAS)


## Repaints the rectangle that contains the current circle (plus warning band and one ring of
## liquid). Cells farther out were painted once by `_paint_field` and never change.
func _paint_circle(edge: int) -> void:
	var extent := circle_extent(current_radius + edge)
	for y in range(-extent.y, extent.y + 1):
		for x in range(-extent.x, extent.x + 1):
			var coords := Vector2i(x, y)
			var kind := classify(screen_dist_sq(coords), current_radius, edge)
			if kind == CellKind.FLOOR:
				set_cell(coords, FLOOR_SOURCE, FLOOR_ATLAS)
			elif kind == CellKind.EDGE:
				set_cell(coords, EDGE_SOURCE, EDGE_ATLAS, EDGE_ALTERNATIVE)
			else:
				set_cell(coords, LAVA_SOURCE, LAVA_ATLAS)
