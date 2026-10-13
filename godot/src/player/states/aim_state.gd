class_name AimState extends State

const TAP_THRESHOLD := 0.15

var ability: Ability
var slot := -1
var hold_time := 0.0


static func is_tap(hold_duration: float) -> bool:
	return hold_duration < TAP_THRESHOLD


func enter(msg := {}) -> void:
	ability = msg["ability"]
	slot = msg["slot"]
	hold_time = 0.0
	owner.aiming = true
	owner.velocity = Vector2.ZERO


func exit() -> void:
	owner.aiming = false


func physics_update(delta: float) -> void:
	hold_time += delta
	owner.update_cast_direction()
	if Input.is_action_just_released(owner.spell_action(slot)):
		var direction: Vector2 = owner.facing_direction() if is_tap(hold_time) else owner.cast_direction
		owner.try_cast(ability, direction)
		state_machine.transition_to("Idle")
