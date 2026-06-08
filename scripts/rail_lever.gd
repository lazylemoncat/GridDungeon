extends Node2D

var cell := Vector2i.ZERO
var target_rail_id := ""
var state := 0


func set_target_rail_id(value: String) -> void:
	target_rail_id = value
	queue_redraw()


func set_state(value: int) -> void:
	state = value
	queue_redraw()


func set_cell(value: Vector2i) -> void:
	cell = value
	refresh_layout()


func refresh_layout() -> void:
	position = GameConfig.cell_to_world(cell)
	queue_redraw()


func _draw() -> void:
	var size := float(GameConfig.cell_size)
	var center := Vector2(size, size) / 2.0
	var base_radius := size * 0.19
	var knob_radius := size * 0.085
	var line_width := maxf(2.0, size * 0.055)
	var lever_color := Color(0.9, 0.68, 0.18)
	var metal_color := Color(0.35, 0.37, 0.40)
	var tick_count := 8
	var angle := -PI / 2.0 + TAU * float(state % tick_count) / float(tick_count)
	var knob_position := center + Vector2(cos(angle), sin(angle)) * size * 0.27

	draw_circle(center, base_radius, Color(0.06, 0.06, 0.07))
	draw_arc(center, base_radius, 0.0, TAU, 32, metal_color, maxf(1.0, size * 0.04))
	draw_line(center, knob_position, lever_color, line_width)
	draw_circle(knob_position, knob_radius, lever_color.lightened(0.15))
	draw_circle(center, size * 0.06, metal_color.lightened(0.2))
