extends CanvasLayer
## HUD de debug: mostra os valores do SPG em tempo real, as habilidades
## ativas e os stats que estão diferentes do profile base (mods).
## Teclas 1..N trocam de personagem em runtime (lista `profiles`) — demo de
## que personagem = 1 .tres (física + loadout de habilidades).

@export var body_path: NodePath
@export var profiles: Array[HarmonyProfile] = []
@onready var label: Label = $Label
@onready var body: HarmonyBody = get_node(body_path) as HarmonyBody


func _unhandled_key_input(event: InputEvent) -> void:
	if body == null or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var i: int = event.keycode - KEY_1
	if i >= 0 and i < profiles.size():
		body.profile = profiles[i]


func _process(_delta: float) -> void:
	if body == null:
		return
	label.text = "%s%s%s\ngsp %.3f   angle %.1f°   mode %s\nvel (%.2f, %.2f)   lock %d   path %s\n\nabilidades: %s\nmods ativos: %s\n\n←/→ move   ↓ rolar   Espaço/Enter pula   ↑ peel out   S speed shoes\n1/2/3 troca de personagem (%s)" % [
		"GROUND" if body.state == HarmonyBody.State.GROUND else "AIR",
		"  ROLL" if body.rolling else "",
		"  JUMP" if body.jumping else "",
		body.ground_speed,
		rad_to_deg(body.ground_angle),
		HarmonyBody.Mode.keys()[body._mode()],
		body.velocity.x,
		body.velocity.y,
		body.control_lock,
		"B" if body.current_path == 1 else "A",
		_abilities_text(),
		_mods_text(),
		", ".join(profiles.map(func(p: HarmonyProfile) -> String: return p.resource_path.get_file().get_basename())),
	]
	label.text += "\nestado: %s" % (body.custom_state if body.custom_state != "" else "—")


func _abilities_text() -> String:
	var names: Array[String] = []
	for a in body.abilities:
		names.append(a.name if a.enabled else a.name + "(off)")
	return ", ".join(names) if not names.is_empty() else "—"


func _mods_text() -> String:
	var diffs: Array[String] = []
	for stat in HarmonyProfile.stat_names():
		var base: Variant = body.profile.get(stat)
		var now: Variant = body.stats.get(stat)
		if base != now:
			diffs.append("%s %s→%s" % [stat, _fmt(base), _fmt(now)])
	return ", ".join(diffs) if not diffs.is_empty() else "—"


func _fmt(v: Variant) -> String:
	return "%.3g" % v if typeof(v) == TYPE_FLOAT else str(v)
