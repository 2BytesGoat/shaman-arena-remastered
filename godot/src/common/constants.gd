extends Node

const PLAYER_COLORS := {
	0: [
		Color("#dd0701"), Color("#8a0102"), Color("#010101"), Color("#00000000"), Color("#00000000")
	],
	1: [
		Color("#b241e5"), Color("#9003d1"), Color("#010101"), Color("#00000000"), Color("#00000000")
	]
}


func palette_for(index: int) -> Array:
	return PLAYER_COLORS.get(index, [])
