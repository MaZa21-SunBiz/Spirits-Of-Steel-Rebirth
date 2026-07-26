extends Node
class_name TroopData

# --- Core Properties ---
var country_name: String
var country_obj: Resource  # Changed to Resource/Object for safety
var province_id: int
var position: Vector2

var stored_divisions: Array[DivisionData] = []

# --- GENERAL STUFF ---
var general_id: String = ""
var general_name: String = ""
var general_attack: int = 0
var general_defense: int = 0
var general_logistics: int = 0

var cached_divisions_count: int = 0
var cached_main_type: String = "infantry"

var divisions_count: int:
	get:
		return cached_divisions_count
	set(value):
		_adjust_divisions_to_match_count(value)

var is_moving: bool = false
var path: Array = []
var waypoints: Array[Vector2] = []
var target_position: Vector2 = Vector2.ZERO
var progress: float = 0.0

func _update_caches() -> void:
	cached_divisions_count = stored_divisions.size()
	if stored_divisions.is_empty():
		cached_main_type = "infantry"
	else:
		cached_main_type = stored_divisions[0].type

func get_influence_radius() -> float:
	return clamp(12.0 + (cached_divisions_count * 1.5), 12.0, 36.0)

func get_speed() -> float:
	var speed_mod = country_obj.troop_speed_modifier if (is_instance_valid(country_obj) and "troop_speed_modifier" in country_obj) else 1.0
	return 12.0 * speed_mod


func _init(
	p_country: String = "",
	p_province_id: int = -1,
	p_divisions: int = 0,
	p_position: Vector2 = Vector2.ZERO,
	p_flag: Texture2D = null
) -> void:
	if p_country == "":
		return
	country_name = p_country
	province_id = p_province_id
	position = p_position

	for i in range(p_divisions):
		var div = DivisionData.new()
		div.name = "Division %d" % (i + 1)
		stored_divisions.append(div)
	_update_caches()


func _adjust_divisions_to_match_count(target_count: int):
	var current = stored_divisions.size()
	if target_count > current:
		for i in range(target_count - current):
			stored_divisions.append(DivisionData.new())
	elif target_count < current:
		stored_divisions.resize(target_count)
	_update_caches()


func get_average_hp_percent() -> float:
	if stored_divisions.is_empty():
		return 0.0
	var total_hp = 0.0
	var total_max = 0.0
	for div in stored_divisions:
		total_hp += div.hp
		total_max += div.max_hp
	return total_hp / total_max if total_max > 0 else 0.0


func get_main_type() -> String:
	return cached_main_type


func get_raw_state() -> Dictionary:
	var data = {}
	for prop in get_property_list():
		# Only save variables you created
		if prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			var val = get(prop.name)

			# DO NOT save actual Objects that belong to other Managers
			# Instead, we just save their names/IDs to re-link later
			if prop.name == "country_obj":
				continue

			# Recursive save for nested "owned" objects (like Divisions)
			if val is Object and val.has_method("get_raw_state"):
				data[prop.name] = val.get_raw_state()
			elif val is Array:
				data[prop.name] = _serialize_array(val)
			else:
				data[prop.name] = val

	# Metadata is essential for your visual positions
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
