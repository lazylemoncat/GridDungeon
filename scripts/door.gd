extends Node2D

@export var texture: Texture2D
@export var cell_size := 56
@export var color_name := "red"

var cell := Vector2i.ZERO


func set_cell(value: Vector2i) -> void:
	cell = value
	position = _cell_to_world(cell)
	queue_redraw()


func set_color_name(value: String) -> void:
	color_name = value
	queue_redraw()


func _draw() -> void:
	if texture != null:
		draw_texture_rect(texture, Rect2(Vector2.ZERO, Vector2(cell_size, cell_size)), false)
		return

	var door_color := GameConfig.get_key_color(color_name)
	var rect := Rect2(Vector2(7, 5), Vector2(cell_size - 14, cell_size - 10))

	draw_rect(rect, door_color, true)
	draw_rect(rect, Color(0.08, 0.06, 0.03), false, 3.0)
	draw_circle(Vector2(cell_size * 0.72, cell_size * 0.52), 4.0, Color(1.0, 0.9, 0.55))
	draw_rect(Rect2(Vector2(cell_size * 0.38, cell_size * 0.42), Vector2(14, 12)), Color(0.1, 0.1, 0.12), true)


func _cell_to_world(value: Vector2i) -> Vector2:
	return GameConfig.BOARD_OFFSET + Vector2(value.x * cell_size, value.y * cell_size)
