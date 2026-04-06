extends Resource
class_name BuildingData

enum BuildingState {
	CONSTRUCTION = 0,
	FUNCTIONAL = 1,
	RUIN = 2
}

@export var type: String
@export var template_name: String = ""
@export var state: BuildingState
@export var durability: float

static func FromValues(a_type: String, a_state: BuildingState, a_durability: float = 1.0) -> BuildingData:
	var building: BuildingData = BuildingData.new()
	
	building.type = a_type
	building.state = a_state
	building.durability = a_durability
	
	return building

static func FromDict(a_data: Dictionary) -> BuildingData:
	var building: BuildingData = BuildingData.new()
	
	building.type = a_data["type"]
	building.template_name = a_data.get("template_name", "")
	building.state = a_data.get("state", BuildingState.FUNCTIONAL) as BuildingState
	building.durability = a_data.get("durability", 1.0)
	
	return building

func ToDict() -> Dictionary:
	return {
		"type": self.type,
		"template_name": self.template_name,
		"state": self.state as int,
		"durability": self.durability
	}
