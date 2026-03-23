extends Resource
class_name BiomeData

@export var name: String
@export var color: Color

static func FromDict(a_data: Dictionary) -> BiomeData:
	var biomeData: BiomeData = BiomeData.new()
	
	biomeData.name = a_data["name"]
	biomeData.color = Color.html(a_data.get("color", "#FFFFFF"))
	
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
	}
