extends Resource
class_name ResourceData

@export var name: String
@export var color: Color
@export var icon: String
@export var base_price: int
@export var tags: Dictionary[String, float]

static func FromDict(a_data: Dictionary) -> ResourceData:
	var resource: ResourceData = ResourceData.new()
	
	resource.name = a_data["name"]
	resource.color = Color.html(a_data.get("color", "#FFFFFF"))
	resource.icon = a_data.get("icon", "")
	resource.base_price = a_data.get("base_price", 100)
	
	var typed_tags: Dictionary[String, float] = {}
	var raw_tags = a_data.get("tags", {})
	for k in raw_tags.keys():
		typed_tags[str(k)] = float(raw_tags[k])
	resource.tags = typed_tags
	
	return resource

static func FromValues(
		a_name: String,
		a_color: Color,
		a_icon: String,
		a_base_price: int,
		a_tags: Dictionary[String, float]
	) -> ResourceData:
	var resource: ResourceData = ResourceData.new()
	
	resource.name = a_name
	resource.color = a_color
	resource.icon = a_icon
	resource.base_price = a_base_price
	resource.tags = a_tags
	
	return resource

func ToDict() -> Dictionary:
	return {
		"name": self.name,
		"color": "#" + self.color.to_html(false).to_upper(),
		"icon": self.icon,
		"base_price": self.base_price,
		"tags": self.tags,
	}
