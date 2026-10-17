class_name Loadout extends RefCounted

## Total spells a player can hold — class basics plus drafted cards.
const MAX_SPELLS := 6

var picks: Array[Ability] = []


## A pool pre-seeded with a class's basic spells; empty for a null class. Copies the array,
## so picking never mutates the class resource.
static func from_class(character_class: CharacterClass) -> Loadout:
	var loadout := Loadout.new()
	if character_class != null:
		loadout.picks.assign(character_class.basic_spells)
	return loadout


func has(ability: Ability) -> bool:
	return picks.has(ability)


func is_full() -> bool:
	return picks.size() >= MAX_SPELLS


func can_pick(ability: Ability) -> bool:
	return ability != null and not has(ability) and not is_full()


func pick(ability: Ability) -> bool:
	if not can_pick(ability):
		return false
	picks.append(ability)
	return true


func unpick(ability: Ability) -> bool:
	var index := picks.find(ability)
	if index < 0:
		return false
	picks.remove_at(index)
	return true


func toggle(ability: Ability) -> void:
	if has(ability):
		unpick(ability)
	else:
		pick(ability)


func clear() -> void:
	picks.clear()
