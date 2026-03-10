extends Resource
# class_name Province

enum { SEA = 0, LAND = 1 }
enum {
	NO_FACTORY = 0,
	NO_PORT = 0,
	FACTORY_BUILDING = 1,
	PORT_BUILDING = 1,
	FACTORY_BUILT = 2,
	PORT_BUILT = 2
}

@export var type: int = LAND
@export var id: int

@export var country: String




@export var city: String

@export var population: int = 0
@export var gdp: int = 1000
@export var center: Vector2
@export var neighbors: Array[int] = []
@export var claims = []

@export var ethnicity = {}
@export var factory: int = NO_FACTORY
@export var port: int = NO_PORT
@export var neighbors_obj: Array = []
@export var troops_here = []
@export var r_color = null

var country_obj: CountryData  # (for save/loading stuff)


func get_raw_state() -> Dictionary:
	var data = {}
	for prop in get_property_list():
		# Only save variables you created
		if prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			var val = get(prop.name)

			if prop.name == "country_obj":
				continue

			if val is Object and val.has_method("get_raw_state"):
				data[prop.name] = val.get_raw_state()
			elif val is Array:
				data[prop.name] = _serialize_array(val)
			else:
				data[prop.name] = val

	var meta_dict = {}
	for m_key in get_meta_list():
		meta_dict[m_key] = get_meta(m_key)
	data["_metadata"] = meta_dict

	return data


func _serialize_array(arr: Array) -> Array:
	var new_arr = []
	for item in arr:
		if item is Object and item.has_method("get_raw_state"):
			new_arr.append(item.get_raw_state())
		else:
			new_arr.append(item)
	return new_arr
