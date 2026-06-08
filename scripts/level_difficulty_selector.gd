class_name LevelDifficultySelector
extends RefCounted

const GENERATION_RETRY_COUNT := 20

var rng := RandomNumberGenerator.new()


func _init() -> void:
	rng.randomize()


func pick_level_request(floor_number: int) -> Dictionary:
	var tier := _get_difficulty_tier(floor_number)
	var grid_size := _pick_grid_size(tier)
	var profile := _make_profile(tier)

	profile["difficulty_tier"] = tier
	profile["floor_number"] = floor_number

	return {
		"grid_size": grid_size,
		"profile": profile
	}


func _get_difficulty_tier(floor_number: int) -> String:
	if floor_number <= 3:
		return "intro"
	if floor_number <= 8:
		return "easy"
	if floor_number <= 15:
		return "normal"
	if floor_number <= 25:
		return "hard"

	return "expert"


func _pick_grid_size(tier: String) -> int:
	match tier:
		"intro":
			return rng.randi_range(_safe_min_grid(5), _safe_max_grid(7))
		"easy":
			return rng.randi_range(_safe_min_grid(6), _safe_max_grid(9))
		"normal":
			return rng.randi_range(_safe_min_grid(8), _safe_max_grid(12))
		"hard":
			return rng.randi_range(_safe_min_grid(10), _safe_max_grid(15))
		"expert":
			return rng.randi_range(_safe_min_grid(12), _safe_max_grid(GameConfig.MAX_GRID_SIZE))

	return _safe_min_grid(8)


func _safe_min_grid(value: int) -> int:
	return clampi(value, GameConfig.MIN_GRID_SIZE, GameConfig.MAX_GRID_SIZE)


func _safe_max_grid(value: int) -> int:
	return clampi(value, GameConfig.MIN_GRID_SIZE, GameConfig.MAX_GRID_SIZE)


func _make_profile(tier: String) -> Dictionary:
	match tier:
		"intro":
			return {
				"target_min_steps": 8,
				"target_max_steps": 30,
				"required_gate_min": 1,
				"required_gate_max": 1,
				"min_floor_ratio": 0.68,
				"max_floor_ratio": 0.82,
				"min_floor_count": 10,
				"min_extra_leaves": 2,
				"main_path_door_spacing": 6,
				"decoy_door_extra_max": 0,
				"loose_key_min": 0,
				"loose_key_max": 1,
				"portal_pair_min": 0,
				"portal_pair_max": 0,
				"require_unique_optimal_solution": true,
				"solution_policy": "unique_optimal"
			}

		"easy":
			return {
				"target_min_steps": 10,
				"target_max_steps": 45,
				"required_gate_min": 1,
				"required_gate_max": 2,
				"min_floor_ratio": 0.66,
				"max_floor_ratio": 0.84,
				"min_floor_count": 14,
				"min_extra_leaves": 3,
				"main_path_door_spacing": 5,
				"decoy_door_extra_max": 1,
				"loose_key_min": 1,
				"loose_key_max": 2,
				"portal_pair_min": 0,
				"portal_pair_max": 1,
				"require_unique_optimal_solution": true,
				"solution_policy": "unique_optimal"
			}

		"normal":
			return {
				"target_min_steps": 18,
				"target_max_steps": 70,
				"required_gate_min": 2,
				"required_gate_max": 4,
				"min_floor_ratio": 0.64,
				"max_floor_ratio": 0.86,
				"min_floor_count": 24,
				"min_extra_leaves": 4,
				"main_path_door_spacing": 4,
				"decoy_door_extra_max": 2,
				"loose_key_min": 1,
				"loose_key_max": 3,
				"portal_pair_min": 1,
				"portal_pair_max": 1,
				"require_unique_optimal_solution": true,
				"solution_policy": "unique_optimal"
			}

		"hard":
			return {
				"target_min_steps": 28,
				"target_max_steps": 110,
				"required_gate_min": 3,
				"required_gate_max": 6,
				"min_floor_ratio": 0.62,
				"max_floor_ratio": 0.88,
				"min_floor_count": 36,
				"min_extra_leaves": 5,
				"main_path_door_spacing": 4,
				"decoy_door_extra_max": 3,
				"loose_key_min": 2,
				"loose_key_max": 4,
				"portal_pair_min": 1,
				"portal_pair_max": 2,
				"require_unique_optimal_solution": true,
				"solution_policy": "unique_optimal"
			}

		"expert":
			return {
				"target_min_steps": 40,
				"target_max_steps": 180,
				"required_gate_min": 4,
				"required_gate_max": 8,
				"min_floor_ratio": 0.60,
				"max_floor_ratio": 0.90,
				"min_floor_count": 48,
				"min_extra_leaves": 6,
				"main_path_door_spacing": 3,
				"decoy_door_extra_max": 4,
				"loose_key_min": 2,
				"loose_key_max": 5,
				"portal_pair_min": 1,
				"portal_pair_max": 2,
				"require_unique_optimal_solution": true,
				"solution_policy": "unique_optimal"
			}

	return {}
