class_name LevelRequestSelector
extends RefCounted

# 生成器内部会反复尝试同一个 profile，这里只负责换一批难度参数。
const GENERATION_RETRY_COUNT := 12
const FLOORS_PER_DIFFICULTY_TIER := 3
const MAX_DIFFICULTY_TIER := 6

var rng := RandomNumberGenerator.new()


func _init() -> void:
	rng.randomize()


func pick_level_request(floor_number: int) -> Dictionary:
	var safe_floor := maxi(1, floor_number)
	var grid_size := _pick_grid_size(safe_floor)
	var profile := _make_profile(safe_floor, grid_size)
	profile["floor_number"] = safe_floor

	return {
		"grid_size": grid_size,
		"profile": profile
	}


func _pick_grid_size(floor_number: int) -> int:
	var tier := _difficulty_tier(floor_number)
	var min_size := clampi(GameConfig.MIN_GRID_SIZE + tier, GameConfig.MIN_GRID_SIZE, GameConfig.MAX_GRID_SIZE)
	var max_size := clampi(min_size + 2 + int(tier / 2), min_size, GameConfig.MAX_GRID_SIZE)

	return rng.randi_range(min_size, max_size)


func _difficulty_tier(floor_number: int) -> int:
	var zero_based_floor := maxi(0, floor_number - 1)
	return clampi(int(floor(float(zero_based_floor) / float(FLOORS_PER_DIFFICULTY_TIER))), 0, MAX_DIFFICULTY_TIER)


func _make_profile(floor_number: int, grid_size: int) -> Dictionary:
	var tier := _difficulty_tier(floor_number)
	var required_gate_min := clampi(2 + int(tier / 2), 2, 6)
	var required_gate_max := clampi(required_gate_min + 1 + int(tier / 3), required_gate_min, 8)
	var deep_key_bonus := 1 if tier >= 3 else 0
	var portal_min := 1 if tier >= 2 else 0
	var portal_max_bonus := 1 if tier >= 4 else 0
	var rail_max_bonus := 1 if tier >= 4 else 0
	var min_required_key_distance := 1 + deep_key_bonus

	# 这是“硬性难度门槛”：生成后必须由求解器验证，不达标就丢弃重生。
	var target_min_steps := maxi(
		14,
		int(round(float(grid_size) * (1.55 + float(tier) * 0.25))) + tier * 2
	)
	var target_max_steps := target_min_steps + grid_size * 5 + tier * 8

	return {
		"max_generation_attempts": 900,

		"target_min_steps": target_min_steps,
		"target_max_steps": target_max_steps,
		"min_solver_state_count": 70 + tier * 45,
		"min_main_path_length": maxi(grid_size + 4, target_min_steps - grid_size),
		"min_decision_branch_count": 3 + tier,
		"min_backtrack_steps": required_gate_min * min_required_key_distance * 2,

		"required_gate_min": required_gate_min,
		"required_gate_max": required_gate_max,
		"min_required_branch_key_count": required_gate_min,
		"min_required_key_dead_end_count": maxi(1, required_gate_min - 1),
		"min_required_key_distance_from_main": min_required_key_distance,
		"require_required_keys_in_branches": true,

		"min_floor_ratio": 0.60,
		"max_floor_ratio": 0.82,
		"min_floor_count": maxi(32, int(round(float(grid_size * grid_size) * 0.58))),
		"min_extra_leaves": 3,
		"main_path_door_spacing": 3,

		"decoy_door_extra_max": 3 + int(tier / 2),
		"loose_key_min": 1 + int(tier / 3),
		"loose_key_max": 3 + int(tier / 2),
		"portal_pair_min": portal_min,
		"portal_pair_max": 1 + portal_max_bonus,
		"rail_min": 1,
		"rail_max": 2 + rail_max_bonus,
		"rail_port_min": 3,
		"rail_port_max": 5 + rail_max_bonus,
		"rail_min_length": 4 + tier,

		# 多口中央变轨器必须配操作杠，否则 state 不会参与谜题。
		"rail_lever_min": 1,
		"rail_lever_max": 1 + int(tier / 3),

		"require_unique_optimal_solution": true,
		"solution_policy": "unique_optimal"
	}
