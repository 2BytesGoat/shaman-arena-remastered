class_name SpellDraw extends RefCounted

## Rounds-style draft offers: draws `count` distinct random abilities from a
## catalogue, never offering a spell that is already in the player's pool.

const OFFER_COUNT := 5


static func draw_offers(
	catalogue: Array[Ability],
	count: int,
	excluded: Array[Ability],
	rng: RandomNumberGenerator
) -> Array[Ability]:
	var candidates := _candidates(catalogue, excluded)
	var offers: Array[Ability] = []
	var offer_count := mini(count, candidates.size())
	for index in offer_count:
		var swap_index := rng.randi_range(index, candidates.size() - 1)
		var offer := candidates[swap_index]
		candidates[swap_index] = candidates[index]
		candidates[index] = offer
		offers.append(offer)
	return offers


## True when a draft would have at least one committable card.
static func has_offers(catalogue: Array[Ability], excluded: Array[Ability]) -> bool:
	return not _candidates(catalogue, excluded).is_empty()


static func _candidates(catalogue: Array[Ability], excluded: Array[Ability]) -> Array[Ability]:
	var candidates: Array[Ability] = []
	for ability in catalogue:
		if ability == null or excluded.has(ability) or candidates.has(ability):
			continue
		candidates.append(ability)
	return candidates
