extends CanvasLayer

signal home_requested
signal restart_requested

@onready var stats_label: Label = $StatsLabel
@onready var return_home_button: Button = $TopRightControls/ReturnHomeButton
@onready var restart_button: Button = $TopRightControls/RestartButton


func _ready() -> void:
	return_home_button.pressed.connect(_on_return_home_pressed)
	restart_button.pressed.connect(_on_restart_pressed)


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


func set_restart_enabled(enabled: bool) -> void:
	restart_button.disabled = not enabled


func _on_return_home_pressed() -> void:
	home_requested.emit()


func _on_restart_pressed() -> void:
	restart_requested.emit()
