class_name DivisionData extends Resource

# --- CONFIGURATION (Game Balance) ---

# NOTE(soi):ideally the player should make their own division templates ala hoi4 style but for now its enum time
const TEMPLATES: Dictionary = {
	"infantry": {
		"hp": 100.0,
		"manpower": 10000,
		"cost": 500,
		"days": 9,
		"attack": 1,
		"defense": 1,
		"speed": 1.0
	}
}




# --- Instance Properties ---
@export var name: String = "Infantry Division"
@export var type: String = "infantry"
@export var hp: float = 100.0  # Current HP
@export var max_hp: float = 100.0  # Max HP (for UI bars)
@export var experience: float = 0.0
@export var max_manpower: int = 10000
@export var attack: float = 1.0
@export var defense: float = 1.0

# NOTE(sockmit): This isnt sockmit BUT SOILAD

func FromDict(a_dict: Dictionary):
	var division = DivisionData.new()
	division.name = a_dict["name"]
	division.type = a_dict["type"]
	division.hp = a_dict["hp"]
	division.max_hp = a_dict["max_hp"]
	division.experience = a_dict["experience"]
	division.max_manpower = a_dict["max_manpower"]
	division.attack = a_dict.get("attack", 1.0)
	division.defense = a_dict.get("defense", 1.0)
	return division


func ToDict():
	return {
		"name": name,
		"type": type,
		"hp": hp,
		"max_hp": max_hp,
		"experience": experience,
		"max_manpower": max_manpower,
		"attack": attack,
		"defense": defense
	}


# --- Helper to get stats safely ---
func get_attack_power() -> float:
	return attack * (1.0 + (experience * 0.5))


func get_defense_power() -> float:
	return defense * (1.0 + (experience * 0.5))


static func create_division(p_type: String, template_stats: Dictionary = {}) -> DivisionData:
	var div = DivisionData.new()
	div.type = p_type

	# Load stats from template
	var stats = template_stats
	if stats.is_empty():
		stats = TEMPLATES.get(p_type, TEMPLATES["infantry"])

	div.hp = stats["hp"]  # Set starting HP
	div.max_hp = stats["hp"]  # Set Max HP
	div.max_manpower = stats["manpower"]
	div.attack = stats.get("attack", 1.0)
	div.defense = stats.get("defense", 1.0)

	div.name = "%s" % [p_type.capitalize()]

	return div
