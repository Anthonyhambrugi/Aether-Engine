extends Node2D
## Teste automatizado (headless) do HarmonyBody + habilidades. Transições
## por condição, com timeout de segurança em cada fase.

@onready var player: HarmonyBody = $Player
var spin: HarmonyAbilitySpindash
var peel: HarmonyAbilityPeelOut
var dj: HarmonyAbilityDoubleJump
var shoes: HarmonyAbilitySpeedShoes
var jump_vy_before := 0.0

var frame := 0
var phase := 0
var ok := true
var saw_ramp_angle := false


func _ready() -> void:
	player.use_player_input = false
	# Spindash/PeelOut/SpeedShoes vêm do loadout de profiles/sonic.tres.
	spin = player.get_ability(HarmonyAbilitySpindash)
	peel = player.get_ability(HarmonyAbilityPeelOut)
	shoes = player.get_ability(HarmonyAbilitySpeedShoes)
	check(spin != null and peel != null and shoes != null, "loadout do profile cria as habilidades (Spindash, PeelOut, SpeedShoes)")
	check(player.abilities.size() == 3, "só as 3 do loadout existem (%d)" % player.abilities.size())
	_api_tests()


func check(cond: bool, msg: String) -> void:
	print(("PASS: " if cond else "FAIL: ") + msg)
	if not cond:
		ok = false


func next(p: int) -> void:
	phase = p
	frame = 0


func timeout(limit: int, msg: String) -> bool:
	if frame >= limit:
		check(false, msg + " (timeout)")
		return true
	return false


func _physics_process(_delta: float) -> void:
	frame += 1

	if absf(rad_to_deg(player.ground_angle)) > 5.0:
		saw_ramp_angle = true

	match phase:
		0:  # cair e assentar no chão plano
			if player.state == HarmonyBody.State.GROUND:
				check(true, "player assenta no chão plano (frame %d, y=%.1f)" % [frame, player.global_position.y])
				next(1)
			elif timeout(120, "nunca assentou no chão"):
				next(1)

		1:  # acelerar pra direita (passa pela rampa) até a top speed
			player.input_right = true
			if is_equal_approx(player.ground_speed, player.profile.top_speed):
				check(true, "atinge top speed andando (%.3f)" % player.ground_speed)
				check(saw_ramp_angle, "detecta ground_angle != 0 ao subir a rampa")
				next(2)
			elif timeout(500, "não atingiu top speed (gsp=%.3f, x=%.1f)" % [player.ground_speed, player.global_position.x]):
				check(saw_ramp_angle, "detecta ground_angle != 0 ao subir a rampa")
				next(2)

		2:  # soltar o direcional, fricção deve zerar
			player.input_right = false
			if is_zero_approx(player.ground_speed):
				check(true, "fricção para o personagem")
				next(3)
			elif timeout(300, "fricção não zerou (gsp=%.3f)" % player.ground_speed):
				next(3)

		3:  # pulo simples (o corpo limpa input_jump_pressed sozinho)
			if frame == 1:
				player.input_jump_pressed = true
			if frame == 2:
				check(player.state == HarmonyBody.State.AIR, "pulo tira do chão")
				check(player.velocity.y < -5.0, "velocidade de pulo plausível (%.3f)" % player.velocity.y)
			if frame > 2 and player.state == HarmonyBody.State.GROUND:
				check(true, "personagem pousou de volta (frame %d)" % frame)
				next(4)
			elif timeout(200, "nunca pousou depois do pulo"):
				next(4)

		4:  # pegar um pouco de velocidade de novo pra poder rolar
			player.input_right = true
			if player.ground_speed >= 1.0:
				next(5)
			elif timeout(200, "não acelerou de novo pra testar o rolar"):
				next(5)

		5:  # rolar
			player.input_right = false
			player.input_down = true
			if player.rolling:
				check(true, "entra em modo rolar com ↓ (gsp=%.3f)" % player.ground_speed)
				next(6)
			elif timeout(30, "nunca começou a rolar (gsp=%.3f)" % player.ground_speed):
				next(6)

		6:  # desenrolar perdendo velocidade
			player.input_down = false
			if not player.rolling:
				check(true, "desenrola ao perder velocidade (gsp=%.4f)" % player.ground_speed)
				next(7)
			elif timeout(400, "nunca desenrolou"):
				next(7)

		7:  # SPINDASH: carregar e soltar
			if frame == 1:
				player.input_down = true
			if frame == 2:
				player.input_jump_pressed = true
			if frame == 3:
				check(spin.charging, "spindash começa a carregar")
				check(not player.rolling, "spindash não rola enquanto ainda carrega")
				player.input_down = false
			if frame == 4:
				check(not spin.charging, "spindash libera ao soltar ↓")
				check(player.rolling, "spindash lança o personagem já rolando")
				check(player.ground_speed >= 8.0 and player.ground_speed <= 9.5, "velocidade de lançamento plausível (%.3f, esperado 8-9.5)" % player.ground_speed)
				next(8)
			elif timeout(20, "spindash não completou o ciclo"):
				next(8)

		8:  # esperar desenrolar depois do spindash antes de testar o peel out
			if not player.rolling:
				check(true, "desenrola depois do spindash")
				next(9)
			elif timeout(500, "não desenrolou depois do spindash (gsp=%.3f)" % player.ground_speed):
				next(9)

		9:  # PEEL OUT: carregar 45 frames e soltar (segurando → pra não perder a velocidade pra fricção logo em seguida)
			if frame == 1:
				player.input_up = true
			if frame == 46:
				player.input_up = false
				player.input_right = true
			if frame == 47:
				check(is_equal_approx(player.ground_speed, peel.launch_speed), "peel out lança na velocidade certa (%.3f, esperado %.1f)" % [player.ground_speed, peel.launch_speed])
				next(10)
			elif timeout(60, "peel out não completou o ciclo (charging=%s frames=%d)" % [peel.charging, peel.frames]):
				next(10)

		10:  # reset: volta pro início do chão plano, parado, pra testar os mods
			player.input_right = false
			player.input_up = false
			player.global_position = Vector2(-300, 200)
			player.velocity = Vector2.ZERO
			player.ground_speed = 0.0
			player.state = HarmonyBody.State.AIR
			phase = 105  # espera pousar antes de começar

		105:
			if player.state == HarmonyBody.State.GROUND:
				next(11)

		11:  # DOUBLE JUMP: adiciona a habilidade em runtime e testa o hook aéreo
			if frame == 1:
				dj = player.add_ability(HarmonyAbilityDoubleJump)
				check(dj != null and player.has_ability(HarmonyAbilityDoubleJump), "add_ability(Script) em runtime registra a habilidade")
				player.input_jump_pressed = true
				player.input_jump_held = true
			elif frame == 2:
				check(player.state == HarmonyBody.State.AIR and dj.used == 0, "pulo normal do chão não gasta o double jump")
			elif frame == 10:
				jump_vy_before = player.velocity.y
				player.input_jump_pressed = true
				player.input_jump_held = true
			elif frame == 11:
				check(dj.used == 1, "pulo no ar aciona o hook on_air_jump_pressed (used=%d)" % dj.used)
				check(is_equal_approx(player.anim_speed.y, player.velocity.y), "anim_speed.y acompanha velocity.y no ar")
				check(is_equal_approx(player.velocity.y, -dj.force + player.stats.gravity), "double jump dá o impulso esperado (vy=%.4f)" % player.velocity.y)
			elif frame == 14:
				jump_vy_before = player.velocity.y
				player.input_jump_pressed = true
				player.input_jump_held = true
			elif frame == 15:
				check(dj.used == 1 and is_equal_approx(player.velocity.y, jump_vy_before + player.stats.gravity), "limite de extra_jumps respeitado (3º pulo não faz nada)")
			elif frame > 15 and player.state == HarmonyBody.State.GROUND:
				check(dj.used == 0, "pousar devolve os pulos extras")
				next(12)
			elif frame > 400:
				check(false, "double jump: nunca pousou (timeout)")
				next(12)

		12:  # enabled = false: o corpo ignora a habilidade
			if frame == 1:
				dj.enabled = false
				player.input_jump_pressed = true
				player.input_jump_held = true
			elif frame == 10:
				jump_vy_before = player.velocity.y
				player.input_jump_pressed = true
				player.input_jump_held = true
			elif frame == 11:
				check(dj.used == 0 and is_equal_approx(player.velocity.y, jump_vy_before + player.stats.gravity), "habilidade desligada (enabled=false) é ignorada")
				dj.enabled = true
			elif frame > 12 and player.state == HarmonyBody.State.GROUND:
				next(13)
			elif frame > 400:
				check(false, "enabled: nunca pousou (timeout)")
				next(13)

		13:  # SPEED SHOES: mod de física temporário, some sozinho
			if frame == 1:
				shoes.activate(30)
				check(is_equal_approx(player.stats.top_speed, 12.0), "speed shoes dobra a top_speed em stats (%.2f)" % player.stats.top_speed)
				check(is_equal_approx(player.profile.top_speed, 6.0), "profile base NÃO é alterado pelos mods (%.2f)" % player.profile.top_speed)
				player.input_right = true
			elif frame == 15:
				check(shoes.is_active() and player.ground_speed > 0.0, "speed shoes ativo no meio da duração")
				check(is_equal_approx(player.anim_speed.x, player.ground_speed), "anim_speed.x = ground_speed no chão")
			elif frame == 40:
				check(not shoes.is_active() and is_equal_approx(player.stats.top_speed, 6.0), "speed shoes expira e a física volta ao normal (%.2f)" % player.stats.top_speed)
				player.input_right = false
				next(14)

		14:  # TROCA DE PERSONAGEM em runtime: física + loadout trocam juntos
			if frame == 1:
				player.remove_ability(dj)  # o dj adicionado em runtime na fase 11
				var feet_before := player.global_position.y + player._hr()
				player.profile = load("res://profiles/tails.tres")
				var feet_after := player.global_position.y + player._hr()
				check(is_equal_approx(player.stats.height_radius, 15.0), "trocar pro Tails muda height_radius (%.1f)" % player.stats.height_radius)
				check(is_equal_approx(feet_before, feet_after), "trocar de raio no chão mantém os pés no lugar (%.2f -> %.2f)" % [feet_before, feet_after])
				check(player.has_ability(HarmonyAbilityDoubleJump), "loadout do Tails traz o double jump")
				check(not player.has_ability(HarmonyAbilityPeelOut) and not player.has_ability(HarmonyAbilitySpeedShoes), "loadout antigo (PeelOut/SpeedShoes) foi removido")
				check(player.has_ability(HarmonyAbilitySpindash), "Spindash continua (está nos dois loadouts)")
				player.profile = load("res://profiles/knuckles.tres")
				check(is_equal_approx(player.stats.jump_force, 6.0) and is_equal_approx(player.stats.height_radius, 19.0), "trocar pro Knuckles muda jump_force e height_radius")
				check(not player.has_ability(HarmonyAbilityDoubleJump), "double jump do Tails foi removido")
				next(15)

		15:  # ZONA DE FÍSICA (Area2D + HarmonyStatEntry): gravidade menor só lá dentro
			if frame == 1:
				player.profile = load("res://profiles/sonic.tres")
				var zone := HarmonyPhysicsZone.new()
				zone.position = Vector2(1100, -60)
				var cs := CollisionShape2D.new()
				var rs := RectangleShape2D.new()
				rs.size = Vector2(500, 400)
				cs.shape = rs
				zone.add_child(cs)
				var e := HarmonyStatEntry.new()
				e.stat = "gravity"
				e.value = 0.4
				zone.modifiers.append(e)
				add_child(zone)
				player.global_position = Vector2(1100, 100)
				player.velocity = Vector2.ZERO
				player.ground_speed = 0.0
			elif frame == 6:
				check(is_equal_approx(player.stats.gravity, 0.21875 * 0.4), "HarmonyPhysicsZone aplica o mod de gravidade ao entrar (%.4f)" % player.stats.gravity)
				player.global_position = Vector2(100, 200)
				player.velocity = Vector2.ZERO
				player.ground_speed = 0.0
				player.state = HarmonyBody.State.AIR
			elif frame == 12:
				check(is_equal_approx(player.stats.gravity, 0.21875), "HarmonyPhysicsZone desfaz o mod ao sair (%.4f)" % player.stats.gravity)
				next(99)

		99:
			print("---")
			print("RESULTADO: %s" % ("TODOS OS TESTES PASSARAM" if ok else "HÁ FALHAS ACIMA"))
			get_tree().quit(0 if ok else 1)


## Testes de API que não dependem de física rodando (síncronos).
func _api_tests() -> void:
	var base_top := player.profile.top_speed

	# --- modificadores: ADD / MULT / SET e como se combinam
	var src_a := "teste_a"
	var src_b := "teste_b"
	player.mod_mul(src_a, &"top_speed", 2.0)
	check(is_equal_approx(player.stats.top_speed, base_top * 2.0), "mod_mul dobra o stat (%.2f)" % player.stats.top_speed)
	player.mod_add(src_b, &"top_speed", 1.0)
	check(is_equal_approx(player.stats.top_speed, (base_top + 1.0) * 2.0), "ADD e MULT combinam: (base+add)*mult (%.2f)" % player.stats.top_speed)
	check(player.remove_mods(src_a) == 1 and is_equal_approx(player.stats.top_speed, base_top + 1.0), "remove_mods(fonte) desfaz só aquela fonte")
	player.mod_set(src_a, &"top_speed", 3.0, 0)
	player.mod_set(src_b, &"top_speed", 9.0, 5)
	check(is_equal_approx(player.stats.top_speed, 9.0), "SET: ganha o de maior priority (%.2f)" % player.stats.top_speed)
	player.clear_mods()
	check(is_equal_approx(player.stats.top_speed, base_top), "clear_mods volta ao base (%.2f)" % player.stats.top_speed)

	# int / bool / enum
	player.mod_mul("ints", &"control_lock_frames", 2.0)
	check(player.stats.control_lock_frames == player.profile.control_lock_frames * 2 and typeof(player.stats.control_lock_frames) == TYPE_INT, "stat int continua int depois do mod (%s)" % str(player.stats.control_lock_frames))
	player.mod_set("bools", &"slope_when_stopped", false)
	check(player.stats.slope_when_stopped == false and player.profile.slope_when_stopped == true, "SET em bool funciona sem tocar no profile")
	player.clear_mods()

	# stat inexistente: erro claro e não quebra
	print("(esperado: um erro 'stat ... não existe' logo abaixo)")
	var bad := player.mod_mul("x", &"top_spedd", 2.0)
	check(bad == null, "stat inexistente devolve null (typo detectado)")
	check(HarmonyProfile.has_stat(&"gravity") and not HarmonyProfile.has_stat(&"ability_scripts"), "HarmonyProfile.has_stat/stat_names")

	# --- habilidades: prioridade, nó filho, remoção, mods somem junto
	var log: Array = []
	var low := _LogAbility.new(); low.tag = "low"; low.priority = 0; low.log = log
	var high := _LogAbility.new(); high.tag = "high"; high.priority = 10; high.log = log
	player.add_child(low)    # entra primeiro...
	player.add_child(high)   # ...mas tem prioridade maior
	check(player.abilities[0] == high, "habilidade de maior priority fica primeiro em body.abilities")
	player._any(&"process_ground")
	check(log == ["high"], "hook bool: a de maior priority que devolve true ganha e as outras nem rodam (%s)" % str(log))
	log.clear()
	high.enabled = false
	player._any(&"process_ground")
	check(log == ["low"] and high.enabled_calls == [false], "desligar: hook é pulado e on_enabled_changed(false) avisa (%s)" % str(log))
	high.enabled = true
	high.priority = -5
	check(player.abilities[player.abilities.size() - 1] == high, "mudar priority em runtime reordena")

	player.mod_mul(low, &"gravity", 0.5)
	check(is_equal_approx(player.stats.gravity, player.profile.gravity * 0.5), "habilidade aplica mod usando a si mesma como fonte")
	check(player.remove_ability(low) and not player.abilities.has(low), "remove_ability(instância) tira da lista")
	check(is_equal_approx(player.stats.gravity, player.profile.gravity), "mods da habilidade removida somem junto")
	check(low.detached and low.body == null, "on_detached chamado e body limpo")
	player.remove_ability(high)
	check(player.abilities.size() == 3, "voltou às 3 habilidades do loadout (%d)" % player.abilities.size())

	# add_ability rejeita script que não é habilidade
	print("(esperado: um erro 'não é uma HarmonyAbility' logo abaixo)")
	var not_ability := player.add_ability(load("res://harmony/harmony_camera.gd"))
	check(not_ability == null and player.abilities.size() == 3, "add_ability rejeita script que não é HarmonyAbility")

	# --- estado de habilidade (set_state / clear_state)
	var st := _LogAbility.new()
	player.add_child(st)
	st.set_state("meu_estado")
	check(player.custom_state == "meu_estado" and st.is_state("meu_estado"), "set_state define o estado de habilidade")
	st.clear_state()
	check(player.custom_state == "", "clear_state limpa o estado")
	st.set_state("meu_estado")
	var other := _LogAbility.new()
	player.add_child(other)
	other.clear_state()
	check(player.custom_state == "meu_estado", "uma habilidade não limpa o estado de outra")
	player.remove_ability(st)
	check(player.custom_state == "", "remover a habilidade limpa o estado dela")
	player.remove_ability(other)

	# --- botão próprio é criado sozinho no InputMap
	var btn := _LogAbility.new()
	btn.button_name = "teste_botao"
	btn.button_key = KEY_F10
	player.add_child(btn)
	check(InputMap.has_action("teste_botao"), "button_name cria a ação no InputMap sozinho")
	player.remove_ability(btn)
	check(player.abilities.size() == 3, "voltou às 3 habilidades do loadout (%d)" % player.abilities.size())


class _LogAbility extends HarmonyAbility:
	var tag := ""
	var log: Array
	var enabled_calls: Array = []
	var detached := false

	func process_ground() -> bool:
		log.append(tag)
		return tag == "high"

	func on_enabled_changed(is_enabled: bool) -> void:
		enabled_calls.append(is_enabled)

	func on_detached() -> void:
		detached = true
