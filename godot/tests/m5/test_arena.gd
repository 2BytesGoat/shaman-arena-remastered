extends GdUnitTestSuite

const ARENA_SCENE := "res://src/match/arena.tscn"
const TILESET := "res://assets/terrain/arena_tileset.tres"


## Small radii keep the fixture cheap: the mask math is the same at any size.
func _spawn_arena(start_radius := 6) -> Arena:
	var arena := (load(ARENA_SCENE) as PackedScene).instantiate() as Arena
	arena.start_radius = start_radius
	add_child(arena)
	auto_free(arena)
	return arena


func test_classify_matches_the_poc_cell_rules() -> void:
	# Initial map: floor inside the circle, magma straight after it (no warning band).
	assert_int(Arena.classify(0, 50, 0)).is_equal(Arena.CellKind.FLOOR)
	assert_int(Arena.classify(49 * 49, 50, 0)).is_equal(Arena.CellKind.FLOOR)
	assert_int(Arena.classify(50 * 50, 50, 0)).is_equal(Arena.CellKind.LAVA)
	# Shrunk map: the removed ring is the warning band, then magma.
	assert_int(Arena.classify(49 * 49, 50, 1)).is_equal(Arena.CellKind.FLOOR)
	assert_int(Arena.classify(50 * 50, 50, 1)).is_equal(Arena.CellKind.EDGE)
	assert_int(Arena.classify(51 * 51, 50, 1)).is_equal(Arena.CellKind.EDGE)
	assert_int(Arena.classify(51 * 51 + 1, 50, 1)).is_equal(Arena.CellKind.LAVA)


func test_ready_paints_floor_inside_and_magma_outside() -> void:
	var arena := _spawn_arena()
	await get_tree().process_frame
	assert_int(arena.current_radius).is_equal(arena.start_radius)
	assert_int(arena.get_cell_source_id(Vector2i.ZERO)).is_equal(Arena.FLOOR_SOURCE)
	assert_vector(arena.get_cell_atlas_coords(Vector2i.ZERO)).is_equal(Arena.FLOOR_ATLAS)
	assert_int(arena.get_cell_source_id(Vector2i(arena.start_radius - 1, 0))).is_equal(
		Arena.FLOOR_SOURCE
	)
	var magma := Vector2i(arena.start_radius, 0)
	assert_int(arena.get_cell_source_id(magma)).is_equal(Arena.LAVA_SOURCE)
	assert_vector(arena.get_cell_atlas_coords(magma)).is_equal(Arena.LAVA_ATLAS)
	assert_bool(arena.is_shrinking()).is_false()


func test_shrink_repaints_only_the_removed_ring() -> void:
	var arena := _spawn_arena()
	await get_tree().process_frame
	arena.shrink()
	assert_int(arena.current_radius).is_equal(arena.start_radius - 1)
	# The rim tile is now the warning band and the old band is now magma.
	var warned := Vector2i(arena.start_radius, 0)
	assert_int(arena.get_cell_source_id(warned)).is_equal(Arena.EDGE_SOURCE)
	assert_vector(arena.get_cell_atlas_coords(warned)).is_equal(Arena.EDGE_ATLAS)
	assert_int(arena.get_cell_source_id(Vector2i(arena.start_radius + 1, 0))).is_equal(
		Arena.LAVA_SOURCE
	)
	# The floor inside the new radius stays floor.
	assert_int(arena.get_cell_source_id(Vector2i(arena.start_radius - 2, 0))).is_equal(
		Arena.FLOOR_SOURCE
	)
	# One more step burns the band the first step warned about.
	arena.shrink()
	assert_int(arena.get_cell_source_id(warned)).is_equal(Arena.LAVA_SOURCE)


func test_reset_restores_the_starting_circle() -> void:
	var arena := _spawn_arena()
	await get_tree().process_frame
	for _step in 3:
		arena.shrink()
	arena.reset()
	assert_int(arena.current_radius).is_equal(arena.start_radius)
	assert_int(arena.get_cell_source_id(Vector2i(arena.start_radius, 0))).is_equal(
		Arena.LAVA_SOURCE
	)
	assert_int(arena.get_cell_source_id(Vector2i(arena.start_radius - 1, 0))).is_equal(
		Arena.FLOOR_SOURCE
	)
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
	for _step in arena.start_radius + 2:
		arena.shrink()
	assert_int(arena.current_radius).is_equal(0)
	assert_bool(arena.is_shrinking()).is_false()


func test_magma_bodies_are_detected_by_the_hurtbox_mask() -> void:
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
