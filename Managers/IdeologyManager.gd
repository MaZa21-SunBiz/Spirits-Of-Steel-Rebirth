extends Node

var ideologies: Dictionary = {}

func Initialize(a_ideologyData: Dictionary):
	ideologies = a_ideologyData

func get_ideology_name(coords: Vector2):
	for ideology in ideologies:
		var lower_bound = ideologies[ideology]["region"][0]
		var upper_bound = ideologies[ideology]["region"][1]
		if (lower_bound[0] <= coords[0] and coords.x <= upper_bound[0]) and (lower_bound[1] <= coords.y and coords[1] <= upper_bound[1]):
			return ideology
	return "neutral"
