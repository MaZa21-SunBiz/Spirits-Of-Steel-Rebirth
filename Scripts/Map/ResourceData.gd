extends Resource
class_name ResourceData

@export var name: String
@export var color: Color
@export var icon: String
@export var tags: Dictionary[String, float]

static func FromDict(a_data: Dictionary) -> ResourceData:
	var resource: ResourceData = ResourceData.new()
	
	resource.name = a_data["name"]
	resource.color = Color.html(a_data.get("color", "#FFFFFF"))
	resource.icon = a_data.get("icon", "")
	resource.tags = a_data.get("tags", {})
	
	return resource

static func FromValues(a_name: String, a_color: Color, a_icon: String, a_tags: Dictionary[String, float]) -> ResourceData:
	var resource: ResourceData = ResourceData.new()
	
	resource.name = a_name
	resource.color = a_color
	resource.icon = a_icon
	resource.tags = a_tags
	
	return resource

func ToDict() -> Dictionary:
	return {
		"name": self.name,
		"color": "#" + self.color.to_html(false).to_upper(),
		"icon": self.icon,
		"tags": self.tags,
	}
