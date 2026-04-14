extends Resource
class_name ImportantFigure

enum Status {
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
@export var legitimacy: int
@export var portrait_path: String = ""
@export var status: Status = Status.ALIVE

static func FromRandom(a_allegiance: String) -> ImportantFigure:
	var figure: ImportantFigure = ImportantFigure.new()
	
	figure.name = ""
	for i in range(randi_range(2, 3)):
		figure.name += NameGenerator.GenerateName(randi() % 2 == 0, randi_range(3, 15)).capitalize()
	figure.skills = {} # TODO
	figure.traits = [] # TODO
	figure.ideology = Vector2i(0, 0)
	figure.allegiance = a_allegiance
	figure.occupation = ""
	figure.portrait_path = ""
	var random_portraits_dir: String = "res://starts/" + GameState.current_start + "/assets/portraits/random/"
	var dir: DirAccess = DirAccess.open(random_portraits_dir)
	if dir:
		dir.list_dir_begin()
		var file_name: String = dir.get_next()
		var portraits: Array[String] = []
		while file_name != "":
			if !dir.current_is_dir() and file_name.ends_with(".png"):
				portraits.append(file_name)
			file_name = dir.get_next()
		
		if portraits.size() > 0:
			figure.portrait_path = random_portraits_dir + portraits.pick_random()
	print(GameState.current_start)
	print(random_portraits_dir)
	print(figure.portrait_path)
	figure.status = Status.ALIVE
	
	return figure

static func FromValues(
	a_name: String,
	a_skills: Dictionary,
	a_traits: Array,
	a_allegiance: String,
	a_occupation: String,
	a_legitimacy: int,
	a_portrait_path: String,
	a_status: Status
) -> ImportantFigure:
	var figure: ImportantFigure = ImportantFigure.new()
	
	figure.name = a_name
	figure.skills = a_skills
	figure.traits = a_traits
	figure.allegiance = a_allegiance
	figure.occupation = a_occupation
	figure.legitimacy = a_legitimacy
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
	figure.legitimacy = a_data.get("legitimacy", 100)
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
		"legitimacy": self.legitimacy,
		"portrait_path": self.portrait_path,
		"status": self.status,
	}

static func GetPortrait(a_figure: ImportantFigure) -> Texture:
	if !a_figure:
		return load("res://assets/portraits/Fallback.png")
	
	print("%s: %s, %s, %s" % [a_figure.name, a_figure.portrait_path, FileAccess.file_exists(a_figure.portrait_path), ResourceLoader.exists(a_figure.portrait_path)])
	
	if a_figure.portrait_path != "" && (FileAccess.file_exists(a_figure.portrait_path) or ResourceLoader.exists(a_figure.portrait_path)):
		return load(a_figure.portrait_path)
	
	var path = "res://starts/%s/assets/portraits/%s/%s.png" % [GameState.current_start, a_figure.allegiance, a_figure.name]
	if FileAccess.file_exists(path) || ResourceLoader.exists(path):
		a_figure.portrait_path = path
		return load(path)

	# Fallback to random folder if it's there but not in portrait_path for some reason
	path = "res://starts/%s/assets/portraits/random/%s.png" % [GameState.current_start, a_figure.name]
	if FileAccess.file_exists(path) || ResourceLoader.exists(path):
		a_figure.portrait_path = path
		return load(path)
	
	a_figure.portrait_path = "res://assets/portraits/Fallback.png"
	return load("res://assets/portraits/Fallback.png")
