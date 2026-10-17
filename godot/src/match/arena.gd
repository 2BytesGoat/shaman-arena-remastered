class_name Arena extends TileMapLayer

## Circular shrinking arena (POC `tilemap_arena.gd` port) on the isometric tile set: the play
## floor is the ellipse of diamonds twice as wide as it is tall, and everything outside it is
## animated liquid (the lava hazard). Shrinking touches only the ring that changed, and
## `reset()` repaints back to the starting ellipse (the match loop calls it once per round,
## D-019).
##
## The layer is y-sorted — that is what keeps the isometric tile overlaps right — and y-sorting
## makes the engine group cells into one canvas item per row, so touching a single cell makes it
## rebuild that row's whole canvas item. On the arcade web build (single-threaded WASM on a
## Tegra) a full ring in one frame staggered for ~0.5 s, so a shrink ring is applied over
## several frames instead, `shrink_rows_per_frame` rows at a time (D-019 addendum).

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

## The play area is an ellipse, twice as wide (x) as it is tall (y) — the isometric look of the
## floor diamonds. Distances weigh the vertical offset `SHAPE_SQUASH_SQ` times, so a `radius` is
## always the ellipse's *horizontal* semi-axis, in px (D-019 addendum).
const SHAPE_ASPECT := 2
const SHAPE_SQUASH_SQ := 4

## Tiles of liquid painted beyond the starting ellipse. The POC filled its whole 300×300 grid;
## this bound sits well past any camera view (the zoom floor is 0.5× the base zoom) and keeps
## scene load and tests cheap.
const FIELD_MARGIN := 1024

## Horizontal semi-axis of the play ellipse at match start, in px (the POC's 50 × 16 px tiles).
@export var start_radius := 800
## Width of the warning band between the floor and the liquid, in px (the POC's one tile).
@export var edge_thickness := 16
## How much one shrink step takes off the radius, in px (the POC: one 16 px tile per step).
@export var shrink_step := 16
## Seconds between shrink steps (POC: 3 s per tile).
@export var shrink_interval := 3.0
## Cell rows of a shrink ring applied per frame. Rows are the unit of work here: y-sorting makes
## one dirty row rebuild that row's whole canvas item, so a whole ring in one frame is what
## staggered on the arcade build. Lower is smoother, higher catches up sooner (D-019 addendum).
@export var shrink_rows_per_frame := 12

var current_radius := 0

## Radius and band width the tile map is painted for. The pending ring is planned from this
## state; a `shrink()`/`reset()` while one is still draining flushes it first.
var _painted_radius := 0
var _painted_edge := 0
## Pending shrink ring: one entry per cell row (y ascending), each entry that row's cells.
var _pending_rows: Array = []
var _pending_radius := 0
var _pending_edge := 0

var _shrink_timer: Timer


func _ready() -> void:
	_shrink_timer = Timer.new()
	_shrink_timer.name = "ShrinkTimer"
	_shrink_timer.wait_time = shrink_interval
	_shrink_timer.one_shot = false
	_shrink_timer.timeout.connect(shrink)
	add_child(_shrink_timer)
	set_process(false)
	_paint_field()
	reset()


## Cell centre relative to the arena origin, in px: the tile set's staggered iso grid
## (`TileMapLayer.map_to_local`, offset axis horizontal). The arena tests pin it against the
## engine, because the ellipse mask below only makes sense if it agrees with the cell placement.
static func cell_center(coords: Vector2i) -> Vector2i:
	var row_shift := HALF_TILE.x * (1 + (coords.y & 1))
	return Vector2i(coords.x * TILE_SIZE.x + row_shift, (coords.y + 1) * HALF_TILE.y)


## Squared distance of a cell centre from the arena origin, in px² of the play ellipse's shape
## space: the vertical offset counts `SHAPE_SQUASH_SQ` times, which is what makes the mask an
## ellipse twice as wide as tall instead of a screen circle (D-019 addendum). The circle metric
## the POC used would paint a tall oval on this staggered iso grid.
static func shape_dist_sq(coords: Vector2i) -> int:
	var center := cell_center(coords)
	return center.x * center.x + SHAPE_SQUASH_SQ * center.y * center.y


## Half-extent, in cells, of the rectangle that contains the play ellipse of `radius` px. Cells
## outside it can never be inside the ellipse, so the repaint loops can stop there.
static func shape_extent(radius: int) -> Vector2i:
	return Vector2i(
		ceili(float(radius) / float(TILE_SIZE.x)) + 1,
		ceili(float(radius) / float(SHAPE_ASPECT) / float(HALF_TILE.y)) + 1
	)


## POC cell rules: floor inside the play area, then (after a shrink) one tile of warning band,
## then liquid. `dist_sq` comes from `shape_dist_sq` (D-019) and `radius` is the ellipse's
## horizontal semi-axis; `edge_thickness` 0 is the initial map: floor straight to liquid.
static func classify(dist_sq: int, radius: int, edge_thickness: int) -> CellKind:
	if dist_sq < radius * radius:
		return CellKind.FLOOR
	var band := radius + edge_thickness
	if edge_thickness > 0 and dist_sq <= band * band:
		return CellKind.EDGE
	return CellKind.LAVA


## Cell rows (y ascending, cells left to right) whose kind changes when the play area moves from
## (`from_radius`, `from_edge`) to (`to_radius`, `to_edge`). A cell outside
## `[min(radius), max(radius + edge)]` keeps its kind either way, so the scan runs on that
## distance annulus instead of the ellipse's bounding rectangle: one shrink step at r=800
## changes ~304 cells where the rectangle holds ~5 460 (D-019 addendum).
static func repaint_rows(from_radius: int, from_edge: int, to_radius: int, to_edge: int) -> Array:
	var inner := mini(from_radius, to_radius)
	var outer := maxi(from_radius + from_edge, to_radius + to_edge)
	var inner_sq := inner * inner
	var outer_sq := outer * outer
	var row_extent := ceili(float(outer) / float(SHAPE_ASPECT) / float(HALF_TILE.y))
	var rows: Array = []
	for y in range(-row_extent - 1, row_extent):
		var center := cell_center(Vector2i(0, y))
		var squash_y := SHAPE_SQUASH_SQ * center.y * center.y
		var lower_sq := inner_sq - squash_y
		var upper_sq := outer_sq - squash_y
		if upper_sq < 0:
			continue # The row misses the annulus entirely.
		var near := ceili(sqrt(float(maxi(lower_sq, 0))))
		var far := floori(sqrt(float(upper_sq)))
		if near > far:
			continue
		# |centre.x| runs [near, far]; take the row's negative half first so it reads left to
		# right. `centre.x = 0` only happens on odd rows, and belongs to the positive half.
		var negative_near := maxi(near, 1)
		var left := Vector2i(
			ceili(float(-far - center.x) / float(TILE_SIZE.x)),
			floori(float(-negative_near - center.x) / float(TILE_SIZE.x))
		)
		var right := Vector2i(
			ceili(float(near - center.x) / float(TILE_SIZE.x)),
			floori(float(far - center.x) / float(TILE_SIZE.x))
		)
		var cells: Array = []
		for half in [left, right]:
			for x in range(half.x, half.y + 1):
				var coords := Vector2i(x, y)
				var painted := classify(shape_dist_sq(coords), from_radius, from_edge)
				if classify(shape_dist_sq(coords), to_radius, to_edge) != painted:
					cells.append(coords)
		if not cells.is_empty():
			rows.append(cells)
	return rows


## Back to the match-start ellipse (no warning band, like the initial map). Stops the shrink
## timer; the match loop restarts it. A ring still draining is applied first, so the tile map is
## exactly the starting ellipse when this returns.
func reset() -> void:
	stop_shrink()
	flush_repaint()
	current_radius = start_radius
	_paint_now(0)
	radius_changed.emit(current_radius)


## One shrink step: the ellipse loses `shrink_step` px off its horizontal semi-axis and the ring
## that changed is queued for the frame-budgeted drain (see the class docs).
func shrink() -> void:
	if current_radius <= 0:
		stop_shrink()
		return
	flush_repaint()
	current_radius = maxi(current_radius - shrink_step, 0)
	_pending_rows = repaint_rows(_painted_radius, _painted_edge, current_radius, edge_thickness)
	_pending_radius = current_radius
	_pending_edge = edge_thickness
	if _pending_rows.is_empty():
		_settle_repaint()
	else:
		set_process(true)
	radius_changed.emit(current_radius)


func start_shrink() -> void:
	_shrink_timer.start()


func stop_shrink() -> void:
	_shrink_timer.stop()


func is_shrinking() -> bool:
	return not _shrink_timer.is_stopped()


## True while a shrink ring is still being applied across frames.
func is_repainting() -> bool:
	return not _pending_rows.is_empty()


## Applies the whole pending ring right away (`reset()` and tests use it; a match never needs
## to: the drain is far quicker than the 3 s between steps).
func flush_repaint() -> void:
	_apply_rows(_pending_rows.size())


## Liquid over the whole field, painted once for the scene: the cell rules of radius zero
## (liquid everywhere) that the first `reset()` then carves the starting ellipse out of.
func _paint_field() -> void:
	var extent := shape_extent(start_radius + FIELD_MARGIN)
	for y in range(-extent.y, extent.y + 1):
		for x in range(-extent.x, extent.x + 1):
			set_cell(Vector2i(x, y), LAVA_SOURCE, LAVA_ATLAS)
	_painted_radius = 0
	_painted_edge = 0


## Repaints everything between the painted play area and the ellipse of `current_radius` with
## `edge` px of band, in this frame (`reset()`; a ring while a match runs drains instead).
func _paint_now(edge: int) -> void:
	_pending_radius = current_radius
	_pending_edge = edge
	_pending_rows = repaint_rows(_painted_radius, _painted_edge, current_radius, edge)
	flush_repaint()


func _process(_delta: float) -> void:
	_apply_rows(shrink_rows_per_frame)


## Applies up to `limit` rows of the pending ring. When the last row lands the tile map is
## painted for the plan's ellipse, so that state becomes the painted state.
func _apply_rows(limit: int) -> void:
	if _pending_rows.is_empty():
		return
	for _row in mini(limit, _pending_rows.size()):
		_apply_row(_pending_rows.pop_front())
	if _pending_rows.is_empty():
		_settle_repaint()


func _apply_row(cells: Array) -> void:
	for coords: Vector2i in cells:
		match classify(shape_dist_sq(coords), _pending_radius, _pending_edge):
			CellKind.FLOOR:
				set_cell(coords, FLOOR_SOURCE, FLOOR_ATLAS)
			CellKind.EDGE:
				set_cell(coords, EDGE_SOURCE, EDGE_ATLAS, EDGE_ALTERNATIVE)
			_:
				set_cell(coords, LAVA_SOURCE, LAVA_ATLAS)


## The pending plan is fully applied: the tile map is painted for it, and the drain sleeps until
## the next `shrink()`.
func _settle_repaint() -> void:
	_painted_radius = _pending_radius
	_painted_edge = _pending_edge
	set_process(false)
