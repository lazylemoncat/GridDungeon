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
var current_floor := 0
var total_moves := 0
var floor_moves := 0
var optimal_steps := -1

var wall_cells: Array[Vector2i] = []
var key_cells := {}
var door_cells := {}
var portal_cells := {}
var floor_cells: Array[Vector2i] = []

var has_active_floor := false
var is_generating_floor := false
var pending_floor_number := 0
var generation_thread: Thread
var block_floor_advance_until_player_leaves_exit := false

var loading_layer: CanvasLayer
var loading_root: Control
var loading_spinner_label: Label
var loading_message_label: Label
var loading_frames: Array[String] = ["◜", "◠", "◝", "◞", "◡", "◟"]
var loading_frame_index := 0
var loading_frame_elapsed := 0.0


func _ready() -> void:
	randomize()
	_create_loading_overlay()
	_begin_generate_floor(1)


func _process(delta: float) -> void:
	_update_loading_overlay(delta)
	_poll_generation_thread()

	if is_generating_floor:
		return

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


func _exit_tree() -> void:
	if generation_thread != null and generation_thread.is_started():
		generation_thread.wait_to_finish()


func _begin_generate_floor(floor_number: int) -> void:
	if is_generating_floor:
		return

	pending_floor_number = floor_number
	is_generating_floor = true
	_show_loading_overlay("正在生成第 %d 层..." % floor_number)

	generation_thread = Thread.new()
	var start_error: int = generation_thread.start(Callable(self, "_generate_floor_thread").bind(floor_number))

	if start_error != OK:
		push_warning("无法启动后台生成线程，改为同步生成。")
		generation_thread = null
		var result: Dictionary = _generate_floor_thread(floor_number)
		is_generating_floor = false
		_finish_generation_result(result)


func _generate_floor_thread(floor_number: int) -> Dictionary:
	var worker_generator := LevelGenerator.new()
	var worker_difficulty_selector := LevelDifficultySelector.new()

	for attempt_index in range(LevelDifficultySelector.GENERATION_RETRY_COUNT):
		var request: Dictionary = worker_difficulty_selector.pick_level_request(floor_number)
		var level: Dictionary = worker_generator.generate(
			int(request["grid_size"]),
			-1,
			request["profile"]
		)

		if not level.is_empty():
			return {
				"success": true,
				"floor_number": floor_number,
				"level": level,
				"attempts": attempt_index + 1
			}

	return {
		"success": false,
		"floor_number": floor_number,
		"level": {},
		"attempts": LevelDifficultySelector.GENERATION_RETRY_COUNT
	}


func _poll_generation_thread() -> void:
	if generation_thread == null:
		return

	if generation_thread.is_alive():
		return

	var result: Dictionary = generation_thread.wait_to_finish()
	generation_thread = null
	is_generating_floor = false
	_finish_generation_result(result)


func _finish_generation_result(result: Dictionary) -> void:
	if bool(result.get("success", false)):
		_apply_generated_floor(int(result["floor_number"]), result["level"])
		_hide_loading_overlay()
		block_floor_advance_until_player_leaves_exit = false
		return

	_hide_loading_overlay()

	if has_active_floor:
		block_floor_advance_until_player_leaves_exit = true
		push_warning("下一层生成失败，保留当前层。")
		_update_hud()
		return

	push_error("初始楼层生成失败。请降低难度参数或增加生成尝试次数。")


func _apply_generated_floor(floor_number: int, level: Dictionary) -> void:
	_clear_floor_entities()
	current_floor = floor_number
	grid_size = int(level["grid_size"])
	floor_cells.assign(level["floor_cells"])
	wall_cells.assign(level["walls"])
	key_cells = level["keys"]
	door_cells = level["doors"]
	portal_cells = level["portals"]
	optimal_steps = int(level["optimal_steps"])

	player.set_cell(level["start"])
	player.clear_keys()
	stairs.set_cell(level["exit"])

	floor_moves = 0
	has_active_floor = true
	_spawn_floor_entities()

	_update_hud()
	queue_redraw()


func _try_move_player(direction: Vector2i) -> void:
	if not has_active_floor or is_generating_floor:
		return

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
	if not has_active_floor or is_generating_floor:
		return false

	if player.cell != stairs.cell:
		block_floor_advance_until_player_leaves_exit = false
		return false

	if block_floor_advance_until_player_leaves_exit:
		return false

	_begin_generate_floor(current_floor + 1)
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


func _create_loading_overlay() -> void:
	loading_layer = CanvasLayer.new()
	loading_layer.layer = 100
	add_child(loading_layer)

	loading_root = Control.new()
	loading_root.visible = false
	loading_root.mouse_filter = Control.MOUSE_FILTER_STOP
	loading_root.anchor_right = 1.0
	loading_root.anchor_bottom = 1.0
	loading_layer.add_child(loading_root)

	var background := ColorRect.new()
	background.color = Color(0.0, 0.0, 0.0, 0.45)
	background.anchor_right = 1.0
	background.anchor_bottom = 1.0
	loading_root.add_child(background)

	var box := VBoxContainer.new()
	box.anchor_left = 0.5
	box.anchor_top = 0.5
	box.anchor_right = 0.5
	box.anchor_bottom = 0.5
	box.offset_left = -180.0
	box.offset_top = -90.0
	box.offset_right = 180.0
	box.offset_bottom = 90.0
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 10)
	loading_root.add_child(box)

	loading_spinner_label = Label.new()
	loading_spinner_label.text = loading_frames[0]
	loading_spinner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	loading_spinner_label.add_theme_font_size_override("font_size", 64)
	box.add_child(loading_spinner_label)

	loading_message_label = Label.new()
	loading_message_label.text = "正在生成关卡..."
	loading_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	loading_message_label.add_theme_font_size_override("font_size", 22)
	box.add_child(loading_message_label)

	var hint_label := Label.new()
	hint_label.text = "正在搜索可解且难度合适的地图"
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.add_theme_font_size_override("font_size", 15)
	hint_label.modulate = Color(1.0, 1.0, 1.0, 0.72)
	box.add_child(hint_label)


func _show_loading_overlay(message: String) -> void:
	if loading_root == null:
		return

	loading_message_label.text = message
	loading_frame_index = 0
	loading_frame_elapsed = 0.0
	loading_spinner_label.text = loading_frames[loading_frame_index]
	loading_root.visible = true


func _hide_loading_overlay() -> void:
	if loading_root == null:
		return

	loading_root.visible = false


func _update_loading_overlay(delta: float) -> void:
	if loading_root == null or not loading_root.visible:
		return

	loading_frame_elapsed += delta

	if loading_frame_elapsed < 0.08:
		return

	loading_frame_elapsed = 0.0
	loading_frame_index = (loading_frame_index + 1) % loading_frames.size()
	loading_spinner_label.text = loading_frames[loading_frame_index]
