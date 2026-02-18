extends Node

signal player_country_changed
var countries: Dictionary[String, CountryData] = {}
var player_country: CountryData


func _on_hour_passed() -> void:
	if GameState.is_loading_game:
		return

	for c_name: String in countries:
		var country_obj: CountryData = countries[c_name]
		country_obj.process_hour()
		

func _on_day_passed() -> void:
	if GameState.is_loading_game:
		return

	EconomyManager.process_economy_day()
	for c_name: String in countries:
		var country_obj: CountryData = countries[c_name]
		country_obj.process_day()
	
	SuperEventManager.check_events()
	

func initialize_countries() -> void:
	if GameState.is_loading_game:
		print("CountryManager: Skipping initialization (loading save)")
		return
	countries.clear()

	var detected_countries = MapManager.country_to_provinces.keys()
	if detected_countries.is_empty():
		detected_countries = MapManager.country_colors.keys()

	for country_name in detected_countries:
		add_country(country_name)
	for country in countries.values():
		country.update_relations()

	print("CountryManager: Initialized %d countries." % countries.size())


func get_country(c_name: String) -> CountryData:
	c_name = c_name.to_lower()
	if c_name == "sea":
		return null
	if countries.has(c_name):
		return countries[c_name]
	push_warning("CountryManager: Requested non-existent country '%s'" % c_name)
	return null


func set_player_country(country_name: String) -> void:
	var country := countries.get(country_name.to_lower()) as CountryData
	if !country:
		push_error("CountryManager: Requested non-existent country '%s'" % country_name)
		return

	if player_country:
		player_country.is_player = false

	player_country = country
	player_country.is_player = true

	print("Player is now playing as: ", country_name)
	emit_signal("player_country_changed")


func add_country(country_name: String) -> CountryData:
	if country_name == "sea": return
	var c_name_lower = country_name.to_lower()

	# 1. Check if it already exists
	if countries.has(c_name_lower):
		push_warning("CountryManager: Country '%s' already exists!" % country_name)
		return countries[c_name_lower]

	# 2. Check if the flag exists before proceeding
	var flag = TroopManager.get_flag(c_name_lower)
	if flag == null:
		var err_msg = "CountryManager: Cannot add '%s'. No flag found." % country_name
		push_error(err_msg)
		return null

	# 3. If flag exists, create and store the country
	var new_country := CountryData.new(country_name)
	
	# NOTE Z21: Relations should be based on political affinity and stuff
	for existing_name in countries.keys():
		new_country.set_relation_with(existing_name, 50)
		countries[existing_name].set_relation_with(c_name_lower, 50)
	
	countries[c_name_lower] = new_country
	return new_country


# HELPER FUNCTIONS ==========================================


func get_country_population(country_name: String) -> int:
	if not MapManager.country_to_provinces.has(country_name):
		return 0
	var total_pop: int = 0
	var pids = MapManager.country_to_provinces[country_name]
	for pid in pids:
		if MapManager.province_objects.has(pid):
			total_pop += MapManager.province_objects[pid].population
	return total_pop


func get_country_gdp(country_name: String) -> int:
	if not MapManager.country_to_provinces.has(country_name):
		return 0

	var total_gdp: int = 0
	var pids = MapManager.country_to_provinces[country_name]

	for pid in pids:
		if MapManager.province_objects.has(pid):
			total_gdp += MapManager.province_objects[pid].gdp

	return total_gdp


func get_factories_amount(country_name: String) -> int:
	var provinces = MapManager.country_to_provinces.get(country_name, [])
	var count = 0
	for pid in provinces:
		if MapManager.province_objects[pid].factory == Province.FACTORY_BUILT:
			count += 1
	return count

# NOTE(pol): We should keep track of the manpower used instead of recalculating
# In CountryManager.gd (or wherever this static function lives)
static func get_country_used_manpower(country_obj: CountryData) -> int:
	var total_used: int = 0

	# 1. Active Troops on the field
	var active_troops = TroopManager.get_troops_for_country(country_obj.country_name)
	for troop in active_troops:
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
	var stats = DivisionData.TEMPLATES.get(type, DivisionData.TEMPLATES["infantry"])
	return stats["manpower"]
	
func cleanup_empty_countries() -> void:
	var to_remove: Array[String] = []
	
	for c_name in countries.keys():
		var provinces = MapManager.country_to_provinces.get(countries[c_name].country_name, [])
		if provinces.is_empty():
			to_remove.append(c_name)

	for c_name in to_remove:
		print("CountryManager: Removing '%s' (No provinces found)." % c_name)
		countries.erase(c_name)

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
