extends Resource
class_name ImportantFigure

@export var name: String
@export var skills: Dictionary
@export var traits: Array
@export var ideology: Vector2i
@export var allegiance: String
@export var occupation: String

static func FromValues(
	a_name: String,
	a_skills: Dictionary,
	a_traits: Array,
	a_allegiance: String,
	a_occupation: String
) -> ImportantFigure:
	var figure: ImportantFigure = ImportantFigure.new()
	
	figure.name = a_name
	figure.skills = a_skills
	figure.traits = a_traits
	figure.allegiance = a_allegiance
	figure.occupation = a_occupation
	
	return figure

static func FromDict(a_data: Dictionary) -> ImportantFigure:
	var figure: ImportantFigure = ImportantFigure.new()
	
	figure.name = a_data["name"]
	figure.skills = a_data["skills"]
	figure.traits = a_data["traits"]
	figure.ideology = Vector2i(a_data["ideology"][0], a_data["ideology"][1])
	figure.allegiance = a_data["allegiance"]
	figure.occupation = a_data["occupation"]
	
	return figure

func ToDict() -> Dictionary:
	return {
		"name": self.name,
		"skills": self.skills,
		"traits": self.traits,
		"ideology": self.ideology,
		"allegiance": self.allegiance,
		"occupation": self.occupation,
	}
