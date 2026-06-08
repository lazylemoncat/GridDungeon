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

	var rect := Rect2(Vector2.ZERO, Vector2(cell_size, cell_size))
	draw_rect(rect, Color(0.08, 0.08, 0.10), true)
	draw_rect(rect, Color(0.50, 0.50, 0.55), false, 2.0)
	draw_line(Vector2(8, 16), Vector2(cell_size - 8, 16), Color(0.25, 0.25, 0.28), 2.0)
	draw_line(Vector2(8, 36), Vector2(cell_size - 8, 36), Color(0.25, 0.25, 0.28), 2.0)


func _cell_to_world(value: Vector2i) -> Vector2:
	return GameConfig.BOARD_OFFSET + Vector2(value.x * cell_size, value.y * cell_size)
