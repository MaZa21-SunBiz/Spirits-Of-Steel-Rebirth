extends Resource

class_name IdeologyDriftTarget

var finalPosition: Vector2 = Vector2(0, 0)
var driftAmount: float = 0

static func FromDict(a_data: Dictionary) -> IdeologyDriftTarget:
	var ideology_drift_target: IdeologyDriftTarget = IdeologyDriftTarget.new()
	
	ideology_drift_target.finalPosition = Vector2(a_data["final_position"][0], a_data["final_position"][1])
	ideology_drift_target.driftAmount = a_data["drift_amount"]
	
	return ideology_drift_target

func ToDict() -> Dictionary:
	return {
		"final_position": [ self.finalPosition.x, self.finalPosition.y ],
		"drift_amount": self.driftAmount
	}
