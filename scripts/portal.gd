extends Node2D

@export var texture: Texture2D
@export var color_name := "blue"

var cell := Vector2i.ZERO


func set_cell(value: Vector2i) -> void:
	cell = value
	refresh_layout()


func refresh_layout() -> void:
	position = _cell_to_world(cell)
	queue_redraw()


func set_color_name(value: String) -> void:
	color_name = value
	queue_redraw()


func _draw() -> void:
	var size := float(GameConfig.cell_size)

	if texture != null:
		draw_texture_rect(texture, Rect2(Vector2.ZERO, Vector2(size, size)), false)
		return

	var center := Vector2(size, size) / 2.0
	var portal_color := GameConfig.get_key_color(color_name)

	draw_circle(center, size * 0.36, Color(0.04, 0.04, 0.08))
	draw_arc(center, size * 0.32, 0.0, TAU, 48, portal_color, maxf(1.0, size * 0.07))
	draw_arc(center, size * 0.20, 0.0, TAU, 48, portal_color.lightened(0.35), maxf(1.0, size * 0.05))
	draw_circle(center, size * 0.08, portal_color.darkened(0.25))


func _cell_to_world(value: Vector2i) -> Vector2:
	return GameConfig.cell_to_world(value)
