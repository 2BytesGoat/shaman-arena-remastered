class_name AbilityButton extends Panel

@export var icon_rect: TextureRect
@export var progress_bar: TextureProgressBar

var _cooldown_total := 0.0
var _cooldown_elapsed := 0.0


func _ready() -> void:
	progress_bar.value = 0.0
	set_process(false)


func setup(ability: Ability) -> void:
	if ability is BaseAbility:
		icon_rect.texture = (ability as BaseAbility).ICON


func setup_empty() -> void:
	icon_rect.texture = null
	self_modulate = Color(1.0, 1.0, 1.0, 0.35)
	stop_cooldown()


func start_cooldown(runtime_ability: RuntimeAbility) -> void:
	_cooldown_total = maxf(runtime_ability.get_cooldown(), 0.001)
	_cooldown_elapsed = 0.0
	progress_bar.value = 1.0
	set_process(true)


func stop_cooldown() -> void:
	_cooldown_elapsed = 0.0
	progress_bar.value = 0.0
	set_process(false)


func _process(delta: float) -> void:
	_cooldown_elapsed += delta
	progress_bar.value = clampf(1.0 - _cooldown_elapsed / _cooldown_total, 0.0, 1.0)
