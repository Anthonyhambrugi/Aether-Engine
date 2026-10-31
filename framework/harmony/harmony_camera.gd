class_name HarmonyCamera2D
extends Camera2D
## Câmera estilo Sonic Genesis (SPG:Camera). O personagem tem uma janela de
## folga (horizontal e vertical) antes da câmera começar a se mexer, e
## quando se mexe, anda no máximo a uma velocidade limitada — por isso ela
## "atrasa" (lag) em altas velocidades em vez de grudar no personagem.
##
## Os valores default abaixo são os oficiais do SPG pra a resolução clássica
## de 320x224. Se sua viewport for outra, ajuste os campos em px ou deixe
## `auto_scale_to_viewport` ligado pra eu escalar proporcionalmente.
##
## Não implementado (fica pra outra hora, os números não são de fácil
## verificação pública): o efeito de "olhar pra cima/baixo" segurando
## ↑/↓ parado por 2 segundos, que desloca a janela vertical.

@export var target_path: NodePath
@onready var target: HarmonyBody = get_node_or_null(target_path) as HarmonyBody

## Se true, os valores abaixo (calibrados pra 320x224) são escalados pra
## viewport atual mantendo a mesma proporção. Se false, use os valores em
## px como estão (pra viewports já pensadas em 320x224 ou perto disso).
@export var auto_scale_to_viewport := true

@export_group("Janela horizontal")
## Distância (px, da borda esquerda da tela) onde a câmera trava à
## esquerda/direita do personagem. SPG: 144 / 160 de 320.
@export var left_border := 144.0
@export var right_border := 160.0
## Velocidade máxima (px/frame) da câmera ao alcançar o personagem. SPG: 16.
@export var h_catch_up_speed := 16.0

@export_group("Janela vertical — no ar")
@export var air_top_border := 64.0
@export var air_bottom_border := 128.0

@export_group("Janela vertical — no chão")
## Posição-alvo (px, do topo da tela) onde o personagem "gruda" no chão.
@export var ground_target_y := 96.0
@export var ground_slow_speed := 6.0
@export var ground_fast_speed := 16.0
## Acima desse ground speed, a câmera usa a velocidade "rápida" pra
## acompanhar ladeiras/loops sem atrasar tanto.
@export var ground_fast_speed_threshold := 8.0

@export_group("Limites do nível")
## Rect2 vazio (padrão) = sem limite. Em coordenadas do mundo.
@export var bounds: Rect2 = Rect2()

var _pos: Vector2
var _scale := 1.0


func _ready() -> void:
	make_current()
	_pos = global_position
	if auto_scale_to_viewport:
		_scale = _effective_size().y / 224.0


func _effective_size() -> Vector2:
	## Tamanho da área do mundo realmente visível, já descontando o zoom
	## (zoom > 1 no Camera2D mostra uma área MENOR do mundo).
	return get_viewport_rect().size / zoom


func _physics_process(_delta: float) -> void:
	if target == null:
		return
	var s := _scale if auto_scale_to_viewport else 1.0
	_update_horizontal(s)
	_update_vertical(s)
	_clamp_to_bounds()
	global_position = _pos


func _update_horizontal(s: float) -> void:
	var half_w := _effective_size().x * 0.5
	var rel_x := target.global_position.x - (_pos.x - half_w)
	var diff := 0.0
	if rel_x < left_border * s:
		diff = rel_x - left_border * s
	elif rel_x > right_border * s:
		diff = rel_x - right_border * s
	if diff != 0.0:
		_pos.x += clampf(diff, -h_catch_up_speed * s, h_catch_up_speed * s)


func _update_vertical(s: float) -> void:
	var half_h := _effective_size().y * 0.5
	var rel_y := target.global_position.y - (_pos.y - half_h)

	if target.state == HarmonyBody.State.AIR:
		var diff := 0.0
		if rel_y < air_top_border * s:
			diff = rel_y - air_top_border * s
		elif rel_y > air_bottom_border * s:
			diff = rel_y - air_bottom_border * s
		if diff != 0.0:
			_pos.y += clampf(diff, -h_catch_up_speed * s, h_catch_up_speed * s)
		return

	var diff := rel_y - ground_target_y * s
	if is_zero_approx(diff):
		return
	var max_speed := ground_fast_speed if absf(target.ground_speed) >= ground_fast_speed_threshold else ground_slow_speed
	_pos.y += clampf(diff, -max_speed * s, max_speed * s)


func _clamp_to_bounds() -> void:
	if bounds.size == Vector2.ZERO:
		return
	var half := _effective_size() * 0.5
	_pos.x = clampf(_pos.x, bounds.position.x + half.x, bounds.end.x - half.x)
	_pos.y = clampf(_pos.y, bounds.position.y + half.y, bounds.end.y - half.y)
