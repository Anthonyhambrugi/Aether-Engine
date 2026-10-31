class_name HarmonyPhysicsZone
extends Area2D
## Zona que muda a física de quem está dentro dela — pelo NÍVEL, sem código.
## Água, gelo, esteira, gravidade baixa...
##
## Como usar: Area2D com este script + um CollisionShape2D filho. No Inspector,
## em "Modifiers", adicione elementos: em cada um escolha "New HarmonyStatEntry"
## e preencha stat (dropdown), op (Multiply/Add/Set) e value.
##
##   água:    gravity x0.5, top_speed x0.5, jump_force x0.6
##   gelo:    friction x0.1, acceleration x0.4
##
## Ao entrar os mods são aplicados em `body.stats`; ao sair (ou se a zona for
## removida) são desfeitos. Várias zonas sobrepostas se combinam.
## O jogador precisa de uma Area2D "Hitbox" na layer 8 (valor 128).

@export var modifiers: Array[HarmonyStatEntry] = []
@export_flags_2d_physics var detect_layers := 128
@export var debug_draw := true
@export var debug_color := Color(0.2, 0.6, 1.0, 0.18)

var _inside: Array[HarmonyBody] = []


func _ready() -> void:
	collision_layer = 0
	collision_mask = detect_layers
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)


func _exit_tree() -> void:
	for b in _inside.duplicate():
		_release(b)


func _on_area_entered(area: Area2D) -> void:
	var b := area.get_parent() as HarmonyBody
	if b == null or _inside.has(b):
		return
	_inside.append(b)
	for e in modifiers:
		if e != null:
			b.add_mod(self, StringName(e.stat), e.mod_op(), e.value)


func _on_area_exited(area: Area2D) -> void:
	var b := area.get_parent() as HarmonyBody
	if b != null:
		_release(b)


func _release(b: HarmonyBody) -> void:
	_inside.erase(b)
	if is_instance_valid(b):
		b.remove_mods(self)


func _draw() -> void:
	if not debug_draw:
		return
	for c in get_children():
		if c is CollisionShape2D and c.shape is RectangleShape2D:
			var size: Vector2 = c.shape.size
			draw_rect(Rect2(c.position - size * 0.5, size), debug_color, true)
