extends Resource
class_name ImportantFigure

enum Status{
	ALIVE,
	WOUNDED,
	DEAD
	}

@export var name: String
@export var skills: Dictionary
@export var traits: Array
@export var ideology: Vector2i
@export var allegiance: String
@export var occupation: String
@export var portrait_path: String = ""
@export var status: Status = Status.ALIVE

static func FromValues(
	a_name: String,
	a_skills: Dictionary,
	a_traits: Array,
	a_allegiance: String,
	a_occupation: String,
	a_portrait_path: String,
	a_status: Status
) -> ImportantFigure:
	var figure: ImportantFigure = ImportantFigure.new()
	
	figure.name = a_name
	figure.skills = a_skills
	figure.traits = a_traits
	figure.allegiance = a_allegiance
	figure.occupation = a_occupation
	figure.portrait_path = a_portrait_path
	figure.status = a_status
	
	return figure

static func FromDict(a_data: Dictionary) -> ImportantFigure:
	var figure: ImportantFigure = ImportantFigure.new()
	
	figure.name = a_data["name"]
	figure.skills = a_data["skills"]
	figure.traits = a_data["traits"]
	figure.ideology = Vector2i(a_data["ideology"][0], a_data["ideology"][1])
	figure.allegiance = a_data["allegiance"]
	figure.occupation = a_data["occupation"]
	figure.portrait_path = a_data.get("portrait_path", "")
	figure.status = a_data.get("status", Status.ALIVE)
	
	return figure

func ToDict() -> Dictionary:
	return {
		"name": self.name,
		"skills": self.skills,
		"traits": self.traits,
		"ideology": [ self.ideology.x, self.ideology.y],
		"allegiance": self.allegiance,
		"occupation": self.occupation,
		"portrait_path": self.portrait_path,
		"status": self.status,
	}
