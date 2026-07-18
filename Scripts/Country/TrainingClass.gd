extends Resource
class_name Training

class TroopTraining:
	var divisions_count: int
	var division_type: String
	var days_left: float
	var daily_cost: float

	func _init(_count: int, _type: String, _days: float, _cost: float):
		divisions_count = _count
		division_type = _type
		days_left = _days
		daily_cost = _cost

class ReadyTroop:
	var stored_divisions: Array[DivisionData] = []

	func _init(_divisions_array: Array[DivisionData]):
		stored_divisions = _divisions_array
