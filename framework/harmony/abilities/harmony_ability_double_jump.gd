class_name HarmonyAbilityDoubleJump
extends HarmonyAbility
## Double jump (hook on_air_jump_pressed). Depois de sair do chão, cada novo
## aperto de Pulo gasta um dos `extra_jumps`. Pousar devolve.

@export var extra_jumps := 1
## Impulso pra cima (px/frame), mesma unidade do jump_force.
@export var force := 6.0
## true = só vale depois de um pulo (não ao cair de plataforma).
@export var only_after_jump := false
## true = devolve o controle aéreo (útil depois de pulo rolando clássico).
@export var restore_air_control := true

var used := 0


func on_air_jump_pressed() -> bool:
	if used >= extra_jumps:
		return false
	if only_after_jump and not body.jumping:
		return false
	used += 1
	body.velocity.y = -force
	body.jumping = true
	if restore_air_control:
		body.rolling_jump = false
	return true


func on_landed() -> void:
	used = 0


func on_attached() -> void:
	used = 0


func on_enabled_changed(_is_enabled: bool) -> void:
	used = 0
