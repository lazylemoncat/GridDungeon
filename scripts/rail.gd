extends Node2D

var rail_id := ""
var ports: Array[Vector2i] = []
var connections: Array = []
var paths: Array = []
var state := 0
var color_name := "cyan"


func set_rail_data(
	p_rail_id: String,
	p_ports: Array[Vector2i],
	p_connections: Array,
	p_state: int,
	p_color_name: String,
	p_paths: Array = []
) -> void:
	rail_id = p_rail_id
	ports = p_ports.duplicate()
	connections = p_connections.duplicate(true)
	paths = p_paths.duplicate(true)
	state = p_state
	color_name = p_color_name
	queue_redraw()


func set_state(value: int) -> void:
	state = value
	queue_redraw()


func refresh_layout() -> void:
	queue_redraw()


func _draw() -> void:
	if ports.is_empty():
		return

	var size := float(GameConfig.cell_size)
	var rail_color := GameConfig.get_key_color(color_name)
	var inactive_color := Color(0.24, 0.28, 0.32)
	var base_color := Color(0.05, 0.07, 0.09)
	var active_connection := _get_active_connection()
	var active_a := -1
	var active_b := -1

	if active_connection.size() >= 2:
		active_a = int(active_connection[0])
		active_b = int(active_connection[1])

	if not paths.is_empty():
		_draw_track_paths(paths, rail_color, inactive_color, base_color, size)
		_draw_active_track_path(paths, active_a, active_b, rail_color, base_color, size)

	var centers: Array[Vector2] = []
	var switch_center := Vector2.ZERO

	for port_cell in ports:
		var center := GameConfig.cell_to_world(port_cell) + Vector2(size, size) / 2.0
		centers.append(center)
		switch_center += center

	switch_center /= float(centers.size())

	# 当前连通关系由轨道路上的高亮路径表现；不再画端口之间的直连线。
	if paths.is_empty():
		_draw_active_hands(centers, switch_center, active_a, active_b, rail_color, size)

	_draw_ports(centers, active_a, active_b, rail_color, inactive_color, base_color, size)
	_draw_center(switch_center, rail_color, base_color, size)


func _get_active_connection() -> Array:
	if connections.is_empty():
		return []

	return connections[wrapi(state, 0, connections.size())]


func _draw_active_hands(
	centers: Array[Vector2],
	switch_center: Vector2,
	active_a: int,
	active_b: int,
	rail_color: Color,
	size: float
) -> void:
	if active_a < 0 or active_b < 0:
		return

	if active_a >= centers.size() or active_b >= centers.size():
		return

	# 兼容旧数据：只有没有 paths 的旧轨道才退回中心指针显示。
	var line_width := maxf(3.0, size * 0.075)
	draw_line(switch_center, centers[active_a], rail_color, line_width)
	draw_line(switch_center, centers[active_b], rail_color, line_width)


func _draw_ports(
	centers: Array[Vector2],
	active_a: int,
	active_b: int,
	rail_color: Color,
	inactive_color: Color,
	base_color: Color,
	size: float
) -> void:
	var radius := size * 0.20
	var active_radius := size * 0.25
	var outline_width := maxf(1.0, size * 0.04)

	for i in range(centers.size()):
		var is_active := i == active_a or i == active_b
		var center := centers[i]
		var use_color := rail_color if is_active else inactive_color
		var use_radius := active_radius if is_active else radius

		draw_circle(center, use_radius, base_color)
		draw_arc(center, use_radius, 0.0, TAU, 36, use_color, outline_width)
		draw_circle(center, size * 0.055, use_color)


func _draw_center(switch_center: Vector2, rail_color: Color, base_color: Color, size: float) -> void:
	var center_radius := size * 0.18
	draw_circle(switch_center, center_radius, base_color)
	draw_arc(switch_center, center_radius, 0.0, TAU, 40, rail_color.lightened(0.12), maxf(1.0, size * 0.045))
	draw_circle(switch_center, size * 0.07, rail_color.lightened(0.2))


func _draw_track_paths(raw_paths: Array, rail_color: Color, inactive_color: Color, base_color: Color, size: float) -> void:
	var road_width := size * 0.46
	var cell_padding := size * 0.17
	var track_color := inactive_color.darkened(0.08)
	var sleeper_color := rail_color.darkened(0.28)

	for raw_path in raw_paths:
		if not (raw_path is Array):
			continue

		var path: Array = raw_path

		if path.size() < 3:
			continue

		for i in range(path.size() - 1):
			if not (path[i] is Vector2i) or not (path[i + 1] is Vector2i):
				continue

			var from_cell: Vector2i = path[i]
			var to_cell: Vector2i = path[i + 1]
			_draw_track_connector(from_cell, to_cell, track_color, road_width, size)

		# 端口是可站立节点；只有中间轨道路格子会被画成不可通行的轨道地面。
		for i in range(1, path.size() - 1):
			if not (path[i] is Vector2i):
				continue

			var track_cell: Vector2i = path[i]
			_draw_track_tile(track_cell, track_color, sleeper_color, base_color, cell_padding, size)


func _draw_active_track_path(
	raw_paths: Array,
	active_a: int,
	active_b: int,
	rail_color: Color,
	base_color: Color,
	size: float
) -> void:
	if active_a < 0 or active_b < 0:
		return

	if active_a >= ports.size() or active_b >= ports.size():
		return

	var active_path := _find_path_between_ports(raw_paths, ports[active_a], ports[active_b])

	if active_path.is_empty():
		return

	var active_width := size * 0.30
	var active_padding := size * 0.23
	var active_track_color := rail_color.darkened(0.08)
	var active_sleeper_color := rail_color.lightened(0.18)

	for i in range(active_path.size() - 1):
		if not (active_path[i] is Vector2i) or not (active_path[i + 1] is Vector2i):
			continue

		var from_cell: Vector2i = active_path[i]
		var to_cell: Vector2i = active_path[i + 1]
		_draw_track_connector(from_cell, to_cell, active_track_color, active_width, size)

	for i in range(1, active_path.size() - 1):
		if not (active_path[i] is Vector2i):
			continue

		var track_cell: Vector2i = active_path[i]
		_draw_track_tile(track_cell, active_track_color, active_sleeper_color, base_color, active_padding, size)


func _find_path_between_ports(raw_paths: Array, port_a: Vector2i, port_b: Vector2i) -> Array:
	if port_a == port_b:
		return [port_a]

	var adjacency := {}

	for raw_path in raw_paths:
		if not (raw_path is Array):
			continue

		var path: Array = raw_path

		if path.size() < 2:
			continue

		for i in range(path.size() - 1):
			if not (path[i] is Vector2i) or not (path[i + 1] is Vector2i):
				continue

			var from_cell: Vector2i = path[i]
			var to_cell: Vector2i = path[i + 1]

			if abs(from_cell.x - to_cell.x) + abs(from_cell.y - to_cell.y) != 1:
				continue

			_append_track_neighbor(adjacency, from_cell, to_cell)
			_append_track_neighbor(adjacency, to_cell, from_cell)

	if not adjacency.has(port_a) or not adjacency.has(port_b):
		return []

	var queue: Array[Vector2i] = [port_a]
	var head := 0
	var previous := {}
	previous[port_a] = port_a

	while head < queue.size():
		var current_cell: Vector2i = queue[head]
		head += 1

		if current_cell == port_b:
			break

		var neighbors: Array = adjacency.get(current_cell, [])

		for raw_neighbor in neighbors:
			if not (raw_neighbor is Vector2i):
				continue

			var neighbor: Vector2i = raw_neighbor

			if previous.has(neighbor):
				continue

			previous[neighbor] = current_cell
			queue.append(neighbor)

	if not previous.has(port_b):
		return []

	var result: Array[Vector2i] = []
	var step_cell: Vector2i = port_b

	while step_cell != port_a:
		result.push_front(step_cell)
		step_cell = previous[step_cell]

	result.push_front(port_a)
	return result


func _append_track_neighbor(adjacency: Dictionary, from_cell: Vector2i, to_cell: Vector2i) -> void:
	if not adjacency.has(from_cell):
		adjacency[from_cell] = []

	var neighbors: Array = adjacency[from_cell]

	if not neighbors.has(to_cell):
		neighbors.append(to_cell)
		adjacency[from_cell] = neighbors


func _draw_track_tile(
	cell: Vector2i,
	track_color: Color,
	sleeper_color: Color,
	base_color: Color,
	cell_padding: float,
	size: float
) -> void:
	var cell_origin := GameConfig.cell_to_world(cell)
	var rect := Rect2(
		cell_origin + Vector2(cell_padding, cell_padding),
		Vector2(size - cell_padding * 2.0, size - cell_padding * 2.0)
	)
	var outline_width := maxf(1.0, size * 0.035)

	draw_rect(rect, base_color, true)
	draw_rect(rect, track_color, true)
	draw_rect(rect, sleeper_color, false, outline_width)

	var sleeper_margin := size * 0.24
	var sleeper_width := maxf(1.0, size * 0.035)
	draw_line(
		cell_origin + Vector2(sleeper_margin, size * 0.36),
		cell_origin + Vector2(size - sleeper_margin, size * 0.36),
		sleeper_color.lightened(0.18),
		sleeper_width
	)
	draw_line(
		cell_origin + Vector2(sleeper_margin, size * 0.64),
		cell_origin + Vector2(size - sleeper_margin, size * 0.64),
		sleeper_color.lightened(0.18),
		sleeper_width
	)


func _draw_track_connector(
	from_cell: Vector2i,
	to_cell: Vector2i,
	track_color: Color,
	road_width: float,
	size: float
) -> void:
	var from_center := GameConfig.cell_to_world(from_cell) + Vector2(size, size) / 2.0
	var to_center := GameConfig.cell_to_world(to_cell) + Vector2(size, size) / 2.0
	var delta := to_cell - from_cell

	if abs(delta.x) + abs(delta.y) != 1:
		return

	var rect := Rect2()

	if delta.x != 0:
		var left := minf(from_center.x, to_center.x)
		rect = Rect2(Vector2(left, from_center.y - road_width / 2.0), Vector2(size, road_width))
	else:
		var top := minf(from_center.y, to_center.y)
		rect = Rect2(Vector2(from_center.x - road_width / 2.0, top), Vector2(road_width, size))

	draw_rect(rect, track_color, true)
