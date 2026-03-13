extends Resource
class_name BuildingTemplate

@export var name: String

static func FromDict(a_data: Dictionary) -> BuildingTemplate:
	var building: BuildingTemplate = BuildingTemplate.new()
	
	building.name = a_data["name"]
	
	return building

func ToDict() -> Dictionary:
	return {
		"name": self.name
	}
