extends SceneTree
# godot --headless --path . -s test_headless.gd   (imprime PASS/FAIL)
var level: Node
var p: SonicPlayer
var cam: SonicCamera
var frame := 0
var fails := 0
var min_y := 1e9
var y0 := 0.0
var states := []

func check(name: String, ok: bool, info := "") -> void:
	print("%s  %s %s" % ["PASS" if ok else "FAIL", name, info])
	if not ok: fails += 1

func _initialize() -> void:
	level = load("res://demo/demo.tscn").instantiate()
	root.add_child(level)

func _physics_process(_d: float) -> bool:
	if p == null:
		p = level.player
		p.use_builtin_input = false
		p.debug_draw = false
		cam = p.get_children().filter(func(n): return n is SonicCamera)[0]
		p.state_changed.connect(func(o, n): states.append(str(n)))
	frame += 1
	match frame:
		5: check("pousou no chão sem acertar o próprio corpo", p.grounded and absf(p.global_position.y - 381.0) < 0.5, "y=%.1f" % p.global_position.y)
		6: check("raios do corpo vieram do CollisionShape2D (9 x 19)", p.width_radius == 9.0 and p.height_radius == 19.0)
		10: p.input_right = true
		140: check("corre até o top speed 6", is_equal_approx(p.gsp, 6.0), "gsp=%.2f" % p.gsp)
		141: p.input_right = false; p.input_down = true
		142: check("rolou: CollisionShape2D virou bola (15x29)", p.rolling and (p.collision_shape.shape as RectangleShape2D).size == Vector2(15, 29), "%s" % (p.collision_shape.shape as RectangleShape2D).size)
		143: p.gsp = 0.3
		150: check("desenrolou e voltou a 19x39", (not p.rolling) and (p.collision_shape.shape as RectangleShape2D).size == Vector2(19, 39))
		151: p.input_down = false
		170: y0 = p.global_position.y; p.jump_pressed = true; p.input_jump_held = true
		280: check("apex do pulo ~96 px", y0 - min_y > 90.0 and y0 - min_y < 100.0, "%.1f" % (y0 - min_y))
		290: p.input_down = true
		300, 304, 308: p.jump_pressed = true
		310: check("spin dash carregando (estado)", str(p.state) == "spindash" and p.charging)
		315: p.input_down = false
		316: check("spin dash disparou e rolou", p.rolling and absf(p.gsp) >= 8.0, "gsp=%.2f" % p.gsp)
		325: check("câmera com lag (player à frente)", p.global_position.x - cam.global_position.x > 30.0, "off=%.0f" % (p.global_position.x - cam.global_position.x))
		430: check("câmera alcançou o player", absf(p.global_position.x - cam.global_position.x) < 20.0, "off=%.0f" % (p.global_position.x - cam.global_position.x))
	if frame > 170 and frame < 280: min_y = minf(min_y, p.global_position.y)
	if frame == 431:
		print("estados vistos: ", states)
		check("sinal state_changed emitiu spindash", "spindash" in states and "roll" in states and "jump" in states)
		print("RESULTADO: ", "OK" if fails == 0 else "%d falhas" % fails)
		quit()
	return false
