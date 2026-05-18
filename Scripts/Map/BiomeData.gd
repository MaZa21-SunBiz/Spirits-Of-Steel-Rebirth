extends Resource
class_name BiomeData

enum Temperature {
		HOT,
		NORMAL,
		COLD
	}

@export var name: String
@export var color: Color
@export var forest: bool
@export var temperature: Temperature

static func FromDict(a_data: Dictionary) -> BiomeData:
	var biomeData: BiomeData = BiomeData.new()
	
	biomeData.name = a_data["name"]
	biomeData.color = Color.html(a_data.get("color", "#FFFFFF"))
	biomeData.forest = a_data.get(
		"forest",
		biomeData.name.to_lower().contains("forest")
	)
	biomeData.temperature = a_data.get("temperature", Temperature.NORMAL) as Temperature
	
	return biomeData

static func FromValues(a_name: String, a_color: Color) -> BiomeData:
	var biomeData: BiomeData = BiomeData.new()
	
	biomeData.name = a_name
	biomeData.color = a_color
	
	return biomeData

func ToDict() -> Dictionary:
	return {
		"name": self.name,
		"color": "#" + self.color.to_html(false).to_upper(),
		"forest": self.forest,
		"temperature": self.temperature
	}
