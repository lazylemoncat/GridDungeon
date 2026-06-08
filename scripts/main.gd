extends Node2D

const MobileControlsScript := preload("res://scripts/ui/mobile_controls.gd")
const RailScript := preload("res://scripts/rail.gd")
const RailLeverScript := preload("res://scripts/rail_lever.gd")

@export var show_mobile_controls := true
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
var rail_cells := {}
var rail_lever_cells := {}
var rail_states := {}
var rail_blocked_cells := {}
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

var mobile_controls
var rails: Node2D
var rail_lever_nodes: Node2D


func _ready() -> void:
	randomize()
	_ensure_movement_containers()
	player.z_index = 10
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	_create_mobile_controls()
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


func _on_viewport_size_changed() -> void:
	_update_board_layout()
	_refresh_existing_floor_layout()
	queue_redraw()


func _update_board_layout() -> void:
	var reserved_bottom := 0.0

	if mobile_controls != null and mobile_controls.has_method("get_reserved_bottom_height"):
		reserved_bottom = float(mobile_controls.get_reserved_bottom_height())

	GameConfig.update_board_layout(get_viewport_rect().size, grid_size, reserved_bottom)


func _refresh_existing_floor_layout() -> void:
	if not has_active_floor:
		return

	if player != null and player.has_method("refresh_layout"):
		player.refresh_layout()

	if stairs != null and stairs.has_method("refresh_layout"):
		stairs.refresh_layout()

	_refresh_container_layout(walls)
	_refresh_container_layout(doors)
	_refresh_container_layout(keys)
	_refresh_container_layout(portals)
	_refresh_container_layout(rails)
	_refresh_container_layout(rail_lever_nodes)


func _refresh_container_layout(container: Node) -> void:
	if container == null:
		return

	for child in container.get_children():
		if child.has_method("refresh_layout"):
			child.refresh_layout()


func _begin_generate_floor(floor_number: int) -> void:
	if is_generating_floor:
		return

	pending_floor_number = floor_number
	is_generating_floor = true
	_set_mobile_controls_enabled(false)
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
	var worker_request_selector := LevelRequestSelector.new()

	for attempt_index in range(LevelRequestSelector.GENERATION_RETRY_COUNT):
		var request: Dictionary = worker_request_selector.pick_level_request(floor_number)
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
		"attempts": LevelRequestSelector.GENERATION_RETRY_COUNT
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
		_set_mobile_controls_enabled(true)
		block_floor_advance_until_player_leaves_exit = false
		return

	_hide_loading_overlay()

	if has_active_floor:
		_set_mobile_controls_enabled(true)
		block_floor_advance_until_player_leaves_exit = true
		push_warning("下一层生成失败，保留当前层。")
		_update_hud()
		return

	_set_mobile_controls_enabled(false)
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
	rail_cells = level.get("rails", {})
	rail_lever_cells = level.get("rail_levers", {})
	rail_states = _make_initial_rail_states(rail_cells)
	rail_blocked_cells = _make_rail_blocked_cells(rail_cells)
	optimal_steps = int(level["optimal_steps"])

	_update_board_layout()

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

	if rail_blocked_cells.has(next_cell):
		return

	if door_cells.has(next_cell):
		var door_color: String = door_cells[next_cell]

		if not player.has_key(door_color):
			return

		player.consume_key(door_color)
		_open_door(next_cell)

	player.set_cell(next_cell)
	_try_activate_rail_lever()
	_try_use_portal()
	_try_use_rail()
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
	var size := float(GameConfig.cell_size)

	for cell in floor_cells:
		var cell_pos := _cell_to_world(cell)
		var rect := Rect2(cell_pos, Vector2(size, size))

		draw_rect(rect, Color(0.18, 0.18, 0.20), true)
		draw_rect(rect, Color(0.65, 0.65, 0.70), false, maxf(1.0, size * 0.035))


func _cell_to_world(cell: Vector2i) -> Vector2:
	return GameConfig.cell_to_world(cell)


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

	_spawn_rail_entities()


func _clear_floor_entities() -> void:
	for container in [walls, doors, keys, portals, rails, rail_lever_nodes]:
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


func _try_activate_rail_lever() -> void:
	if not rail_lever_cells.has(player.cell):
		return

	var lever_data: Dictionary = rail_lever_cells[player.cell]
	var target_rail_id: String = str(lever_data.get("target", ""))

	if target_rail_id == "" or not rail_states.has(target_rail_id):
		return

	_advance_rail_state(target_rail_id)
	_refresh_rail_visuals()


func _try_use_rail() -> void:
	var port_info: Dictionary = _get_rail_port_info(player.cell)

	if port_info.is_empty():
		return

	var rail_id: String = str(port_info["rail_id"])
	var port_index: int = int(port_info["port_index"])

	if not rail_cells.has(rail_id):
		return

	var rail_data: Dictionary = rail_cells[rail_id]
	var ports: Array[Vector2i] = _get_rail_ports(rail_data)
	var connections: Array = _get_rail_connections(rail_data, ports.size())

	if ports.size() < 2 or connections.is_empty():
		return

	var state: int = wrapi(int(rail_states.get(rail_id, int(rail_data.get("state", 0)))), 0, connections.size())
	var connection: Array = connections[state]

	if connection.size() < 2:
		return

	var a: int = int(connection[0])
	var b: int = int(connection[1])

	if a < 0 or a >= ports.size() or b < 0 or b >= ports.size():
		return

	if port_index == a:
		player.set_cell(ports[b])
		return

	if port_index == b:
		player.set_cell(ports[a])
		return


func _get_rail_port_info(cell: Vector2i) -> Dictionary:
	for rail_id in rail_cells.keys():
		var rail_data: Dictionary = rail_cells[rail_id]
		var ports: Array[Vector2i] = _get_rail_ports(rail_data)

		for port_index in range(ports.size()):
			if ports[port_index] == cell:
				return {
					"rail_id": str(rail_id),
					"port_index": port_index
				}

	return {}


func _get_rail_ports(rail_data: Dictionary) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var raw_ports: Array = rail_data.get("ports", [])

	for port in raw_ports:
		if port is Vector2i:
			result.append(port)

	return result


func _get_rail_paths(rail_data: Dictionary) -> Array:
	var result: Array = []
	var raw_paths: Array = rail_data.get("paths", [])

	for raw_path in raw_paths:
		if not (raw_path is Array):
			continue

		var path: Array[Vector2i] = []

		for cell in raw_path:
			if cell is Vector2i:
				path.append(cell)

		if path.size() >= 2:
			result.append(path)

	return result


func _get_rail_connections(rail_data: Dictionary, port_count: int) -> Array:
	var result: Array = []
	var raw_connections: Array = rail_data.get("connections", [])

	for raw_connection in raw_connections:
		if not (raw_connection is Array):
			continue

		var connection: Array = raw_connection as Array

		if connection.size() < 2:
			continue

		var a: int = int(connection[0])
		var b: int = int(connection[1])

		if a == b:
			continue

		if a < 0 or a >= port_count or b < 0 or b >= port_count:
			continue

		result.append([a, b])

	if result.is_empty() and port_count >= 2:
		for i in range(port_count):
			result.append([i, (i + 1) % port_count])

	return result


func _make_rail_blocked_cells(rails_data: Dictionary) -> Dictionary:
	var result := {}

	for rail_id in rails_data.keys():
		var rail_data: Dictionary = rails_data[rail_id]
		var paths: Array = _get_rail_paths(rail_data)

		for path in paths:
			for path_index in range(1, path.size() - 1):
				result[path[path_index]] = true

	return result


func _advance_rail_state(rail_id: String) -> void:
	if not rail_cells.has(rail_id):
		return

	var rail_data: Dictionary = rail_cells[rail_id]
	var ports: Array[Vector2i] = _get_rail_ports(rail_data)
	var connections: Array = _get_rail_connections(rail_data, ports.size())

	if connections.is_empty():
		return

	rail_states[rail_id] = (int(rail_states.get(rail_id, int(rail_data.get("state", 0)))) + 1) % connections.size()


func _make_initial_rail_states(rails_data: Dictionary) -> Dictionary:
	var result := {}

	for rail_id in rails_data.keys():
		var rail_data: Dictionary = rails_data[rail_id]
		var ports: Array[Vector2i] = _get_rail_ports(rail_data)
		var connections: Array = _get_rail_connections(rail_data, ports.size())
		var state: int = int(rail_data.get("state", 0))

		if not connections.is_empty():
			state = wrapi(state, 0, connections.size())

		result[str(rail_id)] = state

	return result


func _spawn_rail_entities() -> void:
	if rails == null or rail_lever_nodes == null:
		return

	for rail_id in rail_cells.keys():
		var rail_data: Dictionary = rail_cells[rail_id]
		var ports: Array[Vector2i] = _get_rail_ports(rail_data)
		var paths: Array = _get_rail_paths(rail_data)
		var connections: Array = _get_rail_connections(rail_data, ports.size())
		var state: int = int(rail_states.get(str(rail_id), int(rail_data.get("state", 0))))
		var color_name: String = str(rail_data.get("color", "cyan"))
		var rail = RailScript.new()
		rails.add_child(rail)
		rail.set_rail_data(str(rail_id), ports, connections, state, color_name, paths)

	for lever_cell in rail_lever_cells.keys():
		var lever_data: Dictionary = rail_lever_cells[lever_cell]
		var target_rail_id: String = str(lever_data.get("target", ""))
		var state: int = int(rail_states.get(target_rail_id, 0))
		var lever = RailLeverScript.new()
		rail_lever_nodes.add_child(lever)
		lever.set_target_rail_id(target_rail_id)
		lever.set_state(state)
		lever.set_cell(lever_cell)


func _refresh_rail_visuals() -> void:
	if rails != null:
		for rail in rails.get_children():
			if rail.has_method("set_state"):
				var rail_id: String = str(rail.rail_id)
				rail.set_state(int(rail_states.get(rail_id, 0)))

	if rail_lever_nodes != null:
		for lever in rail_lever_nodes.get_children():
			if lever.has_method("set_state"):
				var target_rail_id: String = str(lever.target_rail_id)
				lever.set_state(int(rail_states.get(target_rail_id, 0)))


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


func move_player_from_ui(direction: Vector2i) -> void:
	_try_move_player(direction)


func _ensure_movement_containers() -> void:
	var existing_rails := get_node_or_null("Rails")

	if existing_rails is Node2D:
		rails = existing_rails as Node2D
	else:
		rails = Node2D.new()
		rails.name = "Rails"
		add_child(rails)

	rails.z_index = 1

	var existing_rail_levers := get_node_or_null("RailLevers")

	if existing_rail_levers is Node2D:
		rail_lever_nodes = existing_rail_levers as Node2D
	else:
		rail_lever_nodes = Node2D.new()
		rail_lever_nodes.name = "RailLevers"
		add_child(rail_lever_nodes)

	rail_lever_nodes.z_index = 2


func _create_mobile_controls() -> void:
	mobile_controls = MobileControlsScript.new()
	mobile_controls.visible = show_mobile_controls
	mobile_controls.move_requested.connect(move_player_from_ui)
	add_child(mobile_controls)
	mobile_controls.set_input_enabled(false)


func _set_mobile_controls_enabled(enabled: bool) -> void:
	if mobile_controls == null:
		return

	if mobile_controls.has_method("set_input_enabled"):
		mobile_controls.set_input_enabled(enabled)


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
