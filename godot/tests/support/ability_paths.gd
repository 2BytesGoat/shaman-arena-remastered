extends RefCounted

## Maps an ability's `<name>_ability.tres` to its delivery folder under
## `res://src/resources/abilities/` (mirrors `res://src/abilities/spells/`).

const ROOT := "res://src/resources/abilities/"
const GROUPS := {
	"blink": "self",
	"fireball": "projectile",
	"boomerang": "projectile",
	"meteor": "projectile",
	"teleport": "projectile",
	"smoke": "field",
	"anivia_wall": "deployable",
}


static func path(ability_name: String) -> String:
	return "%s%s/%s_ability.tres" % [ROOT, GROUPS[ability_name], ability_name]
