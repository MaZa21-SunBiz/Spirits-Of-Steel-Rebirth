extends Resource
class_name DivisionTemplate

@export var name: String
@export var hp: float
@export var manpower: int
@export var cost: int
@export var days: int
@export var softAttack: float
@export var hardAttack: float
@export var staticDefense: float
@export var offensiveDefense: float
@export var cohesion: float
@export var resiliance: float
@export var organization: float
@export var speed: float

static func FromDict(a_data: Dictionary) -> DivisionTemplate:
	var divisionTemplate: DivisionTemplate = DivisionTemplate.new()
	
	divisionTemplate.name             = a_data["name"]
	divisionTemplate.hp               = a_data["hp"]
	divisionTemplate.manpower         = a_data["manpower"]
	divisionTemplate.cost             = a_data["cost"]
	divisionTemplate.days             = a_data["days"]
	divisionTemplate.softAttack       = a_data["softAttack"]
	divisionTemplate.hardAttack       = a_data["hardAttack"]
	divisionTemplate.staticDefense    = a_data["staticDefense"]
	divisionTemplate.offensiveDefense = a_data["offensiveDefense"]
	divisionTemplate.cohesion         = a_data["cohesion"]
	divisionTemplate.resiliance       = a_data["resiliance"]
	divisionTemplate.organization     = a_data["organization"]
	divisionTemplate.speed            = a_data["speed"]

	return divisionTemplate
