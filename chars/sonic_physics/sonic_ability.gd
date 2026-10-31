class_name SonicAbility
extends Node
## Base para habilidades do Sonic. Adicione um filho deste tipo ao SonicPlayer e ele é registrado sozinho.
## Sobrescreva só os ganchos que precisar. Retornar true em ground_step/air_step
## significa "eu cuidei deste frame", e o player pula a física normal.
##
## Exemplo mínimo:
##   class_name SonicPeelOut extends SonicAbility
##   func ground_step() -> bool:
##       if player.input_up and player.jump_pressed: ...
##       return false

@export var enabled := true

var player: SonicPlayer


## Chamado uma vez quando o player fica pronto (player já está preenchido).
func _ability_ready() -> void:
	pass


## No chão, depois de calcular crouch/look_up e antes do fator de ladeira e do pulo.
func ground_step() -> bool:
	return false


## No começo do passo aéreo (antes de input, gravidade e movimento).
func air_step() -> bool:
	return false


## No chão, quando o jogador apertou pulo, antes do pulo normal. true = consumiu o pulo.
func try_jump() -> bool:
	return false


func on_landed() -> void:
	pass


func on_hurt() -> void:
	pass


## O player pede pra habilidade cancelar o que estiver fazendo (morte, troca de config, etc.).
func interrupt() -> void:
	pass
