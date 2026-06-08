extends Node2D

@export var texture: Texture2D
@export var cell_size := 56

var cell := Vector2i.ZERO


func set_cell(value: Vector2i) -> void:
	cell = value
	position = _cell_to_world(cell)
	queue_redraw()


func _draw() -> void:
	if texture != null:
		draw_texture_rect(texture, Rect2(Vector2.ZERO, Vector2(cell_size, cell_size)), false)
		return

	var rect := Rect2(Vector2(8, 8), Vector2(cell_size - 16, cell_size - 16))

	draw_rect(rect, Color(0.85, 0.72, 0.25), true)
	draw_rect(rect, Color(0.3, 0.22, 0.05), false, 2.0)

	for i in range(4):
		var step_y := rect.position.y + rect.size.y - 8 - i * 9
		var step_x := rect.position.x + 6 + i * 8
		draw_line(
			Vector2(step_x, step_y),
			Vector2(rect.position.x + rect.size.x - 6, step_y),
			Color(0.25, 0.18, 0.04),
			3.0
		)

	var arrow_center := rect.position + rect.size / 2.0
	draw_line(
		arrow_center + Vector2(0, 10),
		arrow_center + Vector2(0, -10),
		Color(0.25, 0.18, 0.04),
		3.0
	)
	draw_line(
		arrow_center + Vector2(0, -10),
		arrow_center + Vector2(-7, -3),
		Color(0.25, 0.18, 0.04),
		3.0
	)
	draw_line(
		arrow_center + Vector2(0, -10),
		arrow_center + Vector2(7, -3),
		Color(0.25, 0.18, 0.04),
		3.0
	)


func _cell_to_world(value: Vector2i) -> Vector2:
	return GameConfig.BOARD_OFFSET + Vector2(value.x * cell_size, value.y * cell_size)
