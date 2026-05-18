extends Node
# Autoload Name: EconomyManager

# Format: { province_id: { "type": "factory", "days": 20, "daily_cost": 50, "country": CountryData } }
var construction_queue: Dictionary = {}
var building_functions: Dictionary = {}
var building_designs: Dictionary[String, Dictionary] = {}

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
			#if country.is_player:
			#	print("Spending %d on %s in %d" % [cost, project.get("type", "UNKNOWN"), pid])
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

	if GameState.instabuild:
		_complete_construction(a_provinceID, construction_queue[a_provinceID])
		construction_queue.erase(a_provinceID)

func start_construction(
	pid: int,
	type: String,
	total_days: int,
	daily_cost: float,
	country: CountryData
):
	var building_province: Province = MapManager.province_objects[pid]
	# Set the province enum to BUILDING state immediately
	building_province.buildings.append(
		BuildingData.FromValues(
			type,
			BuildingData.BuildingState.CONSTRUCTION
		)
	)
	
	if country == CountryManager.player_country:
		MusicManager.play_sfx(MusicManager.SFX.BUILD)
		GameState.game_ui.update_economy_menu()

	construction_queue[pid] = {
		"type": type,
		"index": building_province.buildings.size() - 1,
		"days": total_days,
		"daily_cost": daily_cost,
		"country": country
	}

	if GameState.instabuild:
		_complete_construction(pid, construction_queue[pid])
		construction_queue.erase(pid)

func _complete_construction(pid: int, project: Dictionary):
	var building_province: Province = MapManager.province_objects[pid]
	# Update enum to BUILT state
	print(project["index"])
	print(building_province.buildings.size())
	if (
			project["index"] != -1
			&& project["index"] < building_province.buildings.size()
		):
		building_province.buildings[project["index"]].state = BuildingData.BuildingState.FUNCTIONAL
		print(project)
		match project["type"]:
			"Factory":
				CountryManager.countries[building_province.country].factories_amount += 1
			"Quarry":
				print(building_province.resources)
				if building_province.resources.size() == 0:
					building_province.resources.append(
						ResourceNode.FromDict(
							{
								"type": "Sandstone",
								"amount": 2,
								"quality": 2
							}
						)
					)
				building_province.resource_multiplier += 2
			"Lumber":
				building_province.resources.append(
					ResourceNode.FromDict(
						{
							"type": "Timber",
							"amount": 2,
							"quality": 2
						}
					)
				)
	else:
		match project["type"]:
			"Infrastructure":
				building_province.infrastructure += 1

	CountryManager.countries[building_province.GetFunctionalOwner()].recalculate_stockpile_change()
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
		return "%s: %d days left (%d/day)" % [p["type"].capitalize(), p["days"], p["daily_cost"]]
	return ""
