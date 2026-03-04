extends Node

var plans: Dictionary = {}


func _ready() -> void:
	_load_plans()

func _load_plans():
	var file = FileAccess.open("res://plans.json", FileAccess.READ)
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(json_string)
	if error == OK:
		plans = json.data

