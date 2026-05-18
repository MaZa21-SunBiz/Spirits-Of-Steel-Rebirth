class_name DivisionData extends Resource

# --- CONFIGURATION (Game Balance) ---

# NOTE(soi):ideally the player should make their own division templates ala hoi4 style but for now its enum time



const TEMPLATES = {
	"infantry":
	{
		"hp": 100.0,
		"manpower": 10000,
		"cost": 500,
		"days": 9,
		"attack": 1,
		"defense": 1,
		"speed": 1.0,
		"required_resource": "Infantry_equipment",
		"required_resource_amount": 100
	},
	"tank":
	{
		"hp": 280.0,
		"manpower": 20000,
		"cost": 10000,
		"days": 30,
		"attack": 5,
		"defense": 7,
		"speed": 2.5,
		"required_resource": "Tank_equipment",
		"required_resource_amount": 50
	},
	"artillery":
	{
		"hp": 50.0,
		"manpower": 1000,
		"cost": 10000,
		"days": 15,
		"attack": 5,
		"defense": 0.3,
		"speed": 0.8,
		"required_resource": "Artillery_equipment",
		"required_resource_amount": 30
	}
}

# --- Instance Properties ---
@export var name: String = "Infantry Division"
@export var type: String = "infantry"
@export var hp: float = 100.0  # Current HP
@export var max_hp: float = 100.0  # Max HP (for UI bars)
@export var experience: float = 0.0
@export var max_manpower: int = 10000
@export var manpowerPerHP: int = int(max_manpower / max_hp)

# NOTE(sockmit): This isnt sockmit BUT SOILAD
# NOTE(Sockmit2007): Soilad's errors: 
#  - Didn't make FromDict static
#  - Had no defaults for missing arguments
#  - Forgot to add return type
static func FromDict(a_dict: Dictionary) -> DivisionData:
	var division: DivisionData = DivisionData.new()
	division.name = a_dict["name"]
	division.type = a_dict.get("type", "infantry")
	division.hp = a_dict.get("hp", 100)
	division.max_hp = a_dict.get("max_hp", 100)
	division.experience = a_dict.get("experience", 0.0)
	division.max_manpower = a_dict.get("max_manpower", 10000)
	division.manpowerPerHP = int(division.max_manpower / division.max_hp)
	return division


func ToDict():
	return {
		"name": name,
		"type": type,
		"hp": hp,
		"max_hp": max_hp,
		"experience": experience,
		"max_manpower": max_manpower
	}


# --- Helper to get stats safely ---
func get_attack_power() -> float:
	return TEMPLATES.get(type, TEMPLATES["infantry"])["attack"] * (1.0 + (experience * 0.5))


func get_defense_power() -> float:
	return TEMPLATES.get(type, TEMPLATES["infantry"])["defense"] * (1.0 + (experience * 0.5))


static func create_division(p_type: String) -> DivisionData:
	var div = DivisionData.new()
	div.type = p_type

	# Load stats from template
	var stats = TEMPLATES.get(p_type, TEMPLATES["infantry"])

	div.hp = stats["hp"]  # Set starting HP
	div.max_hp = stats["hp"]  # Set Max HP
	div.max_manpower = stats["manpower"]
	div.manpowerPerHP = div.max_manpower / div.max_hp

	div.name = "%s" % [p_type.capitalize()]

	return div
