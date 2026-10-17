extends GdUnitTestSuite

const ARENA_SCENE := "res://src/match/arena.tscn"
const TILESET := "res://src/resources/arena/arena_tileset.tres"

## Fixture radius, in px: small radii keep the fixture cheap and the ellipse math is the same at
## any size. Row `y = -1` runs through the arena centre (its cells sit at `y = 0`) and steps 32 px
## per cell, so `RIM_CELL` sits exactly on the circle and `FLOOR_CELL` one step inside it.
const START_RADIUS := 96
const RIM_CELL := Vector2i(2, -1)
const FLOOR_CELL := Vector2i(1, -1)
const INNER_CELL := Vector2i(0, -1)


func _spawn_arena(start_radius := START_RADIUS) -> Arena:
	var arena := (load(ARENA_SCENE) as PackedScene).instantiate() as Arena
	arena.start_radius = start_radius
	add_child(arena)
	auto_free(arena)
	return arena


## The kind the arena paints in one cell (`-1` for an empty one).
func _cell_kind(arena: Arena, coords: Vector2i) -> int:
	if arena.get_cell_source_id(coords) == Arena.LAVA_SOURCE:
		return Arena.CellKind.LAVA
	if arena.get_cell_source_id(coords) == Arena.FLOOR_SOURCE:
		return (
			Arena.CellKind.EDGE
			if arena.get_cell_alternative_tile(coords) == Arena.EDGE_ALTERNATIVE
			else Arena.CellKind.FLOOR
		)
	return -1


## Asserts the whole play area is painted the way `classify` paints it for an ellipse with a
## `radius` px horizontal semi-axis and `edge` px of warning band: the reference the incremental
## repaint must match.
func _assert_arena_matches(arena: Arena, radius: int, edge: int) -> void:
	assert_int(arena.current_radius).is_equal(radius)
	var extent := Arena.shape_extent(radius + edge)
	var mismatches := {}
	for y in range(-extent.y, extent.y + 1):
		for x in range(-extent.x, extent.x + 1):
			var coords := Vector2i(x, y)
			var expected := Arena.classify(Arena.shape_dist_sq(coords), radius, edge)
			var painted := _cell_kind(arena, coords)
			if painted != expected:
				mismatches[coords] = [painted, expected]
	assert_dict(mismatches).override_failure_message(
		"Arena cells do not match classify(radius %d, edge %d)" % [radius, edge]
	).is_empty()


## Asserts `Arena.repaint_rows` plans exactly the cells whose kind changes between two painted
## play areas — the brute-force scan is the reference (one short leaves a stale tile behind, one
## extra repaints cells that did not change).
func _assert_plan_matches_brute_force(
	from_radius: int, from_edge: int, to_radius: int, to_edge: int
) -> void:
	var outer := maxi(from_radius + from_edge, to_radius + to_edge)
	var extent := Arena.shape_extent(outer)
	var changed := {}
	for y in range(-extent.y, extent.y + 1):
		for x in range(-extent.x, extent.x + 1):
			var coords := Vector2i(x, y)
			var dist_sq := Arena.shape_dist_sq(coords)
			var before := Arena.classify(dist_sq, from_radius, from_edge)
			if Arena.classify(dist_sq, to_radius, to_edge) != before:
				changed[coords] = true
	var planned := {}
	var total := 0
	for cells: Array in Arena.repaint_rows(from_radius, from_edge, to_radius, to_edge):
		total += cells.size()
		for coords: Vector2i in cells:
			planned[coords] = true
	assert_int(total).is_equal(planned.size()) # No cell is planned twice.
	var missing := []
	for coords: Vector2i in changed:
		if not planned.has(coords):
			missing.append(coords)
	assert_bool(missing.is_empty()).override_failure_message(
		"%d changed cells missing from the repaint plan (%d, %d) -> (%d, %d)"
		% [missing.size(), from_radius, from_edge, to_radius, to_edge]
	).is_true()
	assert_int(planned.size()).is_equal(changed.size())


func test_classify_matches_the_poc_cell_rules() -> void:
	# Initial map: floor inside the circle, liquid straight after it (no warning band).
	assert_int(Arena.classify(0, 50, 0)).is_equal(Arena.CellKind.FLOOR)
	assert_int(Arena.classify(49 * 49, 50, 0)).is_equal(Arena.CellKind.FLOOR)
	assert_int(Arena.classify(50 * 50, 50, 0)).is_equal(Arena.CellKind.LAVA)
	# Shrunk map: the removed ring is the warning band, then liquid.
	assert_int(Arena.classify(49 * 49, 50, 1)).is_equal(Arena.CellKind.FLOOR)
	assert_int(Arena.classify(50 * 50, 50, 1)).is_equal(Arena.CellKind.EDGE)
	assert_int(Arena.classify(51 * 51, 50, 1)).is_equal(Arena.CellKind.EDGE)
	assert_int(Arena.classify(51 * 51 + 1, 50, 1)).is_equal(Arena.CellKind.LAVA)


## The shape metric is only right if it matches how the tile set places cells (D-019): the
## staggered iso grid, not a diagonal `(x - y, x + y)` one.
func test_cell_center_matches_the_engine_iso_mapping() -> void:
	var arena := _spawn_arena()
	for coords: Vector2i in [
		Vector2i.ZERO,
		Vector2i(1, 0),
		Vector2i(2, 2),
		Vector2i(0, -1),
		Vector2i(3, -5),
		Vector2i(-4, 2),
	]:
		assert_vector(Vector2(Arena.cell_center(coords))).is_equal(arena.map_to_local(coords))


## The metric feeds `classify`, so it is the squared distance of the cell centre from the arena
## origin in px² of the play ellipse's shape space: the vertical offset weighs `SHAPE_SQUASH_SQ`
## (4, the 2:1 ellipse), the origin is a cell-grid corner — hence the 512s, not 0.
func test_shape_dist_sq_measures_from_the_arena_origin() -> void:
	assert_int(Arena.SHAPE_SQUASH_SQ).is_equal(Arena.SHAPE_ASPECT * Arena.SHAPE_ASPECT)
	assert_int(Arena.shape_dist_sq(Vector2i(0, 0))).is_equal(512)
	assert_int(Arena.shape_dist_sq(Vector2i(-1, 0))).is_equal(512)
	assert_int(Arena.shape_dist_sq(Vector2i(0, -1))).is_equal(1024)
	assert_int(Arena.shape_dist_sq(Vector2i(0, 1))).is_equal(2048)
	assert_int(Arena.shape_dist_sq(Vector2i(1, -1))).is_equal(4096)


## `shape_extent` bounds the repaint loops: no cell inside the play ellipse may sit outside it.
func test_shape_extent_covers_every_cell_inside_the_ellipse() -> void:
	for radius: int in [96, 800]:
		var extent := Arena.shape_extent(radius)
		var reach := Vector2i.ZERO
		for y in range(-extent.y - 1, extent.y + 2):
			for x in range(-extent.x - 1, extent.x + 2):
				if Arena.shape_dist_sq(Vector2i(x, y)) <= radius * radius:
					reach.x = maxi(reach.x, absi(x))
					reach.y = maxi(reach.y, absi(y))
		assert_int(reach.x).is_less_equal(extent.x)
		assert_int(reach.y).is_less_equal(extent.y)
		# The rectangle stays snug (a loose bound would only cost paint time).
		assert_int(extent.x).is_less_equal(reach.x + 2)
		assert_int(extent.y).is_less_equal(reach.y + 2)


## The repaint plan is built from the distance annulus that changes, not from the ellipse's whole
## bounding rectangle (D-019 addendum): it must contain every cell whose kind changes — a missed
## cell would keep a stale tile — and nothing else.
func test_repaint_plan_is_exactly_the_changed_ring() -> void:
	_assert_plan_matches_brute_force(96, 0, 80, 16) # First step after reset: floor -> warning band.
	_assert_plan_matches_brute_force(80, 16, 64, 16) # Steady state: band -> liquid, floor -> band.
	_assert_plan_matches_brute_force(64, 16, 96, 0) # Reset regrow: liquid and band -> floor.
	_assert_plan_matches_brute_force(96, 16, 96, 16) # No movement: nothing to repaint.
	_assert_plan_matches_brute_force(800, 16, 784, 16) # The real fixture: one match step.


## One shrink step at r=800 changes ~304 cells; the bounding rectangle the old repaint walked
## holds 5 459. The plan has to stay close to the annulus, or the frame budget buys nothing.
func test_repaint_plan_touches_only_the_ring() -> void:
	var rectangle := Arena.shape_extent(800)
	var rectangle_cells := (rectangle.x * 2 + 1) * (rectangle.y * 2 + 1)
	var ring_cells := 0
	for cells: Array in Arena.repaint_rows(800, 16, 784, 16):
		ring_cells += cells.size()
	assert_int(ring_cells).is_greater(200)
	assert_int(ring_cells).is_less(600)
	assert_int(rectangle_cells).is_greater(ring_cells * 10)


func test_ready_paints_floor_inside_and_liquid_outside() -> void:
	var arena := _spawn_arena()
	await get_tree().process_frame
	assert_int(arena.current_radius).is_equal(arena.start_radius)
	assert_int(arena.get_cell_source_id(Vector2i.ZERO)).is_equal(Arena.FLOOR_SOURCE)
	assert_vector(arena.get_cell_atlas_coords(Vector2i.ZERO)).is_equal(Arena.FLOOR_ATLAS)
	assert_int(arena.get_cell_source_id(FLOOR_CELL)).is_equal(Arena.FLOOR_SOURCE)
	assert_int(arena.get_cell_source_id(RIM_CELL)).is_equal(Arena.LAVA_SOURCE)
	assert_vector(arena.get_cell_atlas_coords(RIM_CELL)).is_equal(Arena.LAVA_ATLAS)
	assert_bool(arena.is_shrinking()).is_false()


func test_shrink_repaints_only_the_removed_ring() -> void:
	var arena := _spawn_arena()
	await get_tree().process_frame
	arena.shrink()
	arena.flush_repaint() # The ring drains across frames; apply the rest of it now.
	assert_int(arena.current_radius).is_equal(arena.start_radius - arena.shrink_step)
	# The rim tile is now the warning band, in its own alternative of the floor tile.
	assert_int(arena.get_cell_alternative_tile(RIM_CELL)).is_equal(Arena.EDGE_ALTERNATIVE)
	assert_int(arena.get_cell_source_id(RIM_CELL)).is_equal(Arena.EDGE_SOURCE)
	assert_vector(arena.get_cell_atlas_coords(RIM_CELL)).is_equal(Arena.EDGE_ATLAS)
	# The floor inside the new radius stays floor.
	assert_int(arena.get_cell_source_id(FLOOR_CELL)).is_equal(Arena.FLOOR_SOURCE)
	assert_int(arena.get_cell_source_id(INNER_CELL)).is_equal(Arena.FLOOR_SOURCE)
	# One more step burns the band the first step warned about, and the next ring warns.
	arena.shrink()
	arena.flush_repaint()
	assert_int(arena.get_cell_source_id(RIM_CELL)).is_equal(Arena.LAVA_SOURCE)
	assert_int(arena.get_cell_alternative_tile(FLOOR_CELL)).is_equal(Arena.EDGE_ALTERNATIVE)


## On the arcade web build a whole ring in one frame staggered for ~0.5 s (the layer is y-sorted,
## so each repainted row rebuilds that row's canvas item): the ring must drain over frames, and
## the drained map must be exactly the map a synchronous repaint would have painted.
func test_shrink_ring_drains_over_frames() -> void:
	var arena := _spawn_arena()
	await get_tree().process_frame
	arena.shrink_rows_per_frame = 1
	arena.shrink()
	assert_bool(arena.is_repainting()).is_true()
	var frames := 0
	while arena.is_repainting() and frames < 100:
		arena._process(0.0) # One frame's worth of the drain.
		frames += 1
	assert_bool(arena.is_repainting()).is_false()
	assert_int(frames).is_greater(1)
	_assert_arena_matches(arena, arena.start_radius - arena.shrink_step, arena.edge_thickness)


## The drain is driven by the frame loop, not only by a test pumping it: `shrink()` re-arms
## `_process`, and the ring lands on its own.
func test_shrink_ring_drains_from_the_frame_loop() -> void:
	var arena := _spawn_arena()
	await get_tree().process_frame
	arena.shrink_rows_per_frame = 100 # The fixture ring fits in a frame or two.
	arena.shrink()
	assert_bool(arena.is_repainting()).is_true()
	var deadline := Time.get_ticks_msec() + 1000
	while arena.is_repainting() and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	assert_bool(arena.is_repainting()).is_false()
	_assert_arena_matches(arena, arena.start_radius - arena.shrink_step, arena.edge_thickness)


## A reset (or the next shrink) landing mid-drain must not leave a half-painted play area behind:
## both apply the rest of the pending ring first, then repaint from a known state.
func test_reset_while_draining_restores_the_exact_play_area() -> void:
	var arena := _spawn_arena()
	await get_tree().process_frame
	arena.shrink_rows_per_frame = 1
	arena.shrink()
	arena.shrink()
	assert_bool(arena.is_repainting()).is_true()
	arena.reset()
	assert_bool(arena.is_repainting()).is_false()
	_assert_arena_matches(arena, arena.start_radius, 0)


func test_reset_restores_the_starting_circle() -> void:
	var arena := _spawn_arena()
	await get_tree().process_frame
	for _step in 3:
		arena.shrink()
	arena.reset()
	assert_int(arena.current_radius).is_equal(arena.start_radius)
	assert_int(arena.get_cell_source_id(RIM_CELL)).is_equal(Arena.LAVA_SOURCE)
	assert_int(arena.get_cell_source_id(FLOOR_CELL)).is_equal(Arena.FLOOR_SOURCE)
	assert_bool(arena.is_shrinking()).is_false()


func test_shrink_timer_start_and_stop() -> void:
	var arena := _spawn_arena()
	await get_tree().process_frame
	arena.start_shrink()
	assert_bool(arena.is_shrinking()).is_true()
	arena.stop_shrink()
	assert_bool(arena.is_shrinking()).is_false()


func test_shrink_stops_at_radius_zero() -> void:
	var arena := _spawn_arena()
	await get_tree().process_frame
	arena.start_shrink()
	var steps := int(float(arena.start_radius) / arena.shrink_step)
	for _step in steps + 2:
		arena.shrink()
	assert_int(arena.current_radius).is_equal(0)
	assert_bool(arena.is_shrinking()).is_false()


## The warning band is an alternative of the floor tile: if it ever loses the base tile's texture
## origin it would draw offset from the grid.
func test_warning_band_alternative_keeps_the_floor_tile_placement() -> void:
	var source := (load(TILESET) as TileSet).get_source(Arena.EDGE_SOURCE) as TileSetAtlasSource
	assert_object(source).is_not_null()
	var base := source.get_tile_data(Arena.EDGE_ATLAS, 0)
	var band := source.get_tile_data(Arena.EDGE_ATLAS, Arena.EDGE_ALTERNATIVE)
	assert_object(band).is_not_null()
	assert_vector(band.get_texture_origin()).is_equal(base.get_texture_origin())


func test_liquid_tiles_are_detected_by_the_hurtbox_mask() -> void:
	var layer := TileMapLayer.new()
	layer.tile_set = load(TILESET)
	add_child(layer)
	auto_free(layer)
	layer.set_cell(Vector2i.ZERO, Arena.LAVA_SOURCE, Arena.LAVA_ATLAS)
	var body := CharacterBody2D.new()
	body.collision_layer = 1
	add_child(body)
	auto_free(body)
	var body_shape := CollisionShape2D.new()
	body_shape.shape = RectangleShape2D.new()
	(body_shape.shape as RectangleShape2D).size = Vector2(20.0, 20.0)
	body.add_child(body_shape)
	var hurtbox := Area2D.new()
	hurtbox.collision_layer = 1
	hurtbox.collision_mask = 32
	body.add_child(hurtbox)
	var hurtbox_shape := CollisionShape2D.new()
	hurtbox_shape.shape = RectangleShape2D.new()
	(hurtbox_shape.shape as RectangleShape2D).size = Vector2(20.0, 20.0)
	hurtbox.add_child(hurtbox_shape)
	var entered := [false]
	hurtbox.body_entered.connect(func(_entered_body: Node2D) -> void: entered[0] = true)
	var deadline := Time.get_ticks_msec() + 1000
	while not entered[0] and Time.get_ticks_msec() < deadline:
		await get_tree().physics_frame
	assert_bool(entered[0]).is_true()


func test_match_flow_resets_and_restarts_the_arena() -> void:
	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(main)
	auto_free(main)
	await get_tree().process_frame
	var manager := main.get_node("MatchManager") as MatchManager
	var arena := main.get_node("Arena") as Arena
	assert_object(manager.arena).is_same(arena)
	assert_bool(arena.is_shrinking()).is_false()
	manager.death_slowmo_duration = 0.0
	for panel in manager.selection_panels():
		panel.handle_accept()
		await get_tree().process_frame
	assert_int(manager.phase).is_equal(MatchManager.MatchPhase.RUNNING)
	assert_bool(arena.is_shrinking()).is_true()
	arena.shrink()
	manager.player_for(0).take_hit(manager.player_for(1), 100.0, 0.0, Vector2.RIGHT)
	assert_int(manager.phase).is_equal(MatchManager.MatchPhase.ROUND_OVER)
	assert_bool(arena.is_shrinking()).is_false()
	var loser_panel := manager.selection_panels()[0] as SpellSelect
	loser_panel.handle_accept()
	await get_tree().process_frame
	assert_int(manager.phase).is_equal(MatchManager.MatchPhase.RUNNING)
	assert_int(arena.current_radius).is_equal(arena.start_radius)
	assert_bool(arena.is_shrinking()).is_true()
