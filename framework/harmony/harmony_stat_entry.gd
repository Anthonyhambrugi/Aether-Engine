class_name HarmonyStatEntry
extends Resource
## Uma linha "stat + operação + valor", editável no Inspector (com dropdown).
## Usada pelo HarmonyPhysicsZone. Se você criar stats novos no HarmonyProfile,
## adicione o nome na lista do @export_enum abaixo.

enum Op { MULTIPLY, ADD, SET }

@export_enum("acceleration", "deceleration", "friction", "top_speed",
		"roll_friction", "roll_deceleration", "roll_min_speed", "unroll_speed",
		"roll_max_speed", "roll_slope_uphill", "roll_slope_downhill",
		"slope_factor", "slope_when_stopped", "slip_method", "slip_speed_threshold",
		"control_lock_frames", "air_acceleration", "gravity", "max_fall_speed",
		"jump_force", "jump_release", "jump_frame_delay", "rolling_jump_air_control",
		"width_radius", "height_radius", "roll_width_radius", "roll_height_radius",
		"push_radius") var stat := "gravity"
@export var op: Op = Op.MULTIPLY
## Pra stats bool (ex.: slope_when_stopped) use SET com 0 = false, 1 = true.
@export var value := 1.0


func mod_op() -> HarmonyStatMod.Op:
	match op:
		Op.ADD:
			return HarmonyStatMod.Op.ADD
		Op.SET:
			return HarmonyStatMod.Op.SET
	return HarmonyStatMod.Op.MULT
