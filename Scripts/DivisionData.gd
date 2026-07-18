# res://Scripts/DivisionData.gd
class_name DivisionData extends Resource

# --- CONFIGURATION (Game Balance) ---
const TEMPLATES = {
	"infantry":
	{
		"hp": 100.0,
		"manpower": 10000,
		"cost": 500,
		"days": 1,
		"attack": 1,
		"defense": 1,
		"speed": 1.0,
		"steel": 1.0,
		"oil": 0.0
	},
	"tank":
	{
		"hp": 300.0,
		"manpower": 30000,
		"cost": 10000,
		"days": 30,
		"attack": 5,
		"defense": 7,
		"speed": 2.5,
		"steel": 8.0,
		"oil": 6.0
	},
	"artillery":
	{
		"hp": 50.0,
		"manpower": 10000,
		"cost": 10000,
		"days": 15,
		"attack": 5,
		"defense": 0.3,
		"speed": 0.8,
		"steel": 5.0,
		"oil": 1.0
	}
}

# --- Instance Properties ---
@export var name: String = "Infantry Division"
@export var type: String = "infantry"
@export var hp: float = 100.0  # Current HP
@export var max_hp: float = 100.0  # Max HP (for UI bars)
@export var experience: float = 0.0
@export var max_manpower: int = 10000


# --- Helper to get stats safely ---
func get_attack_power() -> float:
	var base = TEMPLATES.get(type, TEMPLATES["infantry"])["attack"]
	return base * (1.0 + (experience * 0.5))


func get_defense_power() -> float:
	var base = TEMPLATES.get(type, TEMPLATES["infantry"])["defense"]
	return base * (1.0 + (experience * 0.5))


static func create_division(p_type: String) -> DivisionData:
	var div = DivisionData.new()
	div.type = p_type

	# Load stats from template
	var stats = TEMPLATES.get(p_type, TEMPLATES["infantry"])

	div.hp = stats["hp"]  # Set starting HP
	div.max_hp = stats["hp"]  # Set Max HP
	div.max_manpower = stats["manpower"]

	div.name = "%s" % [p_type.capitalize()]

	return div


func get_raw_state() -> Dictionary:
	var data = {}
	for prop in get_property_list():
		if prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			var val = get(prop.name)
			# If the value is another object with this function, go deeper (Deep Copy)
			if val is Object and val.has_method("get_raw_state"):
				data[prop.name] = val.get_raw_state()
			elif val is Array:
				data[prop.name] = _serialize_array(val)
			else:
				data[prop.name] = val
	return data


func _serialize_array(arr: Array) -> Array:
	var new_arr = []
	for item in arr:
		if item is Object and item.has_method("get_raw_state"):
			new_arr.append(item.get_raw_state())
		else:
			new_arr.append(item)
	return new_arr
