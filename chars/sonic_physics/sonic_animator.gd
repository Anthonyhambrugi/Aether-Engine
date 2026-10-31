class_name SonicAnimator
extends Node
## Liga o `state` do SonicPlayer às suas animações (AnimatedSprite2D ou AnimationPlayer),
## vira o sprite pela direção, rotaciona no terreno e ajusta a velocidade da animação.
##
## Estados: idle, run, jump, fall, roll, crouch, look_up, balance, push, hurt, dead + os das habilidades (ex.: spindash).
## Por padrão o nome da animação = nome do estado. Use `animation_names` pra mapear diferente
## (ex.: {"run": "walk"}). Se a animação não existir, tenta a próxima do FALLBACK.

const FALLBACK := {
	&"fall": &"run", &"push": &"run", &"spindash": &"roll", &"jump": &"roll",
	&"crouch": &"idle", &"look_up": &"idle", &"balance": &"idle", &"dead": &"hurt", &"hurt": &"idle",
	&"run": &"idle", &"roll": &"idle",
}

@export var player: SonicPlayer              ## vazio = pai
@export var sprite: AnimatedSprite2D         ## vazio = primeiro AnimatedSprite2D do player
@export var animation_player: AnimationPlayer
@export var use_animation_player := false    ## true = usa o AnimationPlayer em vez do AnimatedSprite2D
@export var animation_names: Dictionary = {}
@export var flip_by_facing := true
@export var rotate_to_ground := true
@export var speed_scale_by_speed := true
@export var speed_scale_per_px := 0.2        ## speed_scale = 1 + |gsp| * isto (só em run/roll)


func _ready() -> void:
	if player == null:
		player = get_parent() as SonicPlayer
	if player == null:
		push_warning("SonicAnimator: sem SonicPlayer.")
		return
	if sprite == null:
		sprite = _find_child_of_type(player, "AnimatedSprite2D") as AnimatedSprite2D
	if animation_player == null:
		animation_player = _find_child_of_type(player, "AnimationPlayer") as AnimationPlayer
	player.state_changed.connect(_on_state_changed)
	_on_state_changed(&"", player.state)


func _process(_delta: float) -> void:
	if player == null:
		return
	var target: Node2D = sprite
	if target:
		if flip_by_facing:
			sprite.flip_h = player.facing < 0
		if rotate_to_ground:
			# a bola (pulo/rolamento) não rotaciona
			sprite.rotation = 0.0 if player.ball_form else wrapf(-player.ground_angle, -PI, PI)
	if speed_scale_by_speed:
		var sc := 1.0
		if player.state == &"run" or player.state == &"roll":
			sc = 1.0 + absf(player.gsp) * speed_scale_per_px
		if use_animation_player and animation_player:
			animation_player.speed_scale = sc
		elif sprite:
			sprite.speed_scale = sc


func _on_state_changed(_old: StringName, new_state: StringName) -> void:
	var anim := _resolve(new_state)
	if anim == &"":
		return
	if use_animation_player and animation_player:
		if animation_player.current_animation != anim:
			animation_player.play(anim)
	elif sprite:
		sprite.play(anim)


func _has(anim: StringName) -> bool:
	if use_animation_player and animation_player:
		return animation_player.has_animation(anim)
	return sprite != null and sprite.sprite_frames != null and sprite.sprite_frames.has_animation(anim)


func _resolve(state: StringName) -> StringName:
	var name: StringName = StringName(animation_names.get(state, state))
	for i in 4:
		if _has(name):
			return name
		if not FALLBACK.has(name):
			break
		name = FALLBACK[name]
	return &""


func _find_child_of_type(root: Node, type_name: String) -> Node:
	for c in root.get_children():
		if c.is_class(type_name):
			return c
	return null
