class_name CountryAI

# --- TUNING ---
const TICK_RATE_PEACE := 12  # Slower thinking in peace time
const TICK_RATE_WAR := 2  # Think fast during war
const SATURATION_IDEAL := 1.0  # Target: At least 1 division equivalent per province
const SATURATION_MAX := 4.0  # Avoid overstacking; redistribute if exceeding
const ATTACK_WEIGHT := 2.0  # Multiplier for provinces with enemy troops
const DEFENSE_WEIGHT := 1.5  # Multiplier for defending own borders under threat
const CITY_BONUS := 50.0  # Extra score for cities
const DISTANCE_PENALTY := 0.1  # Reduce score per unit distance to discourage far moves
const MIN_DIVISIONS_PER_SPLIT := 1  # Smallest split size
const MAX_SPLITS_PER_TROOP := 10  # Limit splits to prevent micro-management overhead

# --- AI DIPLOMACY/WAR LOGIC---
const DECLARE_WAR_COOLDOWN_FRAMES := 60 * 10
const MIN_STRENGTH_RATIO := 1.1
const MAX_PARALLEL_WARS := 2
const WAR_SCORE_THRESHOLD := 0.6
const MAX_WAR_DECLARATIONS_PER_TICK := 1

const WAR_PROBABILITY_BASE := 0.1
const MIN_ECONOMY_FOR_WAR := 15000.0
const TENSION_AGGRESSION_FACTOR := 2.0

var country: CountryData
var personality := {"economy": 1.0, "military": 1.0, "aggression": 1.0}
var _last_declare_frame: int = -999999


func _init(_country: CountryData):
	country = _country


func think_hour():
	var tick_rate = TICK_RATE_WAR if _is_at_war() else TICK_RATE_PEACE
	if Engine.get_frames_drawn() % tick_rate != 0:
		return

	var actions = [
		{"score": _score_frontline(), "action": _execute_frontline}
	]
	_execute_best(actions)


func think_day():
	var actions = [
		{"score": _score_factory(), "action": _execute_factory},
		{"score": _score_train(), "action": _execute_train},
		{"score": _score_war(), "action": _execute_war}
	]
	_execute_best(actions)


func _execute_best(actions: Array):
	actions.sort_custom(func(a, b): return a.score > b.score)
	if actions.size() == 0:
		return
	
	# We can execute multiple actions if their score is high enough, 
	# but for now let's stick to the best one that's > 0
	if actions[0].score > 0:
		actions[0].action.call()


func _score_factory() -> float:
	# Prefer building factories if we have money and low factory count
	if country.money < 1000: return 0.0
	var score = 1.0 - (float(country.factories_amount) / 20.0)
	return max(0.1, score) * personality.economy


func _score_train() -> float:
	# Train more if manpower is high and we have money
	if country.money < 500 or country.manpower < 1000: return 0.0
	return 1.0 * personality.military


func _score_war() -> float:
	# War urgency based on tension and borders
	var tension = MapManager.world_tension
	return tension * personality.aggression


func _score_frontline() -> float:
	return 1.0 # Always high priority to manage frontline


func _execute_factory():
	pass


func _execute_train():
	# Improved: Recruit based on current needs (e.g., more if at war)
	var template = DivisionData.TEMPLATES["infantry"]  # Could vary templates based on tech/manpower
	var cost_per = template["cost"]
	var mp_per = template["manpower"]
	var max_affordable = mini(int(country.money / cost_per), int(country.manpower / mp_per))
	if max_affordable < 1:
		return

	var target_recruit = clampi(max_affordable, 1, 10)
	if _is_at_war():
		target_recruit *= 2  # Recruit more aggressively in war
	target_recruit = mini(target_recruit, max_affordable)

	country.train_troops(target_recruit, "infantry")


func _execute_war():
	if country.is_puppet: return
	# 1. THE STOCHASTIC GATE (Randomness + World Tension)
	# If tension is 0.1, chance is roughly 10%. If tension is 1.0, it's 100%.
	var current_tension = MapManager.world_tension
	var roll = randf()

	# Only proceed if we pass the probability check
	if roll > (current_tension * TENSION_AGGRESSION_FACTOR):
		if roll > WAR_PROBABILITY_BASE:  # Even at 0 tension, a small base chance
			return

	# 2. COOLDOWNS & OVEREXTENSION (Existing)
	var frame_now = Engine.get_frames_drawn()
	if frame_now - _last_declare_frame < DECLARE_WAR_COOLDOWN_FRAMES:
		return

	if WarManager.get_enemies_of(country.country_name).size() >= MAX_PARALLEL_WARS:
		return

	# 3. ECONOMIC PRUDENCE
	# AI won't start a war if they can't afford to sustain it
	if country.money < MIN_ECONOMY_FOR_WAR:
		return

	var candidates = _get_neighbor_countries().filter(
		func(enemy):
			return (
				!FactionManager.in_faction(CountryManager.countries[enemy], country)
				&& !CountryManager.countries[enemy].is_puppet
			)
	)
	print(candidates)
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
		if WarManager.is_at_war_names(country.country_name, target_name) || puppeter.has(target_name):
			continue

		# 4. STRENGTH & DISTANCE ANALYSIS
		var ratio = _estimate_country_strength(country.country_name) / max(1.0, _estimate_country_strength(target_name))

		if ratio < MIN_STRENGTH_RATIO:
			continue

		# 5. DYNAMIC SCORING
		var score = (ratio - 1.0) * 2.0

		# Economic Gain: Is this neighbor rich? (GDP check)
		# Assuming you have access to target's money or GDP
		var target_data = CountryManager.get_country(target_name)
		if target_data:
			if _same_faction(country.factions, target_data.factions): continue
			score += (target_data.money / 50000.0)  # Prefer rich targets

		# Target Cities (Existing)
		score += min(MapManager.get_cities_province_country(target_name).size(), 3) * 0.5

		# 6. FINAL THRESHOLD
		# We add a bit of randomness to the score so it's not always the same neighbor
		score += randf_range(-0.5, 0.5)

		if score > best_score and score > WAR_SCORE_THRESHOLD:
			best_score = score
			best_target = target_name

	# 7. EXECUTION
	if best_target:
		_execute_war_declaration(best_target, frame_now)


func _execute_war_declaration(target_name: String, frame: int):
	var target_data = CountryManager.get_country(target_name)
	if target_data:
		WarManager.declare_war(country, target_data)
		# Increasing tension on every war slows down/speeds up the global state
		MapManager.increase_world_tension(0.02)

		_last_declare_frame = frame


func _execute_frontline():
	_handle_deployment()
	_manage_frontline_logic()


func _manage_frontline_logic() -> void:
	var my_troops = TroopManager.get_troops_for_country(country.country_name)
	var idle_troops = my_troops.filter(func(t): return not t.is_moving)
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
				var dist_a = troop_pos.distance_to(MapManager.province_centers[a.id]) / 100.0
				var dist_b = troop_pos.distance_to(MapManager.province_centers[b.id]) / 100.0
				return (a.score / (dist_a + 1.0)) > (b.score / (dist_b + 1.0))
		)

		var divisions_left = troop.divisions_count

		for target in targets:
			if divisions_left <= 0:
				break
			if target.virtual_strength >= SATURATION_MAX:
				continue

			# DETERMINISTIC SPLITTING:
			# If target is empty, only send 1-2 divisions to "capture" it.
			# If target has enemies, send enough to beat them (or everything left).
			var needed = SATURATION_IDEAL
			if target.enemy_strength > 0:
				needed = target.enemy_strength * 1.2  # Bring 20% more than them

			var amount_to_send = clamp(needed, 1, divisions_left)

			# Only split if it's worth the micro-overhead
			if (
				amount_to_send < divisions_left
				and (divisions_left - amount_to_send) < MIN_DIVISIONS_PER_SPLIT
			):
				amount_to_send = divisions_left

			move_payload.append(
				{"troop": troop, "province_id": target.id, "divisions": amount_to_send}  # Pass this to your Command Move
			)

			target.virtual_strength += amount_to_send
			divisions_left -= amount_to_send

	if not move_payload.is_empty():
		TroopManager.command_move_assigned(move_payload)


func _analyze_frontline_targets(enemies: Array) -> Array:
	var targets = []
	var seen = {}

	for enemy_name in enemies:
		var border_pids = MapManager.get_provinces_bordering_enemy(country.country_name, enemy_name)

		for my_pid in border_pids:
			var neighbors = MapManager.adjacency_list.get(my_pid, [])
			for n_id in neighbors:
				# Check if it's enemy territory
				if MapManager.province_objects[n_id].GetFunctionalOwner() == enemy_name and not seen.has(n_id):
					seen[n_id] = true
					var e_str = TroopManager.get_province_strength(n_id, enemy_name)
					var score = 10.0

					# PRIORITY 1: Enemy Armies (Seek and Destroy)
					if e_str > 0:
						score += (e_str * ATTACK_WEIGHT)

					# PRIORITY 2: Cities (Victory Points)
					if n_id in MapManager.all_cities:
						score += CITY_BONUS

					# PRIORITY 3: Opportunity (Unoccupied Provinces)
					if e_str == 0:
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
					var deep_neighbors = MapManager.adjacency_list.get(n_id, [])
					for dn_id in deep_neighbors:
						if (
							MapManager.province_objects[dn_id].GetFunctionalOwner() == enemy_name
							and not seen.has(dn_id)
						):
							if dn_id in MapManager.all_cities:
								targets.append(
									{
										"id": dn_id,
										"virtual_strength": 0.0,
										"enemy_strength":
										TroopManager.get_province_strength(dn_id, enemy_name),
										"score": CITY_BONUS * 0.8  # Slightly lower priority than immediate targets
									}
								)
	return targets


func _handle_peace_movement(idle_troops: Array) -> void:
	var hubs = _get_peace_hubs()
	var move_payload = []
	for troop in idle_troops:
		if not hubs.has(troop.province_id):
			# Choose closest hub to avoid unnecessary long moves
			var troop_pos = MapManager.province_centers[troop.province_id]
			hubs.sort_custom(
				func(a, b):
					var dist_a = troop_pos.distance_to(MapManager.province_centers[a])
					var dist_b = troop_pos.distance_to(MapManager.province_centers[b])
					return dist_a < dist_b
			)
			move_payload.append({"troop": troop, "province_id": hubs[0]})
	if not move_payload.is_empty():
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
		var deploy_id = cities.pick_random()
		
		TroopManager.deploy_specific_divisions(
			country.country_name, 
			troop_data.stored_divisions, 
			deploy_id
		)
		
		country.ready_troops.erase(troop_data)


# --- UTILITIES ---

func _is_at_war() -> bool:
	return not WarManager.get_enemies_of(country.country_name).is_empty()


func _get_peace_hubs() -> Array:
	# Check if we have a valid list of all cities
	var cities = MapManager.get_cities_province_country(country.country_name)
	
	# Fallback: If the country has no cities, use all their provinces
	if cities.is_empty():
		cities = MapManager.country_to_provinces.get(country.country_name, [])
		
	return cities


func _get_neighbor_countries() -> Array:
	var neighbors := {}
	var provs = MapManager.country_to_provinces.get(country.country_name, [])
	for pid in provs:
		var adj = MapManager.adjacency_list.get(pid, [])
		for nid in adj:
			var owner = MapManager.province_objects[nid].GetFunctionalOwner()
			if owner and owner != country.country_name:
				neighbors[owner] = true
	return neighbors.keys()


func _estimate_country_strength(country_name: String) -> float:
	var total = 0.0
	var c = CountryManager.get_country(country_name)
	if c:
		total += float(c.manpower)
		total += float(c.money) * 0.1
	if TroopManager.has_method("get_troops_for_country"):
		var troops = TroopManager.get_troops_for_country(country_name)
		for t in troops:
			for div in t.stored_divisions:
				total += float(div.max_manpower)
				total += float(div.hp)
	return max(0.1, total)


func _same_faction(arr1, arr2):
	return arr2.any(func(element): return arr1.has(element))
