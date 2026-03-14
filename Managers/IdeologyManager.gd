extends Node

var ideologies: Dictionary = {}
var ideology_names: Array = []



func Initialize(a_ideologyData: Dictionary):
	ideologies = a_ideologyData
	ideology_names = ideologies.keys()
	ideology_names.sort_custom(func(a, b): return _area(ideologies[a]["region"]) < _area(ideologies[b]["region"]))

func get_ideology_name(coords: Vector2):
	for ideology in ideology_names:
		var lower_bound = ideologies[ideology]["region"][0]
		var upper_bound = ideologies[ideology]["region"][1]
		if (lower_bound[0] <= coords[0] && coords.x <= upper_bound[0]) && (lower_bound[1] <= coords.y && coords[1] <= upper_bound[1]):
			return ideology
	return "neutral"

func _area(a):
	return abs((a[0][0]-a[1][0]) * (a[0][1]-a[1][1]))
