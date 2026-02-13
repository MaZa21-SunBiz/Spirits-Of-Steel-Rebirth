extends Node

var factions: Dictionary = {}

func create_faction(leader: String, name: String):
	factions[name] = [leader]
	CountryManager.get_country(leader).factions.append(name)
	print(factions)

func invite_faction(inviter: CountryData, invitee: CountryData):
	for faction in inviter.factions:
		print(faction)
		if factions[faction][0] == inviter.country_name:
			factions[faction].append(invitee.country_name)
			invitee.factions.append_array(inviter.factions)
	print(factions)

func in_faction(inviter: CountryData, invitee: CountryData):
	for faction in invitee.factions:
		if faction in inviter.factions:
			print("smart fella")
			return true
	print("fart smella")
	return false
