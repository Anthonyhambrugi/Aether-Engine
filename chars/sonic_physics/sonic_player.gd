class_name SonicPlayer
extends CharacterBody2D
## Núcleo da física do Sonic (Sonic Physics Guide / Sonic Retro). Movimento e colisão são manuais:
## raycasts fazem o papel dos sensores. O CharacterBody2D é só o "corpo": não usamos move_and_slide.
##
## Extensível por componentes (filhos do player):
##   - SonicAbility (ex.: SonicSpindash): ganchos ground_step/air_step/try_jump/on_landed/on_hurt
##   - SonicAnimator: liga o estado do player às animações
##   - SonicAudio: sons a partir dos sinais
## Estado atual: `state` (StringName) + sinal `state_changed`.
## Ângulo: 0 = chão plano, positivo = sobe pra direita. Requer Godot 4.2+.

signal jumped
signal landed
signal started_rolling
signal got_hurt
signal died
signal state_changed(old_state: StringName, new_state: StringName)
## Eventos genéricos das habilidades (ex.: &"spindash_charge", &"spindash_release"). Áudio/efeitos escutam aqui.
signal ability_event(event: StringName, data: Variant)
signal camera_lag_requested(frames: int)

enum Mode { FLOOR, RIGHT_WALL, CEILING, LEFT_WALL }

const FLOOR_DOWN := [Vector2.DOWN, Vector2.RIGHT, Vector2.UP, Vector2.LEFT]
const FLOOR_RIGHT := [Vector2.RIGHT, Vector2.UP, Vector2.LEFT, Vector2.DOWN]

const SENSOR_ABOVE := 16.0      # o raio do sensor de chão começa 16px acima do pé
const SNAP_DISTANCE := 14.0     # distância máxima pra "grudar" no chão
const JUMP_CEILING_MIN := 6.0
const PUSH_Y_OFFSET := 8.0      # sensores de parede descem 8px com ângulo 0

@export var config: SonicConfig
@export_group("Colisão")
## Se vazio, usa o primeiro filho CollisionShape2D. Ele define o tamanho do corpo e é redimensionado ao rolar.
@export var collision_shape: CollisionShape2D
@export var use_collision_shape_size := true
## Os sensores usam a collision_mask do próprio corpo (Inspector > Collision > Mask).
## Se quiser trocar em runtime (loops A/B): mude `collision_mask` ou use este override (0 = desligado).
@export_flags_2d_physics var terrain_mask_override: int = 0
@export_group("Geral")
@export var use_builtin_input := true
@export var force_60hz := true
@export var debug_draw := false   ## F3 liga/desliga em runtime

# --- estado físico ---
var gsp := 0.0            # ground speed
var xsp := 0.0
var ysp := 0.0
var ground_angle := 0.0   # radianos [0, TAU)
var grounded := false
var rolling := false
var jumping := false
var crouching := false
var looking_up := false
var balancing := false
var pushing := false
var hurt := false
var dead := false
var ball_form := false
var roll_jump_locked := false
var control_lock := 0
var facing := 1

# --- para habilidades / animação ---
var state: StringName = &"idle"
var custom_state: StringName = &""   ## habilidades setam (ex.: &"spindash") pra sobrescrever o estado
var charging := false                ## habilidades setam enquanto carregam algo (câmera não olha pra baixo)
var abilities: Array[SonicAbility] = []

# --- entrada (preencha por fora se use_builtin_input = false) ---
var input_left := false
var input_right := false
var input_up := false
var input_down := false
var input_jump_held := false
var jump_pressed := false

var width_radius := 9.0
var height_radius := 19.0

var _stand_w := 9.0
var _stand_h := 19.0
var _roll_w := 7.0
var _roll_h := 14.0
var _query := PhysicsRayQueryParameters2D.new()
var _space: PhysicsDirectSpaceState2D


static func ensure_input_map() -> void:
	var defs := {
		"sonic_left": [KEY_LEFT, KEY_A],
		"sonic_right": [KEY_RIGHT, KEY_D],
		"sonic_up": [KEY_UP, KEY_W],
		"sonic_down": [KEY_DOWN, KEY_S],
		"sonic_jump": [KEY_SPACE, KEY_Z, KEY_X],
	}
	var pads := {
		"sonic_left": JOY_BUTTON_DPAD_LEFT, "sonic_right": JOY_BUTTON_DPAD_RIGHT,
		"sonic_up": JOY_BUTTON_DPAD_UP, "sonic_down": JOY_BUTTON_DPAD_DOWN,
		"sonic_jump": JOY_BUTTON_A,
	}
	for action in defs:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for k in defs[action]:
			var e := InputEventKey.new()
			e.physical_keycode = k
			InputMap.action_add_event(action, e)
		var j := InputEventJoypadButton.new()
		j.button_index = pads[action]
		InputMap.action_add_event(action, j)


# ============================================================ SETUP

func _ready() -> void:
	add_to_group("sonic_player")
	if config == null:
		config = SonicConfig.sonic_3k()
	if force_60hz:
		Engine.physics_ticks_per_second = 60
	if use_builtin_input:
		ensure_input_map()
	_query.exclude = [get_rid()]  # os raios não podem acertar o próprio corpo
	_setup_body()
	_collect_abilities()


## Recalcula raios do corpo a partir do CollisionShape2D (ou da config). Chame após trocar `config`.
func _setup_body() -> void:
	if collision_shape == null:
		for c in get_children():
			if c is CollisionShape2D:
				collision_shape = c
				break
	_stand_w = config.width_radius
	_stand_h = config.height_radius
	if collision_shape and collision_shape.shape and use_collision_shape_size:
		if not collision_shape.shape.resource_local_to_scene:
			collision_shape.shape = collision_shape.shape.duplicate()  # não altera o recurso compartilhado
		var s := collision_shape.shape
		if s is RectangleShape2D:
			_stand_w = ((s as RectangleShape2D).size.x - 1.0) * 0.5
			_stand_h = ((s as RectangleShape2D).size.y - 1.0) * 0.5
		elif s is CapsuleShape2D:
			_stand_w = (s as CapsuleShape2D).radius - 0.5
			_stand_h = ((s as CapsuleShape2D).height - 1.0) * 0.5
		elif s is CircleShape2D:
			_stand_w = (s as CircleShape2D).radius - 0.5
			_stand_h = _stand_w
	_roll_w = _stand_w - (config.width_radius - config.roll_width_radius)
	_roll_h = _stand_h - (config.height_radius - config.roll_height_radius)
	_set_ball(ball_form)


func set_config(new_config: SonicConfig) -> void:
	config = new_config
	_setup_body()


func _collect_abilities() -> void:
	abilities.clear()
	for c in get_children():
		if c is SonicAbility:
			var a := c as SonicAbility
			a.player = self
			abilities.append(a)
	for a in abilities:
		a._ability_ready()


func get_ability(type: Script) -> SonicAbility:
	for a in abilities:
		if is_instance_of(a, type):
			return a
	return null


# ============================================================ LOOP

func _physics_process(_delta: float) -> void:
	_space = get_world_2d().direct_space_state
	if use_builtin_input:
		_poll_input()
	if dead:
		_step_dead()
	elif grounded:
		_step_ground()
	else:
		_step_air()
	jump_pressed = false
	velocity = Vector2(xsp, ysp)
	_update_state()
	queue_redraw()


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F3:
		debug_draw = not debug_draw
		queue_redraw()


func _poll_input() -> void:
	input_left = Input.is_action_pressed("sonic_left")
	input_right = Input.is_action_pressed("sonic_right")
	input_up = Input.is_action_pressed("sonic_up")
	input_down = Input.is_action_pressed("sonic_down")
	input_jump_held = Input.is_action_pressed("sonic_jump")
	if Input.is_action_just_pressed("sonic_jump"):
		jump_pressed = true


func _update_state() -> void:
	var s: StringName
	if dead:
		s = &"dead"
	elif hurt:
		s = &"hurt"
	elif custom_state != &"":
		s = custom_state
	elif not grounded:
		s = &"jump" if jumping else &"fall"
	elif rolling:
		s = &"roll"
	elif crouching:
		s = &"crouch"
	elif looking_up:
		s = &"look_up"
	elif balancing:
		s = &"balance"
	elif pushing:
		s = &"push"
	elif is_zero_approx(gsp):
		s = &"idle"
	else:
		s = &"run"
	if s != state:
		var old := state
		state = s
		state_changed.emit(old, s)


# ============================================================ CHÃO

func _step_ground() -> void:
	var mode := _mode_of(ground_angle, false)
	var down: Vector2 = FLOOR_DOWN[mode]
	pushing = false

	var flat := mode == Mode.FLOOR
	crouching = input_down and flat and not rolling and absf(gsp) < config.crouch_speed_limit
	looking_up = input_up and flat and not rolling and not crouching and is_zero_approx(gsp)

	# habilidades (spin dash, etc.)
	for a in abilities:
		if a.enabled and a.ground_step():
			return

	# 1. fator de ladeira
	_apply_slope_factor(mode)

	# 2. pulo (usa xsp/ysp do frame anterior, como no original)
	if jump_pressed:
		for a in abilities:
			if a.enabled and a.try_jump():
				return
		if _try_jump(mode, down):
			return

	# 3. entrada / atrito
	_apply_ground_input()

	# velocidade derivada do gsp (antes dos sensores de parede, como no código original)
	xsp = gsp * cos(ground_angle)
	ysp = -gsp * sin(ground_angle)
	if rolling and config.roll_max_x_speed > 0.0:
		xsp = clampf(xsp, -config.roll_max_x_speed, config.roll_max_x_speed)

	# 5. sensores de parede (push)
	_ground_push()

	# 6. checagem de rolamento
	_check_roll()

	# 8. mover
	global_position += Vector2(xsp, ysp)

	# 9. sensores de chão
	snap_to_ground()
	if not grounded:
		return

	# 10. slip / fall
	_check_slip()


func _apply_slope_factor(mode: int) -> void:
	if mode == Mode.CEILING:
		return
	var s := sin(ground_angle)
	var factor := config.slope_factor
	if rolling:
		factor = config.roll_uphill_slope_factor if signf(gsp) == signf(s) else config.roll_downhill_slope_factor
	var delta := factor * s
	var apply := not is_zero_approx(gsp)
	if config.s3k_slope_rules and absf(delta) >= 13.0 / 256.0:
		apply = true
	if apply:
		gsp -= delta


func _apply_ground_input() -> void:
	var can_steer := control_lock == 0 and not crouching
	var top := config.top_speed
	if rolling:
		if can_steer:
			if input_left and gsp > 0.0:
				gsp -= config.roll_deceleration
				if gsp < 0.0:
					gsp = -0.5
			if input_right and gsp < 0.0:
				gsp += config.roll_deceleration
				if gsp > 0.0:
					gsp = 0.5
		gsp -= minf(absf(gsp), config.roll_friction) * signf(gsp)
		if absf(gsp) < config.unroll_speed:
			_unroll()
		return

	if can_steer:
		if input_left:
			facing = -1
			if gsp > 0.0:
				gsp -= config.deceleration
				if gsp <= 0.0:
					gsp = -0.5
			elif gsp > -top:
				gsp -= config.acceleration
				if gsp <= -top:
					gsp = -top
		if input_right:
			facing = 1
			if gsp < 0.0:
				gsp += config.deceleration
				if gsp >= 0.0:
					gsp = 0.5
			elif gsp < top:
				gsp += config.acceleration
				if gsp >= top:
					gsp = top
	# atrito: só sem L/R apertado (mesmo com control lock, o botão físico conta)
	if (not input_left and not input_right) or crouching:
		gsp -= minf(absf(gsp), config.friction) * signf(gsp)


func _try_jump(mode: int, down: Vector2) -> bool:
	if _ceiling_distance(mode) < JUMP_CEILING_MIN:
		return false
	xsp -= config.jump_force * sin(ground_angle)
	ysp -= config.jump_force * cos(ground_angle)
	grounded = false
	jumping = true
	if rolling:
		rolling = false
		roll_jump_locked = config.roll_jump_lock
	elif not ball_form:
		_set_ball(true)
		global_position += down * (_stand_h - _roll_h)
	jumped.emit()
	return true  # o frame do pulo termina aqui (jump delay do original)


func _check_roll() -> void:
	if rolling or not input_down or input_left or input_right:
		return
	if absf(gsp) < config.roll_min_speed:
		return
	begin_roll()


## Entra em rolamento no chão (ajusta corpo e posição). Habilidades chamam isto ao disparar.
func begin_roll() -> void:
	if rolling:
		return
	rolling = true
	if not ball_form:
		var down: Vector2 = FLOOR_DOWN[_mode_of(ground_angle, false)]
		_set_ball(true)
		global_position += down * (_stand_h - _roll_h)
	started_rolling.emit()


func _unroll() -> void:
	var down: Vector2 = FLOOR_DOWN[_mode_of(ground_angle, false)]
	rolling = false
	_set_ball(false)
	global_position -= down * (_stand_h - _roll_h)


func _ground_push() -> void:
	if is_zero_approx(gsp):
		return
	var deg := rad_to_deg(ground_angle)
	if deg > 90.01 and deg < 269.99:
		return
	var mode := _mode_of(ground_angle, true)
	var right: Vector2 = FLOOR_RIGHT[mode]
	var down: Vector2 = FLOOR_DOWN[mode]
	var dir := signf(gsp)
	var y_off := PUSH_Y_OFFSET if is_zero_approx(ground_angle) else 0.0
	var origin := _center() + down * y_off + Vector2(xsp, ysp)
	var res := _cast(origin, right * dir, config.push_radius)
	if res.is_empty():
		return
	var d: float = res.dist - config.push_radius
	if d < 0.0:
		var fix := right * dir * d
		xsp += fix.x
		ysp += fix.y
		gsp = 0.0
		pushing = true


## Sensores de chão A/B: gruda no terreno, atualiza o ângulo, ou solta (grounded = false).
## Habilidades que ficam paradas no chão (spin dash) chamam isto todo frame.
func snap_to_ground() -> void:
	var mode := _mode_of(ground_angle, false)
	var down: Vector2 = FLOOR_DOWN[mode]
	var right: Vector2 = FLOOR_RIGHT[mode]
	var tol := minf(absf(Vector2(xsp, ysp).dot(right)) + 4.0, SNAP_DISTANCE)
	var base := _center() + down * (height_radius - SENSOR_ABOVE)
	var a := _sense(base - right * width_radius, down, SENSOR_ABOVE + SNAP_DISTANCE, SENSOR_ABOVE)
	var b := _sense(base + right * width_radius, down, SENSOR_ABOVE + SNAP_DISTANCE, SENSOR_ABOVE)
	var a_ok := _ground_ok(a.d, tol)
	var b_ok := _ground_ok(b.d, tol)
	if not a_ok and not b_ok:
		grounded = false
		balancing = false
		return
	var win: Dictionary
	if a_ok and b_ok:
		win = a if a.d <= b.d else b
	else:
		win = a if a_ok else b
	global_position += down * float(win.d)
	_set_ground_angle(_angle_of(win.normal))

	balancing = false
	if is_zero_approx(gsp) and a_ok != b_ok and mode == Mode.FLOOR:
		var c := _sense(_center() + down * (height_radius - SENSOR_ABOVE), down, SENSOR_ABOVE + SNAP_DISTANCE, SENSOR_ABOVE)
		balancing = not _ground_ok(c.d, SNAP_DISTANCE)


func _ground_ok(d: float, tol: float) -> bool:
	return d >= -SNAP_DISTANCE and d <= tol


func _check_slip() -> void:
	if control_lock > 0:
		control_lock -= 1
		return
	if absf(gsp) >= config.slip_speed_threshold:
		return
	var deg := rad_to_deg(ground_angle)
	if config.s3k_slope_rules:
		if deg >= 35.0 and deg <= 326.0:
			control_lock = config.control_lock_frames
			if deg >= 69.0 and deg <= 293.0:
				grounded = false
			elif deg < 180.0:
				gsp -= 0.5
			else:
				gsp += 0.5
	else:
		if deg >= 46.0 and deg <= 314.0:
			grounded = false
			gsp = 0.0
			control_lock = config.control_lock_frames


# ============================================================ AR

func _step_air() -> void:
	for a in abilities:
		if a.enabled and a.air_step():
			return
	var top := config.top_speed
	# 1. pulo variável
	if jumping and not input_jump_held and ysp < -config.jump_release_cap:
		ysp = -config.jump_release_cap
	# 3. controle aéreo
	if not roll_jump_locked and not hurt:
		if input_left:
			facing = -1
			if xsp > -top:
				xsp -= config.air_acceleration
				if xsp <= -top:
					xsp = -top
		if input_right:
			facing = 1
			if xsp < top:
				xsp += config.air_acceleration
				if xsp >= top:
					xsp = top
	# 4. air drag (xsp/32 em subpixels, só subindo devagar)
	if ysp < 0.0 and ysp > -4.0 and not hurt:
		xsp -= floorf(xsp / 0.125) / 256.0
	# 5. mover, 6. gravidade DEPOIS de mover
	global_position += Vector2(xsp, ysp)
	ysp += config.hurt_gravity if hurt else config.gravity
	# 8. ângulo visual volta a 0
	var a := wrapf(ground_angle, -PI, PI)
	ground_angle = fposmod(move_toward(a, 0.0, deg_to_rad(2.8125)), TAU)
	# 9. colisões
	_air_collision()


func _air_collision() -> void:
	var mostly_h := absf(xsp) > absf(ysp)
	# sensores de parede primeiro
	if mostly_h:
		_air_wall(signf(xsp))
	else:
		_air_wall(-1.0)
		_air_wall(1.0)
	# depois chão / teto
	if ysp >= 0.0:
		_air_land_ground(not mostly_h)
	else:
		_air_hit_ceiling(mostly_h)


func _air_wall(dir: float) -> void:
	var res := _cast(_center(), Vector2(dir, 0.0), config.push_radius)
	if res.is_empty():
		return
	var d: float = res.dist - config.push_radius
	if d < 0.0:
		global_position.x += dir * d
		xsp = 0.0


func _air_land_ground(down_quadrant: bool) -> void:
	var ext := maxf(SENSOR_ABOVE, ysp + 9.0)
	var base := _center() + Vector2(0.0, height_radius - ext)
	var a := _sense(base + Vector2(-width_radius, 0.0), Vector2.DOWN, ext, ext)
	var b := _sense(base + Vector2(width_radius, 0.0), Vector2.DOWN, ext, ext)
	var a_ok: bool = a.d < 0.0 and (not down_quadrant or a.d >= -(ysp + 8.0))
	var b_ok: bool = b.d < 0.0 and (not down_quadrant or b.d >= -(ysp + 8.0))
	if not a_ok and not b_ok:
		return
	var win: Dictionary
	if a_ok and b_ok:
		win = a if a.d <= b.d else b
	else:
		win = a if a_ok else b
	global_position.y += float(win.d)
	var ang := _angle_of(win.normal)
	var deg := rad_to_deg(ang)
	var new_gsp: float
	if absf(xsp) > absf(ysp) or deg >= 339.0 or deg <= 23.0:
		new_gsp = xsp
	elif deg >= 316.0 or deg <= 45.0:
		new_gsp = ysp * 0.5 * -signf(sin(ang))
	else:
		new_gsp = ysp * -signf(sin(ang))
	_finish_landing(ang, new_gsp)


func _air_hit_ceiling(mostly_h: bool) -> void:
	var ext := maxf(SENSOR_ABOVE, -ysp + 9.0)
	var base := _center() + Vector2(0.0, -height_radius + ext)
	var a := _sense(base + Vector2(-width_radius, 0.0), Vector2.UP, ext, ext)
	var b := _sense(base + Vector2(width_radius, 0.0), Vector2.UP, ext, ext)
	var a_ok: bool = a.d < 0.0
	var b_ok: bool = b.d < 0.0
	if not a_ok and not b_ok:
		return
	var win: Dictionary
	if a_ok and b_ok:
		win = a if a.d <= b.d else b
	else:
		win = a if a_ok else b
	global_position.y -= float(win.d)
	var ang := _angle_of(win.normal)
	var deg := rad_to_deg(ang)
	if mostly_h or (deg >= 136.0 and deg <= 225.0):
		ysp = 0.0  # bateu a cabeça
	else:
		_finish_landing(ang, ysp * -signf(sin(ang)))


func _finish_landing(new_angle: float, new_gsp: float) -> void:
	ground_angle = new_angle
	gsp = new_gsp
	grounded = true
	var mode := _mode_of(new_angle, false)
	if ball_form:
		var down: Vector2 = FLOOR_DOWN[mode]
		_set_ball(false)
		global_position -= down * (_stand_h - _roll_h)
	rolling = false
	jumping = false
	roll_jump_locked = false
	if hurt:
		hurt = false
		xsp = 0.0
		gsp = 0.0
	for a in abilities:
		if a.enabled:
			a.on_landed()
	landed.emit()


func _step_dead() -> void:
	# sem entrada e sem colisões: só gravidade normal
	global_position += Vector2(xsp, ysp)
	ysp += config.gravity


# ============================================================ API PÚBLICA

func hurt_from(source_x: float) -> void:
	if hurt or dead:
		return
	if ball_form:
		global_position -= Vector2.DOWN * (_stand_h - _roll_h)
		_set_ball(false)
	hurt = true
	grounded = false
	rolling = false
	jumping = false
	roll_jump_locked = false
	custom_state = &""
	charging = false
	for a in abilities:
		a.on_hurt()
	var s := signf(global_position.x - source_x)
	if s == 0.0:
		s = 1.0
	xsp = config.hurt_x_force * s
	ysp = config.hurt_y_force
	got_hurt.emit()


func die() -> void:
	if dead:
		return
	for a in abilities:
		a.interrupt()
	if ball_form:
		_set_ball(false)
	dead = true
	grounded = false
	rolling = false
	jumping = false
	hurt = false
	custom_state = &""
	charging = false
	xsp = 0.0
	ysp = -7.0
	died.emit()


## Mola vertical (ou qualquer lançamento): define a velocidade e solta do chão.
func launch(vx: float, vy: float, keep_jump_flag := false) -> void:
	xsp = vx
	ysp = vy
	grounded = false
	rolling = false
	jumping = keep_jump_flag
	roll_jump_locked = false
	if ball_form:
		_set_ball(false)


## Mola horizontal no chão: define a ground speed e trava o controle.
func spring_horizontal(speed: float, lock_frames := 16) -> void:
	gsp = speed
	facing = 1 if speed > 0.0 else -1
	control_lock = lock_frames


func get_mode() -> int:
	return _mode_of(ground_angle, false) if grounded else Mode.FLOOR


# ============================================================ HELPERS

## Centro do corpo (o do CollisionShape2D, se houver).
func _center() -> Vector2:
	return collision_shape.global_position if collision_shape else global_position


func _terrain_mask() -> int:
	return terrain_mask_override if terrain_mask_override != 0 else collision_mask


func _set_ball(on: bool) -> void:
	ball_form = on
	width_radius = _roll_w if on else _stand_w
	height_radius = _roll_h if on else _stand_h
	_apply_shape_size()


func _apply_shape_size() -> void:
	if collision_shape == null or collision_shape.shape == null or not use_collision_shape_size:
		return
	var s := collision_shape.shape
	if s is RectangleShape2D:
		(s as RectangleShape2D).size = Vector2(width_radius * 2.0 + 1.0, height_radius * 2.0 + 1.0)
	elif s is CapsuleShape2D:
		var cap := s as CapsuleShape2D
		cap.radius = width_radius + 0.5
		cap.height = maxf(height_radius * 2.0 + 1.0, cap.radius * 2.0)
	elif s is CircleShape2D:
		(s as CircleShape2D).radius = width_radius + 0.5


func _mode_of(angle: float, push: bool) -> int:
	var deg := rad_to_deg(angle)
	var w := 1.0 if push else 0.0  # sensores de parede trocam de modo mais cedo
	if deg <= 45.0 - w or deg >= 315.0 + w:
		return Mode.FLOOR
	if deg <= 134.0 + w:
		return Mode.RIGHT_WALL
	if deg <= 225.0 - w:
		return Mode.CEILING
	if deg <= 314.0 + w:
		return Mode.LEFT_WALL
	return Mode.FLOOR


func _set_ground_angle(new_angle: float) -> void:
	if config.snap_large_angle_change and absf(angle_difference(new_angle, ground_angle)) > deg_to_rad(45.0):
		new_angle = fposmod(snappedf(ground_angle, PI * 0.5), TAU)
	ground_angle = new_angle


func _angle_of(normal: Vector2) -> float:
	var a := atan2(-normal.x, -normal.y)
	var step := TAU / float(config.angle_steps)
	a = roundf(a / step) * step
	a = fposmod(a, TAU)
	if a > TAU - 0.0001:
		a = 0.0
	return a


func _cast(origin: Vector2, dir: Vector2, length: float) -> Dictionary:
	_query.from = origin
	_query.to = origin + dir * length
	_query.collision_mask = _terrain_mask()
	var res := _space.intersect_ray(_query)
	if not res.is_empty():
		res["dist"] = origin.distance_to(res["position"])
	return res


## Retorna {d, normal}. d = distância até a superfície menos `above` (negativo = enterrado).
func _sense(origin: Vector2, dir: Vector2, length: float, above: float) -> Dictionary:
	var res := _cast(origin, dir, length)
	if res.is_empty():
		return {"d": INF, "normal": Vector2.UP}
	return {"d": float(res["dist"]) - above, "normal": res["normal"]}


func _ceiling_distance(mode: int) -> float:
	var down: Vector2 = FLOOR_DOWN[mode]
	var right: Vector2 = FLOOR_RIGHT[mode]
	var up := -down
	var best := INF
	for sx in [-1.0, 1.0]:
		var origin: Vector2 = _center() + right * (sx * width_radius) + up * (height_radius - SENSOR_ABOVE)
		var res := _cast(origin, up, SENSOR_ABOVE + 16.0)
		if not res.is_empty():
			best = minf(best, float(res["dist"]) - SENSOR_ABOVE)
	return best


func _draw() -> void:
	if not debug_draw or config == null:
		return
	var mode := get_mode()
	var down: Vector2 = FLOOR_DOWN[mode]
	var right: Vector2 = FLOOR_RIGHT[mode]
	var off := _center() - global_position
	var col := Color(0.3, 0.9, 1.0, 0.9)
	draw_rect(Rect2(off + Vector2(-width_radius, -height_radius), Vector2(width_radius, height_radius) * 2.0), col, false, 1.0)
	draw_line(off + Vector2(-config.push_radius, 0), off + Vector2(config.push_radius, 0), Color(1, 1, 0, 0.9), 1.0)
	draw_circle(off + down * height_radius - right * width_radius, 1.5, Color.RED)     # A
	draw_circle(off + down * height_radius + right * width_radius, 1.5, Color.LIME)    # B
	var txt := "gsp %.2f  ang %d  %s" % [gsp, roundi(rad_to_deg(ground_angle)), state]
	draw_string(ThemeDB.fallback_font, off + Vector2(-40, -height_radius - 8), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 10)
