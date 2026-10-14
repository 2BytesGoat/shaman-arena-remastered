class_name AimState extends State

const TAP_THRESHOLD := 0.15

var ability: Ability
var hold_time := 0.0


static func is_tap(hold_duration: float) -> bool:
	return hold_duration < TAP_THRESHOLD


func enter(msg := {}) -> void:
	ability = msg["ability"]
	hold_time = 0.0
	owner.aiming = true
	owner.aiming_slot = msg["slot"]
	owner.velocity = Vector2.ZERO
	owner.visuals.play(self.name)


func exit() -> void:
	owner.aiming = false
	owner.aiming_slot = -1
	owner.release_cast_requested = false


func physics_update(delta: float) -> void:
	hold_time += delta
	if owner.consume_release_request():
		var direction: Vector2 = owner.facing_direction() if is_tap(hold_time) else owner.cast_direction
		owner.try_cast(ability, direction)
		state_machine.transition_to(AnimationSlots.IDLE)
