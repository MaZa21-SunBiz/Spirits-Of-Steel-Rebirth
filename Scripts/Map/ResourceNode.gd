extends Resource
class_name ResourceNode

@export var type: String
@export var amount: int
@export var quality: float

static func FromDict(a_data: Dictionary) -> ResourceNode:
	var resource: ResourceNode = ResourceNode.new()
	
	resource.type = a_data["type"]
	resource.amount = a_data.get("amount", 1)
	resource.quality = a_data.get("quality", 1.0)
	
	return resource

func ToDict() -> Dictionary:
	return {
		"type": self.type,
		"amount": self.amount,
		"quality": self.quality
	}
