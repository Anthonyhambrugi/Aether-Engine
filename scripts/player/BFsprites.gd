extends AnimatedSprite2D
## Animador do SONIC (sem class_name: copie e renomeie pra outros personagens).
## Coloque como filho direto do HarmonyBody (ou arraste o corpo em `body`).
## Só lê o estado do corpo, nunca escreve nele.
##
## Os nomes abaixo são os de um SpriteFrames estilo Sonic clássico/Mania.
## Se os seus se chamam diferente, é só trocar o texto no Inspector, em
## "Nomes das animações" (sem mexer no código). Animação que não existir no
## SpriteFrames é pulada e cai na parecida (dash -> run -> walk, etc).
##
## Habilidades mandam a animação pelo ESTADO: dentro da habilidade,
## set_state("air_dash") toca a animação "air_dash" (se existir no SpriteFrames)
## e clear_state() volta ao normal. Ver docs/MODDING.md.

@export var body: HarmonyBody

@export_group("Velocidade (px/frame)")
@export var walk_speed_threshold := 0.1
@export var run_speed_threshold := 6.0
@export var dash_speed_threshold := 10.0
## Freando (direcional contrário) a partir dessa velocidade.
@export var skid_speed_threshold := 4.0

@export_group("Multiplicadores de Animação")
## Chão/rolando: speed_scale = |anim_speed.x| * este valor (0.29 ~ 1/3.5).
@export var speed_scale_x := 0.29
## Queda: speed_scale = |anim_speed.y| * este valor.
@export var speed_scale_y := 0.15
@export var min_speed_scale := 0.8
@export var max_speed_scale := 3.5

@export_group("Sonic")
## Parado e sem apertar nada por tantos segundos -> toca anim_bored.
@export var bored_after_seconds := 8.0

@export_group("Nomes das animações")
@export var anim_idle: StringName = "idle"
@export var anim_bored: StringName = "bored"
@export var anim_walk: StringName = "walk"
@export var anim_run: StringName = "run"
@export var anim_dash: StringName = "dash"
@export var anim_roll: StringName = "roll"
@export var anim_fall: StringName = "fall"
@export var anim_skid: StringName = "skid"
@export var anim_crouch: StringName = "crouch"
@export var anim_look_up: StringName = "look_up"

## Estado de habilidade sem animação própria -> usa esta parecida.
## Formato: "estado": "animação". Ex.: se não existir a animação "spindash"
## no SpriteFrames, o spindash toca "crouch". Acrescente as suas.
@export var state_fallbacks: Dictionary = {"spindash": "crouch", "peelout": "look_up"}

var _idle_time := 0.0


func _ready() -> void:
	if body == null:
		body = get_parent() as HarmonyBody
	if body == null:
		push_warning("Animator (%s): nenhum HarmonyBody. Use como filho direto dele ou preencha 'Body'." % name)
		return
	body.landed.connect(_on_landed)
	body.jumped.connect(_on_jumped)
	body.left_ground.connect(_on_left_ground)
	body.roll_changed.connect(_on_roll_changed)


func _process(delta: float) -> void:
	if body == null:
		return
	_update_idle_time(delta)
	_update_transforms()
	_update_animation()


## Conta há quanto tempo o Sonic está parado sem tocar em nada.
func _update_idle_time(delta: float) -> void:
	var still := body.state == HarmonyBody.State.GROUND \
			and absf(body.ground_speed) < walk_speed_threshold \
			and not (body.input_left or body.input_right or body.input_up or body.input_down)
	_idle_time = _idle_time + delta if still else 0.0


## Direção do sprite e rotação nas ladeiras.
func _update_transforms() -> void:
	flip_h = body.facing < 0
	# visual_angle já é suave no ar e alinhado ao chão nas ladeiras
	rotation = body.visual_angle


func _update_animation() -> void:
	_play_current_state_animation()
	_adjust_animation_speed()


# ==============================================================================
# ÁREA DE EDIÇÃO: dispara o play() direto na animação correspondente ao estado.
# A primeira regra que bater vence.
# ==============================================================================
func _play_current_state_animation() -> void:
	# 1. Estado de habilidade (set_state): toca a animação de MESMO NOME.
	#    Se ela não existir, tenta a parecida de `state_fallbacks`; se também
	#    não existir, segue a lógica normal abaixo.
	if body.custom_state != "":
		var wanted: String = body.custom_state_animation if body.custom_state_animation != "" else body.custom_state
		if _play_if_has(wanted):
			return
		if state_fallbacks.has(body.custom_state) and _play_if_has(state_fallbacks[body.custom_state]):
			return

	# (compatibilidade) habilidade antiga com método get_animation()
	for a in body.abilities:
		if a.enabled and a.has_method("get_animation"):
			var custom: StringName = a.get_animation()
			if custom != "" and _play_if_has(custom):
				return

	# 2. Bola: rolando ou pulando
	if body.rolling or body.jumping:
		_play_if_has(anim_roll)
		return

	# 3. No ar sem ter pulado (caiu de plataforma, mola...)
	if body.state == HarmonyBody.State.AIR:
		if not _play_if_has(anim_fall):
			_play_if_has(anim_walk)
		return

	# 4. Chão
	var speed := absf(body.anim_speed.x)

	if speed < walk_speed_threshold:
		if body.input_down:
			if not _play_if_has(anim_crouch):
				_play_if_has(anim_idle)
		elif body.input_up:
			if not _play_if_has(anim_look_up):
				_play_if_has(anim_idle)
		elif _idle_time >= bored_after_seconds and _play_if_has(anim_bored):
			pass  # entediado: já tocou
		else:
			_play_if_has(anim_idle)
		return

	# freando: indo numa direção e segurando a contrária
	var braking := (body.ground_speed > 0.0 and body.input_left) or (body.ground_speed < 0.0 and body.input_right)
	if braking and speed >= skid_speed_threshold and body.control_lock == 0:
		if not _play_if_has(anim_skid):
			_play_if_has(anim_walk)
		return

	if speed >= dash_speed_threshold:
		if not _play_if_has(anim_dash):
			if not _play_if_has(anim_run):
				_play_if_has(anim_walk)
		return

	if speed >= run_speed_threshold:
		if not _play_if_has(anim_run):
			_play_if_has(anim_walk)
		return

	_play_if_has(anim_walk)


## Toca a animação apenas se ela existir no SpriteFrames. Devolve true se conseguiu tocar.
func _play_if_has(anim_name: StringName) -> bool:
	if sprite_frames != null and sprite_frames.has_animation(anim_name):
		if animation != anim_name:
			play(anim_name)
		return true
	return false


## Velocidade de reprodução a partir do body.anim_speed (x e y).
func _adjust_animation_speed() -> void:
	if animation == anim_walk or animation == anim_run or animation == anim_dash or animation == anim_roll:
		speed_scale = clampf(absf(body.anim_speed.x) * speed_scale_x, min_speed_scale, max_speed_scale)
	elif animation == anim_fall:
		speed_scale = clampf(absf(body.anim_speed.y) * speed_scale_y, min_speed_scale, max_speed_scale)
	else:
		speed_scale = 1.0


# ==============================================================================
# SINAIS DO HARMONYBODY (poeira, sons, animações pontuais...)
# ==============================================================================
func _on_landed() -> void:
	pass


func _on_jumped() -> void:
	pass


func _on_left_ground() -> void:
	pass


func _on_roll_changed(_is_rolling: bool) -> void:
	pass
