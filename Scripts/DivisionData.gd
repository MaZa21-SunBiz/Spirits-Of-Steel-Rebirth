# res://Scripts/DivisionData.gd
class_name DivisionData extends Resource

# --- CONFIGURATION (Game Balance) ---
const TEMPLATES = {
	"infantry":
	{
		"hp": 100.0,
		"manpower": 10000,
		"cost": 500,
		"days": 9,
		"attack": 1,
		"defense": 1,
		"speed": 1.0
	},
	"tank":
	{
		"hp": 280.0,
		"manpower": 20000,
		"cost": 10000,
		"days": 30,
		"attack": 5,
		"defense": 7,
		"speed": 2.5
	},
	"artillery":
	{
		"hp": 50.0,
		"manpower": 1000,
		"cost": 10000,
		"days": 15,
		"attack": 5,
		"defense": 0.3,
		"speed": 0.8
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
