class_name SonicCamera
extends Camera2D
## Câmera do Sonic Physics Guide: bordas de rolagem, velocidade máxima, foco vertical,
## olhar pra cima/baixo com delay e lag do spin dash.
## Pode ficar como filho do player ou solto na cena. Sem `target`, usa o pai (se for SonicPlayer) ou o grupo "sonic_player".
## Valores em pixels da tela original 320x224. Limites de fase: use limit_left/right/top/bottom do Camera2D.

@export var target: SonicPlayer
@export var max_speed := 16.0            ## S3K: 24
@export var border_left := -16.0         ## relativo ao centro (original: 144 de 320). Dica do guia: -8 / 8
@export var border_right := 0.0          ## original: 160 de 320
@export var focus_default := 96.0        ## foco vertical (coordenada de tela, 224 px de altura)
@export var focus_up := 104.0
@export var focus_down := 88.0
@export var look_delay := 120            ## frames segurando cima/baixo (S2+)
@export var avoid_backward_lag := true   ## evita o bug do guia (câmera andando pra trás no spin dash rápido)
@export var pixel_snap := false

const SCREEN_HALF_H := 112.0
const HISTORY := 33

var _pos := Vector2.ZERO
var _focus := 96.0
var _look_timer := 0
var _lag := 0
var _history: Array[Vector2] = []


func _ready() -> void:
	process_physics_priority = 100  # roda depois do player
	position_smoothing_enabled = false
	make_current()
	if target == null:
		target = get_parent() as SonicPlayer
	if target == null:
		target = get_tree().get_first_node_in_group("sonic_player") as SonicPlayer
	if target == null:
		return
	_focus = focus_default
	_pos = target.global_position - Vector2(0.0, _focus - SCREEN_HALF_H)
	global_position = _pos
	target.camera_lag_requested.connect(_on_lag_requested)


func snap_to_target() -> void:
	if target == null:
		return
	_history.clear()
	_pos = target.global_position - Vector2(0.0, _focus - SCREEN_HALF_H)
	global_position = _pos


func _on_lag_requested(frames: int) -> void:
	_lag = maxi(1, frames)
	if avoid_backward_lag:
		for i in _history.size():
			_history[i] = target.global_position


func _physics_process(_delta: float) -> void:
	if target == null:
		return
	var p := target.global_position
	_history.append(p)
	if _history.size() > HISTORY:
		_history.pop_front()

	_update_look()

	# horizontal (com lag do spin dash: usa a posição de N frames atrás)
	var px := p.x
	if _lag > 0:
		px = _history[maxi(0, _history.size() - 1 - _lag)].x
		_lag -= 1
	var dx := px - _pos.x
	if dx < border_left:
		_pos.x += maxf(dx - border_left, -max_speed)
	elif dx > border_right:
		_pos.x += minf(dx - border_right, max_speed)

	# vertical
	var focus_rel := _focus - SCREEN_HALF_H
	if target.grounded:
		var cap := max_speed
		if is_equal_approx(_focus, focus_default):
			if absf(target.gsp) < 8.0:
				cap = 6.0
		else:
			cap = 2.0
		_pos.y += clampf(p.y - (_pos.y + focus_rel), -cap, cap)
	else:
		var dy := p.y - _pos.y
		var top := focus_rel - 32.0
		var bottom := focus_rel + 32.0
		if dy < top:
			_pos.y += maxf(dy - top, -16.0)
		elif dy > bottom:
			_pos.y += minf(dy - bottom, 16.0)

	global_position = _pos.round() if pixel_snap else _pos


func _update_look() -> void:
	var looking_up := target.grounded and target.looking_up
	var looking_down := target.grounded and target.crouching and not target.charging
	if looking_up or looking_down:
		_look_timer += 1
	else:
		_look_timer = 0
	var goal := focus_default
	if _look_timer >= look_delay:
		goal = focus_up if looking_up else focus_down
	_focus = move_toward(_focus, goal, 2.0)
