extends Node

const MIN_GRID_SIZE := 9
const MAX_GRID_SIZE := 18

# 这个值不再直接决定实际格子大小，只作为桌面端的最大参考尺寸。
const BASE_CELL_SIZE := 80
const MIN_CELL_SIZE := 20
const MAX_CELL_SIZE := 100

# HUD 占用上方空间。棋盘会在剩余区域内居中缩放。
const BOARD_MARGIN_LEFT := 32.0
const BOARD_MARGIN_RIGHT := 32.0
const BOARD_MARGIN_TOP := 140.0
const BOARD_MARGIN_BOTTOM := 32.0

# 运行时布局结果。所有棋盘实体都应该读取这两个值，而不是写死 56 / Vector2(180, 120)。
var cell_size := BASE_CELL_SIZE
var board_offset := Vector2(180, 120)

const KEY_COLOR_NAMES := ["red", "blue", "green", "yellow", "purple", "orange", "cyan", "pink", "white"]

const KEY_COLORS := {
	"red": Color(0.95, 0.18, 0.14),
	"blue": Color(0.15, 0.45, 1.0),
	"green": Color(0.15, 0.85, 0.35),
	"yellow": Color(0.95, 0.82, 0.18),
	"purple": Color(0.68, 0.32, 0.95),
	"orange": Color(1.0, 0.48, 0.12),
	"cyan": Color(0.1, 0.85, 0.95),
	"pink": Color(1.0, 0.35, 0.68),
	"white": Color(0.92, 0.92, 0.88)
}


func update_board_layout(viewport_size: Vector2, grid_size: int, reserved_bottom: float = 0.0) -> void:
	var safe_grid_size: int = maxi(1, grid_size)
	var actual_bottom_margin: float = maxf(BOARD_MARGIN_BOTTOM, reserved_bottom)
	var available_width: float = maxf(1.0, viewport_size.x - BOARD_MARGIN_LEFT - BOARD_MARGIN_RIGHT)
	var available_height: float = maxf(1.0, viewport_size.y - BOARD_MARGIN_TOP - actual_bottom_margin)
	var raw_cell_size: int = int(floor(minf(available_width, available_height) / float(safe_grid_size)))

	# 以“放得下”为最高优先级。窗口极小时允许小于 MIN_CELL_SIZE。
	if raw_cell_size < MIN_CELL_SIZE:
		cell_size = maxi(8, raw_cell_size)
	else:
		cell_size = clampi(raw_cell_size, MIN_CELL_SIZE, MAX_CELL_SIZE)

	var board_size: float = float(cell_size * safe_grid_size)
	var offset_x: float = (viewport_size.x - board_size) / 2.0
	var offset_y: float = BOARD_MARGIN_TOP + maxf(0.0, (available_height - board_size) / 2.0)

	board_offset = Vector2(offset_x, offset_y)


func cell_to_world(cell: Vector2i) -> Vector2:
	return board_offset + Vector2(cell.x * cell_size, cell.y * cell_size)


func get_key_color(color_name: String) -> Color:
	if KEY_COLORS.has(color_name):
		return KEY_COLORS[color_name]

	return Color.WHITE
