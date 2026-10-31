extends Node2D
## Visual provisório: retângulo (em pé) ou círculo (rolando/pulando),
## girando com o visual_angle. Troque por um AnimatedSprite2D quando tiver arte.
## Lê os raios de `body.stats` (já com modificadores aplicados).

@onready var body: HarmonyBody = get_parent()


func _process(_delta: float) -> void:
	rotation = body.visual_angle
	queue_redraw()


func _draw() -> void:
	var p := body.stats
	var col := Color(0.15, 0.4, 1.0)
	if body.rolling or body.jumping:
		draw_circle(Vector2.ZERO, p.roll_height_radius, col)
		draw_line(Vector2.ZERO, Vector2(p.roll_height_radius * body.facing, 0), Color.WHITE, 2.0)
	else:
		draw_rect(Rect2(-p.width_radius, -p.height_radius, p.width_radius * 2.0, p.height_radius * 2.0), col)
		draw_rect(Rect2(3.0 * body.facing - 3.0, -12.0, 6.0, 6.0), Color.WHITE)
