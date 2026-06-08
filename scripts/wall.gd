extends Node2D

@export var texture: Texture2D

var cell := Vector2i.ZERO


func set_cell(value: Vector2i) -> void:
	cell = value
	refresh_layout()


func refresh_layout() -> void:
	position = _cell_to_world(cell)
	queue_redraw()


func _draw() -> void:
	var size := float(GameConfig.cell_size)

	if texture != null:
		draw_texture_rect(texture, Rect2(Vector2.ZERO, Vector2(size, size)), false)
		return

	var rect := Rect2(Vector2.ZERO, Vector2(size, size))
	var line_width := maxf(1.0, size * 0.035)

	draw_rect(rect, Color(0.08, 0.08, 0.10), true)
	draw_rect(rect, Color(0.50, 0.50, 0.55), false, line_width)
	draw_line(Vector2(size * 0.14, size * 0.29), Vector2(size * 0.86, size * 0.29), Color(0.25, 0.25, 0.28), line_width)
	draw_line(Vector2(size * 0.14, size * 0.64), Vector2(size * 0.86, size * 0.64), Color(0.25, 0.25, 0.28), line_width)


func _cell_to_world(value: Vector2i) -> Vector2:
	return GameConfig.cell_to_world(value)
