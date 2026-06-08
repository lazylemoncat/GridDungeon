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

	var padding := size * 0.14
	var rect := Rect2(Vector2(padding, padding), Vector2(size - padding * 2.0, size - padding * 2.0))
	var line_width := maxf(1.0, size * 0.04)

	draw_rect(rect, Color(0.85, 0.72, 0.25), true)
	draw_rect(rect, Color(0.3, 0.22, 0.05), false, line_width)

	for i in range(4):
		var step_y := rect.position.y + rect.size.y - size * 0.14 - float(i) * size * 0.16
		var step_x := rect.position.x + size * 0.11 + float(i) * size * 0.14
		draw_line(
			Vector2(step_x, step_y),
			Vector2(rect.position.x + rect.size.x - size * 0.11, step_y),
			Color(0.25, 0.18, 0.04),
			line_width
		)

	var arrow_center := rect.position + rect.size / 2.0
	var arrow_length := size * 0.18
	var arrow_side := size * 0.12
	draw_line(
		arrow_center + Vector2(0, arrow_length),
		arrow_center + Vector2(0, -arrow_length),
		Color(0.25, 0.18, 0.04),
		line_width
	)
	draw_line(
		arrow_center + Vector2(0, -arrow_length),
		arrow_center + Vector2(-arrow_side, -arrow_length * 0.3),
		Color(0.25, 0.18, 0.04),
		line_width
	)
	draw_line(
		arrow_center + Vector2(0, -arrow_length),
		arrow_center + Vector2(arrow_side, -arrow_length * 0.3),
		Color(0.25, 0.18, 0.04),
		line_width
	)


func _cell_to_world(value: Vector2i) -> Vector2:
	return GameConfig.cell_to_world(value)
