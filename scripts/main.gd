extends Node2D

@export var wall_scene: PackedScene
@export var door_scene: PackedScene
@export var key_scene: PackedScene
@export var portal_scene: PackedScene

@onready var walls := $Walls
@onready var doors := $Doors
@onready var keys := $Keys
@onready var portals := $Portals
@onready var player := $Player
@onready var stairs := $Stairs
@onready var hud := $HUD

var grid_size := 5
var current_floor := 1
var total_moves := 0
var floor_moves := 0
var optimal_steps := -1

var wall_cells: Array[Vector2i] = []
var key_cells := {}
var door_cells := {}
var portal_cells := {}
var floor_cells: Array[Vector2i] = []

var level_generator := LevelGenerator.new()
var difficulty_selector := LevelDifficultySelector.new()


func _ready() -> void:
	randomize()
	_start_new_floor()


func _process(_delta: float) -> void:
	if _try_advance_floor_if_on_exit():
		return

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


func _start_new_floor() -> void:
	var level := {}

	for _attempt in range(LevelDifficultySelector.GENERATION_RETRY_COUNT):
		var settings := difficulty_selector.pick_level_settings()
		level = level_generator.generate(settings["grid_size"], settings["door_count"])

		if not level.is_empty():
			break

	if level.is_empty():
		return

	_clear_floor_entities()
	grid_size = level["grid_size"]
	floor_cells.assign(level["floor_cells"])
	wall_cells.assign(level["walls"])
	key_cells = level["keys"]
	door_cells = level["doors"]
	portal_cells = level["portals"]
	optimal_steps = level["optimal_steps"]

	player.set_cell(level["start"])
	player.clear_keys()
	stairs.set_cell(level["exit"])

	floor_moves = 0
	_spawn_floor_entities()

	_update_hud()
	queue_redraw()


func _try_move_player(direction: Vector2i) -> void:
	var next_cell: Vector2i = player.cell + direction

	if not _is_inside_grid(next_cell):
		return

	if wall_cells.has(next_cell):
		return

	if door_cells.has(next_cell):
		var door_color: String = door_cells[next_cell]

		if not player.has_key(door_color):
			return

		player.consume_key(door_color)
		_open_door(next_cell)

	player.set_cell(next_cell)
	_try_use_portal()
	total_moves += 1
	floor_moves += 1

	_try_pick_up_key()

	if not _try_advance_floor_if_on_exit():
		_update_hud()
		queue_redraw()


func _is_inside_grid(cell: Vector2i) -> bool:
	return floor_cells.has(cell)


func _update_hud() -> void:
	hud.set_stats(current_floor, total_moves, floor_moves, grid_size, player.get_key_text(), optimal_steps)


func _try_advance_floor_if_on_exit() -> bool:
	if player.cell != stairs.cell:
		return false

	current_floor += 1
	_start_new_floor()
	return true


func _draw() -> void:
	_draw_grid()


func _draw_grid() -> void:
	for cell in floor_cells:
		var cell_pos := _cell_to_world(cell)
		var rect := Rect2(cell_pos, Vector2(GameConfig.CELL_SIZE, GameConfig.CELL_SIZE))

		draw_rect(rect, Color(0.18, 0.18, 0.20), true)
		draw_rect(rect, Color(0.65, 0.65, 0.70), false, 2.0)


func _cell_to_world(cell: Vector2i) -> Vector2:
	return GameConfig.BOARD_OFFSET + Vector2(cell.x * GameConfig.CELL_SIZE, cell.y * GameConfig.CELL_SIZE)


func _spawn_floor_entities() -> void:
	for wall_cell in wall_cells:
		var wall := wall_scene.instantiate()
		walls.add_child(wall)
		wall.set_cell(wall_cell)

	for door_cell in door_cells.keys():
		var door := door_scene.instantiate()
		doors.add_child(door)
		door.set_color_name(door_cells[door_cell])
		door.set_cell(door_cell)

	for key_cell in key_cells.keys():
		var key := key_scene.instantiate()
		keys.add_child(key)
		key.set_color_name(key_cells[key_cell])
		key.set_cell(key_cell)

	for portal_cell in portal_cells.keys():
		var portal := portal_scene.instantiate()
		portals.add_child(portal)
		portal.set_color_name(portal_cells[portal_cell])
		portal.set_cell(portal_cell)


func _clear_floor_entities() -> void:
	for container in [walls, doors, keys, portals]:
		for child in container.get_children():
			child.queue_free()


func _try_use_portal() -> void:
	if not portal_cells.has(player.cell):
		return

	var portal_color: String = portal_cells[player.cell]

	for portal_cell in portal_cells.keys():
		if portal_cell == player.cell:
			continue

		if portal_cells[portal_cell] == portal_color:
			player.set_cell(portal_cell)
			return


func _try_pick_up_key() -> void:
	if not key_cells.has(player.cell):
		return

	var key_color: String = key_cells[player.cell]
	player.add_key(key_color)
	key_cells.erase(player.cell)

	for key in keys.get_children():
		if key.cell == player.cell:
			key.queue_free()
			break


func _open_door(cell: Vector2i) -> void:
	door_cells.erase(cell)

	for door in doors.get_children():
		if door.cell == cell:
			door.queue_free()
			break
