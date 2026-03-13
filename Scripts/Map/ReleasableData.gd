extends Resource
class_name ReleasableData

@export var data: Dictionary
@export var claims: PackedInt32Array

static func FromDict(a_data: Dictionary) -> ReleasableData:
	var releasable: ReleasableData = ReleasableData.new()
	
	releasable.data = a_data["data"]
	releasable.claims = a_data.get("claims", [])
	
	return releasable

func ToDict() -> Dictionary:
	return {
		"data": self.data,
		"claims": self.claims
	}
