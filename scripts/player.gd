extends Node2D

@export var texture: Texture2D
@export var color := Color(0.1, 0.45, 1.0)

var cell := Vector2i.ZERO
var owned_key_counts := {}


func set_cell(value: Vector2i) -> void:
	cell = value
	refresh_layout()


func refresh_layout() -> void:
	position = _cell_to_world(cell)
	queue_redraw()


func _draw() -> void:
	var size := float(GameConfig.cell_size)
	var center := Vector2(size, size) / 2.0
	var radius := size * 0.32

	if texture != null:
		draw_texture_rect(texture, Rect2(Vector2.ZERO, Vector2(size, size)), false)
	else:
		draw_circle(center, radius, color)

	_draw_owned_key_icons(center, radius)


func clear_keys() -> void:
	owned_key_counts.clear()
	queue_redraw()


func add_key(color_name: String) -> void:
	owned_key_counts[color_name] = int(owned_key_counts.get(color_name, 0)) + 1
	queue_redraw()


func has_key(color_name: String) -> bool:
	return int(owned_key_counts.get(color_name, 0)) > 0


func consume_key(color_name: String) -> bool:
	if not has_key(color_name):
		return false

	var next_count := int(owned_key_counts[color_name]) - 1

	if next_count <= 0:
		owned_key_counts.erase(color_name)
	else:
		owned_key_counts[color_name] = next_count

	queue_redraw()
	return true


func get_key_text() -> String:
	if owned_key_counts.is_empty():
		return "无"

	var parts: Array[String] = []

	for color_name in owned_key_counts.keys():
		parts.append("%s x%d" % [color_name, owned_key_counts[color_name]])

	return ", ".join(parts)


func _draw_owned_key_icons(player_center: Vector2, player_radius: float) -> void:
	var icon_index := 0
	var size_scale := float(GameConfig.cell_size) / 56.0

	for color_name in owned_key_counts.keys():
		var key_color := GameConfig.get_key_color(color_name)
		var count := int(owned_key_counts[color_name])

		for _i in range(count):
			var icon_center := player_center + Vector2(
				player_radius + (13.0 + icon_index * 16.0) * size_scale,
				-player_radius + 5.0 * size_scale
			)

			_draw_key_icon(icon_center, key_color, 0.45 * size_scale)
			icon_index += 1


func _draw_key_icon(center: Vector2, key_color: Color, scale: float) -> void:
	var head_radius := 8.0 * scale
	var shaft_length := 20.0 * scale
	var shaft_width := maxf(1.0, 3.0 * scale)
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
	return GameConfig.cell_to_world(value)
