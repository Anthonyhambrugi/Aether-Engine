extends HarmonyAbility
## MOLDE DE HABILIDADE (já funciona: é um dash no ar).
##
## COMO USAR
##   1. No painel FileSystem, duplique este arquivo (Ctrl+D) e renomeie,
##      ex.: harmony_ability_meu_dash.gd
##   2. (Opcional) tire o "#" da linha class_name abaixo e troque o nome.
##   3. Ative a habilidade de UM destes jeitos:
##        - arraste o script em "Ability Scripts" do .tres do personagem; ou
##        - adicione um Node filho do HarmonyBody e ponha este script nele; ou
##        - por código: body.add_ability(preload("caminho/do/arquivo.gd"))
##   4. Rode, pule e aperte X no ar.
##
## Tudo aqui é opcional: apague o que não for usar.
## Guia completo: docs/MODDING.md

# class_name HarmonyAbilityMeuDash

## Ajustes: aparecem no Inspector.
@export var dash_speed := 9.0
## Quantos frames dura o dash (60 frames = 1 segundo).
@export var dash_frames := 15

var _used := false  # só 1 dash por pulo; volta ao pousar


func _init() -> void:
	# Botão próprio. A ação "air_dash" é criada sozinha no InputMap.
	button_name = "air_dash"
	button_key = KEY_X
	button_joy = JOY_BUTTON_X


## NO AR, todo frame, antes da física. Devolva true se você cuida do frame
## inteiro (a física normal NÃO roda); false = a física normal continua.
func process_air() -> bool:
	if is_state("air_dash"):
		body.velocity.y = 0.0  # sem cair durante o dash
		if state_frames() >= dash_frames:
			clear_state()
		return false

	if not _used and button_pressed():
		_used = true
		body.velocity = Vector2(body.facing * dash_speed, 0.0)  # no AR mexa em velocity
		set_state("air_dash")  # o animator toca a animação "air_dash", se existir
	return false


func on_landed() -> void:
	_used = false
	clear_state()


func on_enabled_changed(_is_enabled: bool) -> void:
	_used = false


# ---------------------------------------------------------------------------
# OUTROS GANCHOS (descomente o que precisar; todos são opcionais)
# ---------------------------------------------------------------------------
# func process_ground() -> bool:        # NO CHÃO, todo frame, antes da física
#     return false                      # (no chão mexa em body.ground_speed)
#
# func on_jump_pressed() -> bool:       # pulo apertado no chão
#     return false                      # true = o pulo normal NÃO acontece
#
# func on_air_jump_pressed() -> bool:   # pulo apertado no ar (pulo duplo...)
#     return false                      # true = você usou o aperto
#
# func pre_step() -> void:              # todo frame, antes da física
#     pass
#
# func post_step() -> void:             # todo frame, depois da física
#     pass
#
# func on_jumped() -> void:             # acabou de pular
#     pass
#
# func on_left_ground() -> void:        # saiu do chão (caiu, pulou, rampa...)
#     pass
#
# func on_roll_changed(_rolling: bool) -> void:   # começou / parou de rolar
#     pass
#
# func on_wall_hit(_side: int) -> void: # bateu na parede (-1 esquerda, +1 direita)
#     pass
#
# func on_path_changed(_path_id: int) -> void:    # trocou de caminho A/B (loops)
#     pass
#
# func on_stats_changed() -> void:      # body.stats foi recalculado
#     pass
