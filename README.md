我是个第一次使用 godot 的人，我正在学习使用 godot。
创建了项目 GridDungeon，创建了一个 main.tscn 并设置为主场景.

给 main 挂了一个脚本: main.gd
```
extends Node2D

const MIN_GRID_SIZE := 2
const MAX_GRID_SIZE := 9
const CELL_SIZE := 56
const BOARD_OFFSET := Vector2(80, 120)

var grid_size := 5

var player_cell := Vector2i.ZERO
var stair_cell := Vector2i.ZERO

var current_floor := 1
var total_moves := 0
var floor_moves := 0

var stats_label: Label


func _ready() -> void:
	randomize()
	_create_hud()
	_start_new_floor()


func _process(_delta: float) -> void:
	var direction := Vector2i.ZERO

	if Input.is_action_just_pressed("move_up"):
		direction = Vector2i(0, -1)
	elif Input.is_action_just_pressed("move_down"):
		direction = Vector2i(0, 1)
	elif Input.is_action_just_pressed("move_left"):
		direction = Vector2i(-1, 0)
	elif Input.is_action_just_pressed("move_right"):
		direction = Vector2i(1, 0)

	if direction != Vector2i.ZERO:
		_try_move_player(direction)


func _create_hud() -> void:
	var canvas_layer := CanvasLayer.new()
	add_child(canvas_layer)

	stats_label = Label.new()
	stats_label.position = Vector2(20, 20)
	stats_label.add_theme_font_size_override("font_size", 20)
	canvas_layer.add_child(stats_label)


func _start_new_floor() -> void:
	grid_size = randi_range(MIN_GRID_SIZE, MAX_GRID_SIZE)

	player_cell = Vector2i(0, grid_size - 1)
	stair_cell = Vector2i(grid_size - 1, 0)

	floor_moves = 0

	_update_hud()
	queue_redraw()


func _try_move_player(direction: Vector2i) -> void:
	var next_cell := player_cell + direction

	if not _is_inside_grid(next_cell):
		return

	player_cell = next_cell
	total_moves += 1
	floor_moves += 1

	if player_cell == stair_cell:
		current_floor += 1
		_start_new_floor()
	else:
		_update_hud()
		queue_redraw()


func _is_inside_grid(cell: Vector2i) -> bool:
	return (
		cell.x >= 0
		and cell.x < grid_size
		and cell.y >= 0
		and cell.y < grid_size
	)


func _update_hud() -> void:
	stats_label.text = "当前层数：%d\n总移动次数：%d\n当前层移动次数：%d\n网格大小：%d x %d" % [
		current_floor,
		total_moves,
		floor_moves,
		grid_size,
		grid_size
	]


func _draw() -> void:
	_draw_grid()
	_draw_stairs()
	_draw_player()


func _draw_grid() -> void:
	for y in range(grid_size):
		for x in range(grid_size):
			var cell_pos := _cell_to_world(Vector2i(x, y))
			var rect := Rect2(cell_pos, Vector2(CELL_SIZE, CELL_SIZE))

			draw_rect(rect, Color(0.18, 0.18, 0.20), true)
			draw_rect(rect, Color(0.65, 0.65, 0.70), false, 2.0)


func _draw_player() -> void:
	var center := _cell_to_world(player_cell) + Vector2(CELL_SIZE, CELL_SIZE) / 2.0
	var radius := CELL_SIZE * 0.32

	draw_circle(center, radius, Color(0.1, 0.45, 1.0))


func _draw_stairs() -> void:
	var pos := _cell_to_world(stair_cell)
	var rect := Rect2(pos + Vector2(8, 8), Vector2(CELL_SIZE - 16, CELL_SIZE - 16))

	draw_rect(rect, Color(0.85, 0.72, 0.25), true)
	draw_rect(rect, Color(0.3, 0.22, 0.05), false, 2.0)

	# 简单画一个“向上楼梯”的感觉
	for i in range(4):
		var step_y := rect.position.y + rect.size.y - 8 - i * 9
		var step_x := rect.position.x + 6 + i * 8
		draw_line(
			Vector2(step_x, step_y),
			Vector2(rect.position.x + rect.size.x - 6, step_y),
			Color(0.25, 0.18, 0.04),
			3.0
		)

	# 向上箭头
	var arrow_center := rect.position + rect.size / 2.0
	draw_line(
		arrow_center + Vector2(0, 10),
		arrow_center + Vector2(0, -10),
		Color(0.25, 0.18, 0.04),
		3.0
	)
	draw_line(
		arrow_center + Vector2(0, -10),
		arrow_center + Vector2(-7, -3),
		Color(0.25, 0.18, 0.04),
		3.0
	)
	draw_line(
		arrow_center + Vector2(0, -10),
		arrow_center + Vector2(7, -3),
		Color(0.25, 0.18, 0.04),
		3.0
	)


func _cell_to_world(cell: Vector2i) -> Vector2:
	return BOARD_OFFSET + Vector2(cell.x * CELL_SIZE, cell.y * CELL_SIZE)
```

设置了键盘输入: move_up,move_down,move_left,move_right

