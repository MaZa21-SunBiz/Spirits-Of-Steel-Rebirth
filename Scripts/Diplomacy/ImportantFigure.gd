class_name ImportantFigure extends Resource

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

static var NOBLE_SKILLS: Dictionary[String, Dictionary] = {
	"stability":                {"type": "add", "min": -1.0, "base": 0.0, "max":  1.0, "step": 0.01 , "dir": "more", "val": 1.0, "precision": 2},
	"warSupport":               {"type": "add", "min": -1.0, "base": 0.0, "max":  1.0, "step": 0.01 , "dir": "more", "val": 1.0, "precision": 2},
	"dailyPPGain":              {"type": "add", "min": -1.0, "base": 0.0, "max":  1.0, "step": 0.01 , "dir": "more", "val": 4.0, "precision": 2},
	"divCostMod":               {"type": "mul", "min":  0.0, "base": 1.0, "max": 10.0, "step": 0.01 , "dir": "less", "val": 3.5, "precision": 0},
	"troopSpeed":               {"type": "add", "min": -1.0, "base": 0.0, "max":  1.0, "step": 0.005, "dir": "more", "val": 7.0, "precision": 3},
	"troopAttackAdd":           {"type": "add", "min": -5.0, "base": 0.0, "max":  5.0, "step": 0.025, "dir": "more", "val": 2.5, "precision": 3},
	"troopAttackMod":           {"type": "mul", "min":  0.0, "base": 1.0, "max": 10.0, "step": 0.01 , "dir": "more", "val": 6.0, "precision": 0},
	"troopDefendAdd":           {"type": "add", "min": -5.0, "base": 0.0, "max":  5.0, "step": 0.025, "dir": "more", "val": 2.5, "precision": 3},
	"troopDefendMod":           {"type": "mul", "min":  0.0, "base": 1.0, "max": 10.0, "step": 0.01 , "dir": "more", "val": 6.0, "precision": 0},
	"attackerAttackMitigation": {"type": "mul", "min":  0.0, "base": 1.0, "max":  5.0, "step": 0.01 , "dir": "less", "val": 8.0, "precision": 0},
	"defenderAttackMitigation": {"type": "mul", "min":  0.0, "base": 1.0, "max":  5.0, "step": 0.01 , "dir": "less", "val": 8.0, "precision": 0},
}

static func FromRandom(a_allegiance: String, a_budget: float = 0.0) -> ImportantFigure:
	print("Hello?")
	var figure: ImportantFigure = ImportantFigure.new()
	
	figure.name = ""
	for i in range(randi_range(2, 3)):
		figure.name += NameGenerator.GenerateName(randi() % 2 == 0, randi_range(3, 10)).capitalize()
	figure.skills = {} # TODO
	var skillsToPick: int = randi_range(1,  5)
	var pickableSkills: Array = NOBLE_SKILLS.keys()
	for i in range(skillsToPick):
		var skill: String = pickableSkills.pick_random()
		var skillData: Dictionary = NOBLE_SKILLS[skill]
		var level: int = maxi(randi_range(1, 5) - randi_range(0, 2), 1)
		var cost: float = skillData.val * level
		var result: float = skillData.base
		match skillData.dir:
			"more":
				result += skillData.step * level
			"less":
				result -= skillData.step * level
		#print("%s getting positive skill (%d/%d) for %3.1f at %d with %+6.3f: %s" % [figure.name, i + 1, skillsToPick, cost, level, result, skill])
		a_budget -= cost
		pickableSkills.erase(skill)
		figure.skills[skill] = result
	
	while a_budget < 0 && !pickableSkills.is_empty():
		var skill: String = pickableSkills.pick_random()
		var skillData: Dictionary = NOBLE_SKILLS[skill]
		var level: int = maxi(randi_range(1, 5) - randi_range(0, 2), 1)
		var cost: float = skillData.val * level
		var result: float = skillData.base
		match skillData.dir:
			"more":
				result -= skillData.step * level
			"less":
				result += skillData.step * level
		#print("%s getting negative skill (---) for %3.1f at %d with %+6.3f: %s" % [figure.name, cost, level, result, skill])
		a_budget += cost
		pickableSkills.erase(skill)
		figure.skills[skill] = result
	
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
	#print(GameState.current_start)
	#print(random_portraits_dir)
	#print(figure.portrait_path)
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


func GetDisplayString() -> String:
	var toReturn: String = name.capitalize() + "\nSkills:"
	for skill: String in skills:
		toReturn += "\n"
		
		match NOBLE_SKILLS[skill].type:
			"add":
				toReturn += "%+.*f " % [mini(NOBLE_SKILLS[skill].precision, step_decimals(skills[skill])), skills[skill]]
			"mul":
				toReturn += "%+.*f%% " % [mini(NOBLE_SKILLS[skill].precision, step_decimals((skills[skill] - NOBLE_SKILLS[skill].base) * 100)), (skills[skill] - NOBLE_SKILLS[skill].base) * 100]
		toReturn += skill.capitalize()
	return toReturn

func GetDisplaySkills() -> String:
	var toReturn: String = ""
	for skill: String in skills:
		toReturn += "\n"
		
		match NOBLE_SKILLS[skill].type:
			"add":
				toReturn += "%+.*f " % [mini(NOBLE_SKILLS[skill].precision, step_decimals(skills[skill])), skills[skill]]
			"mul":
				toReturn += "%+.*f%% " % [mini(NOBLE_SKILLS[skill].precision, step_decimals((skills[skill] - NOBLE_SKILLS[skill].base) * 100)), (skills[skill] - NOBLE_SKILLS[skill].base) * 100]
		toReturn += skill.capitalize()
	return toReturn
