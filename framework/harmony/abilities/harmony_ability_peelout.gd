class_name HarmonyAbilityPeelOut
extends HarmonyAbility
## Super Peel Out (Sonic CD). Ver SPG:Special Abilities > Spindash (Sonic CD)
## — a mesma página descreve o Peel Out com a mecânica de "segurar N passos".
##
## Segure ↑ parado; depois de `charge_frames` (45) frames carregando, soltar
## ↑ lança o personagem correndo a `launch_speed` (12) px/frame. Soltar antes
## da hora não faz nada.
##
## É o exemplo MAIS SIMPLES de habilidade (gatilho por "segurar direção").
## Copie este arquivo como ponto de partida.

@export var charge_frames := 45
@export var launch_speed := 12.0

var charging := false
var frames := 0


func process_ground() -> bool:
	if body.rolling:
		_reset()
		return false

	if body.input_up and absf(body.ground_speed) < 0.5:
		if not charging:
			charging = true
			frames = 0
			set_state("peelout")
		frames += 1
		body.ground_speed = 0.0
		return true

	if charging:
		if frames >= charge_frames:
			body.ground_speed = launch_speed * float(body.facing)
		_reset()

	return false


func on_left_ground() -> void:
	_reset()


func on_enabled_changed(_is_enabled: bool) -> void:
	_reset()


func on_detached() -> void:
	_reset()


func _reset() -> void:
	charging = false
	frames = 0
	clear_state()
