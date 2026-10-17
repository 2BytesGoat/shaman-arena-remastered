extends GdUnitTestSuite

const ARENA_SCENE := "res://src/match/arena.tscn"
const TILESET := "res://src/resources/arena/arena_tileset.tres"

## Fixture radius, in px: small radii keep the fixture cheap and the mask math is the same at
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


## The circle metric is only right if it matches how the tile set places cells (D-019): the
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
## origin in px² — the origin is a cell-grid corner, not a cell centre, hence the 320 not 0.
func test_screen_dist_sq_measures_from_the_arena_origin() -> void:
	assert_int(Arena.screen_dist_sq(Vector2i(0, 0))).is_equal(320)
	assert_int(Arena.screen_dist_sq(Vector2i(-1, 0))).is_equal(320)
	assert_int(Arena.screen_dist_sq(Vector2i(0, -1))).is_equal(1024)
	assert_int(Arena.screen_dist_sq(Vector2i(0, 1))).is_equal(1280)
	assert_int(Arena.screen_dist_sq(Vector2i(1, -1))).is_equal(4096)


## `circle_extent` bounds the repaint loops: no cell inside the circle may sit outside it.
func test_circle_extent_covers_every_cell_inside_the_circle() -> void:
	for radius: int in [96, 800]:
		var extent := Arena.circle_extent(radius)
		var reach := Vector2i.ZERO
		for y in range(-extent.y - 1, extent.y + 2):
			for x in range(-extent.x - 1, extent.x + 2):
				if Arena.screen_dist_sq(Vector2i(x, y)) <= radius * radius:
					reach.x = maxi(reach.x, absi(x))
					reach.y = maxi(reach.y, absi(y))
		assert_int(reach.x).is_less_equal(extent.x)
		assert_int(reach.y).is_less_equal(extent.y)
		# The rectangle stays snug (a loose bound would only cost paint time).
		assert_int(extent.x).is_less_equal(reach.x + 2)
		assert_int(extent.y).is_less_equal(reach.y + 2)


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
	assert_int(arena.get_cell_source_id(RIM_CELL)).is_equal(Arena.LAVA_SOURCE)
	assert_int(arena.get_cell_alternative_tile(FLOOR_CELL)).is_equal(Arena.EDGE_ALTERNATIVE)


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
