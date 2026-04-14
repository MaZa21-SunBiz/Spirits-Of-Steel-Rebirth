extends Resource
class_name BuildingTemplate

@export var name: String
@export var power: float
@export var water: float
@export var sewage: float
@export var population: float
@export var money_cost: float

@export var functionalities: Array = []
@export var assigned_inputs: Dictionary = {}

@export var on_coast: bool
@export var produces: float
@export var gather_resources: Dictionary
@export var storage: float
@export var heal_amount: float
@export var supply_amount: float
@export var tech_points: float

static func FromDict(a_data: Dictionary) -> BuildingTemplate:
	var building: BuildingTemplate = BuildingTemplate.new()
	
	building.name = a_data.get("name", "")
	building.power = a_data.get("power", 0.0)
	building.water = a_data.get("water", 0.0)
	building.sewage = a_data.get("sewage", 0.0)
	building.population = a_data.get("population", 0.0)
	building.money_cost = a_data.get("money_cost", 0.0)

	building.on_coast = a_data.get("on_coast", false)
	building.produces = a_data.get("produces", 0.0)
	building.gather_resources = a_data.get("gather_resources", {})
	building.storage = a_data.get("storage", 0.0)
	building.heal_amount = a_data.get("heal_amount", 0.0)
	building.supply_amount = a_data.get("supply_amount", 0.0)
	building.tech_points = a_data.get("tech_points", 0.0)

	building.functionalities = a_data.get("functionalities", [])
	building.assigned_inputs = a_data.get("assigned_inputs", {})
	
	return building

func ToDict() -> Dictionary:
	return {
		"name": name,
		"power": power,
		"water": water,
		"sewage": sewage,
		"population": population,
		"money_cost": money_cost,
		"on_coast": on_coast,
		"produces": produces,
		"gather_resources": gather_resources,
		"storage": storage,
		"heal_amount": heal_amount,
		"supply_amount": supply_amount,
		"tech_points": tech_points,
		"functionalities": functionalities,
		"assigned_inputs": assigned_inputs
	}
