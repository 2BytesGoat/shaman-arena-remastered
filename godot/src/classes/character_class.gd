class_name CharacterClass extends Resource

## A playable archetype. Its basic spells are seeded into the player's pool before the
## first draft, so no hand ever offers them.

@export var display_name := ""
@export var basic_spells: Array[Ability] = []
