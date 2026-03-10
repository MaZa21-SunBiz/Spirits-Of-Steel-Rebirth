extends Resource
class_name ImportantFigure

@export var name: String
@export var skills: Dictionary
@export var modifiers: Dictionary

static func FromValues(a_name: String, a_skills: Dictionary, a_modifiers: Dictionary) -> ImportantFigure:
	var figure: ImportantFigure = ImportantFigure.new()
	
	figure.name = a_name
	figure.skills = a_skills
	figure.modifiers = a_modifiers
	
	return figure

static func FromDict(a_data: Dictionary) -> ImportantFigure:
	var figure: ImportantFigure = ImportantFigure.new()
	
	figure.name = a_data["name"]
	figure.skills = a_data["skills"]
	figure.modifiers = a_data["modifiers"]
	
	return figure

func ToDict() -> Dictionary:
	return {
		"name": self.name,
		"skills": self.skills,
		"modifiers": self.modifiers
	}
