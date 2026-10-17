extends GdUnitTestSuite

const AbilityPaths := preload("res://tests/support/ability_paths.gd")
const ALL_NAMES := ["fireball", "boomerang", "meteor", "smoke", "teleport", "blink", "anivia_wall"]


func _catalogue(names: Array = ALL_NAMES) -> Array[Ability]:
	var abilities: Array[Ability] = []
	for name in names:
		abilities.append(load(AbilityPaths.path(name)))
	return abilities


func _seeded_rng(seed_value := 1234) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _no_exclusions() -> Array[Ability]:
	return []


func test_draws_five_distinct_offers_from_the_catalogue() -> void:
	var catalogue := _catalogue()
	var offers := SpellDraw.draw_offers(catalogue, SpellDraw.OFFER_COUNT, _no_exclusions(), _seeded_rng())
	assert_int(offers.size()).is_equal(SpellDraw.OFFER_COUNT)
	var seen := {}
	for offer in offers:
		assert_bool(catalogue.has(offer)).is_true()
		assert_bool(seen.has(offer)).is_false()
		seen[offer] = true


func test_offers_exclude_owned_spells() -> void:
	var catalogue := _catalogue()
	var owned: Array[Ability] = [catalogue[0], catalogue[1], catalogue[2]]
	var offers := SpellDraw.draw_offers(catalogue, SpellDraw.OFFER_COUNT, owned, _seeded_rng())
	assert_int(offers.size()).is_equal(catalogue.size() - owned.size())
	for offer in offers:
		assert_bool(owned.has(offer)).is_false()
	assert_array(offers).contains_exactly_in_any_order([catalogue[3], catalogue[4], catalogue[5], catalogue[6]])


func test_offers_all_remaining_when_the_catalogue_is_smaller_than_the_count() -> void:
	var catalogue := _catalogue(["fireball", "smoke"])
	var offers := SpellDraw.draw_offers(catalogue, SpellDraw.OFFER_COUNT, _no_exclusions(), _seeded_rng())
	assert_array(offers).contains_exactly_in_any_order(catalogue)


func test_exhausted_catalogue_draws_nothing() -> void:
	var catalogue := _catalogue()
	var offers := SpellDraw.draw_offers(catalogue, SpellDraw.OFFER_COUNT, catalogue, _seeded_rng())
	assert_array(offers).is_empty()


func test_zero_count_draws_nothing() -> void:
	var offers := SpellDraw.draw_offers(_catalogue(), 0, _no_exclusions(), _seeded_rng())
	assert_array(offers).is_empty()


func test_has_offers_matches_whether_any_candidate_remains() -> void:
	var catalogue := _catalogue()
	assert_bool(SpellDraw.has_offers(catalogue, _no_exclusions())).is_true()
	var almost_full: Array[Ability] = []
	for index in catalogue.size() - 1:
		almost_full.append(catalogue[index])
	assert_bool(SpellDraw.has_offers(catalogue, almost_full)).is_true()
	assert_bool(SpellDraw.has_offers(catalogue, catalogue)).is_false()


func test_duplicate_catalogue_entries_never_repeat_an_offer() -> void:
	var catalogue := _catalogue(["fireball", "smoke"])
	catalogue.append(catalogue[0])
	var offers := SpellDraw.draw_offers(catalogue, SpellDraw.OFFER_COUNT, _no_exclusions(), _seeded_rng())
	assert_array(offers).contains_exactly_in_any_order(_catalogue(["fireball", "smoke"]))


func test_draw_is_deterministic_for_a_seed() -> void:
	var first := SpellDraw.draw_offers(_catalogue(), SpellDraw.OFFER_COUNT, _no_exclusions(), _seeded_rng(99))
	var second := SpellDraw.draw_offers(_catalogue(), SpellDraw.OFFER_COUNT, _no_exclusions(), _seeded_rng(99))
	assert_array(first).is_equal(second)
