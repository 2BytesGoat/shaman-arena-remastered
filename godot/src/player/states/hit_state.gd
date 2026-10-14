class_name HitState extends State


func enter(_msg := {}) -> void:
	owner.hit_locked = true
	owner.visuals.play(self.name)


func exit() -> void:
	owner.hit_locked = false


func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	if anim_name != &"Hit":
		return
	if owner.player_dead:
		state_machine.transition_to("Dead")
	else:
		state_machine.transition_to("Idle")
