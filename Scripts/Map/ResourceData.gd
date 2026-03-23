extends Resource
class_name ResourceData

@export var name: String
@export var color: Color
@export var icon: String

static func FromDict(a_data: Dictionary) -> ResourceData:
	var resource: ResourceData = ResourceData.new()
	
	resource.name = a_data["name"]
	resource.color = Color.html(a_data.get("color", "#FFFFFF"))
	resource.icon = a_data.get("icon", "")
	
	return resource

func ToDict() -> Dictionary:
	return {
		"name": self.name,
		"color": "#" + self.color.to_html(false).to_upper(),
		"icon": self.icon,
	}
