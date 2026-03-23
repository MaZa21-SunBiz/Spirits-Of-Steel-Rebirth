extends Resource
class_name FactionData

@export var name: String
@export var color: Color
@export var members: Array

static func FromValues(a_name: String, a_color: Color, a_members: Array[FactionMember] = []) -> FactionData:
	var faction: FactionData = FactionData.new()
	
	faction.name = a_name
	faction.color = a_color
	faction.members = a_members
	
	return faction

static func FromDict(a_data: Dictionary) -> FactionData:
	var faction: FactionData = FactionData.new()
	
	faction.name = a_data["name"]
	faction.color = Color.html(a_data.get("color", "#FFFFFF"))
	for factionMemberData: Dictionary in a_data["members"]:
		faction.members.append(FactionMember.FromDict(factionMemberData))
	
	return faction

func ToDict() -> Dictionary:
	var data: Dictionary = {
		"name": self.name,
		"color": "#"+color.to_html(false).to_upper(),
		"members": []
	}

	for factionMember: FactionMember in self.members:
		data["members"].append(factionMember.ToDict())

	return data

func UpdateMemberStatus(_a_member: String, _a_index: int) -> void:
	pass
