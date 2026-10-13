class_name DamagedState extends State

const HIT_LOCK_TIME := 0.2

var elapsed := 0.0


func enter(_msg := {}) -> void:
	elapsed = 0.0
	owner.hit_locked = true


func exit() -> void:
	owner.hit_locked = false


func physics_update(delta: float) -> void:
	elapsed += delta
	if elapsed >= HIT_LOCK_TIME:
		state_machine.transition_to("Idle")
