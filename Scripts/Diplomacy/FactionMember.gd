extends Resource
class_name FactionMember

@export var polity: String
@export var status: String

static func FromValues(a_polity: String, a_status: String) -> FactionMember:
	var member: FactionMember = FactionMember.new()
	
	member.polity = a_polity
	member.status = a_status
	
	return member

static func FromDict(a_data: Dictionary) -> FactionMember:
	var member: FactionMember = FactionMember.new()
	
	member.polity = a_data["polity"]
	member.status = a_data["status"]
	
	return member

func ToDict() -> Dictionary:
	return {
		"polity": self.polity,
		"status": self.status
	}

static func GetIndex(a_status: String) -> int:
	match a_status:
		"Leader":
			return 0
		"Member":
			return 1
		_:
			return -1
