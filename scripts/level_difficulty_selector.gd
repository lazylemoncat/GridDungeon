class_name LevelDifficultySelector
extends RefCounted

const MIN_DOOR_COUNT := 3
const GENERATION_RETRY_COUNT := 20

var rng := RandomNumberGenerator.new()


func _init() -> void:
	rng.randomize()


func pick_level_settings() -> Dictionary:
	var grid_size := rng.randi_range(GameConfig.MIN_GRID_SIZE, GameConfig.MAX_GRID_SIZE)
	var max_door_request := grid_size * grid_size
	var min_door_request := mini(maxi(MIN_DOOR_COUNT, GameConfig.KEY_COLOR_NAMES.size()), max_door_request)

	return {
		"grid_size": grid_size,
		"door_count": rng.randi_range(min_door_request, max_door_request)
	}
