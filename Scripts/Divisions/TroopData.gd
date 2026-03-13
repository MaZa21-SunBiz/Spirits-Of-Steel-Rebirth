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
	set(value):
		_adjust_divisions_to_match_count(value)

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
	country_obj = CountryManager.get_country(p_country)

	for i in range(p_divisions):
		var div = DivisionData.new()
		div.name = "Division %d" % (i + 1)
		stored_divisions.append(div)


func _adjust_divisions_to_match_count(target_count: int):
	var current = stored_divisions.size()
	if target_count > current:
		for i in range(target_count - current):
			stored_divisions.append(DivisionData.new())
	elif target_count < current:
		stored_divisions.resize(target_count)
