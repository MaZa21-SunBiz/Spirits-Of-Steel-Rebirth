extends Resource
class_name BuildingTemplate

@export var name: String
@export var power: int
@export var water: int
@export var sewage: int
@export var population: int

@export var on_coast: bool
@export var produces: int
@export var gather_resources: Dictionary
@export var storage: Dictionary
@export var heal_amount: int
@export var supply_amount: int

static func FromDict(a_data: Dictionary) -> BuildingTemplate:
	var building: BuildingTemplate = BuildingTemplate.new()
	
	building.name = a_data["name"]
	building.power = a_data["power"]
	building.water = a_data["water"]
	building.sewage = a_data["sewage"]
	building.population = a_data["population"]

	building.on_coast = a_data["on_coast"]
	building.produces = a_data["produces"]
	building.gather_resources = a_data["gather_resources"]
	building.storage = a_data["storage"]
	building.heal_amount = a_data["heal_amount"]
	building.supply_amount = a_data["supply_amount"]
	
	return building

func ToDict() -> Dictionary:
	return {
		"name": name,
		"power": power,
		"water": water,
		"sewage": sewage,
		"population": population,
		"on_coast": on_coast,
		"produces": produces,
		"gather_resources": gather_resources,
		"storage": storage,
		"heal_amount": heal_amount,
		"supply_amount": supply_amount
	}
