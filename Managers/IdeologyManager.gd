extends Node

var ideologies: Dictionary = {}
var file_path = "res://ideologies.json"

func _ready():
	if not FileAccess.file_exists(file_path):
		print("File not found: ", file_path)
		return
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	var content = file.get_as_text()
	
	var json = JSON.new()
	var parse_result = json.parse(content)
	if parse_result != OK:
		print("JSON parse error at line ", json.get_error_line(), ": ", json.get_error_string())
		return
	
	var data = json.get_data()
	if typeof(data) == TYPE_DICTIONARY:
		ideologies = data
		print(ideologies)
	else:
		print("Unexpected JSON root type: expected Dictionary")

func get_ideology_name(coords: Array):
	for ideology in ideologies:
		var lower_bound = ideologies[ideology][0]
		var upper_bound = ideologies[ideology][1]
		if (lower_bound[0] < coords[0] and coords[0] < upper_bound[0]) and (lower_bound[1] < coords[1] and coords[1] < upper_bound[1]):
			return ideology
	return "neutral"
