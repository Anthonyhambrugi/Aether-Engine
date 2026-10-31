class_name HarmonyAbilitySpindash
extends HarmonyAbility
## Spindash com dois modos de carga (escolha em `charge_mode`):
##
##   SPAM_JUMP      Sonic 2/3/K: ↓ + Pulo começa; cada novo Pulo soma carga,
##                  que decai sozinha (spinrev -= trunc(spinrev/0.125)/256).
##   HOLD_TO_CHARGE estilo Sonic CD: ↓ + Pulo UMA vez e é só esperar; a carga
##                  sobe sozinha até o máximo em `hold_frames_to_max`.
##                  (Aproximação: os números do modo CD não vêm do SPG,
##                  ajuste os exports até ficar com o feeling que quiser.)
##
## Nos dois: soltar ↓ lança rolando a base_speed + floor(spinrev) / 2.

enum ChargeMode { SPAM_JUMP, HOLD_TO_CHARGE }

@export var charge_mode: ChargeMode = ChargeMode.SPAM_JUMP
## Abaixo disso o personagem conta como "parado" pra poder começar.
@export var min_speed_to_start := 0.5
@export var base_speed := 8.0
@export var max_rev := 8.0

@export_group("Spam de pulo")
@export var rev_per_press := 2.0

@export_group("Esperar carregar (CD)")
## Frames segurando até a carga máxima (60 = 1 segundo).
@export var hold_frames_to_max := 60

var charging := false
var spinrev := 0.0


func on_jump_pressed() -> bool:
	# só chamado no chão, fora do carregamento (durante ele o core nem chega
	# no pulo — por isso o spam é lido em process_ground).
	if charging:
		return true
	if not body.rolling and body.input_down and absf(body.ground_speed) < min_speed_to_start:
		charging = true
		set_state("spindash")
		spinrev = minf(rev_per_press, max_rev) if charge_mode == ChargeMode.SPAM_JUMP else 0.0
		body.ground_speed = 0.0
		return true
	return false


func process_ground() -> bool:
	if not charging:
		return false

	if charge_mode == ChargeMode.SPAM_JUMP:
		if body.input_jump_pressed:
			spinrev = minf(spinrev + rev_per_press, max_rev)
		spinrev = maxf(spinrev - float(int(spinrev / 0.125)) / 256.0, 0.0)
	else:
		spinrev = minf(spinrev + max_rev / float(maxi(hold_frames_to_max, 1)), max_rev)
	body.ground_speed = 0.0

	if not body.input_down:
		body.ground_speed = (base_speed + floor(spinrev) / 2.0) * float(body.facing)
		body.force_roll(true)
		_reset()

	return true


func on_left_ground() -> void:
	_reset()


func on_enabled_changed(_is_enabled: bool) -> void:
	_reset()


func on_detached() -> void:
	_reset()


func _reset() -> void:
	charging = false
	spinrev = 0.0
	clear_state()
