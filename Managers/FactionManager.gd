extends Node

var factions: Dictionary[String, FactionData] = {}

func Initialize(a_factionData: Array) -> void:
	for factionData: Dictionary in a_factionData:
		factions[factionData["name"]] = FactionData.FromDict(factionData)
		for member: FactionMember in factions[factionData["name"]].members:
			CountryManager.get_country(member.polity).factions.append(factionData["name"])

func create_faction(a_leader: String, a_name: String, a_color: Color) -> void:
	factions[a_name] = FactionData.FromValues(a_name, a_color, [FactionMember.FromValues(a_leader, "Leader")])
	CountryManager.get_country(a_leader).factions.append(a_name)
	print(factions)

func invite_faction(inviter: CountryData, invitee: CountryData) -> void:
	for faction in inviter.factions:
		print(faction)
		if factions[faction].members[factions[faction].members.find_custom(
			func(a_faction): return a_faction.polity == inviter.country_name
			)].status == "Leader":
			factions[faction].members.append(FactionMember.FromValues(invitee.country_name, "Member"))
			invitee.factions.append_array(inviter.factions)
	print(factions)

func in_faction(inviter: CountryData, invitee: CountryData) -> bool:
	for faction in invitee.factions:
		if faction in inviter.factions:
			return true
	return false
