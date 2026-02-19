extends Node
# Autoload Name: EconomyManager

# Format: { province_id: { "type": "factory", "days": 20, "daily_cost": 50, "country": CountryData } }
var construction_queue: Dictionary = {}

func process_economy_day():
	var finished_projects = []

	for pid in construction_queue.keys():
		var project = construction_queue[pid]
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
		else:
			if country.is_player:
				print("Construction stalled in %d: Need %d money" % [pid, cost])

	for pid in finished_projects:
		construction_queue.erase(pid)

func start_construction(pid: int, type: String, total_days: int, daily_cost: float, country: CountryData):
	# Set the province enum to BUILDING state immediately
	MapManager.province_objects[pid].buildings.append(BuildingData.FromValues(type, BuildingData.BuildingState.CONSTRUCTION))
	
	if country == CountryManager.player_country:
		MusicManager.play_sfx(MusicManager.SFX.BUILD)

	construction_queue[pid] = {
		"type": type,
		"index": MapManager.province_objects[pid].buildings.size(),
		"days": total_days,
		"daily_cost": daily_cost,
		"country": country
	}
	

func _complete_construction(pid: int, project: Dictionary):
	# Update enum to BUILT state
	MapManager.province_objects[pid].buildings[project["index"]].state = BuildingData.BuildingState.FUNCTIONAL

	if project["country"].is_player:
		#PopupManager.show_alert("economy", country, null, "Construction of %s complete!" % type.capitalize())
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
