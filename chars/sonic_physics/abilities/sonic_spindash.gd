class_name SonicSpindash
extends SonicAbility
## Spin dash (Sonic 2/3&K): agachado + pulo carrega; cada aperto soma rev; soltar Baixo dispara.
## Velocidade = base_speed + floor(rev) / 2 (máx. 12 com os valores padrão).

signal charged(rev: float)
signal launched(rev: float)

@export var base_speed := 8.0
@export var rev_step := 2.0
@export var rev_max := 8.0

var charging := false
var rev := 0.0


func ground_step() -> bool:
	var p := player
	if not charging:
		if p.jump_pressed and p.crouching:
			_start()
			return true
		return false

	if p.jump_pressed:
		rev = minf(rev + rev_step, rev_max)
		charged.emit(rev)
		p.ability_event.emit(&"spindash_charge", rev)
	# drag idêntico ao air drag
	rev -= floorf(rev / 0.125) / 256.0

	if p.input_down:
		p.gsp = 0.0
		p.xsp = 0.0
		p.ysp = 0.0
		p.snap_to_ground()  # continua colado no chão
		if not p.grounded:
			_stop()
		return true

	_launch()
	return true


func air_step() -> bool:
	if charging:
		_stop()
	return false


func on_hurt() -> void:
	_stop()


func interrupt() -> void:
	_stop()


func _start() -> void:
	charging = true
	rev = 0.0
	var p := player
	p.charging = true
	p.custom_state = &"spindash"
	p.gsp = 0.0
	p.xsp = 0.0
	p.ysp = 0.0
	p.ability_event.emit(&"spindash_charge", 0.0)


func _launch() -> void:
	var p := player
	var r := rev
	p.gsp = (base_speed + floorf(r) / 2.0) * p.facing
	p.begin_roll()
	p.camera_lag_requested.emit(maxi(1, 32 - int(r)))
	p.ability_event.emit(&"spindash_release", r)
	launched.emit(r)
	_stop()


func _stop() -> void:
	if not charging:
		return
	charging = false
	rev = 0.0
	player.charging = false
	if player.custom_state == &"spindash":
		player.custom_state = &""
