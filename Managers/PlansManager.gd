extends Node

var plans: Dictionary = {}
var current_start_folder: String = ""


func _ready() -> void:
	load_plans_from_path("res://plans.json")


func load_plans_from_path(path: String):
	current_start_folder = path.get_base_dir() + "/"
	plans.clear()
	if not FileAccess.file_exists(path):
		return

	var file = FileAccess.open(path, FileAccess.READ)
	var json_string = file.get_as_text()
	file.close()

	var json = JSON.new()
	var error = json.parse(json_string)
	if error == OK:
		plans = json.data
