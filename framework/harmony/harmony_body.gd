class_name HarmonyBody
extends Node2D
## Corpo do Harmony: física estilo Sonic (Mega Drive) sem CharacterBody2D.
##
## Segue a ordem de execução de SPG:Main Game Loop:
##   CHÃO: fator de ladeira -> pulo -> input/fricção -> sensores de empurrar
##         -> checa rolar -> move -> sensores do chão -> slip/queda
##   AR:   pulo variável -> input -> air drag -> move -> gravidade
##         -> sensores (paredes, depois teto/chão)
##
## Unidades: px/frame, 60 ticks de física por segundo.
##
## MODDING (ver docs/MODDING.md):
##   - `profile`  = física BASE (Resource, compartilhado, não escreva nele).
##   - `stats`    = física EFETIVA deste corpo (base + modificadores). É o
##                  que o código de física lê. Mude via add_mod/mod_mul/...
##   - habilidades = nós HarmonyAbility (loadout do profile, filhos, ou
##                  add_ability) com hooks no ciclo — sem editar este arquivo.
##
## Convenção de ângulo (Godot, y pra baixo; o SPG usa o sentido oposto):
##   ground_angle = 0  -> chão plano
##   ground_angle > 0  -> superfície descendo pra direita
##   ground_angle < 0  -> superfície subindo pra direita

signal landed
signal jumped
signal left_ground
signal roll_changed(is_rolling: bool)
signal ability_added(ability: HarmonyAbility)
signal ability_removed(ability: HarmonyAbility)
## `stats` foi recalculado (mod adicionado/removido, profile trocado/editado).
signal stats_changed
## O estado de habilidade (custom_state) mudou. "" = nenhum.
signal custom_state_changed(old_state: String, new_state: String)

enum State { GROUND, AIR }
enum Mode { FLOOR, RIGHT_WALL, CEILING, LEFT_WALL }
enum Quad { UP, RIGHT, DOWN, LEFT }

## Distância máxima (px) que o sensor do chão "gruda" (SPG:Slope Collision).
const SNAP_MAX := 14.0
## Ângulo visual volta pra 0 a 2.8125° por frame no ar (só visual).
const VISUAL_ANGLE_STEP := 0.04908738521

## Física BASE do personagem (+ loadout de habilidades). Pode ser trocado em
## runtime (`body.profile = outro`) pra trocar de personagem inteiro.
@export var profile: HarmonyProfile:
	set(value):
		if profile != null and profile.changed.is_connected(_on_profile_changed):
			profile.changed.disconnect(_on_profile_changed)
		profile = value
		if profile != null:
			profile.changed.connect(_on_profile_changed)
		if _ready_done:
			_apply_profile()
@export_flags_2d_physics var common_mask := 1
@export_flags_2d_physics var path_a_mask := 2
@export_flags_2d_physics var path_b_mask := 4
## false = você escreve os input_* (IA do Tails, testes, replays).
@export var use_player_input := true
@export var debug_draw := true

@export_group("Input")
@export var action_left: StringName = "ui_left"
@export var action_right: StringName = "ui_right"
@export var action_up: StringName = "ui_up"
@export var action_down: StringName = "ui_down"
@export var action_jump: StringName = "A"

# --- input (lido de Input ou escrito por fora) ---
var input_left := false
var input_right := false
var input_up := false
var input_down := false
var input_jump_pressed := false  # só vale por 1 frame
var input_jump_held := false

# --- estado ---
var state: State = State.AIR
var velocity := Vector2.ZERO  # px/frame
var ground_speed := 0.0
var ground_angle := 0.0  # radianos (convenção acima)
var visual_angle := 0.0  # use isso pra girar o sprite
var control_lock := 0
var facing := 1
var rolling := false
var jumping := false
var rolling_jump := false  # sem controle aéreo
var current_path := 0  # 0 = caminho A, 1 = caminho B

## Estado de habilidade em TEXTO SIMPLES (ex.: "spindash", "air_dash"); "" = nenhum.
## Quem escreve é a habilidade, com set_state()/clear_state() (harmony_ability.gd).
## O animator toca sozinho a animação de MESMO NOME. Aqui você só lê.
var custom_state := ""
## Animação específica do estado (vazio = usa o próprio nome do estado).
var custom_state_animation := ""
## Frames desde que o estado atual começou (0 no frame em que começou).
var custom_state_frames := 0

## Velocidade pra ANIMAÇÃO, com sinal, atualizada todo frame (antes do post_step).
##   x: no chão = ground_speed (ao longo da superfície); no ar = velocity.x
##   y: velocity.y (positivo = descendo), no chão e no ar
## Use absf() pra velocidade de passada/rolagem; o sinal diz o lado (x) e
## se está subindo/descendo (y).
var anim_speed := Vector2.ZERO

## Toda HarmonyAbility filha direta é registrada aqui automaticamente (ver
## _ready). O core chama esses hooks nos pontos certos do ciclo pra permitir
## mods/novas habilidades sem tocar neste arquivo — veja harmony_ability.gd.
var abilities: Array[HarmonyAbility] = []

## Física EFETIVA (profile + modificadores). O core lê só daqui.
var stats := HarmonyProfile.new()

## Input "extra" pra habilidades com botões próprios (ataque, habilidade
## especial...). Com use_player_input = true lê o InputMap; com false (IA,
## replay, testes) escreva `extra_pressed["acao"] = true` (vale 1 frame) /
## `extra_held["acao"] = true`. Habilidades usam action_pressed()/action_held().
var extra_pressed := {}
var extra_held := {}

const _FROM_PROFILE_META := "harmony_from_profile"

var _mods: Array[HarmonyStatMod] = []
var _ready_done := false
var _stats_built := false
var _dbg: Array = []
var _custom_state_source: Object = null


class Sense:
	var found := false
	var gap := 0.0  # distância pé -> superfície (negativo = enterrado)
	var normal := Vector2.ZERO


func _enter_tree() -> void:
	# stats prontos ANTES das habilidades-filhas entrarem (elas entram depois).
	if profile == null:
		profile = HarmonyProfile.new()
	_rebuild_stats()


func _ready() -> void:
	# habilidades-filhas já se registraram sozinhas no _enter_tree delas.
	_spawn_profile_abilities()
	_ready_done = true


func _physics_process(_delta: float) -> void:
	if use_player_input:
		_read_player_input()
	_dbg.clear()
	_notify("pre_step")
	if state == State.GROUND:
		_step_ground()
	else:
		_step_air()
	_update_visual_angle()
	_update_anim_speed()
	_notify("post_step")
	if custom_state != "":
		custom_state_frames += 1
	input_jump_pressed = false
	extra_pressed.clear()
	queue_redraw()


func set_path(path_id: int) -> void:
	if current_path == path_id:
		return
	current_path = path_id
	_notify_arg("on_path_changed", path_id)


# =============================================================== INPUT

func _read_player_input() -> void:
	input_left = Input.is_action_pressed(action_left)
	input_right = Input.is_action_pressed(action_right)
	input_up = Input.is_action_pressed(action_up)
	input_down = Input.is_action_pressed(action_down)
	input_jump_pressed = Input.is_action_just_pressed(action_jump)
	input_jump_held = Input.is_action_pressed(action_jump)


## Botão "extra" apertado neste frame (pra habilidades). Respeita
## use_player_input (ver extra_pressed). Ação inexistente = false.
func action_pressed(action: StringName) -> bool:
	if use_player_input:
		return InputMap.has_action(action) and Input.is_action_just_pressed(action)
	return extra_pressed.get(action, false) or extra_pressed.get(String(action), false)


func action_held(action: StringName) -> bool:
	if use_player_input:
		return InputMap.has_action(action) and Input.is_action_pressed(action)
	return extra_held.get(action, false) or extra_held.get(String(action), false)


# ================================================================ CHÃO

func _step_ground() -> void:
	var p := stats

	# 0. ganchos de habilidades: uma ability pode assumir o frame inteiro
	# (ex.: carregando um spindash) devolvendo true.
	if _any("process_ground"):
		return

	# 1. fator de ladeira (pseudo-gravidade)
	_apply_slope_factor()

	# 2. pulo (sai do resto do ciclo)
	if input_jump_pressed and _can_jump():
		if not _any("on_jump_pressed"):
			_do_jump()
			if not p.jump_frame_delay:
				input_jump_pressed = false  # não conta de novo como pulo no ar
				_step_air()
			return

	# 3. input + fricção
	if rolling:
		_roll_input()
	else:
		_walk_input()

	# 4. velocidade X/Y a partir da ground speed
	velocity = Vector2.RIGHT.rotated(ground_angle) * ground_speed

	# 5. sensores de empurrar (antes de mover)
	_ground_push()

	# 6. checa começar a rolar
	_check_start_roll()

	# 7. mover
	global_position += velocity

	# 8. sensores do chão
	if not _ground_snap():
		return

	# 9. slip / queda
	_check_slip()


func _apply_slope_factor() -> void:
	var p := stats
	if _mode() == Mode.CEILING:
		return
	var s := sin(ground_angle)
	var f := p.slope_factor
	if rolling:
		f = p.roll_slope_uphill if ground_speed * s < 0.0 else p.roll_slope_downhill
	elif ground_speed == 0.0:
		if not p.slope_when_stopped or absf(f * s) < 0.05078125:
			return
	ground_speed += f * s


func _walk_input() -> void:
	var p := stats
	if control_lock == 0:
		if input_left:
			if ground_speed > 0.0:
				ground_speed -= p.deceleration
				if ground_speed <= 0.0:
					ground_speed = -0.5
			elif ground_speed > -p.top_speed:
				ground_speed -= p.acceleration
				if ground_speed <= -p.top_speed:
					ground_speed = -p.top_speed
			facing = -1
		if input_right:
			if ground_speed < 0.0:
				ground_speed += p.deceleration
				if ground_speed >= 0.0:
					ground_speed = 0.5
			elif ground_speed < p.top_speed:
				ground_speed += p.acceleration
				if ground_speed >= p.top_speed:
					ground_speed = p.top_speed
			facing = 1
	# fricção só age sem direcional pressionado (vale também no control lock)
	if not input_left and not input_right:
		ground_speed -= minf(absf(ground_speed), p.friction) * signf(ground_speed)


func _roll_input() -> void:
	var p := stats
	if control_lock == 0:
		if input_left:
			if ground_speed > 0.0:
				ground_speed -= p.roll_deceleration
				if ground_speed <= 0.0:
					ground_speed = -0.5
			facing = -1
		if input_right:
			if ground_speed < 0.0:
				ground_speed += p.roll_deceleration
				if ground_speed >= 0.0:
					ground_speed = 0.5
			facing = 1
	# rolando não acelera; a fricção sempre age
	ground_speed -= minf(absf(ground_speed), p.roll_friction) * signf(ground_speed)
	if p.roll_max_speed > 0.0:
		ground_speed = clampf(ground_speed, -p.roll_max_speed, p.roll_max_speed)
	if absf(ground_speed) < p.unroll_speed:
		_set_rolling(false)


func _check_start_roll() -> void:
	## SPG:Rolling > Criteria: só exige Down pressionado e velocidade mínima;
	## segurar esquerda/direita ao mesmo tempo não impede rolar.
	if rolling or not input_down:
		return
	if absf(ground_speed) < stats.roll_min_speed:
		return
	_set_rolling(true)


func _set_rolling(value: bool) -> void:
	if rolling == value:
		return
	var diff := stats.height_radius - stats.roll_height_radius
	# mantém os pés no chão ao trocar de raio
	global_position += _down() * (diff if value else -diff)
	rolling = value
	roll_changed.emit(value)
	_notify_arg("on_roll_changed", value)


## API pública pra habilidades: forçar entrar/sair do estado de rolar sem
## depender do gatilho padrão (Down + velocidade mínima). Ex.: spindash.
func force_roll(value: bool) -> void:
	_set_rolling(value)


func _can_jump() -> bool:
	# SPG: se o teto está a menos de 6px, o pulo nem acontece.
	var s := _sense_pair(-_down(), _right(), _hr() + 6.0)
	return not (s.found and s.gap < 6.0)


func _do_jump() -> void:
	var p := stats
	var a := ground_angle
	velocity += Vector2(sin(a), -cos(a)) * p.jump_force
	if not rolling:
		# vira "bola" (raios menores) sem descolar os pés do chão
		global_position += _down() * (p.height_radius - p.roll_height_radius)
	rolling_jump = rolling and not p.rolling_jump_air_control
	jumping = true
	state = State.AIR
	ground_angle = 0.0
	jumped.emit()
	_notify("on_jumped")


func _ground_push() -> void:
	# SPG:Slope Collision > Push Sensors. Só com ground speed != 0 e ângulo
	# entre -90° e 90°. O offset da velocidade evita atravessar a parede.
	if ground_speed == 0.0 or absf(ground_angle) > PI * 0.5 + 0.0001:
		return
	var dir := _right() * signf(ground_speed)
	var origin := global_position
	if absf(ground_angle) < 0.0001:
		origin += _down() * 8.0  # no plano, o sensor desce 8px
	var reach := stats.push_radius + maxf(velocity.dot(dir), 0.0)
	var r := _ray(origin, dir, reach)
	if r.is_empty():
		return
	var d := origin.distance_to(r.position)
	var side := int(signf(ground_speed))
	velocity -= dir * (reach - d)
	ground_speed = 0.0
	_notify_arg("on_wall_hit", side)


func _ground_snap() -> bool:
	## Sensores A/B: vence o de menor distância (empate = A).
	## Sonic 2+: distância válida entre -14 e min(|velocidade|+4, 14).
	var down := _down()
	var right := _right()
	var s := _sense_pair(down, right, _hr() + SNAP_MAX)
	var max_gap := minf(absf(velocity.dot(right)) + 4.0, SNAP_MAX)
	if not s.found or s.gap > max_gap:
		_leave_ground()
		return false
	if s.gap < -SNAP_MAX:
		return true  # enterrado demais: ignora (não corrige)
	global_position += down * s.gap
	ground_angle = _angle_from_normal(s.normal, ground_angle)
	return true


func _check_slip() -> void:
	var p := stats
	if control_lock > 0:
		control_lock -= 1
		return
	if absf(ground_speed) >= p.slip_speed_threshold:
		return
	var ad := absf(rad_to_deg(ground_angle))
	if p.slip_method == HarmonyProfile.SlipMethod.SONIC_1_2_CD:
		if ad > 45.0:
			ground_speed = 0.0
			control_lock = p.control_lock_frames
			_leave_ground()
	else:
		if ad >= 33.75:  # slip: 0x18..0xE7
			control_lock = p.control_lock_frames
			if ad >= 67.5:  # queda: 0x30..0xD0
				_leave_ground()
			else:
				ground_speed += 0.5 * signf(sin(ground_angle))


func _leave_ground() -> void:
	state = State.AIR
	ground_angle = 0.0
	left_ground.emit()
	_notify("on_left_ground")


func _become_grounded() -> void:
	## Cauda comum de qualquer pouso (chão ou teto/parede íngreme).
	var p := stats
	var was_ball := jumping or rolling
	state = State.GROUND
	jumping = false
	rolling = false
	rolling_jump = false
	if was_ball:
		global_position -= _down() * (p.height_radius - p.roll_height_radius)
	velocity = Vector2.RIGHT.rotated(ground_angle) * ground_speed
	landed.emit()
	_notify("on_landed")


# ================================================================== AR

func _step_air() -> void:
	var p := stats

	# 0. ganchos de habilidades (ex.: drop dash carregando no ar).
	if _any("process_air"):
		return

	# 1. pulo variável (antes de mover e aplicar gravidade)
	if jumping and not input_jump_held and velocity.y < -p.jump_release:
		velocity.y = -p.jump_release

	# 1.5 pulo apertado no ar (double jump, insta-shield...). Depois do corte
	# do pulo variável de propósito: a velocidade que a habilidade definir não
	# é cortada no mesmo frame. A física do frame segue normalmente.
	if input_jump_pressed:
		_any("on_air_jump_pressed")

	# 2. input aéreo (limitado pela top speed)
	if not rolling_jump:
		if input_left:
			if velocity.x > -p.top_speed:
				velocity.x -= p.air_acceleration
				if velocity.x <= -p.top_speed:
					velocity.x = -p.top_speed
			facing = -1
		if input_right:
			if velocity.x < p.top_speed:
				velocity.x += p.air_acceleration
				if velocity.x >= p.top_speed:
					velocity.x = p.top_speed
			facing = 1

	# 3. air drag (subindo devagar): xsp -= trunc(xsp / 0.125) / 256
	if velocity.y < 0.0 and velocity.y > -4.0 and absf(velocity.x) >= 0.125:
		velocity.x -= float(int(velocity.x / 0.125)) / 256.0

	# 4. mover
	global_position += velocity

	# 5. gravidade (depois de mover, antes das colisões)
	velocity.y += p.gravity
	if p.max_fall_speed > 0.0:
		velocity.y = minf(velocity.y, p.max_fall_speed)

	# 6. colisões
	_air_collisions()


func _air_quadrant() -> Quad:
	if absf(velocity.y) >= absf(velocity.x):
		return Quad.UP if velocity.y < 0.0 else Quad.DOWN
	return Quad.RIGHT if velocity.x > 0.0 else Quad.LEFT


func _air_collisions() -> void:
	var q := _air_quadrant()
	_air_walls(q)
	if q != Quad.DOWN:
		if _air_ceiling(q):
			return
	_air_ground(q)


func _air_walls(q: Quad) -> void:
	var sides: Array[float] = []
	match q:
		Quad.UP, Quad.DOWN:
			sides = [-1.0, 1.0]
		Quad.RIGHT:
			sides = [1.0]
		Quad.LEFT:
			sides = [-1.0]
	var pr := stats.push_radius
	for side in sides:
		var r := _ray(global_position, Vector2(side, 0.0), pr)
		if r.is_empty():
			continue
		var d := global_position.distance_to(r.position)
		if d < pr:
			global_position.x -= side * (pr - d)
			if velocity.x * side > 0.0:
				velocity.x = 0.0
			_notify_arg("on_wall_hit", int(side))


func _air_ceiling(q: Quad) -> bool:
	var s := _sense_pair(Vector2.UP, Vector2.RIGHT, _hr())
	if not s.found or s.gap >= 0.0:
		return false
	global_position += Vector2.DOWN * (-s.gap)
	var a := _angle_from_normal(s.normal, PI)
	var ad := absf(rad_to_deg(a))
	# teto/parede íngreme (45°..135°) subindo: gruda nele (SPG:Slope Physics)
	if q == Quad.UP and ad >= 45.0 and ad < 135.0 and velocity.y < 0.0:
		ground_angle = a
		ground_speed = velocity.y * signf(sin(a))
		_become_grounded()
		return true
	if velocity.y < 0.0:
		velocity.y = 0.0
	return false


func _air_ground(q: Quad) -> bool:
	if q == Quad.UP:
		return false
	if q != Quad.DOWN and velocity.y < 0.0:
		return false
	var s := _sense_pair(Vector2.DOWN, Vector2.RIGHT, _hr())
	if not s.found or s.gap >= 0.0:
		return false
	if q == Quad.DOWN and s.gap < -(velocity.y + 8.0):
		return false
	global_position += Vector2.DOWN * s.gap
	var a := _angle_from_normal(s.normal, 0.0)
	var ad := absf(rad_to_deg(a))
	if q != Quad.DOWN or ad <= 22.5:
		ground_speed = velocity.x  # plano (ou movendo na horizontal)
	elif ad <= 45.0:
		ground_speed = velocity.y * 0.5 * signf(sin(a))
	else:
		ground_speed = velocity.y * signf(sin(a))
	ground_angle = a
	_become_grounded()
	return true


# ======================================================= ESTADO DE HABILIDADE
# Um "estado de habilidade" é só um TEXTO ("spindash", "air_dash"...). O
# animator toca sozinho a animação de MESMO NOME. Dentro de uma habilidade use
# set_state()/clear_state() (harmony_ability.gd): elas chamam estas aqui.

## Define o estado. `source` é quem definiu (a habilidade): só ele consegue
## limpar depois. `animation` é opcional (vazio = usa o nome do estado).
func set_custom_state(state_name: String, source: Object = null, animation := "") -> void:
	if custom_state == state_name:
		_custom_state_source = source
		custom_state_animation = animation
		return
	var old := custom_state
	custom_state = state_name
	custom_state_animation = animation
	custom_state_frames = 0
	_custom_state_source = source
	custom_state_changed.emit(old, state_name)


## Limpa o estado. Se `source` for passado, só limpa se foi ele quem definiu
## (assim uma habilidade nunca apaga o estado de outra).
func clear_custom_state(source: Object = null) -> void:
	if custom_state == "":
		return
	if source != null and source != _custom_state_source:
		return
	var old := custom_state
	custom_state = ""
	custom_state_animation = ""
	custom_state_frames = 0
	_custom_state_source = null
	custom_state_changed.emit(old, "")


func is_custom_state(state_name: String) -> bool:
	return custom_state == state_name


# ============================================================ HABILIDADES
# API pública (ver docs/MODDING.md). O registro é automático: qualquer
# HarmonyAbility que entra como filho direto deste corpo vira parte de
# `abilities` (ver HarmonyAbility._enter_tree).

## Adiciona uma habilidade. Aceita um Script (que extende HarmonyAbility),
## uma PackedScene ou um nó HarmonyAbility já criado. Devolve a instância.
func add_ability(what: Variant) -> HarmonyAbility:
	var a: HarmonyAbility = null
	if what is HarmonyAbility:
		a = what
	elif what is Script or what is PackedScene:
		var inst: Variant = what.new() if what is Script else what.instantiate()
		if inst is HarmonyAbility:
			a = inst
			if what is Script and what.resource_path != "":
				a.name = what.resource_path.get_file().get_basename().to_pascal_case()
		else:
			push_error("add_ability: %s não é uma HarmonyAbility." % str(what))
			if inst is Node:
				inst.free()
			return null
	else:
		push_error("add_ability: passe um Script, PackedScene ou HarmonyAbility.")
		return null
	if a.get_parent() == null:
		add_child(a)  # o _enter_tree dela se registra
	elif a.get_parent() != self:
		push_error("add_ability: a habilidade já pertence a outro nó.")
		return null
	return a


## Remove (e libera) uma habilidade: passe a instância ou o Script (remove
## todas as instâncias daquele script). Devolve true se removeu algo.
func remove_ability(what: Variant) -> bool:
	var removed := false
	for a in abilities.duplicate():
		if a == what or (what is Script and is_instance_of(a, what)):
			a.get_parent().remove_child(a)  # dispara o _exit_tree -> unregister
			a.queue_free()
			removed = true
	return removed


## Primeira habilidade daquele Script (ou subclasse), ou null.
func get_ability(script: Script) -> HarmonyAbility:
	for a in abilities:
		if is_instance_of(a, script):
			return a
	return null


func has_ability(script: Script) -> bool:
	return get_ability(script) != null


func _register_ability(a: HarmonyAbility) -> void:
	if abilities.has(a):
		return
	a.body = self
	abilities.append(a)
	_sort_abilities()
	a.on_attached()
	ability_added.emit(a)


func _unregister_ability(a: HarmonyAbility) -> void:
	if not abilities.has(a):
		return
	abilities.erase(a)
	remove_mods(a)  # mods aplicados por ela somem junto
	clear_custom_state(a)  # o estado dela também
	a.on_detached()
	a.body = null
	ability_removed.emit(a)


func _sort_abilities() -> void:
	abilities.sort_custom(_ability_before)


static func _ability_before(a: HarmonyAbility, b: HarmonyAbility) -> bool:
	if a.priority != b.priority:
		return a.priority > b.priority
	return a.get_index() < b.get_index()


## Chama o hook em cada habilidade ligada, em ordem de prioridade; devolve
## true assim que uma devolver true (ela "ganha", as outras nem são chamadas).
func _any(hook: StringName) -> bool:
	for a in abilities.duplicate():
		if a.enabled and a.call(hook):
			return true
	return false


func _notify(hook: StringName) -> void:
	for a in abilities.duplicate():
		if a.enabled:
			a.call(hook)


func _notify_arg(hook: StringName, arg: Variant) -> void:
	for a in abilities.duplicate():
		if a.enabled:
			a.call(hook, arg)


func _spawn_profile_abilities() -> void:
	if profile == null:
		return
	for script in profile.ability_scripts:
		if script == null or has_ability(script):
			continue  # já existe (ex.: colocada como nó na cena)
		var a := add_ability(script)
		if a != null:
			a.set_meta(_FROM_PROFILE_META, true)


func _apply_profile() -> void:
	# troca de personagem: tira o loadout antigo, recalcula, põe o novo.
	for a in abilities.duplicate():
		if a.has_meta(_FROM_PROFILE_META):
			remove_ability(a)
	_rebuild_stats()
	_spawn_profile_abilities()


# ================================================================== STATS
# `stats` = profile + modificadores. Reconstruído sempre que algo muda, então
# o core nunca paga custo por frame.

func _on_profile_changed() -> void:
	_rebuild_stats()


## Recalcula `stats` agora (útil se você editou `profile` por script).
func refresh_stats() -> void:
	_rebuild_stats()


## Adiciona um modificador. Devolve ele (guarde se quiser remover só esse
## depois com remove_mod) ou null se o nome do stat não existir.
func add_mod(source: Variant, stat: StringName, op: HarmonyStatMod.Op, value: Variant, priority := 0) -> HarmonyStatMod:
	var m := _push_mod(source, stat, op, value, priority)
	if m != null:
		_rebuild_stats()
	return m


func mod_mul(source: Variant, stat: StringName, factor: float, priority := 0) -> HarmonyStatMod:
	return add_mod(source, stat, HarmonyStatMod.Op.MULT, factor, priority)


func mod_add(source: Variant, stat: StringName, amount: float, priority := 0) -> HarmonyStatMod:
	return add_mod(source, stat, HarmonyStatMod.Op.ADD, amount, priority)


func mod_set(source: Variant, stat: StringName, value: Variant, priority := 0) -> HarmonyStatMod:
	return add_mod(source, stat, HarmonyStatMod.Op.SET, value, priority)


## Vários de uma vez ({stat: fator}) com um único recálculo.
func mod_mul_all(source: Variant, factors: Dictionary) -> void:
	for stat in factors:
		_push_mod(source, StringName(stat), HarmonyStatMod.Op.MULT, factors[stat], 0)
	_rebuild_stats()


func mod_add_all(source: Variant, amounts: Dictionary) -> void:
	for stat in amounts:
		_push_mod(source, StringName(stat), HarmonyStatMod.Op.ADD, amounts[stat], 0)
	_rebuild_stats()


func mod_set_all(source: Variant, values: Dictionary) -> void:
	for stat in values:
		_push_mod(source, StringName(stat), HarmonyStatMod.Op.SET, values[stat], 0)
	_rebuild_stats()


## Remove todos os mods daquela fonte. Devolve quantos removeu.
func remove_mods(source: Variant) -> int:
	var kept: Array[HarmonyStatMod] = []
	for m in _mods:
		if m.source != source:
			kept.append(m)
	var removed := _mods.size() - kept.size()
	_mods = kept
	if removed > 0:
		_rebuild_stats()
	return removed


func remove_mod(mod: HarmonyStatMod) -> void:
	if _mods.has(mod):
		_mods.erase(mod)
		_rebuild_stats()


func has_mods(source: Variant) -> bool:
	for m in _mods:
		if m.source == source:
			return true
	return false


func clear_mods() -> void:
	if not _mods.is_empty():
		_mods.clear()
		_rebuild_stats()


func _push_mod(source: Variant, stat: StringName, op: HarmonyStatMod.Op, value: Variant, priority: int) -> HarmonyStatMod:
	if not HarmonyProfile.has_stat(stat):
		push_error("Harmony: stat '%s' não existe. Stats válidos: %s" % [stat, ", ".join(HarmonyProfile.stat_names())])
		return null
	var m := HarmonyStatMod.new(source, stat, op, value, priority)
	_mods.append(m)
	return m


func _rebuild_stats() -> void:
	var base := profile if profile != null else HarmonyProfile.new()
	var old_hr := _hr() if _stats_built else 0.0
	stats.copy_from(base)

	var by_stat := {}
	for m in _mods:
		if not by_stat.has(m.stat):
			by_stat[m.stat] = []
		by_stat[m.stat].append(m)
	for stat in by_stat:
		stats.set(stat, _combine(base.get(stat), by_stat[stat]))

	# se o raio mudou com o personagem no chão, mantém os pés no mesmo lugar
	if _stats_built and state == State.GROUND:
		global_position += _down() * (old_hr - _hr())
	_stats_built = true
	stats_changed.emit()
	_notify("on_stats_changed")


static func _combine(base: Variant, mods: Array) -> Variant:
	var numeric := typeof(base) == TYPE_FLOAT or typeof(base) == TYPE_INT
	var add := 0.0
	var mult := 1.0
	var set_mod: HarmonyStatMod = null
	for m: HarmonyStatMod in mods:
		match m.op:
			HarmonyStatMod.Op.ADD:
				add += float(m.value)
			HarmonyStatMod.Op.MULT:
				mult *= float(m.value)
			HarmonyStatMod.Op.SET:
				if set_mod == null or m.priority >= set_mod.priority:
					set_mod = m
	if set_mod != null:
		match typeof(base):
			TYPE_BOOL:
				return bool(set_mod.value)
			TYPE_INT:
				return int(set_mod.value)
		return set_mod.value
	if not numeric:
		return base  # bool: ADD/MULT não se aplicam
	var v := (float(base) + add) * mult
	return int(roundf(v)) if typeof(base) == TYPE_INT else v


# ============================================================== SENSORES

func _mask() -> int:
	return common_mask | (path_a_mask if current_path == 0 else path_b_mask)


func _is_ball() -> bool:
	return rolling or jumping


func _wr() -> float:
	return stats.roll_width_radius if _is_ball() else stats.width_radius


func _hr() -> float:
	return stats.roll_height_radius if _is_ball() else stats.height_radius


## Modo de colisão a partir do ângulo (SPG:Slope Collision > Determining The Mode).
func _mode() -> Mode:
	var d := rad_to_deg(ground_angle)
	var ad := absf(d)
	if ad <= 45.0:
		return Mode.FLOOR
	if ad >= 135.0:
		return Mode.CEILING
	return Mode.LEFT_WALL if d > 0.0 else Mode.RIGHT_WALL


func _mode_rotation() -> float:
	match _mode():
		Mode.LEFT_WALL:
			return PI * 0.5
		Mode.CEILING:
			return PI
		Mode.RIGHT_WALL:
			return -PI * 0.5
	return 0.0


func _down() -> Vector2:
	return Vector2.DOWN.rotated(_mode_rotation())


func _right() -> Vector2:
	return Vector2.RIGHT.rotated(_mode_rotation())


func _angle_from_normal(n: Vector2, fallback: float) -> float:
	if n == Vector2.ZERO:
		return fallback  # raio começou dentro do sólido
	return atan2(n.x, -n.y)


func _ray(from: Vector2, dir: Vector2, length: float) -> Dictionary:
	var to := from + dir * length
	var q := PhysicsRayQueryParameters2D.create(from, to, _mask())
	q.hit_from_inside = true
	var r := get_world_2d().direct_space_state.intersect_ray(q)
	if debug_draw:
		_dbg.append([from, to, not r.is_empty()])
	return r


## Par de sensores (A = lado -, B = lado +) lançados do centro na direção `dir`.
## `gap` é medido a partir da borda (raio de altura). Vence o menor gap.
func _sense_pair(dir: Vector2, axis: Vector2, reach: float) -> Sense:
	var s := Sense.new()
	var best := INF
	var wr := _wr()
	var hr := _hr()
	for i in 2:
		var off := wr * (-1.0 if i == 0 else 1.0)
		var from := global_position + axis * off
		var r := _ray(from, dir, reach)
		if r.is_empty():
			continue
		var g := from.distance_to(r.position) - hr
		if g < best:
			best = g
			s.found = true
			s.gap = g
			s.normal = r.normal
	return s


func _update_anim_speed() -> void:
	anim_speed.x = ground_speed if state == State.GROUND else velocity.x
	anim_speed.y = velocity.y


func _update_visual_angle() -> void:
	if state == State.GROUND:
		visual_angle = ground_angle
	else:
		visual_angle = move_toward(visual_angle, 0.0, VISUAL_ANGLE_STEP)


# ================================================================ DEBUG

func _draw() -> void:
	if not debug_draw or profile == null:
		return
	for r in _dbg:
		draw_line(to_local(r[0]), to_local(r[1]), Color.GREEN if r[2] else Color.RED, 1.0)
	draw_set_transform(Vector2.ZERO, _mode_rotation())
	draw_rect(Rect2(-_wr(), -_hr(), _wr() * 2.0, _hr() * 2.0), Color(1, 1, 1, 0.35), false)
	draw_set_transform(Vector2.ZERO, 0.0)
	draw_line(Vector2.ZERO, Vector2.RIGHT.rotated(ground_angle) * 24.0, Color.YELLOW, 1.0)
