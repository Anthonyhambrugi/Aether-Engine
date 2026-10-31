class_name HarmonyAbilityWallJump
extends HarmonyAbility
## Wall jump: no ar, encostado numa parede, apertar Pulo chuta o personagem
## pra longe dela e pra cima. Usa um sensor próprio (raio horizontal), então
## funciona mesmo sem estar empurrando a parede.
##
## Prioridade 10 por padrão: ganha do DoubleJump quando há parede por perto
## (se não houver, o Pulo passa pro DoubleJump normalmente).

## Velocidade horizontal do chute (px/frame), pra longe da parede.
@export var kick_speed := 4.0
## Velocidade vertical do chute (px/frame, pra cima).
@export var jump_speed := 6.0
## Folga além do push_radius pra considerar "encostado" (px).
@export var reach_margin := 2.0
## true = só pula se o direcional estiver apontando pra parede.
@export var require_holding_toward_wall := true
## Limite de wall jumps por tempo no ar. 0 = ilimitado.
@export var max_per_airtime := 0
@export var restore_air_control := true

var used := 0


func _init() -> void:
	priority = 10


func on_air_jump_pressed() -> bool:
	if max_per_airtime > 0 and used >= max_per_airtime:
		return false
	var side := _find_wall()
	if side == 0:
		return false
	if require_holding_toward_wall:
		if (side > 0 and not body.input_right) or (side < 0 and not body.input_left):
			return false
	used += 1
	body.velocity = Vector2(-side * kick_speed, -jump_speed)
	body.facing = -side
	body.jumping = true
	if restore_air_control:
		body.rolling_jump = false
	return true


## +1 = parede à direita, -1 = à esquerda, 0 = nenhuma.
func _find_wall() -> int:
	var reach: float = body.stats.push_radius + reach_margin
	for side in [1, -1]:
		var r: Dictionary = body._ray(body.global_position, Vector2(side, 0.0), reach)
		# ignora chão/rampa: só conta superfície bem vertical
		if not r.is_empty() and absf(r.normal.y) < 0.5:
			return side
	return 0


func on_landed() -> void:
	used = 0


func on_attached() -> void:
	used = 0


func on_enabled_changed(_is_enabled: bool) -> void:
	used = 0
