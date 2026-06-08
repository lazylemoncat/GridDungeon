extends CanvasLayer

signal move_requested(direction: Vector2i)

const DEFAULT_BUTTON_SIZE := 64.0
const MIN_BUTTON_SIZE := 48.0
const MAX_BUTTON_SIZE := 76.0
const EDGE_MARGIN := 24.0
const BOTTOM_MARGIN := 24.0
const BUTTON_ALPHA := 0.78

var root: Control
var up_button: Button
var down_button: Button
var left_button: Button
var right_button: Button
var input_enabled := true
var cached_reserved_bottom_height := 0.0


func _ready() -> void:
	layer = 50
	_build_ui()
	get_viewport().size_changed.connect(_update_layout)
	_update_layout()


func _build_ui() -> void:
	root = Control.new()
	root.name = "MobileControlsRoot"
	root.anchor_right = 1.0
	root.anchor_bottom = 1.0
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	up_button = _create_direction_button("UpButton", "↑", Vector2i(0, -1))
	down_button = _create_direction_button("DownButton", "↓", Vector2i(0, 1))
	left_button = _create_direction_button("LeftButton", "←", Vector2i(-1, 0))
	right_button = _create_direction_button("RightButton", "→", Vector2i(1, 0))

	root.add_child(up_button)
	root.add_child(down_button)
	root.add_child(left_button)
	root.add_child(right_button)


func _create_direction_button(button_name: String, label: String, direction: Vector2i) -> Button:
	var button := Button.new()
	button.name = button_name
	button.text = label
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.pressed.connect(_emit_move_requested.bind(direction))
	_apply_button_style(button)
	return button


func _apply_button_style(button: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.08, 0.09, 0.11, BUTTON_ALPHA)
	normal.border_color = Color(1.0, 1.0, 1.0, 0.32)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(16)
	button.add_theme_stylebox_override("normal", normal)

	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(0.15, 0.17, 0.22, 0.86)
	hover.border_color = Color(1.0, 1.0, 1.0, 0.45)
	hover.set_border_width_all(2)
	hover.set_corner_radius_all(16)
	button.add_theme_stylebox_override("hover", hover)

	var pressed := StyleBoxFlat.new()
	pressed.bg_color = Color(0.25, 0.31, 0.42, 0.92)
	pressed.border_color = Color(1.0, 1.0, 1.0, 0.62)
	pressed.set_border_width_all(2)
	pressed.set_corner_radius_all(16)
	button.add_theme_stylebox_override("pressed", pressed)

	var disabled := StyleBoxFlat.new()
	disabled.bg_color = Color(0.08, 0.08, 0.09, 0.28)
	disabled.border_color = Color(1.0, 1.0, 1.0, 0.12)
	disabled.set_border_width_all(2)
	disabled.set_corner_radius_all(16)
	button.add_theme_stylebox_override("disabled", disabled)


func _update_layout() -> void:
	if root == null:
		return

	var viewport_size := get_viewport().get_visible_rect().size
	var button_size: float = clampf(viewport_size.y * 0.095, MIN_BUTTON_SIZE, MAX_BUTTON_SIZE)
	var gap: float = maxf(8.0, button_size * 0.14)
	var pad_size: float = button_size * 3.0 + gap * 2.0
	var start_x: float = viewport_size.x - pad_size - EDGE_MARGIN
	var start_y: float = viewport_size.y - pad_size - BOTTOM_MARGIN

	start_x = maxf(EDGE_MARGIN, start_x)
	start_y = maxf(EDGE_MARGIN, start_y)
	cached_reserved_bottom_height = viewport_size.y - start_y + EDGE_MARGIN

	_set_button_rect(up_button, Vector2(start_x + button_size + gap, start_y), button_size)
	_set_button_rect(left_button, Vector2(start_x, start_y + button_size + gap), button_size)
	_set_button_rect(right_button, Vector2(start_x + (button_size + gap) * 2.0, start_y + button_size + gap), button_size)
	_set_button_rect(down_button, Vector2(start_x + button_size + gap, start_y + (button_size + gap) * 2.0), button_size)


func _set_button_rect(button: Button, position: Vector2, button_size: float) -> void:
	button.position = position
	button.size = Vector2(button_size, button_size)
	button.custom_minimum_size = Vector2(button_size, button_size)
	button.add_theme_font_size_override("font_size", int(button_size * 0.52))


func _emit_move_requested(direction: Vector2i) -> void:
	if not input_enabled:
		return

	move_requested.emit(direction)


func set_input_enabled(enabled: bool) -> void:
	input_enabled = enabled

	for button in [up_button, down_button, left_button, right_button]:
		if button != null:
			button.disabled = not enabled


func get_reserved_bottom_height() -> float:
	if not visible:
		return 0.0

	return cached_reserved_bottom_height
