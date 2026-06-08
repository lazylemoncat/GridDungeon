extends Node

const MIN_GRID_SIZE := 2
const MAX_GRID_SIZE := 18
const CELL_SIZE := 56
const BOARD_OFFSET := Vector2(180, 120)

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


func get_key_color(color_name: String) -> Color:
	if KEY_COLORS.has(color_name):
		return KEY_COLORS[color_name]

	return Color.WHITE
