class_name HarmonyPathSwitch
extends Area2D
## Troca o caminho de colisão do jogador (A/B) ao tocar, como nos loops
## do Sonic (SPG:Terrain Interaction). Precisa que o jogador tenha uma
## Area2D na layer 8 (o "Hitbox" do player.tscn).

@export_range(0, 1) var path_id := 0
## Layer(s) em que procurar o Hitbox do jogador (padrão: layer 8).
## (Antes dependia do collision_mask padrão da Area2D, que é 1 e nunca
## enxergava o Hitbox na layer 8.)
@export_flags_2d_physics var detect_layers := 128


func _ready() -> void:
	collision_layer = 0
	collision_mask = detect_layers
	area_entered.connect(_on_area_entered)


func _on_area_entered(area: Area2D) -> void:
	var body := area.get_parent()
	if body is HarmonyBody:
		body.set_path(path_id)
