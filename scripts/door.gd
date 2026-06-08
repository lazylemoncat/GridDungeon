extends Node2D

@export var texture: Texture2D
@export var color_name := "red"

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

	var door_color := GameConfig.get_key_color(color_name)
	var rect := Rect2(Vector2(size * 0.125, size * 0.09), Vector2(size * 0.75, size * 0.82))
	var outline_width := maxf(1.0, size * 0.05)

	draw_rect(rect, door_color, true)
	draw_rect(rect, Color(0.08, 0.06, 0.03), false, outline_width)
	draw_circle(Vector2(size * 0.72, size * 0.52), maxf(2.0, size * 0.07), Color(1.0, 0.9, 0.55))
	draw_rect(Rect2(Vector2(size * 0.38, size * 0.42), Vector2(size * 0.25, size * 0.22)), Color(0.1, 0.1, 0.12), true)


func _cell_to_world(value: Vector2i) -> Vector2:
	return GameConfig.cell_to_world(value)
