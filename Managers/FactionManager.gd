extends Node

var factions: Dictionary = {}

func create_faction(leader: String, name: String):
	factions[name] = [leader]
	CountryManager.get_country(leader).factions.append(name)
	print(factions)

func invite_faction(inviter: CountryData, invitee: CountryData):
	for faction in inviter.factions:
		factions[faction].append(invitee.country_name)
		invitee.factions = inviter.factions
	print(factions)
