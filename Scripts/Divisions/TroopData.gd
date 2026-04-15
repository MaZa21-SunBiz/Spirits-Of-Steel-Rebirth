extends Node
class_name TroopData

# --- Core Properties ---
var country_name: String
var country_obj: Resource # Changed to Resource/Object for safety
var province_id: int
var position: Vector2

var stored_divisions: Array[DivisionData] = []

var divisions_count: int:
	get:
		return stored_divisions.size()

var is_moving: bool = false
var path: Array = []
var target_position: Vector2 = Vector2.ZERO
var progress: float = 0.0


func _init(
	p_country: String, p_province_id: int, p_divisions: int, p_position: Vector2, _p_flag: Texture2D
) -> void:
	if p_country == "": return
	country_name = p_country
	province_id = p_province_id
	position = p_position
	country_obj = CountryManager.countries[p_country]

	for i in range(p_divisions):
		var div = DivisionData.new()
		div.name = "Division %d" % (i + 1)
		stored_divisions.append(div)

func ToDict() -> Dictionary:
	return {
		"country_name": country_name,
		"divisions": stored_divisions.map(func(d: DivisionData): return d.ToDict()),
		"is_moving": is_moving,
		"path": path,
		"target_position": [target_position.x, target_position.y],
		"progress": progress
	}


static func FromDict(data: Dictionary) -> TroopData:
	# p_country: String, p_province_id: int, p_divisions: int, p_position: Vector2, _p_flag: Texture2D
	var troop = TroopData.new(data["country_name"], 0, 0, Vector2.ZERO, null)
	
	troop.stored_divisions.clear()
	for div_data in data["divisions"]:
		troop.stored_divisions.append(DivisionData.FromDict(div_data))
	
	troop.is_moving = data.get("is_moving", false)
	troop.path = data.get("path", [])
	
	var tp = data.get("target_position", [0, 0])
	troop.target_position = Vector2(tp[0], tp[1])
	
	troop.progress = data.get("progress", 0.0)
	
	return troop
