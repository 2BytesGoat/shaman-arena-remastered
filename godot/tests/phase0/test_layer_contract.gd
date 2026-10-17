extends GdUnitTestSuite

const PROJECTILES := "res://src/abilities/spells/projectile/"
const FIELDS := "res://src/abilities/spells/field/"
const DEPLOYABLES := "res://src/abilities/spells/deployable/"
const EFFECTS := "res://src/abilities/effects/"
const IMPACTS := "res://src/abilities/effects/impact/"
const TELEGRAPHS := "res://src/abilities/effects/telegraph/"


func _area(path: String) -> Area2D:
	var scene: PackedScene = load(path)
	var area := scene.instantiate() as Area2D
	add_child(area)
	auto_free(area)
	return area


func _area_links(area: Area2D) -> int:
	return area.get_signal_connection_list("area_entered").size()


func test_layer_names_match_the_ported_mapping() -> void:
	var expected := {
		"player_0": 1,
		"player_1": 2,
		"player_2": 3,
		"player_3": 4,
		"projectile": 5,
		"lava": 6,
		"Environment": 7,
	}
	for layer_name: String in expected:
		var setting := "layer_names/2d_physics/layer_%d" % expected[layer_name]
		assert_str(str(ProjectSettings.get_setting(setting))).is_equal(layer_name)


func test_player_body_collides_with_other_player_and_environment() -> void:
	var player := load("res://src/player/player.tscn").instantiate() as CharacterBody2D
	add_child(player)
	auto_free(player)
	assert_int(player.collision_layer).is_equal(1)
	assert_int(player.collision_mask).is_equal(65)
	var hurtbox := player.get_node("Hurtbox") as Area2D
	assert_int(hurtbox.collision_layer).is_equal(1)
	# M5 (D-019): the hurtbox listens to the lava layer for the arena burn; spell hits stay
	# attacker-side, so the projectile layers are not masked here.
	assert_int(hurtbox.collision_mask).is_equal(32)


func test_direct_projectiles_mask_players_projectiles_and_environment() -> void:
	for name: String in ["fireball", "boomerang"]:
		var area := _area(PROJECTILES + name + ".tscn")
		assert_int(area.collision_layer).is_equal(16)
		assert_int(area.collision_mask).is_equal(95)
		assert_int(_area_links(area)).is_equal(1)


func test_travel_only_spells_leave_their_inherited_mask_inert() -> void:
	for name: String in ["teleport", "meteor"]:
		var area := _area(PROJECTILES + name + ".tscn")
		assert_int(area.collision_layer).is_equal(0)
		assert_int(area.collision_mask).is_equal(15)
		assert_int(_area_links(area)).is_equal(0)


func test_smoke_hits_players_only_and_expires_on_animation() -> void:
	var smoke := _area(FIELDS + "smoke.tscn")
	assert_int(smoke.collision_layer).is_equal(16)
	assert_int(smoke.collision_mask).is_equal(1)
	assert_int(_area_links(smoke)).is_equal(1)


func test_meteor_telegraph_contact_is_inert() -> void:
	var telegraph := _area(TELEGRAPHS + "meteor_incoming.tscn")
	assert_int(telegraph.collision_layer).is_equal(16)
	assert_int(telegraph.collision_mask).is_equal(95)
	assert_int(_area_links(telegraph)).is_equal(0)


func test_effects_hit_players_only_and_inherit_the_area_handler() -> void:
	var paths := [
		EFFECTS + "effect.tscn",
		IMPACTS + "explosion_effect.tscn",
		IMPACTS + "meteor_explosion.tscn",
	]
	for path: String in paths:
		var area := _area(path)
		assert_int(area.collision_layer).is_equal(16)
		assert_int(area.collision_mask).is_equal(1)
		assert_int(_area_links(area)).is_equal(1)


func test_wall_blocks_bodies_and_despawns_on_spell_contact() -> void:
	var wall := _area(DEPLOYABLES + "anivia_wall.tscn")
	assert_int(wall.collision_layer).is_equal(64)
	assert_int(wall.collision_mask).is_equal(31)
	assert_int(_area_links(wall)).is_equal(1)
	var body := wall.get_node("StaticBody2D-Wall") as StaticBody2D
	assert_int(body.collision_layer).is_equal(64)
	assert_int(body.collision_mask).is_equal(15)


func test_arena_tileset_puts_magma_on_the_lava_layer() -> void:
	var tileset: TileSet = load("res://assets/terrain/arena_tileset.tres")
	assert_int(tileset.get_physics_layers_count()).is_equal(1)
	assert_int(tileset.get_physics_layer_collision_layer(0)).is_equal(32)
	assert_int(tileset.get_physics_layer_collision_mask(0)).is_equal(0)
	var magma := tileset.get_source(Arena.LAVA_SOURCE) as TileSetAtlasSource
	assert_object(magma).is_not_null()
	assert_int(magma.get_tile_animation_frames_count(Arena.LAVA_ATLAS)).is_equal(2)
	var tile := magma.get_tile_data(Arena.LAVA_ATLAS, 0)
	assert_int(tile.get_collision_polygons_count(0)).is_equal(1)
