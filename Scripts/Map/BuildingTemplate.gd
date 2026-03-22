extends Resource
class_name BuildingTemplate

@export var name: String
@export var power: int
@export var water: int
@export var sewage: int
@export var population: int
@export var on_coast: bool

static func FromDict(a_data: Dictionary) -> BuildingTemplate:
	var building: BuildingTemplate = BuildingTemplate.new()
	
	building.name = a_data["name"]
	building.power = a_data["power"]
	building.water = a_data["water"]
	building.sewage = a_data["sewage"]
	building.population = a_data["population"]
	
	return building

func ToDict() -> Dictionary:
	return {
		"name": self.name,
		"power": self.power,
		"water": self.water,
		"sewage": self.sewage,
		"population": self.population
	}
