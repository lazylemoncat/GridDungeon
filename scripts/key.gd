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

	_draw_key_icon(Vector2(cell_size, cell_size) / 2.0, GameConfig.get_key_color(color_name), 1.0)


func _draw_key_icon(center: Vector2, key_color: Color, scale: float) -> void:
	var head_radius := 8.0 * scale
	var shaft_length := 20.0 * scale
	var shaft_width := 3.0 * scale
	var tooth_size := 5.0 * scale

	var head_center := center + Vector2(-shaft_length * 0.35, 0)
	var shaft_start := center + Vector2(-shaft_length * 0.1, 0)
	var shaft_end := center + Vector2(shaft_length * 0.65, 0)

	draw_circle(head_center, head_radius, key_color)
	draw_circle(head_center, head_radius * 0.45, Color(0.12, 0.12, 0.14))
	draw_line(shaft_start, shaft_end, key_color, shaft_width)
	draw_line(shaft_end, shaft_end + Vector2(0, tooth_size), key_color, shaft_width)
	draw_line(
		shaft_end - Vector2(tooth_size, 0),
		shaft_end - Vector2(tooth_size, 0) + Vector2(0, tooth_size),
		key_color,
		shaft_width
	)


func _cell_to_world(value: Vector2i) -> Vector2:
	return GameConfig.BOARD_OFFSET + Vector2(value.x * cell_size, value.y * cell_size)
