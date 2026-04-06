extends Node
# Autoload Name: EconomyManager

# Format: { province_id: { "type": "factory", "days": 20, "daily_cost": 50, "country": CountryData } }
var construction_queue: Dictionary = {}
var building_functions: Dictionary = {}
var building_designs: Dictionary[String, Array] = {}

func _get_latest_design_for_type(country: CountryData, building_type: String) -> BuildingTemplate:
	if country == null:
		return null
	var designs: Array = building_designs.get(country.country_name, [])
	for i in range(designs.size() - 1, -1, -1):
		var design = designs[i]
		if design is BuildingTemplate and design.functionalities.has(building_type):
			return design
	return null

func _get_design_by_name_for_type(country: CountryData, building_type: String, template_name: String) -> BuildingTemplate:
	if country == null or template_name.is_empty():
		return null
	var designs: Array = building_designs.get(country.country_name, [])
	for design in designs:
		if design is BuildingTemplate and design.name == template_name and design.functionalities.has(building_type):
			return design
	return null

func initialize(path: String) -> void:
	var content := FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(content)
	if parsed is Dictionary:
		building_functions = parsed
	else:
		building_functions = {}


func process_economy_day():
	var finished_projects: PackedInt32Array = []
	for pid in construction_queue:
		var project: Dictionary = construction_queue[pid]
		var country: CountryData = project["country"]
		var cost = project["daily_cost"]

		# 1. Deduct daily cost if affordable
		if country.money >= cost:
			country.money -= cost
			project["days"] -= 1
			
			# 2. Check for completion
			if project["days"] <= 0:
				finished_projects.append(pid)
				_complete_construction(pid, project)
		elif country.is_player:
			#print("Construction stalled in %d: Need %d money" % [pid, cost])
			pass

	for pid in finished_projects:
		construction_queue.erase(pid)


func StartInfrastructureConstruction(a_provinceID: int, a_totalDays: int, a_dailyCost: float, a_country: CountryData) -> void:
	if a_country == CountryManager.player_country:
		MusicManager.play_sfx(MusicManager.SFX.BUILD)
		GameState.game_ui.update_economy_menu()
	
	construction_queue[a_provinceID] = {
		"type": "Infrastructure",
		"index": - 1,
		"days": a_totalDays,
		"daily_cost": a_dailyCost,
		"country": a_country
	}

func start_construction(pid: int, type: String, total_days: int, daily_cost: float, country: CountryData, selected_template_name: String = ""):
	var design: BuildingTemplate = _get_design_by_name_for_type(country, type, selected_template_name)
	if design == null:
		design = _get_latest_design_for_type(country, type)
	var display_name = type
	var template_name = ""
	if design != null and not design.name.is_empty():
		display_name = design.name
		template_name = design.name

	# Set the province enum to BUILDING state immediately
	MapManager.province_objects[pid].buildings.append(BuildingData.FromValues(type, BuildingData.BuildingState.CONSTRUCTION, 1.0))
	MapManager.province_objects[pid].buildings[-1].template_name = template_name
	
	if country == CountryManager.player_country:
		MusicManager.play_sfx(MusicManager.SFX.BUILD)
		GameState.game_ui.update_economy_menu()

	construction_queue[pid] = {
		"type": type,
		"name": display_name,
		"index": MapManager.province_objects[pid].buildings.size() - 1,
		"days": total_days,
		"daily_cost": daily_cost,
		"country": country
	}

func _complete_construction(pid: int, project: Dictionary):
	# Update enum to BUILT state
	if project["index"] != -1 && MapManager.province_objects[pid].buildings.has(project["index"]):
		MapManager.province_objects[pid].buildings[project["index"]].state = BuildingData.BuildingState.FUNCTIONAL
	else:
		match project["type"]:
			"Infrastructure":
				MapManager.province_objects[pid].infrastructure += 1

	if project["country"].is_player:
		#EventManager.show_alert("economy", country, null, "Construction of %s complete!" % type.capitalize())
		if GameState.industry_building:
			MusicManager.play_sfx(MusicManager.SFX.CLAPPING)
		MapManager.province_updated()

func is_province_building(pid: int) -> bool:
	return construction_queue.has(pid)

func get_progress_string(pid: int) -> String:
	if construction_queue.has(pid):
		var p = construction_queue[pid]
		var label = p.get("name", p["type"].capitalize())
		return "%s: %d days left (%d/day)" % [label, p["days"], p["daily_cost"]]
	return ""
