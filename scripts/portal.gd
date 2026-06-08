extends Node2D

@export var texture: Texture2D
@export var cell_size := 56
@export var color_name := "blue"

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

	var center := Vector2(cell_size, cell_size) / 2.0
	var portal_color := GameConfig.get_key_color(color_name)

	draw_circle(center, cell_size * 0.36, Color(0.04, 0.04, 0.08))
	draw_arc(center, cell_size * 0.32, 0.0, TAU, 48, portal_color, 4.0)
	draw_arc(center, cell_size * 0.20, 0.0, TAU, 48, portal_color.lightened(0.35), 3.0)
	draw_circle(center, cell_size * 0.08, portal_color.darkened(0.25))


func _cell_to_world(value: Vector2i) -> Vector2:
	return GameConfig.BOARD_OFFSET + Vector2(value.x * cell_size, value.y * cell_size)
