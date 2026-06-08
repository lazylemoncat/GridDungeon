class_name LevelGenerator
extends RefCounted

const DIRS: Array[Vector2i] = [
	Vector2i(1, 0),
	Vector2i(-1, 0),
	Vector2i(0, 1),
	Vector2i(0, -1)
]

const INVALID_CELL := Vector2i(-1, -1)
const MAX_BITMASK_ENTITY_COUNT := 60


const ENTITY_KEY := "key"
const ENTITY_DOOR := "door"
const ENTITY_PORTAL := "portal"
const ENTITY_BOMB := "bomb" # future: collected resource, can destroy breakable walls / doors.
const ENTITY_RAIL := "rail" # future: forced movement cell.
const ENTITY_RAIL_LEVER := "rail_lever" # future: changes rail destination / routing state.

const TERRAIN_FLOOR := "floor"
const TERRAIN_WALL := "wall"
const TERRAIN_BREAKABLE_WALL := "breakable_wall" # future: destroyed by bomb.
const TERRAIN_IRON_WALL := "iron_wall" # future: cannot be destroyed by bomb.

const LAYER_TERRAIN := "terrain"
const LAYER_BLOCKING := "blocking"
const LAYER_ITEM := "item"
const LAYER_MOVEMENT := "movement"
const LAYER_SPECIAL := "special"

const DEFAULT_GENERATION_PROFILE := {
	"max_generation_attempts": 300,
	"min_floor_ratio": 0.64,
	"max_floor_ratio": 0.86,
	"min_floor_count": 4,
	"min_extra_leaves": 3,
	"main_path_door_spacing": 4,
	"required_gate_min": 1,
	"required_gate_max": 3,
	"target_min_steps": 0,
	"target_max_steps": 999999,
	"require_unique_optimal_solution": true,
	"solution_policy": "unique_optimal",
	"decoy_door_extra_max": 2,
	"loose_key_min": 1,
	"loose_key_max": 3,
	"portal_pair_min": 1,
	"portal_pair_max": 2,
	"return_failure_report": false,
	"future_bomb_enabled": false,
	"future_rail_enabled": false
}

var rng := RandomNumberGenerator.new()


# SolverState is intentionally mechanism-oriented, not level-object-oriented.
# Future mechanics can store additional compact signatures in `extra`, for example:
# - bomb_count: int
# - destroyed_blocking_mask: int
# - rail_switch_mask: int
class SolverState:
	var cell: Vector2i = Vector2i.ZERO
	var key_counts: Array[int] = []
	var picked_key_mask: int = 0
	var opened_door_mask: int = 0
	var extra: Dictionary = {}

	func _init(p_cell: Vector2i = Vector2i.ZERO, p_key_counts: Array[int] = []) -> void:
		cell = p_cell
		key_counts = p_key_counts.duplicate()

	func clone():
		var result := SolverState.new(cell, key_counts)
		result.picked_key_mask = picked_key_mask
		result.opened_door_mask = opened_door_mask
		result.extra = extra.duplicate(true)
		return result


class SolverContext:
	var grid_size: int = 0
	var floor_set: Dictionary = {}
	var exit_cell: Vector2i = Vector2i.ZERO
	var key_colors: Array[String] = []
	var color_to_index: Dictionary = {}
	var key_cell_to_index: Dictionary = {}
	var key_cell_to_color: Dictionary = {}
	var door_cell_to_index: Dictionary = {}
	var door_cell_to_color: Dictionary = {}
	var portal_links: Dictionary = {}
	var rules: Array = []


# Mechanic rules are deliberately duck-typed.
# A new mechanic only needs to implement the same methods and be appended to context.rules.
class DoorMechanicRule:
	func can_enter(context, _from_cell: Vector2i, to_cell: Vector2i, state) -> bool:
		if not context.door_cell_to_color.has(to_cell):
			return true

		var door_index: int = int(context.door_cell_to_index[to_cell])

		if (state.opened_door_mask & (1 << door_index)) != 0:
			return true

		var door_color: String = context.door_cell_to_color[to_cell]

		if not context.color_to_index.has(door_color):
			return false

		return state.key_counts[int(context.color_to_index[door_color])] > 0

	func on_enter(context, cell: Vector2i, state) -> void:
		if not context.door_cell_to_color.has(cell):
			return

		var door_index: int = int(context.door_cell_to_index[cell])

		if (state.opened_door_mask & (1 << door_index)) != 0:
			return

		var door_color: String = context.door_cell_to_color[cell]

		if not context.color_to_index.has(door_color):
			return

		var color_index: int = int(context.color_to_index[door_color])
		state.key_counts[color_index] = maxi(0, state.key_counts[color_index] - 1)
		state.opened_door_mask = state.opened_door_mask | (1 << door_index)

	func after_enter(_context, cell: Vector2i, _state) -> Vector2i:
		return cell


class KeyMechanicRule:
	func can_enter(_context, _from_cell: Vector2i, _to_cell: Vector2i, _state) -> bool:
		return true

	func on_enter(context, cell: Vector2i, state) -> void:
		if not context.key_cell_to_index.has(cell):
			return

		var key_index: int = int(context.key_cell_to_index[cell])

		if (state.picked_key_mask & (1 << key_index)) != 0:
			return

		var key_color: String = context.key_cell_to_color[cell]

		if not context.color_to_index.has(key_color):
			return

		var color_index: int = int(context.color_to_index[key_color])
		state.key_counts[color_index] += 1
		state.picked_key_mask = state.picked_key_mask | (1 << key_index)

	func after_enter(_context, cell: Vector2i, _state) -> Vector2i:
		return cell


class PortalMechanicRule:
	func can_enter(_context, _from_cell: Vector2i, _to_cell: Vector2i, _state) -> bool:
		return true

	func on_enter(_context, _cell: Vector2i, _state) -> void:
		pass

	func after_enter(context, cell: Vector2i, _state) -> Vector2i:
		if context.portal_links.has(cell):
			return context.portal_links[cell]

		return cell


func generate(grid_size: int, seed: int = -1, profile: Dictionary = {}) -> Dictionary:
	if seed >= 0:
		rng.seed = seed
	else:
		rng.randomize()

	var generation_profile := _make_generation_profile(grid_size, profile)
	var safe_grid_size: int = generation_profile["grid_size"]
	var max_attempts: int = int(generation_profile["max_generation_attempts"])
	var require_unique_optimal_solution: bool = bool(generation_profile["require_unique_optimal_solution"])
	var fail_reasons := {}

	for attempt in range(max_attempts):
		var level := _try_generate(safe_grid_size, generation_profile, fail_reasons)

		if level.is_empty():
			continue

		var solved := solve_level(level, require_unique_optimal_solution, false)

		if not solved["found"]:
			_record_fail(fail_reasons, "solver_no_solution")
			continue

		if require_unique_optimal_solution and int(solved["optimal_solution_count"]) != 1:
			_record_fail(fail_reasons, "not_unique_optimal_solution")
			continue

		if not _matches_difficulty_target(solved, generation_profile):
			_record_fail(fail_reasons, "difficulty_target_mismatch")
			continue

		var solved_with_path := solve_level(level, false, true)

		level["optimal_steps"] = solved_with_path["steps"]
		level["optimal_path"] = solved_with_path["path"]
		level["optimal_solution_count"] = solved_with_path["optimal_solution_count"]
		level["solution_count"] = solved_with_path["optimal_solution_count"] # Legacy alias.
		level["generation_debug"] = {
			"attempt": attempt + 1,
			"fail_reasons": fail_reasons.duplicate(),
			"solution_policy": generation_profile["solution_policy"],
			"profile": generation_profile.duplicate(),
			"solver_state_count": solved_with_path.get("state_count", 0),
			"solver_max_queue_size": solved_with_path.get("max_queue_size", 0)
		}
		return level

	push_error("关卡生成失败：尝试次数过多。失败统计：%s" % [str(fail_reasons)])

	if bool(generation_profile["return_failure_report"]):
		return {
			"failed": true,
			"fail_reasons": fail_reasons,
			"generation_profile": generation_profile
		}

	return {}


func _try_generate(
	grid_size: int,
	generation_profile: Dictionary,
	fail_reasons: Dictionary
) -> Dictionary:
	var total_cell_count := grid_size * grid_size
	var target_floor_count := clampi(
		int(total_cell_count * rng.randf_range(
			float(generation_profile["min_floor_ratio"]),
			float(generation_profile["max_floor_ratio"])
		)),
		int(generation_profile["min_floor_count"]),
		total_cell_count
	)

	var floor_cells := _build_tree_cells(grid_size, target_floor_count)

	if floor_cells.size() < int(target_floor_count * 0.85):
		_record_fail(fail_reasons, "not_enough_floor")
		return {}

	var floor_set := _make_set(floor_cells)
	var adjacency := _build_adjacency(floor_set, grid_size)
	var leaves := _get_leaves(adjacency)

	var door_count_by_leaves := leaves.size() - int(generation_profile["min_extra_leaves"])

	if door_count_by_leaves < 1:
		_record_fail(fail_reasons, "not_enough_leaves")
		return {}

	var random_leaf: Vector2i = leaves[rng.randi_range(0, leaves.size() - 1)]
	var start_cell := _farthest_leaf(random_leaf, adjacency)
	var exit_cell := _farthest_leaf(start_cell, adjacency)
	var main_path := _find_path(start_cell, exit_cell, adjacency)

	var spacing := int(generation_profile["main_path_door_spacing"])
	var required_gate_count := _choose_required_gate_count(main_path.size(), door_count_by_leaves, generation_profile)

	if required_gate_count < 1:
		_record_fail(fail_reasons, "main_path_too_short")
		return {}

	var path_set := _make_set(main_path)
	var door_indices := _choose_door_indices(main_path.size(), required_gate_count, spacing)

	if door_indices.size() != required_gate_count:
		_record_fail(fail_reasons, "door_indices_failed")
		return {}

	var occupied := {}
	occupied[start_cell] = true
	occupied[exit_cell] = true

	var doors := {}
	var keys := {}
	var portals := {}
	var used_colors := {}
	var required_colors := _make_door_color_sequence(required_gate_count)

	for i in range(required_gate_count):
		var door_index: int = door_indices[i]
		var door_cell: Vector2i = main_path[door_index]
		var color_name: String = required_colors[i]

		doors[door_cell] = color_name
		occupied[door_cell] = true
		used_colors[color_name] = true

	var previous_door_index := 0

	for i in range(required_gate_count):
		var door_index: int = door_indices[i]
		var color_name: String = required_colors[i]
		var zone_cells := _collect_zone_cells(main_path, adjacency, previous_door_index, door_index - 1, path_set)
		var key_cell := _choose_key_cell(zone_cells, adjacency, path_set, occupied, start_cell, exit_cell, doors)

		if key_cell == INVALID_CELL:
			_record_fail(fail_reasons, "key_place_failed")
			return {}

		keys[key_cell] = color_name
		occupied[key_cell] = true
		previous_door_index = door_index

	_add_decoy_mechanics(
		floor_cells,
		adjacency,
		path_set,
		occupied,
		keys,
		doors,
		portals,
		used_colors,
		start_cell,
		exit_cell,
		required_gate_count,
		generation_profile
	)

	var wall_cells: Array[Vector2i] = []

	for y in range(grid_size):
		for x in range(grid_size):
			var cell := Vector2i(x, y)

			if not floor_set.has(cell):
				wall_cells.append(cell)

	return _build_level_data(
		grid_size,
		floor_cells,
		wall_cells,
		start_cell,
		exit_cell,
		keys,
		doors,
		portals,
		used_colors,
		main_path,
		door_indices,
		generation_profile
	)


func solve_level(level: Dictionary, stop_after_multiple_optimal := false, store_path := true) -> Dictionary:
	var context = _build_solver_context(level)

	if context == null:
		return {
			"found": false,
			"steps": -1,
			"optimal_solution_count": 0,
			"solution_count": 0,
			"path": [],
			"state_count": 0,
			"max_queue_size": 0
		}

	var start_cell: Vector2i = _get_start_cell(level)
	var start_key_counts: Array[int] = []
	start_key_counts.resize(context.key_colors.size())
	start_key_counts.fill(0)

	var start_state := SolverState.new(start_cell, start_key_counts)

	# Preserve the original behavior: the start cell can grant an item, but start-cell portal
	# movement is not automatically applied unless the player moves onto a portal later.
	for rule in context.rules:
		rule.on_enter(context, start_cell, start_state)

	var start_state_key := _make_state_key(context, start_state)
	var queue: Array = [start_state]
	var head := 0
	var distances := {}
	var ways := {}
	var previous_state := {}
	var state_cell := {}

	distances[start_state_key] = 0
	ways[start_state_key] = 1
	state_cell[start_state_key] = start_cell

	if store_path:
		previous_state[start_state_key] = ""

	var best_steps := -1
	var max_queue_size := 1

	while head < queue.size():
		if queue.size() > max_queue_size:
			max_queue_size = queue.size()

		var current_state = queue[head]
		head += 1

		var current_state_key := _make_state_key(context, current_state)
		var current_distance: int = distances[current_state_key]

		if best_steps != -1 and current_distance >= best_steps:
			continue

		for direction in DIRS:
			var next_state = _try_move_state(context, current_state, direction)

			if next_state == null:
				continue

			var next_state_key := _make_state_key(context, next_state)
			var next_distance := current_distance + 1

			if not distances.has(next_state_key):
				distances[next_state_key] = next_distance
				ways[next_state_key] = ways[current_state_key]
				state_cell[next_state_key] = next_state.cell

				if store_path:
					previous_state[next_state_key] = current_state_key

				queue.append(next_state)

				if next_state.cell == context.exit_cell and (best_steps == -1 or next_distance < best_steps):
					best_steps = next_distance
			elif distances[next_state_key] == next_distance:
				ways[next_state_key] = int(ways[next_state_key]) + int(ways[current_state_key])

	if best_steps == -1:
		return {
			"found": false,
			"steps": -1,
			"optimal_solution_count": 0,
			"solution_count": 0,
			"path": [],
			"state_count": distances.size(),
			"max_queue_size": max_queue_size
		}

	var optimal_solution_count := 0
	var best_exit_state_key := ""

	for state_key in distances.keys():
		if state_cell[state_key] != context.exit_cell:
			continue

		if distances[state_key] != best_steps:
			continue

		optimal_solution_count += int(ways[state_key])

		if best_exit_state_key == "":
			best_exit_state_key = state_key

		if stop_after_multiple_optimal and optimal_solution_count > 1:
			return {
				"found": true,
				"steps": best_steps,
				"optimal_solution_count": optimal_solution_count,
				"solution_count": optimal_solution_count,
				"path": [],
				"state_count": distances.size(),
				"max_queue_size": max_queue_size
			}

	var path: Array[Vector2i] = []

	if store_path and best_exit_state_key != "":
		path = _reconstruct_state_path(best_exit_state_key, previous_state, state_cell)

	return {
		"found": true,
		"steps": best_steps,
		"optimal_solution_count": optimal_solution_count,
		"solution_count": optimal_solution_count, # Legacy alias.
		"path": path,
		"state_count": distances.size(),
		"max_queue_size": max_queue_size
	}


func _try_move_state(context, current_state, direction: Vector2i):
	var target_cell: Vector2i = current_state.cell + direction

	if not context.floor_set.has(target_cell):
		return null

	for rule in context.rules:
		if not rule.can_enter(context, current_state.cell, target_cell, current_state):
			return null

	var next_state = current_state.clone()

	for rule in context.rules:
		rule.on_enter(context, target_cell, next_state)

	var final_cell := target_cell

	for rule in context.rules:
		final_cell = rule.after_enter(context, final_cell, next_state)

	next_state.cell = final_cell
	return next_state


func _build_solver_context(level: Dictionary):
	var context := SolverContext.new()
	context.grid_size = int(level.get("grid_size", 0))
	context.floor_set = _make_set(_get_floor_cells(level))
	context.exit_cell = _get_exit_cell(level)

	var keys := _get_key_map(level)
	var doors := _get_door_map(level)
	var portals := _get_portal_map(level)

	if level.has("key_colors"):
		context.key_colors = _normalize_color_array(level["key_colors"])
	else:
		context.key_colors = _collect_key_colors(keys, doors)

	for i in range(context.key_colors.size()):
		context.color_to_index[context.key_colors[i]] = i

	var key_cells := keys.keys()
	_sort_vector2i_array(key_cells)

	if key_cells.size() > MAX_BITMASK_ENTITY_COUNT:
		push_error("钥匙数量超过 bitmask 求解器上限：%d" % [key_cells.size()])
		return null

	for i in range(key_cells.size()):
		var cell: Vector2i = key_cells[i]
		context.key_cell_to_index[cell] = i
		context.key_cell_to_color[cell] = keys[cell]

	var door_cells := doors.keys()
	_sort_vector2i_array(door_cells)

	if door_cells.size() > MAX_BITMASK_ENTITY_COUNT:
		push_error("门数量超过 bitmask 求解器上限：%d" % [door_cells.size()])
		return null

	for i in range(door_cells.size()):
		var cell: Vector2i = door_cells[i]
		context.door_cell_to_index[cell] = i
		context.door_cell_to_color[cell] = doors[cell]

	if level.has("portal_links"):
		context.portal_links = level["portal_links"]
	else:
		context.portal_links = _build_portal_links(portals)

	# Rule order preserves current behavior: door cost -> key pickup -> portal movement.
	context.rules = [
		DoorMechanicRule.new(),
		KeyMechanicRule.new(),
		PortalMechanicRule.new()
	]

	return context


func _build_level_data(
	grid_size: int,
	floor_cells: Array[Vector2i],
	wall_cells: Array[Vector2i],
	start_cell: Vector2i,
	exit_cell: Vector2i,
	keys: Dictionary,
	doors: Dictionary,
	portals: Dictionary,
	used_colors: Dictionary,
	main_path: Array,
	door_indices: Array,
	generation_profile: Dictionary
) -> Dictionary:
	var key_colors := _sort_colors_by_config(_collect_used_colors(keys, doors))
	var portal_links := _build_portal_links(portals)
	var terrain := {
		"floor_cells": floor_cells,
		"wall_cells": wall_cells,
		"walls": wall_cells,
		"breakable_wall_cells": [],
		"iron_wall_cells": []
	}
	var markers := {
		"start": start_cell,
		"exit": exit_cell
	}
	var layers := {
		LAYER_TERRAIN: terrain,
		LAYER_BLOCKING: {
			"doors": doors,
			"future_breakable_doors": {},
			"future_iron_doors": {}
		},
		LAYER_ITEM: {
			"keys": keys,
			"future_bombs": {}
		},
		LAYER_MOVEMENT: {
			"future_rails": {},
			"future_rail_levers": {}
		},
		LAYER_SPECIAL: {
			"portals": portals
		}
	}

	return {
		"grid_size": grid_size,
		"terrain": terrain,
		"markers": markers,
		"layers": layers,
		"entities": _build_entities(keys, doors, portals),
		"mechanic_schema_version": 2,
		"mechanic_rules": [ENTITY_DOOR, ENTITY_KEY, ENTITY_PORTAL],
		"generation_profile": generation_profile.duplicate(),
		"portal_links": portal_links,
		"key_colors": key_colors,
		"main_path": main_path,
		"door_indices": door_indices,
		"required_gate_count": door_indices.size(),
		"optimal_steps": -1,
		"optimal_path": [],
		"optimal_solution_count": 0,
		"solution_count": 0,

		# Legacy fields retained for existing renderers / callers.
		"floor_cells": floor_cells,
		"walls": wall_cells,
		"start": start_cell,
		"exit": exit_cell,
		"keys": keys,
		"doors": doors,
		"portals": portals
	}


func _build_entities(keys: Dictionary, doors: Dictionary, portals: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var key_cells := keys.keys()
	var door_cells := doors.keys()
	var portal_cells := portals.keys()
	_sort_vector2i_array(key_cells)
	_sort_vector2i_array(door_cells)
	_sort_vector2i_array(portal_cells)

	for cell in key_cells:
		result.append({
			"type": ENTITY_KEY,
			"layer": LAYER_ITEM,
			"cell": cell,
			"color": keys[cell]
		})

	for cell in door_cells:
		result.append({
			"type": ENTITY_DOOR,
			"layer": LAYER_BLOCKING,
			"cell": cell,
			"color": doors[cell]
		})

	for cell in portal_cells:
		result.append({
			"type": ENTITY_PORTAL,
			"layer": LAYER_SPECIAL,
			"cell": cell,
			"group": portals[cell]
		})

	return result


func _make_generation_profile(grid_size: int, overrides: Dictionary) -> Dictionary:
	var result := DEFAULT_GENERATION_PROFILE.duplicate(true)

	for key in overrides.keys():
		result[key] = overrides[key]

	result["grid_size"] = clampi(grid_size, GameConfig.MIN_GRID_SIZE, GameConfig.MAX_GRID_SIZE)
	result["required_gate_min"] = maxi(1, int(result["required_gate_min"]))
	result["required_gate_max"] = maxi(int(result["required_gate_min"]), int(result["required_gate_max"]))
	result["main_path_door_spacing"] = maxi(1, int(result["main_path_door_spacing"]))
	result["target_min_steps"] = maxi(0, int(result["target_min_steps"]))
	result["target_max_steps"] = maxi(int(result["target_min_steps"]), int(result["target_max_steps"]))
	result["min_floor_count"] = clampi(int(result["min_floor_count"]), 2, result["grid_size"] * result["grid_size"])

	return result


func _record_fail(fail_reasons: Dictionary, reason: String) -> void:
	if not fail_reasons.has(reason):
		fail_reasons[reason] = 0

	fail_reasons[reason] = int(fail_reasons[reason]) + 1


func _build_tree_cells(grid_size: int, target_floor_count: int) -> Array[Vector2i]:
	var floor_cells: Array[Vector2i] = []
	var floor_set := {}
	var start_cell := Vector2i(rng.randi_range(0, grid_size - 1), rng.randi_range(0, grid_size - 1))

	floor_cells.append(start_cell)
	floor_set[start_cell] = true

	var guard := 0

	while floor_cells.size() < target_floor_count and guard < 10000:
		guard += 1

		var candidate_set := {}

		for floor_cell in floor_cells:
			for direction in DIRS:
				var next_cell: Vector2i = floor_cell + direction

				if _is_inside_grid(next_cell, grid_size) and not floor_set.has(next_cell):
					if _count_floor_neighbors(next_cell, floor_set, grid_size) == 1:
						candidate_set[next_cell] = true

		var candidates := candidate_set.keys()

		if candidates.is_empty():
			break

		var chosen_cell: Vector2i = candidates[rng.randi_range(0, candidates.size() - 1)]
		floor_set[chosen_cell] = true
		floor_cells.append(chosen_cell)

	return floor_cells


func _choose_key_cell(
	zone_cells: Array[Vector2i],
	adjacency: Dictionary,
	path_set: Dictionary,
	occupied: Dictionary,
	start_cell: Vector2i,
	exit_cell: Vector2i,
	doors: Dictionary
) -> Vector2i:
	var dead_end_candidates: Array[Vector2i] = []
	var fallback_candidates: Array[Vector2i] = []

	for cell in zone_cells:
		if occupied.has(cell) or cell == start_cell or cell == exit_cell or doors.has(cell):
			continue

		fallback_candidates.append(cell)

		if not path_set.has(cell) and adjacency[cell].size() == 1:
			dead_end_candidates.append(cell)

	if not dead_end_candidates.is_empty():
		return dead_end_candidates[rng.randi_range(0, dead_end_candidates.size() - 1)]

	if not fallback_candidates.is_empty():
		return fallback_candidates[rng.randi_range(0, fallback_candidates.size() - 1)]

	return INVALID_CELL


func _add_decoy_mechanics(
	floor_cells: Array[Vector2i],
	adjacency: Dictionary,
	path_set: Dictionary,
	occupied: Dictionary,
	keys: Dictionary,
	doors: Dictionary,
	portals: Dictionary,
	used_colors: Dictionary,
	start_cell: Vector2i,
	exit_cell: Vector2i,
	required_door_count: int,
	generation_profile: Dictionary
) -> void:
	var decoy_door_target := rng.randi_range(1, required_door_count + int(generation_profile["decoy_door_extra_max"]))
	var loose_key_target := rng.randi_range(int(generation_profile["loose_key_min"]), int(generation_profile["loose_key_max"]))
	var portal_pair_target := rng.randi_range(int(generation_profile["portal_pair_min"]), int(generation_profile["portal_pair_max"]))
	var portal_colors := {}
	var branch_cells: Array[Vector2i] = []
	var available_cells: Array[Vector2i] = []

	for cell in floor_cells:
		if occupied.has(cell) or cell == start_cell or cell == exit_cell:
			continue

		if not path_set.has(cell):
			branch_cells.append(cell)
		else:
			available_cells.append(cell)

	for _i in range(decoy_door_target):
		if branch_cells.is_empty():
			break

		var door_cell := _take_random_free_cell(branch_cells, occupied)

		if door_cell == INVALID_CELL:
			break

		var color_name := _pick_color_name()
		doors[door_cell] = color_name
		occupied[door_cell] = true
		used_colors[color_name] = true

		var candidate_keys := available_cells.duplicate()
		candidate_keys.append_array(branch_cells)
		var key_cell := _take_random_free_cell(candidate_keys, occupied)

		if key_cell == INVALID_CELL:
			doors.erase(door_cell)
			occupied.erase(door_cell)
			continue

		keys[key_cell] = color_name
		occupied[key_cell] = true

	for _i in range(loose_key_target):
		var color_name := _pick_color_name()
		var candidates := available_cells.duplicate()
		candidates.append_array(branch_cells)
		var key_cell := _take_random_free_cell(candidates, occupied)

		if key_cell == INVALID_CELL:
			break

		keys[key_cell] = color_name
		occupied[key_cell] = true
		used_colors[color_name] = true

	for _i in range(portal_pair_target):
		var color_name := _pick_unused_color_name(portal_colors)

		if color_name == "":
			break

		var candidates_a := branch_cells.duplicate()
		candidates_a.append_array(available_cells)
		var first_cell := _take_random_free_cell(candidates_a, occupied)

		if first_cell == INVALID_CELL:
			break

		occupied[first_cell] = true

		var candidates_b := available_cells.duplicate()
		candidates_b.append_array(branch_cells)
		var second_cell := _take_random_free_cell_not_adjacent(candidates_b, occupied, first_cell)

		if second_cell == INVALID_CELL:
			occupied.erase(first_cell)
			continue

		portals[first_cell] = color_name
		portals[second_cell] = color_name
		occupied[second_cell] = true
		portal_colors[color_name] = true


func _take_random_free_cell(cells: Array[Vector2i], occupied: Dictionary) -> Vector2i:
	while not cells.is_empty():
		var index := rng.randi_range(0, cells.size() - 1)
		var cell := cells[index]
		cells.remove_at(index)

		if not occupied.has(cell):
			return cell

	return INVALID_CELL


func _take_random_free_cell_not_adjacent(
	cells: Array[Vector2i],
	occupied: Dictionary,
	forbidden_neighbor: Vector2i
) -> Vector2i:
	while not cells.is_empty():
		var index := rng.randi_range(0, cells.size() - 1)
		var cell := cells[index]
		cells.remove_at(index)

		if occupied.has(cell):
			continue

		if _are_orthogonal_neighbors(cell, forbidden_neighbor):
			continue

		return cell

	return INVALID_CELL


func _are_orthogonal_neighbors(a: Vector2i, b: Vector2i) -> bool:
	return abs(a.x - b.x) + abs(a.y - b.y) == 1


func _pick_color_name() -> String:
	return GameConfig.KEY_COLOR_NAMES[rng.randi_range(0, GameConfig.KEY_COLOR_NAMES.size() - 1)]


func _make_door_color_sequence(door_count: int) -> Array[String]:
	var result: Array[String] = []
	var colors := GameConfig.KEY_COLOR_NAMES.duplicate()
	_shuffle_array(colors)

	for color_name in colors:
		if result.size() >= door_count:
			return result

		result.append(color_name)

	while result.size() < door_count:
		result.append(_pick_color_name())

	return result


func _pick_unused_color_name(used_colors: Dictionary) -> String:
	var candidates := GameConfig.KEY_COLOR_NAMES.duplicate()
	_shuffle_array(candidates)

	for color_name in candidates:
		if not used_colors.has(color_name):
			return color_name

	return ""


func _count_floor_neighbors(cell: Vector2i, floor_set: Dictionary, grid_size: int) -> int:
	var count := 0

	for direction in DIRS:
		var neighbor: Vector2i = cell + direction

		if _is_inside_grid(neighbor, grid_size) and floor_set.has(neighbor):
			count += 1

	return count


func _build_adjacency(floor_set: Dictionary, grid_size: int) -> Dictionary:
	var adjacency := {}

	for cell in floor_set.keys():
		adjacency[cell] = []

		for direction in DIRS:
			var neighbor: Vector2i = cell + direction

			if _is_inside_grid(neighbor, grid_size) and floor_set.has(neighbor):
				adjacency[cell].append(neighbor)

	return adjacency


func _get_leaves(adjacency: Dictionary) -> Array[Vector2i]:
	var leaves: Array[Vector2i] = []

	for cell in adjacency.keys():
		if adjacency[cell].size() == 1:
			leaves.append(cell)

	return leaves


func _farthest_leaf(from_cell: Vector2i, adjacency: Dictionary) -> Vector2i:
	var distances := _bfs_distances(from_cell, adjacency)
	var best_cell := from_cell
	var best_distance := -1

	for cell in distances.keys():
		if adjacency[cell].size() != 1:
			continue

		var distance: int = distances[cell]

		if distance > best_distance:
			best_distance = distance
			best_cell = cell

	return best_cell


func _bfs_distances(start_cell: Vector2i, adjacency: Dictionary) -> Dictionary:
	var queue: Array[Vector2i] = [start_cell]
	var head := 0
	var distances := {}

	distances[start_cell] = 0

	while head < queue.size():
		var current_cell := queue[head]
		head += 1

		for neighbor in adjacency[current_cell]:
			if distances.has(neighbor):
				continue

			distances[neighbor] = distances[current_cell] + 1
			queue.append(neighbor)

	return distances


func _find_path(start_cell: Vector2i, target_cell: Vector2i, adjacency: Dictionary) -> Array[Vector2i]:
	var queue: Array[Vector2i] = [start_cell]
	var head := 0
	var visited := {}
	var previous := {}

	visited[start_cell] = true

	while head < queue.size():
		var current_cell := queue[head]
		head += 1

		if current_cell == target_cell:
			break

		for neighbor in adjacency[current_cell]:
			if visited.has(neighbor):
				continue

			visited[neighbor] = true
			previous[neighbor] = current_cell
			queue.append(neighbor)

	if not visited.has(target_cell):
		return []

	var path: Array[Vector2i] = []
	var current := target_cell

	while current != start_cell:
		path.push_front(current)
		current = previous[current]

	path.push_front(start_cell)
	return path


func _choose_required_gate_count(
	main_path_size: int,
	max_gates_by_leaves: int,
	generation_profile: Dictionary
) -> int:
	var spacing := maxi(1, int(generation_profile["main_path_door_spacing"]))
	var min_index := 3
	var max_index := main_path_size - 2
	var usable_count := max_index - min_index + 1

	if usable_count <= 0:
		return 0

	var max_gates_by_path := maxi(1, int(ceil(float(usable_count) / float(spacing))))
	var max_gate_count := mini(max_gates_by_leaves, max_gates_by_path)

	if max_gate_count < 1:
		return 0

	var requested_min := int(generation_profile["required_gate_min"])
	var requested_max := int(generation_profile["required_gate_max"])
	var safe_min := clampi(requested_min, 1, max_gate_count)
	var safe_max := clampi(requested_max, safe_min, max_gate_count)

	return rng.randi_range(safe_min, safe_max)


func _choose_door_indices(path_size: int, door_count: int, spacing: int) -> Array[int]:
	var result: Array[int] = []
	var min_index := 3
	var max_index := path_size - 2

	if max_index < min_index or door_count < 1:
		return result

	var slots: Array[int] = []
	var index := min_index

	while index <= max_index:
		slots.append(index)
		index += spacing

	if slots.size() < door_count:
		return result

	if door_count == 1:
		result.append(slots[int(slots.size() / 2)])
		return result

	var last_slot_index := slots.size() - 1

	for i in range(door_count):
		var slot_position := int(round(float(i) * float(last_slot_index) / float(door_count - 1)))
		result.append(slots[slot_position])

	result.sort()
	return result


func _collect_zone_cells(
	main_path: Array,
	adjacency: Dictionary,
	from_index: int,
	to_index: int,
	path_set: Dictionary
) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var visited := {}
	var safe_from_index := maxi(from_index, 0)
	var safe_to_index := mini(to_index, main_path.size() - 1)

	if safe_from_index > safe_to_index:
		return result

	for i in range(safe_from_index, safe_to_index + 1):
		var root_cell: Vector2i = main_path[i]

		if not visited.has(root_cell):
			visited[root_cell] = true
			result.append(root_cell)

		for neighbor in adjacency[root_cell]:
			if not path_set.has(neighbor):
				_collect_branch_cells(neighbor, root_cell, adjacency, path_set, visited, result)

	return result


func _collect_branch_cells(
	cell: Vector2i,
	from_cell: Vector2i,
	adjacency: Dictionary,
	path_set: Dictionary,
	visited: Dictionary,
	result: Array[Vector2i]
) -> void:
	if visited.has(cell) or path_set.has(cell):
		return

	visited[cell] = true
	result.append(cell)

	for neighbor in adjacency[cell]:
		if neighbor != from_cell:
			_collect_branch_cells(neighbor, cell, adjacency, path_set, visited, result)


func _build_portal_links(portals: Dictionary) -> Dictionary:
	var groups := {}

	for portal_cell in portals.keys():
		var portal_group: String = portals[portal_cell]

		if not groups.has(portal_group):
			groups[portal_group] = []

		groups[portal_group].append(portal_cell)

	var links := {}

	for portal_group in groups.keys():
		var cells: Array = groups[portal_group]

		if cells.size() != 2:
			continue

		links[cells[0]] = cells[1]
		links[cells[1]] = cells[0]

	return links


func _make_state_key(context: SolverContext, state: SolverState) -> String:
	var cell_id: int = state.cell.y * context.grid_size + state.cell.x
	var key_counts_signature: String = _encode_key_counts(state.key_counts)

	if state.extra.is_empty():
		return "%d|%s|%d|%d" % [
			cell_id,
			key_counts_signature,
			state.picked_key_mask,
			state.opened_door_mask
		]

	return "%d|%s|%d|%d|%s" % [
		cell_id,
		key_counts_signature,
		state.picked_key_mask,
		state.opened_door_mask,
		_make_extra_state_signature(context, state.extra)
	]


func _encode_key_counts(key_counts: Array[int]) -> String:
	var parts: Array[String] = []

	for count in key_counts:
		parts.append(str(count))

	return ",".join(parts)


func _make_extra_state_signature(_context, extra: Dictionary) -> String:
	if extra.is_empty():
		return ""

	var parts: Array[String] = []
	var keys := extra.keys()
	keys.sort()

	for key in keys:
		parts.append("%s=%s" % [str(key), str(extra[key])])

	return ";".join(parts)


func _reconstruct_state_path(end_state_key: String, previous_state: Dictionary, state_cell: Dictionary) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	var current_state_key := end_state_key

	while current_state_key != "":
		path.push_front(state_cell[current_state_key])
		current_state_key = previous_state[current_state_key]

	return path


func _get_floor_cells(level: Dictionary) -> Array:
	if level.has("floor_cells"):
		return level["floor_cells"]

	if level.has("terrain") and level["terrain"].has("floor_cells"):
		return level["terrain"]["floor_cells"]

	return []


func _get_start_cell(level: Dictionary) -> Vector2i:
	if level.has("start"):
		return level["start"]

	if level.has("markers") and level["markers"].has("start"):
		return level["markers"]["start"]

	return Vector2i.ZERO


func _get_exit_cell(level: Dictionary) -> Vector2i:
	if level.has("exit"):
		return level["exit"]

	if level.has("markers") and level["markers"].has("exit"):
		return level["markers"]["exit"]

	return Vector2i.ZERO


func _get_key_map(level: Dictionary) -> Dictionary:
	if level.has("keys"):
		return level["keys"]

	return _entities_to_cell_map(level.get("entities", []), ENTITY_KEY, "color")


func _get_door_map(level: Dictionary) -> Dictionary:
	if level.has("doors"):
		return level["doors"]

	return _entities_to_cell_map(level.get("entities", []), ENTITY_DOOR, "color")


func _get_portal_map(level: Dictionary) -> Dictionary:
	if level.has("portals"):
		return level["portals"]

	return _entities_to_cell_map(level.get("entities", []), ENTITY_PORTAL, "group")


func _entities_to_cell_map(entities: Array, target_type: String, value_key: String) -> Dictionary:
	var result := {}

	for entity in entities:
		if not entity.has("type") or entity["type"] != target_type:
			continue

		if not entity.has("cell") or not entity.has(value_key):
			continue

		result[entity["cell"]] = entity[value_key]

	return result


func _normalize_color_array(colors: Array) -> Array[String]:
	var color_set := {}

	for color_name in colors:
		color_set[str(color_name)] = true

	return _sort_colors_by_config(color_set)


func _collect_key_colors(keys: Dictionary, doors: Dictionary) -> Array[String]:
	var color_set := {}

	for cell in keys.keys():
		color_set[keys[cell]] = true

	for cell in doors.keys():
		color_set[doors[cell]] = true

	return _sort_colors_by_config(color_set)


func _collect_used_colors(keys: Dictionary, doors: Dictionary) -> Dictionary:
	var result := {}

	for cell in keys.keys():
		result[keys[cell]] = true

	for cell in doors.keys():
		result[doors[cell]] = true

	return result


func _matches_difficulty_target(solved: Dictionary, profile: Dictionary) -> bool:
	var steps := int(solved["steps"])

	if steps < int(profile["target_min_steps"]):
		return false

	if steps > int(profile["target_max_steps"]):
		return false

	return true


func _sort_colors_by_config(color_set: Dictionary) -> Array[String]:
	var result: Array[String] = []

	for color_name in GameConfig.KEY_COLOR_NAMES:
		if color_set.has(color_name):
			result.append(color_name)

	var leftovers: Array[String] = []

	for color_name in color_set.keys():
		if not result.has(color_name):
			leftovers.append(str(color_name))

	leftovers.sort()
	result.append_array(leftovers)
	return result


func _sort_vector2i_array(items: Array) -> void:
	items.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		if a.y == b.y:
			return a.x < b.x

		return a.y < b.y
	)


static func _has_bit(mask: int, index: int) -> bool:
	return (mask & (1 << index)) != 0


static func _set_bit(mask: int, index: int) -> int:
	return mask | (1 << index)


func _make_set(cells: Array) -> Dictionary:
	var result := {}

	for cell in cells:
		result[cell] = true

	return result


func _shuffle_array(items: Array) -> void:
	for i in range(items.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var temp = items[i]
		items[i] = items[j]
		items[j] = temp


func _is_inside_grid(cell: Vector2i, grid_size: int) -> bool:
	return cell.x >= 0 and cell.x < grid_size and cell.y >= 0 and cell.y < grid_size
