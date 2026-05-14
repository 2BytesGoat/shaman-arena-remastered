class_name AbilityButton extends Panel

@export var button: Button
@export var progress_bar: TextureProgressBar
@export var timer: Timer

var is_on_cooldown := false
var time_emplased  := 0.0
var tracked_ability: Ability = null


func start_cooldown(ability: Ability) -> void:
	is_on_cooldown  = true
	time_emplased   = 0.0
	tracked_ability = ability
	timer.start()


func update_cooldown() -> void:
	var progress = time_emplased / tracked_ability.COOLDOWN
	progress_bar.value = abs(1 - progress)


func stop_cooldown() -> void:
	is_on_cooldown     = false
	progress_bar.value = 0.0
	timer.stop()


func _on_timer_timeout() -> void:
	if is_on_cooldown:
		time_emplased += timer.wait_time
		update_cooldown()
		timer.start()
