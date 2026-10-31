class_name HarmonyAbilitySpeedShoes
extends HarmonyAbility
## Power-up por modificadores de stat (não mexe no profile; some ao desativar).
## Ative por código (`activate()`) ou pelo botão "speed_shoes" (tecla S): o botão
## é criado sozinho no InputMap (veja "Botão próprio" no Inspector).

@export var duration_frames := 600
@export var top_speed_mult := 2.0
@export var acceleration_mult := 2.0
@export var air_acceleration_mult := 2.0
@export var friction_mult := 2.0
@export var roll_friction_mult := 2.0
var frames_left := 0


func _init() -> void:
	button_name = "speed_shoes"
	button_key = KEY_S


func is_active() -> bool:
	return frames_left > 0


## frames < 0 usa `duration_frames`.
func activate(frames := -1) -> void:
	body.remove_mods(self)
	frames_left = duration_frames if frames < 0 else frames
	body.mod_mul_all(self, {
		"top_speed": top_speed_mult,
		"acceleration": acceleration_mult,
		"air_acceleration": air_acceleration_mult,
		"friction": friction_mult,
		"roll_friction": roll_friction_mult,
	})


func deactivate() -> void:
	frames_left = 0
	body.remove_mods(self)


func post_step() -> void:
	if frames_left > 0:
		frames_left -= 1
		if frames_left == 0:
			deactivate()
	if button_pressed():
		activate()


func on_enabled_changed(is_enabled: bool) -> void:
	if not is_enabled:
		deactivate()
