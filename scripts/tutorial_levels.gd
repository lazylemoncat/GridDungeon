class_name TutorialLevels
extends RefCounted

const TUTORIAL_LEVEL_DIR := "res://levels/tutorial"
const LEVEL_CONFIGS: Array[Dictionary] = [
    {
		"file": "001_exit.csv",
		"optimal_steps": 2
	},
    {
		"file": "002_wall.csv",
		"optimal_steps": 11
	},
    {
		"file": "003_wall_exam.csv",
		"optimal_steps": 9
	},
	{
		"file": "002_key_door.csv",
		"optimal_steps": 10
	},
]


static func get_levels() -> Array[Dictionary]:
	var levels: Array[Dictionary] = []

	for config in LEVEL_CONFIGS:
		var file_name := str(config.get("file", ""))

		if file_name == "":
			push_warning("Skipping tutorial level config without file.")
			continue

		var level := _load_csv_level("%s/%s" % [TUTORIAL_LEVEL_DIR, file_name])

		if level.is_empty():
			push_warning("Skipping invalid tutorial level: %s" % file_name)
			continue

		level["optimal_steps"] = int(config.get("optimal_steps", -1))
		levels.append(level)

	return levels


static func _load_csv_level(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)

	if file == null:
		push_error("Cannot open tutorial level: %s" % path)
		return {}

	var rows: Array[PackedStringArray] = []
	var width := 0

	while not file.eof_reached():
		var row := file.get_csv_line()

		if row.is_empty() or _is_blank_row(row):
			continue

		rows.append(row)
		width = maxi(width, row.size())

	if rows.is_empty() or width <= 0:
		push_error("Tutorial level is empty: %s" % path)
		return {}

	return _make_level_from_rows(path, rows, width)


static func _make_level_from_rows(path: String, rows: Array[PackedStringArray], width: int) -> Dictionary:
	var floor_cells: Array[Vector2i] = []
	var wall_cells: Array[Vector2i] = []
	var keys := {}
	var doors := {}
	var portals := {}
	var start := Vector2i(-1, -1)
	var exit := Vector2i(-1, -1)

	for y in range(rows.size()):
		var row := rows[y]

		for x in range(width):
			var raw_token := ""

			if x < row.size():
				raw_token = row[x]

			var token := raw_token.strip_edges().to_lower()
			var cell := Vector2i(x, y)

			if token == "" or token == "empty":
				continue

			if token == "wall":
				wall_cells.append(cell)
				continue

			if token == "floor":
				floor_cells.append(cell)
			elif token == "start":
				floor_cells.append(cell)
				start = cell
			elif token == "exit":
				floor_cells.append(cell)
				exit = cell
			elif token.begins_with("key:"):
				floor_cells.append(cell)
				keys[cell] = token.get_slice(":", 1)
			elif token.begins_with("door:"):
				floor_cells.append(cell)
				doors[cell] = token.get_slice(":", 1)
			elif token.begins_with("portal:"):
				floor_cells.append(cell)
				portals[cell] = token.get_slice(":", 1)
			else:
				push_warning("Unknown tutorial token '%s' in %s at (%d, %d)." % [raw_token, path, x, y])

	if start == Vector2i(-1, -1):
		push_error("Tutorial level has no start: %s" % path)
		return {}

	if exit == Vector2i(-1, -1):
		push_error("Tutorial level has no exit: %s" % path)
		return {}

	return {
		"grid_size": maxi(width, rows.size()),
		"floor_cells": floor_cells,
		"walls": wall_cells,
		"keys": keys,
		"doors": doors,
		"portals": portals,
		"rails": {},
		"rail_levers": {},
		"start": start,
		"exit": exit,
		"optimal_steps": -1
	}


static func _is_blank_row(row: PackedStringArray) -> bool:
	for token in row:
		if token.strip_edges() != "":
			return false

	return true
