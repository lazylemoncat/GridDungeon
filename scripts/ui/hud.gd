extends CanvasLayer

@onready var stats_label: Label = $StatsLabel


func set_stats(
	current_floor: int,
	total_moves: int,
	floor_moves: int,
	grid_size: int,
	key_text: String,
	optimal_steps: int
) -> void:
	stats_label.text = "当前层数：%d\n总移动次数：%d\n当前层移动次数：%d\n网格大小：%d x %d\n持有钥匙：%s\n最优步数：%d" % [
		current_floor,
		total_moves,
		floor_moves,
		grid_size,
		grid_size,
		key_text,
		optimal_steps
	]
