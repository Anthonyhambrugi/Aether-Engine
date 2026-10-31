class_name HarmonyAbility
extends Node
## Classe base de uma habilidade "mod" do Harmony.
##
## COMO USAR (qualquer um dos 3 jeitos, sem editar harmony_body.gd):
##   1. Loadout no profile: arraste o script em `ability_scripts` do .tres
##      do personagem (o jeito mais simples — personagem = 1 arquivo).
##   2. Nó filho: adicione um Node com o script como FILHO DIRETO do
##      HarmonyBody na cena.
##   3. Código: `body.add_ability(MeuScript)` / `body.remove_ability(MeuScript)`.
##
## Ao entrar no corpo ela se registra sozinha em `body.abilities`
## (ordenada por `priority`, maior primeiro; empate = ordem dos nós).
## Todos os hooks abaixo são OPCIONAIS — sobrescreva só os que precisar.
## (Se sobrescrever _enter_tree/_exit_tree, chame super() — ou use
## on_attached/on_detached, que é mais fácil.)
##
## ───────────── hooks que podem TOMAR CONTROLE (devolvem bool) ─────────────
##   process_ground() -> bool      todo frame no chão, ANTES de qualquer
##                                 física. true = você cuida do frame todo.
##   process_air() -> bool         idem no ar.
##   on_jump_pressed() -> bool     Pulo apertado no CHÃO, antes do pulo padrão.
##                                 true = consome (o pulo padrão não acontece).
##   on_air_jump_pressed() -> bool Pulo apertado NO AR (double jump, insta-
##                                 shield, drop dash...). true = consome o
##                                 input; a física do frame continua normal.
##
## ───────────── hooks passivos (não retornam nada) ─────────────
##   on_attached() / on_detached()  entrou/saiu de um corpo (body já válido)
##   on_enabled_changed(bool)       `enabled` mudou — resete seu estado aqui
##   pre_step() / post_step()       antes/depois da física de TODO frame
##                                  (timers, cooldowns, ler input extra)
##   on_jumped() / on_landed() / on_left_ground() / on_roll_changed(bool)
##   on_wall_hit(side: int)         -1 esquerda / +1 direita; dispara a cada
##                                  frame em que a parede para/empurra o corpo
##   on_path_changed(path_id: int)  loop A/B trocou
##   on_stats_changed()             `body.stats` foi recalculado (mods/profile)
##
## ───────────── estado, animação e botão (texto simples) ─────────────
##   set_state("air_dash")   define o estado: o animator toca a animação
##                           "air_dash" sozinho (se existir no SpriteFrames)
##   clear_state()           volta ao normal
##   is_state("air_dash")  /  state_frames()  (frames desde que começou)
##   button_name = "dash"    botão próprio, criado sozinho no InputMap
##   button_pressed()  /  button_held()
## Guia: docs/MODDING.md. Molde: abilities/harmony_ability_template.gd.
##
## `body` é preenchido automaticamente antes de qualquer hook.
## Pra mexer em física temporariamente use body.mod_mul/mod_add/mod_set
## (cuidado: NÃO escreva em body.profile, ele é a base compartilhada).

## Desligada = o corpo ignora todos os hooks (e on_enabled_changed(false)
## é chamado pra você limpar o estado).
@export var enabled := true:
	set(value):
		if enabled == value:
			return
		enabled = value
		if body != null:
			if not value:
				clear_state()  # desligar também desliga o estado dela
			on_enabled_changed(value)

## Maior roda primeiro. Quando duas habilidades disputam o mesmo hook
## bool, a de maior prioridade que devolver true "ganha".
@export var priority := 0:
	set(value):
		priority = value
		if body != null:
			body._sort_abilities()

@export_group("Botão próprio (opcional)")
## Nome do botão (ex.: "dash"). Vazio = a habilidade não tem botão próprio.
## Se esse botão ainda não existir no InputMap, ele é criado sozinho com a
## tecla / botão de controle abaixo.
@export var button_name := ""
@export var button_key: Key = KEY_NONE
@export var button_joy: JoyButton = JOY_BUTTON_INVALID
@export_group("")

var body: HarmonyBody


func _enter_tree() -> void:
	ensure_button(button_name, button_key, button_joy)
	var parent := get_parent()
	if parent is HarmonyBody:
		parent._register_ability(self)
	else:
		push_warning("HarmonyAbility '%s' precisa ser filho DIRETO de um HarmonyBody (ou use body.add_ability)." % name)


func _exit_tree() -> void:
	if body != null and is_instance_valid(body):
		body._unregister_ability(self)


# --- controle ---------------------------------------------------------

func process_ground() -> bool:
	return false


func process_air() -> bool:
	return false


func on_jump_pressed() -> bool:
	return false


func on_air_jump_pressed() -> bool:
	return false


# --- passivos ---------------------------------------------------------

func on_attached() -> void:
	pass


func on_detached() -> void:
	pass


func on_enabled_changed(_is_enabled: bool) -> void:
	pass


func pre_step() -> void:
	pass


func post_step() -> void:
	pass


func on_jumped() -> void:
	pass


func on_landed() -> void:
	pass


func on_left_ground() -> void:
	pass


func on_roll_changed(_rolling: bool) -> void:
	pass


func on_wall_hit(_side: int) -> void:
	pass


func on_path_changed(_path_id: int) -> void:
	pass


func on_stats_changed() -> void:
	pass


# --- estado e animação (texto simples) -----------------------------------

## Define o estado desta habilidade. O animator toca a animação de MESMO NOME
## (ou `animation`, se você passar outra). Ex.: set_state("air_dash")
func set_state(state_name: String, animation := "") -> void:
	if body != null:
		body.set_custom_state(state_name, self, animation)


## Limpa o estado (só se ele ainda for desta habilidade).
func clear_state() -> void:
	if body != null:
		body.clear_custom_state(self)


func is_state(state_name: String) -> bool:
	return body != null and body.custom_state == state_name


## Frames desde que o estado atual começou (0 no frame em que começou).
func state_frames() -> int:
	return body.custom_state_frames if body != null else 0


# --- botão próprio -------------------------------------------------------

## Apertou o botão neste frame? (false se `button_name` estiver vazio)
func button_pressed() -> bool:
	return button_name != "" and body != null and body.action_pressed(button_name)


## Está segurando o botão?
func button_held() -> bool:
	return button_name != "" and body != null and body.action_held(button_name)


## Cria o botão no InputMap se ele ainda não existir. Já é chamado sozinho
## quando a habilidade entra no corpo; use direto só se precisar de um botão
## fora de habilidades.
static func ensure_button(button: String, key: Key = KEY_NONE, joy: JoyButton = JOY_BUTTON_INVALID) -> void:
	if button == "" or InputMap.has_action(button):
		return
	InputMap.add_action(button)
	if key != KEY_NONE:
		var ev := InputEventKey.new()
		ev.physical_keycode = key
		InputMap.action_add_event(button, ev)
	if joy != JOY_BUTTON_INVALID:
		var jb := InputEventJoypadButton.new()
		jb.button_index = joy
		InputMap.action_add_event(button, jb)
