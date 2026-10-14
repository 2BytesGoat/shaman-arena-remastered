class_name AnimationSlots

const IDLE := &"Idle"
const MOVE := &"Move"
const AIM := &"Aim"
const HIT := &"Hit"
const DEAD := &"Dead"

const CAST_OFFENSIVE := &"CastOffensive"
const CAST_DEFENSIVE := &"CastDefensive"
const CAST_UTILITY := &"CastUtility"

const ATTACK := &"Attack"
const CHANNEL := &"Channel"
const TAUNT := &"Taunt"

const CAST_DEFERRED := [IDLE, MOVE, AIM]

const REQUIRED := [
	IDLE, MOVE, AIM, HIT, DEAD, CAST_OFFENSIVE, CAST_DEFENSIVE, CAST_UTILITY
]
