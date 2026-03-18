class_name CountryAI

# --- TUNING ---
const TICK_RATE_PEACE := 12  # Slower thinking in peace time
const TICK_RATE_WAR := 2  # Think fast during war
const SATURATION_IDEAL := 1.0  # Target: At least 1 division equivalent per province
const SATURATION_MAX := 4.0  # Avoid overstacking; redistribute if exceeding
const DISTANCE_PENALTY := 0.1  # Reduce score per unit distance to discourage far moves
const MIN_DIVISIONS_PER_SPLIT := 1  # Smallest split size
const MAX_SPLITS_PER_TROOP := 10  # Limit splits to prevent micro-management overhead

# --- AI DIPLOMACY/WAR LOGIC---
const DECLARE_WAR_COOLDOWN_FRAMES := 600
const MAX_PARALLEL_WARS := 2
const WAR_SCORE_THRESHOLD := 0.6
const MAX_WAR_DECLARATIONS_PER_TICK := 1


var country: CountryData
var personality: Dictionary[String, Variant]= {
	"economy": {
		"trade": 1.0,
		"industry_amount_factor": 0.05,
		"industry": 1.0,
		"surplus": 1.0
	},
	"military": {
		"training_factor": 1.0,
		"max_economic_ratio": 0.7,
	},
	"war": {
		"probability": {
			"base": 0.1,
			"tension_factor": 2.0,
		},
		"score": {
			"strength": 2.0,
			"money_factor": 0.00002,
			"max_cities": 3,
			"cities": 0.5
		},
		"combat": {
			"attack_weight": 2.0,
			"defense_weight": 1.5,
			"city_bonus": 50.0,
		},
		"min_strength_ratio": 1.1,
		"min_economy": 15000,
	},
	"aggression": 1.0,
}
var _last_declare_frame: int = -999999


func _init(_country: CountryData) -> void:
	country = _country


func think_hour() -> void:
	if Engine.get_frames_drawn() % (TICK_RATE_WAR if _is_at_war() else TICK_RATE_PEACE) != 0:
		return

	_execute_best([
		{"score": _score_frontline(), "action": _execute_frontline}
	])


func think_day() -> void:
	_execute_best([
		{"score": _score_factory(), "action": _execute_factory},
		{"score": _score_train(), "action": _execute_train},
		{"score": _score_war(), "action": _execute_war}
	])


func _execute_best(actions: Array) -> void:
	if actions.size() == 0:
		return
	
	actions.sort_custom(func(a, b): return a.score > b.score)
	
	if actions[0].score > 0:
		actions[0].action.call()


func _score_factory() -> float:
	return 0 if country.money < 1000 else max(0.1, 1.0 - (float(country.factories_amount) * personality["economy"]["industry_amount_factor"])) * personality["economy"]["industry"]


func _score_train() -> float:
	return 0 if country.money < 500 || country.manpower < 1000 else personality["military"]["training_factor"]


func _score_war() -> float:
	return 0 if country.is_puppet else MapManager.world_tension * personality["aggression"]


func _score_frontline() -> float:
	return 1.0 # Always high priority to manage frontline


func _execute_factory() -> void:
	pass


func _execute_train() -> void:
	# Improved: Recruit based on current needs (e.g., more if at war)
	var template = DivisionData.TEMPLATES["infantry"]  # Could vary templates based on tech/manpower
	var max_affordable = mini(int(country.money / template["cost"]), int(country.manpower / template["manpower"]))
	if max_affordable < 1:
		return
	
	country.train_troops(clampi(max_affordable, 1, 20 if _is_at_war() else 10), "infantry")


func _execute_war() -> void:
	# 1. THE STOCHASTIC GATE (Randomness + World Tension)
	# If tension is 0.1, chance is roughly 10%. If tension is 1.0, it's 100%.

	# Only proceed if we pass the probability check
	if randf() > (personality["war"]["probability"]["base"] + MapManager.world_tension * personality["war"]["probability"]["tension_factor"]):
		return

	# 2. COOLDOWNS & OVEREXTENSION (Existing)
	var frame_now = Engine.get_frames_drawn()
	if frame_now - _last_declare_frame < DECLARE_WAR_COOLDOWN_FRAMES || WarManager.get_enemies_of(country.country_name).size() >= MAX_PARALLEL_WARS || country.money < personality["war"]["min_economy"]:
		return

	var candidates = _get_neighbor_countries().filter(
		func(enemy):
			return (
				!FactionManager.in_faction(CountryManager.countries[enemy], country)
				#&& !CountryManager.countries[enemy].is_puppet
			)
	)
	#print(candidates)
	if candidates.is_empty():
		return

	var best_score = -INF
	var best_target = null
	
	var puppeter: PackedStringArray = []
	puppeter.append_array(country.puppets)
	
	if country.is_puppet:
		puppeter.append(country.owner)
		puppeter.append_array(CountryManager.countries[country.owner].puppets)

	for target_name in candidates:
		var target_data = CountryManager.countries[target_name]
		if _same_faction(country.factions, target_data.factions) || WarManager.is_at_war_names(country.country_name, target_name) || puppeter.has(target_name):
			continue

		# 4. STRENGTH & DISTANCE ANALYSIS
		var ratio = _estimate_country_strength(country.country_name) / max(1.0, _estimate_country_strength(target_name))

		if ratio < personality["war"]["min_strength_ratio"]:
			continue

		# 5. DYNAMIC SCORING
		var score = (ratio - 1.0) * personality["war"]["score"]["strength"]  # Strength advantage

		# Economic Gain: Is this neighbor rich? (GDP check)
		# Assuming you have access to target's money or GDP
		score += target_data.money * personality["war"]["score"]["money_factor"]  # Prefer rich targets

		# Target Cities (Existing)
		score += min(MapManager.get_cities_province_country(target_name).size(), personality["war"]["score"]["max_cities"]) * personality["war"]["score"]["cities"]  # More cities = more score, capped at 3 for balance

		# 6. FINAL THRESHOLD
		# We add a bit of randomness to the score so it's not always the same neighbor
		score += randf_range(-0.5, 0.5)

		if score > best_score && score > WAR_SCORE_THRESHOLD:
			best_score = score
			best_target = target_name

	# 7. EXECUTION
	if best_target:
		_execute_war_declaration(best_target, frame_now)


func _execute_war_declaration(target_name: String, frame: int):
	WarManager.declare_war(country, CountryManager.countries[target_name])
	# Increasing tension on every war slows down/speeds up the global state
	MapManager.increase_world_tension(0.02)

	_last_declare_frame = frame


func _execute_frontline():
	_handle_deployment()
	_manage_frontline_logic()


func _manage_frontline_logic() -> void:
	var idle_troops = TroopManager.get_troops_for_country(country.country_name).filter(func(t): return not t.is_moving)
	if idle_troops.is_empty():
		return

	var enemies = WarManager.get_enemies_of(country.country_name)
	if enemies.is_empty():
		_handle_peace_movement(idle_troops)
		return

	# Get weighted targets (Cities, Troops, and Empty Gaps)
	var targets = _analyze_frontline_targets(enemies)
	if targets.is_empty():
		return

	var move_payload = []

	for troop in idle_troops:
		# Sort targets by a mix of Score and Distance
		# Math: score / (distance + 1)
		var troop_pos = MapManager.province_centers[troop.province_id]
		targets.sort_custom(
			func(a, b):
				return (a.score / (troop_pos.distance_to(MapManager.province_centers[a.id]) * 0.01 + 1.0)) > (b.score / (troop_pos.distance_to(MapManager.province_centers[b.id]) * 0.01 + 1.0))
		)

		var divisions_left: int = troop.divisions_count

		for target in targets:
			if divisions_left <= 0:
				break
			if target.virtual_strength >= SATURATION_MAX:
				continue

			# DETERMINISTIC SPLITTING:
			# If target is empty, only send 1-2 divisions to "capture" it.
			# If target has enemies, send enough to beat them (or everything left).
			var amount_to_send: int = clamp(target.enemy_strength * 1.2 if target.enemy_strength > 0 else SATURATION_IDEAL, 1, divisions_left)

			# Only split if it's worth the micro-overhead
			if (
				amount_to_send < divisions_left
				&& (divisions_left - amount_to_send) < MIN_DIVISIONS_PER_SPLIT
			):
				amount_to_send = divisions_left

			move_payload.append(
				{"troop": troop, "province_id": target.id, "divisions": amount_to_send}  # Pass this to your Command Move
			)

			target.virtual_strength += amount_to_send
			divisions_left -= amount_to_send

	if !move_payload.is_empty():
		TroopManager.command_move_assigned(move_payload)


func _analyze_frontline_targets(enemies: Array) -> Array:
	var targets = []
	var seen = {}

	for enemy_name in enemies:
		var border_pids = MapManager.get_provinces_bordering_enemy(country.country_name, enemy_name)

		for my_pid in border_pids:
			for n_id in MapManager.adjacency_list.get(my_pid, []):
				# Check if it's enemy territory
				if MapManager.province_objects[n_id].GetFunctionalOwner() == enemy_name && !seen.has(n_id):
					seen[n_id] = true
					var e_str = TroopManager.get_province_strength(n_id, enemy_name)
					var score = 10.0

					if n_id in MapManager.all_cities:
						score += personality["war"]["combat"]["city_bonus"]

					if e_str > 0:
						score += (e_str * personality["war"]["combat"]["attack_weight"])
					else:
						score += 15.0  # High priority to flip "free" land fast

					targets.append(
						{
							"id": n_id,
							"virtual_strength": 0.0,
							"enemy_strength": e_str,
							"score": score
						}
					)

					# --- BLITZKRIEG LOGIC ---
					# Look at the neighbor's neighbors (2 tiles deep)
					# If an enemy city is just behind the front line and empty, go for it!
					for dn_id in MapManager.adjacency_list.get(n_id, []):
						if (MapManager.province_objects[dn_id].GetFunctionalOwner() == enemy_name && !seen.has(dn_id) && dn_id in MapManager.all_cities):
							targets.append(
								{
									"id": dn_id,
									"virtual_strength": 0.0,
									"enemy_strength":
									TroopManager.get_province_strength(dn_id, enemy_name),
									"score": personality["war"]["combat"]["city_bonus"] * 0.8
								}
							)
	return targets


func _handle_peace_movement(idle_troops: Array) -> void:
	var hubs = _get_peace_hubs()
	var move_payload = []
	for troop in idle_troops:
		if !hubs.has(troop.province_id):
			# Choose closest hub to avoid unnecessary long moves
			var troop_pos: Vector2 = MapManager.province_centers[troop.province_id]
			hubs.sort_custom(
				func(a, b):
					return troop_pos.distance_squared_to(MapManager.province_centers[a]) < troop_pos.distance_squared_to(MapManager.province_centers[b])
			)
			move_payload.append({"troop": troop, "province_id": hubs[0]})
	if !move_payload.is_empty():
		TroopManager.command_move_assigned(move_payload)


func _handle_deployment() -> void:
	if country.ready_troops.is_empty():
		return

	# Get every city the country owns
	var cities = _get_peace_hubs()
	if cities.is_empty():
		return # No land to deploy to

	# We duplicate to safely erase during iteration
	for troop_data in country.ready_troops.duplicate():
		# Pick a random city from the full list to ensure spreading
		TroopManager.deploy_specific_divisions(
			country.country_name, 
			troop_data.stored_divisions, 
			cities.pick_random()
		)
		
		country.ready_troops.erase(troop_data)


# --- UTILITIES ---

func _is_at_war() -> bool:
	return !WarManager.get_enemies_of(country.country_name).is_empty()


func _get_peace_hubs() -> Array:
	# Check if we have a valid list of all cities
	var cities: Array = MapManager.get_cities_province_country(country.country_name)
	
	return MapManager.country_to_provinces.get(country.country_name, []) if cities.is_empty() else cities


func _get_neighbor_countries() -> Array:
	var neighbors: PackedStringArray = []
	for pid in MapManager.country_to_provinces.get(country.country_name, []):
		for nid in MapManager.adjacency_list.get(pid, []):
			var owner: String = MapManager.province_objects[nid].GetFunctionalOwner()
			if owner && owner != country.country_name:
				neighbors.append(owner)
	return neighbors


func _estimate_country_strength(country_name: String) -> float:
	var total = 0.0
	var c = CountryManager.get_country(country_name)
	if c:
		total += float(c.manpower)
		total += float(c.money) * 0.1
	for t in TroopManager.get_troops_for_country(country_name):
		for div in t.stored_divisions:
			total += float(div.max_manpower)
			total += float(div.hp)
	return max(0.1, total)


func _same_faction(arr1: PackedStringArray, arr2: Array[String]) -> bool:
	return arr2.any(func(element): return arr1.has(element))
