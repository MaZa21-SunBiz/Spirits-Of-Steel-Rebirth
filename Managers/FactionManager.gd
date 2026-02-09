extends Node

var factions: Dictionary = {}

func create_faction(leader: String, name: String):
	factions[name] = [leader]
	CountryManager.get_country(leader).factions.append(name)
	print(factions)

func invite_faction(inviter: CountryData, invitee: CountryData):
	factions[inviter.faction_name].append(invitee.country_name)
	invitee.faction_name = inviter.faction_name
	print(factions)
