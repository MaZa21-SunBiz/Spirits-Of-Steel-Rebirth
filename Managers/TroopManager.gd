extends Node

var AUTO_MERGE = true

var troops: Array = []
var moving_troops: Array = []

var path_cache: Dictionary = {} # { start_id: { target_id: path_array } }
var flag_cache: Dictionary = {} # { country_name: texture }

var troop_selection: TroopSelection

const TroopDataScript = preload("res://Scripts/TroopData.gd")


func _process(delta: float) -> void:
	for troop in moving_troops:
		_update_moving_troop(troop, delta)


## TroopManager.gd


func _update_moving_troop(troop: TroopData, _delta: float) -> void:
	# We no longer calculate position here.
	# We only check if the logical time has expired.

	if GameState.main.clock.paused:
		return

	var start_time = troop.get_meta("start_time", 0.0)
	var duration = troop.get_meta("duration", 0.0)

	# Use the same 'visual clock' the shader uses
	# Assuming GameState or similar tracks total unpaused game seconds
	var current_game_time = GameState.main.clock.total_game_seconds

	var progress = (current_game_time - start_time) / duration

	# Update meta so _draw() knows where to put labels
	troop.set_meta("progress", clamp(progress, 0.0, 1.0))

	var targetPID = troop.path.front()
	var enemies = MapManager.province_objects[targetPID].troops_here.filter(
		func(t):
			return WarManager.is_at_war_names(t.country_name, troop.country_name)
	)

	if not enemies.is_empty() and not GameState.current_world.clock.paused:
		WarManager.start_battle(troop.province_id, targetPID)
		pause_troop(troop)
		for enemy in enemies:
			pause_troop(enemy)
		return

	var start = troop.get_meta("start_pos", troop.position)
	var end = troop.target_position
	var total_dist = start.distance_to(end)

	# Safety check for instant arrival
	if total_dist < 0.5:
		troop.position = end
		_arrive_at_leg_end(troop)
		return

	# Unified progress calculation
	var move_progress = troop.get_meta("progress", 0.0)

	var base_speed = 1

	# Increment progress based on real-time and game speed
	move_progress += (base_speed * (troop.country_obj.troop_speed_modifier if troop.country_obj else 1.0) * GameState.current_world.clock.time_scale * delta) / total_dist

	if move_progress >= 1.0:
		troop.position = end
		troop.set_meta("progress", 0.0)
		_arrive_at_leg_end(troop)
	else:
		# Smoothly slide from A to B
		troop.position = start.lerp(end, move_progress)
		troop.set_meta("progress", move_progress)


func _start_next_leg(troop: TroopData) -> void:
	if troop.path.is_empty():
		_stop_troop(troop)
		return

	var next_pid = troop.path[0]

	# --- Combat Check ---
	var enemies = MapManager.province_objects.get(next_pid).troops_here.filter(
		func(t): return WarManager.is_at_war_names(t.country_name, troop.country_name)
	)

	if not enemies.is_empty() and not GameState.current_world.clock.paused:
		WarManager.start_battle(troop.province_id, next_pid)
		pause_troop(troop)
		for enemy in enemies:
			pause_troop(enemy)
		return

	var target_pos = MapManager.province_centers.get(next_pid, troop.position)
	var dist = troop.position.distance_to(target_pos)

	var base_speed = 1.0
	var speed_mod = troop.country_obj.troop_speed_modifier if troop.country_obj else 1.0
	var duration = dist / (base_speed * speed_mod)
	troop.target_position = target_pos
	troop.set_meta("start_pos", troop.position)
	troop.set_meta("duration", duration)
	troop.set_meta("start_time", GameState.main.clock.total_game_seconds)

	troop.is_moving = true

	if not moving_troops.has(troop):
		moving_troops.append(troop)


func _arrive_at_leg_end(troop: TroopData) -> void:
	if troop.path.is_empty():
		_stop_troop(troop)
		return

	var arrived_pid = int(troop.path.pop_front())

	_move_troop_to_province_logically(troop, arrived_pid)
	MapManager.update_province_troop_state(arrived_pid)

	# Trigger occupation/events
	WarManager.resolve_province_arrival(arrived_pid, troop)

	# Check if we keep going or stop
	if troop.path.is_empty():
		_stop_troop(troop)
		if AUTO_MERGE:
			_auto_merge_in_province(troop.province_id, troop.country_name)
	else:
		_start_next_leg(troop)


func _stop_troop(troop: TroopData) -> void:
	moving_troops.erase(troop)
	troop.is_moving = false
	troop.path.clear()


# Pause a troop along its path
func pause_troop(troop: TroopData) -> void:
	moving_troops.erase(troop)

	troop.target_position = troop.position

	troop.is_moving = false


func command_move_assigned(payload: Array) -> void:
	if payload.is_empty():
		return

	# 1. Group the payload by troop
	# We need this because one source troop might be the "parent" for 5 different moves
	var troop_to_moves = {}
	for entry in payload:
		var t = entry.get("troop")
		if not t:
			continue
		if not troop_to_moves.has(t):
			troop_to_moves[t] = []
		troop_to_moves[t].append(entry)

	# 2. Process each source troop
	for troop in troop_to_moves:
		var moves = troop_to_moves[troop]

		# Sort moves so that the one requiring the MOST divisions happens last
		# This allows us to keep the original troop node for the "main" objective
		moves.sort_custom(func(a, b): return a.get("divisions", 1) < b.get("divisions", 1))

		for i in range(moves.size()):
			var move_data = moves[i]
			var requested_count = int(move_data.get("divisions", 1))

			# If this is the last move in the list OR we are requesting everything left
			if i == moves.size() - 1 or requested_count >= troop.stored_divisions.size():
				# No splitting needed for the final move; just move the original troop
				_apply_movement_path(troop, move_data["province_id"])
				break
			else:
				# Splitting logic:
				var batch: Array[DivisionData] = []
				for j in range(requested_count):
					if not troop.stored_divisions.is_empty():
						batch.append(troop.stored_divisions.pop_back()) # Take from the end

				if batch.is_empty():
					continue

				# Create a new troop node for this small "detachment"
				_apply_movement_path(_create_new_split_troop(troop, batch), move_data["province_id"])


# Helper to keep your code clean
func _apply_movement_path(troop: TroopData, target_pid: int) -> void:
	if troop.province_id == target_pid:
		_stop_troop(troop)
		return

	var country_ref = CountryManager.get_country(troop.country_name)
	var allowed = country_ref.allowedCountries if country_ref else []
	var path = _get_cached_path(troop.province_id, target_pid, allowed)

	if not path.is_empty():
		troop.path = path.duplicate()
		if int(troop.path[0]) == int(troop.province_id):
			troop.path.pop_front()

		troop.set_meta("start_pos", troop.position)
		_start_next_leg(troop)
	else:
		_stop_troop(troop)


func _get_cached_path(start_id: int, target_id: int, allowed_countries: Array[String]) -> Array:
	if start_id == target_id:
		return []

	var key = Vector2i(start_id, target_id)
	if path_cache.has(key):
		return path_cache[key].duplicate()

	var path = MapManager.find_path(start_id, target_id, allowed_countries)

	if not path.is_empty() and path[0] == start_id:
		path.pop_front()

	if not path.is_empty():
		path_cache[key] = path.duplicate()

	return path


func _create_new_split_troop(original: TroopData, specific_divisions: Array) -> TroopData:
	var pos = original.position
	MapManager.update_province_troop_state(original.province_id)

	var new_troop = TroopDataScript.new(
		original.country_name,
		original.province_id,
		0,
		pos,
		TroopManager.get_flag(original.country_name)
	)
	# FIX: Ensure the new split troop knows which country it belongs to
	new_troop.country_obj = original.country_obj

	# Immediately overwrite the empty array with our specific divisions
	new_troop.stored_divisions = specific_divisions

	# Copy runtime metadata for new troop
	new_troop.is_moving = false
	new_troop.path = []
	new_troop.set_meta("start_pos", pos)
	new_troop.set_meta("time_left", 0.0)
	new_troop.set_meta("progress", 0.0)

	# Register the new troop in all indexes
	troops.append(new_troop)
	_add_troop_to_indexes(new_troop)

	return new_troop


func create_troop(country: String, divs: int, prov_id: int) -> TroopData:
	if divs <= 0:
		return null

	var country_data = CountryManager.get_country(country)
	var ideology = country_data.ideology_name if country_data else ""
	var flag = get_flag(country, ideology)

	var pos = MapManager.province_centers.get(prov_id, Vector2.ZERO)

	var troop = load("res://Scripts/Divisions/TroopData.gd").new(
		country, prov_id, divs, pos, flag
	)

	# FIX: Assign the country object reference
	troop.country_obj = CountryManager.get_country(country)

	# Initialize runtime metadata
	troop.set_meta("start_pos", pos)
	troop.set_meta("time_left", 0.0)
	troop.set_meta("progress", 0.0)
	troop.is_moving = false
	troop.path = []
	troop.province_id = prov_id

	troops.append(troop)
	_add_troop_to_indexes(troop)

	if AUTO_MERGE:
		_auto_merge_in_province(prov_id, country)

	return troop


func _auto_merge_in_province(province_id: int, country: String) -> void:
	if not AUTO_MERGE:
		return

	var province = MapManager.province_objects.get(province_id)
	var candidates: Array = []

	# 1. Collect Valid Candidates
	for t in province.troops_here:
		if t.country_name == country:
			if not t.is_moving and t.path.is_empty() and not moving_troops.has(t):
				candidates.append(t)

	if candidates.size() <= 1:
		return

	# 2. Pick the BEST Primary (The one to keep)
	var primary = candidates[0]
	var current_selection = null

	# Check selection safely
	if troop_selection and "selected_troop" in troop_selection:
		current_selection = troop_selection.selected_troop

	for i in range(1, candidates.size()):
		var current = candidates[i]

		# Prioritize keeping the selected unit
		if current_selection and current_selection == current:
			primary = current
			break

		# Keep the one with the most divisions
		if current.divisions_count > primary.divisions_count:
			primary = current

	# 3. Merge others into Primary
	var to_remove = []
	for t in candidates:
		if t == primary:
			continue

		# MERGE ARRAYS: Transfer divisions from 't' to 'primary'
		primary.stored_divisions.append_array(t.stored_divisions)

		# Clear 't' divisions so they don't get messy during deletion
		t.stored_divisions.clear()

		to_remove.append(t)

		# Update selection if we just merged the selected unit into another
		if current_selection and current_selection == t:
			if troop_selection.has_method("select_troop"):
				troop_selection.select_troop(primary)
			elif "selected_troop" in troop_selection:
				troop_selection.selected_troop = primary

	for troop in to_remove:
		remove_troop(troop)


## Public hook for the WarManager to force a troop to its home province center.
func move_to_garrison(troop: TroopData) -> void:
	var center = MapManager.province_centers.get(troop.province_id, troop.position)
	troop.position = center
	troop.target_position = center
	_stop_troop(troop) # Stops any ongoing movement


## Adds a troop reference to the spatial and country dictionaries.
func _add_troop_to_indexes(troop: TroopData) -> void:
	var pid = troop.province_id
	var country = troop.country_name

	# Province Index
	if not MapManager.province_objects.has(pid):
		MapManager.province_objects[pid].troops_here = []
	MapManager.province_objects[pid].troops_here.append(troop)

	# Country Index
	if not CountryManager.countries.has(country):
		CountryManager.countries[country].troops_country = []
	CountryManager.countries[country].troops_country.append(troop)


## Removes a troop reference from all data structures (master, moving, indexes).
func remove_troop(troop: TroopData) -> void:
	troops.erase(troop)

	moving_troops.erase(troop)
	var province = MapManager.get_province(troop.province_id)
	if province:
		province.troops_here.erase(troop)

	var country_list = CountryManager.countries[troop.country_name].troops_country
	if country_list:
		country_list.erase(troop)


func _move_troop_to_province_logically(troop: TroopData, new_pid: int) -> void:
	var old_pid = troop.province_id
	if old_pid == new_pid:
		return

	var old_province = MapManager.get_province(old_pid)
	if old_province:
		old_province.troops_here.erase(troop)

	troop.province_id = new_pid

	MapManager.update_province_troop_state(old_pid)
	MapManager.update_province_troop_state(new_pid)

	var new_province = MapManager.get_province(new_pid)
	if new_province:
		new_province.troops_here.append(troop)
	else:
		push_error("TroopManager: Attempted to move troop to non-existent province ID %d" % new_pid)


# Careful using this
func teleport_troop_to_province(troop: TroopData, target_pid: int) -> void:
	var old_province = MapManager.get_province(troop.province_id)
	if old_province:
		old_province.troops_here.erase(troop)

	troop.province_id = target_pid
	troop.is_moving = false
	troop.path.clear()

	var new_center = MapManager.province_centers.get(target_pid, Vector2.ZERO)
	troop.position = new_center
	troop.target_position = new_center

	# Update metadata for the shader/label systems
	troop.set_meta("start_pos", new_center)
	troop.set_meta("progress", 0.0)

	var new_province = MapManager.get_province(target_pid)
	if new_province:
		new_province.troops_here.append(troop)
	else:
		push_error("TroopManager: Teleported to invalid province ID %d" % target_pid)


func get_province_division_count(pid: int) -> int:
	var total = 0
	var list = MapManager.get_province(pid).troops_here
	for troop in list:
		total += troop.divisions_count
	return total


func have_troops_in_both_provinces(pid_a: int, pid_b: int) -> bool:
	var prov_a = MapManager.get_province(pid_a)
	var prov_b = MapManager.get_province(pid_b)

	var a_occupied = prov_a and not prov_a.troops_here.is_empty()
	var b_occupied = prov_b and not prov_b.troops_here.is_empty()

	return a_occupied and b_occupied


func clear_path_cache() -> void:
	path_cache.clear()
	print("Pathfinding cache cleared")


# Remove leading waypoints that are equal to the troop's current province.
func _sanitize_path_for_troop(path: Array, start_pid: int) -> Array:
	if not path:
		return []
	# Duplicate to avoid mutating caller arrays
	var p = path.duplicate()
	# Pop front while first entry equals start_pid
	while p.size() > 0 and int(p[0]) == int(start_pid):
		p.pop_front()
	return p


# Note z21: this function is redundant now
func get_troops_for_country(country):
	if CountryManager.countries.has(country):
		return CountryManager.countries[country].troops_country
	return []


func get_troops_in_province(province_id):
	return MapManager.get_province(province_id).troops_here


func get_province_strength(pid: int, country: String) -> int:
	var total = 0
	for t in MapManager.get_province(pid).troops_here:
		if t.country_name == country:
			total += t.divisions_count
	return total


func deploy_specific_divisions(
	country: String, divisions_to_deploy: Array, prov_id: int
) -> TroopData:
	if divisions_to_deploy.is_empty():
		return null

	var country_data = CountryManager.get_country(country)

	var pos = MapManager.province_centers.get(prov_id, Vector2.ZERO)

	# 1. Create the container (TroopData) with 0 divisions initially
	var troop = TroopDataScript.new(country, prov_id, 0, pos, flag_cache.get(country))

	# 2. Inject the specific divisions we trained
	troop.stored_divisions = divisions_to_deploy

	# 3. Setup Runtime Metadata
	troop.set_meta("start_pos", pos)
	troop.set_meta("time_left", 0.0)
	troop.set_meta("progress", 0.0)
	troop.is_moving = false
	troop.path = []
	troop.province_id = prov_id

	# 4. Register
	troops.append(troop)
	_add_troop_to_indexes(troop)

	if AUTO_MERGE:
		_auto_merge_in_province(prov_id, country)

	return troop


# Used by popup for now
var flag_redirects: Dictionary = {}

func _ready() -> void:
	_load_flag_redirects()

func _load_flag_redirects() -> void:
	var path = "res://assets/flags/flag_redirects.json"
	if FileAccess.file_exists(path):
		var file = FileAccess.open(path, FileAccess.READ)
		var json = JSON.new()
		var error = json.parse(file.get_as_text())
		if error == OK:
			flag_redirects = json.data
		else:
			push_error("TroopManager: Failed to parse flag_redirects.json")

var custom_flag_path: String = ""

func set_custom_flag_path(path: String):
	if path != "" and not path.ends_with("/"):
		path += "/"
	custom_flag_path = path
	flag_cache.clear() # Clear cache to force reload from new path


func get_flag(country: String, ideology: String = "") -> Texture2D:
	# Normalize the keys
	country = country.to_lower()
	ideology = ideology.to_lower()
	
	# Cache key needs to include ideology if provided
	var cache_key = country
	if ideology != "":
		cache_key = "%s_%s" % [country, ideology]

	# If already cached → return it
	if flag_cache.has(cache_key):
		return flag_cache[cache_key]

	# 0. Check Redirects
	if flag_redirects.has(country):
		var redirect = flag_redirects[country]
		var target_country = redirect["target"]
		var target_ideology = redirect["ideology"]
		
		if ideology != "":
			return get_flag(target_country, ideology)
		else:
			return get_flag(target_country, target_ideology)

	var path = ""
	
	# Helper to check both custom and default locations
	var find_resource = func(sub_path: String):
		if custom_flag_path != "":
			var full_custom = custom_flag_path + sub_path
			if ResourceLoader.exists(full_custom):
				return full_custom
		var full_default = "res://assets/flags/" + sub_path
		if ResourceLoader.exists(full_default):
			return full_default
		return ""

	# 1. Try Specific Ideology Flag: {path}/country/ideology_flag.png
	if ideology != "":
		path = find_resource.call("%s/%s_flag.png" % [country, ideology])
		if path != "":
			var tex := load(path)
			flag_cache[cache_key] = tex
			return tex

	# 2. Try Neutral/Default Flag in new structure: {path}/country/neutral_flag.png
	path = find_resource.call("%s/neutral_flag.png" % country)
	if path != "":
		var tex := load(path)
		flag_cache[cache_key] = tex
		return tex

	# 3. Fallback: Suffix Stripping / Semantic Fallback
	var suffixes = {
		"_kingdom": "monarchist",
		"_empire": "monarchist",
		"_republic": "liberal",
		"_commune": "communist",
		"_union": "communist",
		"_socialist": "communist",
		"_fascist": "facist",
		"_national": "facist",
		"_democratic": "liberal"
	}
	
	for suffix in suffixes:
		if country.ends_with(suffix):
			var base_country = country.left(country.length() - suffix.length())
			var fallback_ideology = suffixes[suffix]
			var check_ideology = ideology if ideology != "" else fallback_ideology
			
			var tex = get_flag(base_country, check_ideology)
			if tex:
				flag_cache[cache_key] = tex
				return tex
			
			if ideology != "":
				tex = get_flag(base_country, "")
				if tex:
					flag_cache[cache_key] = tex
					return tex

	# 4. Fallback to old flat structure (just in case): {path}/country_flag.png
	path = find_resource.call("%s_flag.png" % country)
	if path != "":
		var tex := load(path)
		flag_cache[cache_key] = tex
		return tex

	return null


func find_troop_owning_division(div_to_find: DivisionData) -> TroopData:
	for t in troops:
		if div_to_find in t.stored_divisions:
			return t
	return null
