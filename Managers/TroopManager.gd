extends Node

var AUTO_MERGE = false

func _arrive_at_waypoint(troop: TroopData) -> void:
	if troop.waypoints.is_empty():
		_stop_troop(troop)
	else:
		_start_next_waypoint(troop)

var troops: Array = []
var moving_troops: Array = []

var path_cache: Dictionary = {}  # { start_id: { target_id: path_array } }
var flag_cache: Dictionary = {}  # { country_name: texture }

var troop_selection: TroopSelection

const TroopDataScript = preload("res://Scripts/TroopData.gd")


func _process(delta: float) -> void:
	if GameState.main and GameState.main.clock and GameState.main.clock.paused:
		return

	var time_scale = GameState.main.clock.time_scale if (GameState.main and GameState.main.clock) else 1.0
	var step_mult = delta * time_scale

	for i in range(moving_troops.size() - 1, -1, -1):
		var troop = moving_troops[i]
		if not is_instance_valid(troop):
			moving_troops.remove_at(i)
			continue
		_update_moving_troop(troop, step_mult)


func _update_moving_troop(troop: TroopData, step_mult: float) -> void:
	var speed = troop.get_speed()
	var move_dist = speed * step_mult
	
	troop.position = troop.position.move_toward(troop.target_position, move_dist)

	if troop.position.distance_squared_to(troop.target_position) <= 2.25:
		troop.position = troop.target_position
		_arrive_at_waypoint(troop)


func move_troop_to_position(troop: TroopData, target_pos: Vector2) -> void:
	if not is_instance_valid(troop):
		return

	if not is_instance_valid(GameState) or not GameState.main:
		return

	var map_sprite = GameState.main.get_node_or_null("MapContainer/CultureSprite")
	if not map_sprite:
		return

	var target_pid := 1
	var path_pids := []

	if is_instance_valid(MapManager):
		target_pid = MapManager.get_province_at_pos(target_pos, map_sprite)
		if target_pid > 1:
			var target_prov = MapManager.province_objects.get(target_pid)
			if target_prov and target_prov.country != troop.country_name:
				return
			path_pids = MapManager.find_path(troop.province_id, target_pid)

	if target_pid <= 1:
		return

	troop.waypoints.clear()

	if is_instance_valid(MapManager):
		for pid in path_pids:
			var c = MapManager.province_centers.get(pid)
			if c:
				troop.waypoints.append(c)

	if troop.waypoints.is_empty() or troop.waypoints[-1].distance_to(target_pos) > 2.0:
		troop.waypoints.append(target_pos)

	troop.path = path_pids
	_start_next_waypoint(troop)


func _start_next_waypoint(troop: TroopData) -> void:
	if troop.waypoints.is_empty():
		_stop_troop(troop)
		return

	var target_pos = troop.waypoints.pop_front()
	if troop.position.distance_squared_to(target_pos) <= 2.25:
		if not troop.waypoints.is_empty():
			_start_next_waypoint(troop)
		else:
			_stop_troop(troop)
		return

	troop.target_position = target_pos
	troop.is_moving = true

	if not moving_troops.has(troop):
		moving_troops.append(troop)


func _stop_troop(troop: TroopData) -> void:
	moving_troops.erase(troop)
	troop.is_moving = false
	troop.waypoints.clear()


func pause_troop(troop: TroopData) -> void:
	moving_troops.erase(troop)
	troop.target_position = troop.position
	troop.is_moving = false
	troop.waypoints.clear()


func get_flag(country_name: String) -> Texture2D:
	var clean_name = country_name.to_lower()
	if flag_cache.has(clean_name):
		return flag_cache[clean_name]

	var path = "res://map_data/flags/%s.png" % clean_name
	if ResourceLoader.exists(path):
		var tex = load(path) as Texture2D
		flag_cache[clean_name] = tex
		return tex

	flag_cache[clean_name] = null
	return null


func spawn_troop(country_name: String, province_id: int, divisions_count: int) -> TroopData:
	var center = MapManager.province_centers.get(province_id, Vector2.ZERO) if is_instance_valid(MapManager) else Vector2.ZERO
	var flag = get_flag(country_name)

	var troop = TroopDataScript.new(country_name, province_id, divisions_count, center, flag)
	troop.country_obj = CountryManager.get_country(country_name) if is_instance_valid(CountryManager) else null

	troops.append(troop)

	if troop.country_obj:
		troop.country_obj.troops_country.append(troop)

	if is_instance_valid(MapManager):
		var prov = MapManager.province_objects.get(province_id)
		if prov:
			prov.troops_here.append(troop)
		MapManager.update_province_troop_state(province_id)

	return troop


func _auto_merge_in_province(pid: int, country_name: String) -> void:
	if not is_instance_valid(MapManager) or not MapManager.province_objects.has(pid):
		return

	var local_troops = MapManager.province_objects[pid].troops_here.filter(
		func(t): return t.country_name == country_name and not t.is_moving
	)

	if local_troops.size() <= 1:
		return

	var primary = local_troops[0]
	for i in range(1, local_troops.size()):
		var current = local_troops[i]
		if current.divisions_count > primary.divisions_count:
			primary = current

	for t in local_troops:
		if t == primary:
			continue
		primary.stored_divisions.append_array(t.stored_divisions)
		delete_troop(t)


func split_troop(troop: TroopData, amount_to_split: int) -> TroopData:
	if amount_to_split <= 0 or amount_to_split >= troop.divisions_count:
		return null

	var split_divisions: Array[DivisionData] = []
	for i in range(amount_to_split):
		split_divisions.append(troop.stored_divisions.pop_back())

	var new_troop = TroopDataScript.new(
		troop.country_name,
		troop.province_id,
		0,
		troop.position + Vector2(8, 8),
		get_flag(troop.country_name)
	)
	new_troop.country_obj = troop.country_obj
	new_troop.stored_divisions = split_divisions
	troop._update_caches()
	new_troop._update_caches()

	troops.append(new_troop)

	if new_troop.country_obj:
		new_troop.country_obj.troops_country.append(new_troop)

	if is_instance_valid(MapManager):
		var prov = MapManager.province_objects.get(troop.province_id)
		if prov:
			prov.troops_here.append(new_troop)

	return new_troop


func delete_troop(troop: TroopData) -> void:
	if not is_instance_valid(troop):
		return

	troops.erase(troop)
	moving_troops.erase(troop)

	var pid = troop.province_id
	if is_instance_valid(MapManager) and MapManager.province_objects.has(pid):
		MapManager.province_objects[pid].troops_here.erase(troop)
		MapManager.update_province_troop_state(pid)

	var country_obj = CountryManager.get_country(troop.country_name) if is_instance_valid(CountryManager) else null
	if country_obj:
		country_obj.troops_country.erase(troop)

	if is_instance_valid(troop_selection):
		troop_selection.selected_troops.erase(troop)
		troop_selection.selection_changed.emit()

	troop.queue_free()


func _move_troop_to_province_logically(troop: TroopData, new_pid: int) -> void:
	var old_pid = troop.province_id
	if is_instance_valid(MapManager) and MapManager.province_objects.has(old_pid):
		var old_province = MapManager.province_objects[old_pid]
		old_province.troops_here.erase(troop)

	troop.province_id = new_pid

	if is_instance_valid(MapManager) and MapManager.province_objects.has(new_pid):
		var new_province = MapManager.province_objects[new_pid]
		new_province.troops_here.append(troop)


func get_troops_in_province(pid: int) -> Array:
	if not is_instance_valid(MapManager) or not MapManager.province_objects.has(pid):
		return []
	return MapManager.province_objects[pid].troops_here


func get_troops_for_country(country_name: String) -> Array:
	return troops.filter(func(t): return t.country_name == country_name)


func find_troop_owning_division(div: DivisionData) -> TroopData:
	for t in troops:
		if t.stored_divisions.has(div):
			return t
	return null


func command_move_assigned(move_payload: Array) -> void:
	if not is_instance_valid(MapManager):
		return
	for entry in move_payload:
		var troop: TroopData = entry.get("troop")
		var target_pid: int = entry.get("province_id", -1)
		if is_instance_valid(troop) and target_pid > 1:
			var target_pos = MapManager.province_centers.get(target_pid, troop.position)
			move_troop_to_position(troop, target_pos)


func deploy_specific_divisions(c_name: String, divisions: Array, target_pid: int) -> TroopData:
	var center = MapManager.province_centers.get(target_pid, Vector2.ZERO) if is_instance_valid(MapManager) else Vector2.ZERO
	var flag = get_flag(c_name)

	var troop = TroopDataScript.new(c_name, target_pid, 0, center, flag)
	troop.country_obj = CountryManager.get_country(c_name) if is_instance_valid(CountryManager) else null

	for d in divisions:
		if d is DivisionData:
			troop.stored_divisions.append(d)
	troop._update_caches()

	troops.append(troop)

	if troop.country_obj:
		troop.country_obj.troops_country.append(troop)

	if is_instance_valid(MapManager):
		var prov = MapManager.province_objects.get(target_pid)
		if prov:
			prov.troops_here.append(troop)
		MapManager.update_province_troop_state(target_pid)

	if AUTO_MERGE:
		_auto_merge_in_province(target_pid, c_name)

	return troop


func remove_troop(troop: TroopData) -> void:
	delete_troop(troop)


func teleport_troop_to_province(troop: TroopData, new_pid: int) -> void:
	if not is_instance_valid(troop):
		return
	_move_troop_to_province_logically(troop, new_pid)
	var center = MapManager.province_centers.get(new_pid, troop.position) if is_instance_valid(MapManager) else troop.position
	troop.position = center
	troop.target_position = center
	if is_instance_valid(MapManager):
		MapManager.update_province_troop_state(new_pid)


func get_province_strength(pid: int, c_name: String) -> int:
	var total = 0
	for t in get_troops_in_province(pid):
		if t.country_name == c_name:
			total += t.divisions_count
	return total
