extends Control

@onready var tutorial_button: Button = $CenterContainer/VBoxContainer/TutorialButton
@onready var start_button: Button = $CenterContainer/VBoxContainer/StartButton
@onready var exit_button: Button = $CenterContainer/VBoxContainer/ExitButton


func _ready() -> void:
	tutorial_button.pressed.connect(_on_tutorial_pressed)
	start_button.pressed.connect(_on_start_pressed)
	exit_button.pressed.connect(_on_exit_pressed)


func _on_tutorial_pressed() -> void:
	GameConfig.game_mode = GameConfig.GAME_MODE_TUTORIAL
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _on_start_pressed() -> void:
	GameConfig.game_mode = GameConfig.GAME_MODE_NORMAL
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _on_exit_pressed() -> void:
	get_tree().quit()
