extends Node

signal player_country_changed
var countries: Dictionary[String, CountryData] = {}
var player_country: CountryData

var Releasables: Array[ReleasableData] = []


func _on_hour_passed() -> void:
	#if GameState.is_loading_game:
	#	return

	for c_name: String in countries:
		countries[c_name].process_hour()
		

func _on_day_passed() -> void:
	#if GameState.is_loading_game:
	#	return

	EconomyManager.process_economy_day()
	for c_name: String in countries:
		countries[c_name].process_day()
	
	SuperEventManager.check_events()
	

func initialize_countries(a_countriesData: Array) -> void:
	if GameState.is_loading_game:
		print("CountryManager: Skipping initialization (loading save)")
		return
	countries.clear()

	for countryData: Dictionary in a_countriesData:
		add_country(countryData)
		
	for country: CountryData in countries.values():
		country.update_relations()
		for puppeted: String in country.puppets:
			InformPuppet(country, countries[puppeted])

	print("CountryManager: Initialized %d countries." % countries.size())


func get_country(c_name: String) -> CountryData:
	if c_name == "Sea":
		return null
	if countries.has(c_name):
		return countries[c_name]
	push_warning("CountryManager: Requested non-existent country '%s'" % c_name)
	return null

func GetCountryColor(a_country: String, a_defaultColor: Color = Color.BLACK) -> Color:
	return countries[a_country].country_color if countries.has(a_country) else a_defaultColor

func set_player_country(country_name: String) -> void:
	var country := countries.get(country_name) as CountryData
	if !country:
		push_error("CountryManager: Requested non-existent country '%s'" % country_name)
		return

	if player_country:
		player_country.is_player = false

	player_country = country
	player_country.is_player = true

	print("Player is now playing as: ", country_name)
	emit_signal("player_country_changed")


func add_country(a_countryData: Dictionary) -> CountryData:
	if a_countryData["name"] == "Sea": return
	var tempName = a_countryData["name"]

	# 1. Check if it already exists
	if countries.has(tempName):
		push_warning("CountryManager: Country '%s' already exists!" % tempName)
		return countries[tempName]

	# 2. Check if the flag exists before proceeding
	var flag = TroopManager.get_flag(tempName)
	if flag == null:
		var err_msg = "CountryManager: Cannot add '%s'. No flag found." % tempName
		push_error(err_msg)
		return null

	# 3. If flag exists, create and store the country
	var new_country: CountryData = CountryData.FromDict(a_countryData)
	
	# NOTE Z21: Relations should be based on political affinity and stuff
	for existing_name in countries.keys():
		new_country.set_relation_with(existing_name, 50)
		countries[existing_name].set_relation_with(tempName, 50)
	
	countries[tempName] = new_country
	return new_country


# HELPER FUNCTIONS ==========================================


func get_country_population(country_name: String) -> int:
	if not MapManager.country_to_provinces.has(country_name):
		return 0
	var total_pop: int = 0
	for pid in MapManager.country_to_provinces[country_name]:
		if MapManager.province_objects.has(pid):
			total_pop += MapManager.province_objects[pid].GetPopulation()
	return total_pop


func get_country_gdp(country_name: String) -> int:
	if not MapManager.country_to_provinces.has(country_name):
		return 0
	var total_gdp: int = 0
	for pid in MapManager.country_to_provinces[country_name]:
		if MapManager.province_objects.has(pid):
			total_gdp += MapManager.province_objects[pid].gdp
	return total_gdp


func get_factories_amount(country_name: String) -> int:
	return MapManager.country_to_provinces.get(country_name, []).reduce(
		func(pid: int, accum: int):
			return (accum + MapManager.province_objects[pid].buildings.reduce(
				func(building: BuildingData, b_accum: int): 
					return (b_accum + 1) if (building.type == "Factory" && building.state == BuildingData.BuildingState.FUNCTIONAL) else b_accum,\
				0
			) if (MapManager.province_objects.has(pid)) else 0),
		0
	)

# NOTE(pol): We should keep track of the manpower used instead of recalculating
# In CountryManager.gd (or wherever this static function lives)
static func get_country_used_manpower(country_obj: CountryData) -> int:
	var total_used: int = 0

	# 1. Active Troops on the field
	for troop in TroopManager.get_troops_for_country(country_obj.country_name):
		for div in troop.stored_divisions:
			total_used += _get_manpower_from_template(div.type)

	# 2. Ongoing Training (Already using templates, but cleaned up)
	for training in country_obj.ongoing_training:
		total_used += (
			training.divisions_count * _get_manpower_from_template(training.division_type)
		)

	# 3. Troops in the "Ready" queue (deployment pool)
	for batch in country_obj.ready_troops:
		for div in batch.stored_divisions:
			total_used += _get_manpower_from_template(div.type)

	return total_used


# Helper to keep the code DRY (Don't Repeat Yourself)
static func _get_manpower_from_template(type: String) -> int:
	return DivisionData.TEMPLATES.get(type, DivisionData.TEMPLATES["infantry"])["manpower"]

func cleanup_empty_countries() -> void:
	var to_remove: Array[String] = []
	
	for c_name in countries.keys():
		var provinces = MapManager.country_to_provinces.get(countries[c_name].country_name, [])
		if provinces.is_empty():
			to_remove.append(c_name)

	for c_name in to_remove:
		print("CountryManager: Removing '%s' (No provinces found)." % c_name)
		# So here, we offer options: Government In Exile, or Dissolution
		var country: CountryData = countries[c_name]
		if country.is_player:
			# Uh oh.
			var lostTerritoryUI = get_tree().root.find_child("LostTerritoryUI", true, false)
			if lostTerritoryUI:
				# Pass the player as the default winner/beneficiary, and the full list of winners
				lostTerritoryUI.open_menu(country)
			pass
		else:
			MapManager.country_to_provinces.erase(c_name)
			countries.erase(c_name)

func InformPuppet(puppeter: CountryData, puppetee: CountryData):
	puppeter.allowedCountries.append(puppetee.country_name)
	puppetee.allowedCountries.append(puppeter.country_name)
	puppetee.is_puppet = true
	puppetee.owner = puppeter.country_name
	puppetee.ideology = puppeter.ideology
	puppetee.ideology_name = puppeter.ideology_name
	puppetee.relations[puppeter.country_name] = 200

func make_puppet(puppeter: CountryData, puppetee: CountryData):
	puppeter.puppets.append(puppetee.country_name)
	puppeter.allowedCountries.append(puppetee.country_name)
	puppetee.allowedCountries.append(puppeter.country_name)
	puppetee.is_puppet = true
	puppetee.owner = puppeter.country_name
	puppetee.ideology = puppeter.ideology
	puppetee.ideology_name = puppeter.ideology_name
	puppetee.relations[puppeter.country_name] = 200
	MapManager.show_countries_map()

func release_puppet(puppeter: CountryData, puppetee: CountryData):
	puppeter.puppets.erase(puppetee.country_name)
	puppeter.allowedCountries.erase(puppetee.country_name)
	puppetee.allowedCountries.erase(puppeter.country_name)
	puppetee.is_puppet = false
	puppetee.owner = ""
	MapManager.show_countries_map()

func MakeHost(a_host: CountryData, a_hosted: CountryData) -> void:
	a_host.hostedGovernments.append(a_hosted.country_name)
	a_host.allowedCountries.append(a_hosted.country_name)
	a_hosted.allowedCountries.append(a_host.country_name)
	a_hosted.is_exiled = true
	a_hosted.host = a_host.country_name
	MapManager.show_countries_map()

func FreeHost(a_host: CountryData, a_hosted: CountryData):
	a_host.puppets.erase(a_hosted.country_name)
	a_host.allowedCountries.erase(a_hosted.country_name)
	a_hosted.allowedCountries.erase(a_host.country_name)
	a_hosted.is_exiled = false
	a_hosted.host = ""
	MapManager.show_countries_map()

func RenameCountry(a_old: String, a_new: String) -> void:
	pass
