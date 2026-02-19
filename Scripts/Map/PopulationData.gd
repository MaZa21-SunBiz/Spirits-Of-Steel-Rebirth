extends Resource
class_name PopulationData

@export var ethnicity: String
@export var amount: int

static func FromDict(a_data: Dictionary) -> PopulationData:
	var population: PopulationData = PopulationData.new()
	
	population.ethnicity = a_data["ethnicity"]
	population.amount = a_data["amount"]
	
	return population

func ToDict() -> Dictionary:
	return {
		"ethnicity": self.ethnicity,
		"amount": self.amount
	}
