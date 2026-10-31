extends Node2D
## Fase de teste gerada por código: chão, rampa, descida e quarter-pipe.
## Controles: setas/WASD, Espaço/Z/X = pulo, Baixo em movimento = rolar,
## agachado (Baixo parado) + pulo repetido = spin dash (solta Baixo pra disparar), R = reiniciar.

var player: SonicPlayer
var label: Label


func _ready() -> void:
	var pts := PackedVector2Array([
		Vector2(-600, 400), Vector2(900, 400), Vector2(1200, 340), Vector2(1500, 340),
		Vector2(1800, 513), Vector2(2100, 513),
	])
	# quarter-pipe (raio 350) saindo do chão em x=2100
	var r := 350.0
	var c := Vector2(2100, 513.0 - r)
	for i in range(1, 33):
		var t := deg_to_rad(90.0 * i / 32.0)
		pts.append(c + Vector2(sin(t), cos(t)) * r)
	pts.append(Vector2(2700, c.y))
	pts.append(Vector2(2700, 900))
	pts.append(Vector2(-600, 900))

	var body := StaticBody2D.new()
	add_child(body)
	var col := CollisionPolygon2D.new()
	col.polygon = pts
	body.add_child(col)
	var vis := Polygon2D.new()
	vis.polygon = pts
	vis.color = Color(0.25, 0.5, 0.25)
	add_child(vis)

	# player montado por código (na sua cena isso é a árvore Sonic > CollisionShape2D, etc.)
	player = SonicPlayer.new()
	player.position = Vector2(0, 400 - 19)
	player.debug_draw = true
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(19, 39)  # 9 de raio de largura, 19 de altura (como no Genesis)
	shape.shape = rect
	player.add_child(shape)
	player.add_child(SonicSpindash.new())
	player.add_child(SonicAnimator.new())
	player.add_child(SonicAudio.new())
	var cam := SonicCamera.new()
	player.add_child(cam)
	add_child(player)

	var layer := CanvasLayer.new()
	add_child(layer)
	label = Label.new()
	label.position = Vector2(8, 8)
	layer.add_child(label)


func _process(_d: float) -> void:
	label.text = "estado %s\ngsp %.2f  xsp %.2f  ysp %.2f\nangulo %d  lock %d\nF3 debug | R reiniciar" % [
		player.state, player.gsp, player.xsp, player.ysp, roundi(rad_to_deg(player.ground_angle)), player.control_lock]
	if Input.is_key_pressed(KEY_R):
		get_tree().reload_current_scene()
