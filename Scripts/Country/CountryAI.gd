extends RefCounted
class_name CountryAI

var country: CountryData

# AI Tweakables
var money_buffer := 1000.0       # Keep this much cash for emergencies
var factory_cost_estimate := 5000.0
var desired_army_size := 8       # AI will try to maintain this many troops

func _init(c: CountryData):
	country = c

# --- TRIGGERED BY COUNTRYDATA ---

func think_day():
	_manage_economy()
	_manage_politics()
	_manage_military_growth()
	_deploy_queued_troops()

func _manage_politics():
	var at_war = WarManager.is_country_at_war(country.country_name)
	
	if country.political_power >= 150.0:
		var desired_ratio = 0.005
		if at_war:
			desired_ratio = 0.02
		else:
			desired_ratio = 0.01
			
		if country.military_size_ratio < desired_ratio:
			country.political_power -= 150.0
			country.military_size_ratio = desired_ratio
			if desired_ratio == 0.01:
				country.economy_law_penalty = 0.05
			elif desired_ratio == 0.02:
				country.economy_law_penalty = 0.30
			country.update_manpower_pool()

	if country.political_power >= 100.0:
		if country.stability < 0.6:
			country.political_power -= 50.0
			country.stability = min(1.0, country.stability + 0.15)
		elif country.war_support < 0.6 and at_war:
			country.political_power -= 50.0
			country.war_support = min(1.0, country.war_support + 0.15)
		elif country.money >= 5000:
			country.political_power -= 100.0
			country.money -= 5000.0
			country.factories_amount += 1
			country.factories_available += 1

func think_hour():
	# Stagger movement thinking so that countries don't all process paths on every single tick.
	# Checking every 6 hours is more than sufficient for movement updates.
	if (GameState.main.clock.total_ticks + country.daily_process_hour) % 6 == 0:
		_manage_movement()

# --- 1. STRATEGIC: Economy & Industry ---

func _manage_economy():
	# Don't build if we are broke or need the money for war
	if country.money < (factory_cost_estimate + money_buffer):
		return
		
	# Industrialize: Prioritize land-locked factories
	for prov in country.provinces:
		if prov.type == Province.LAND and prov.factory == Province.NO_FACTORY:
			country.build_factory(prov)
			return # Only one project per day

	# Maritime: Build ports if coastal
	for prov in country.provinces:
		if prov.port == Province.NO_PORT:
			for n_id in prov.neighbors:
				if MapManager.province_objects[n_id].type == Province.SEA:
					country.build_port(prov)
					return

# --- 2. STRATEGIC: Military Growth ---

func _manage_military_growth():
	var current_total = country.troops_country.size() + country.ongoing_training.size()
	var needed = desired_army_size - current_total
	
	if needed <= 0:
		return

	var build_priority = ["tank", "artillery", "infantry"]
	
	for type in build_priority:
		if needed <= 0: break
		
		var stats = DivisionData.TEMPLATES[type]
		
		var can_afford_money = floor(country.money / stats.cost)
		var can_afford_manpower = floor(country.manpower / stats.manpower)
		
		var amount_to_train = min(needed, min(can_afford_money, can_afford_manpower))
		
		if amount_to_train > 0:
			country.train_troops(int(amount_to_train), type)
			needed -= amount_to_train

func _deploy_queued_troops():
	if country.ready_troops.is_empty(): 
		return
	
	# Always try to deploy to a City province for organization
	var target_pid = -1
	if not country.provinces_with_city.is_empty():
		target_pid = country.provinces_with_city.pick_random().id
	
	for i in range(country.ready_troops.size() - 1, -1, -1):
		country.deploy_ready_troop(country.ready_troops[i], target_pid)


func _manage_movement():
	var idle_troops = _get_idle_troops()
	if idle_troops.is_empty(): 
		return
	
	var move_payload = []
	var enemies = WarManager.get_enemies_of(country.country_name)
	
	# Determine if we are at war
	if not enemies.is_empty():
		# 1. First priority: Retake our own provinces that have been captured by enemies
		var captured_pids = []
		if MapManager.country_to_provinces.has(country.country_name):
			for pid in MapManager.country_to_provinces[country.country_name]:
				var prov = MapManager.province_objects.get(pid)
				if prov and prov.country != country.country_name:
					captured_pids.append(pid)
					
		# 2. Find enemy border provinces or provinces owned by enemies bordering us
		var threat_pids = []
		for border_prov in country.enemy_border_provinces:
			if border_prov.country in enemies:
				threat_pids.append(border_prov.id)
				
		var targets = []
		targets.append_array(captured_pids)
		targets.append_array(threat_pids)
		
		# If we have targets, send idle troops to the closest target
		if not targets.is_empty():
			for troop in idle_troops:
				var target_pid = _get_closest_pid(troop.province_id, targets)
				if target_pid != -1 and target_pid != troop.province_id:
					move_payload.append({
						"troop": troop, 
						"province_id": target_pid, 
						"divisions": troop.divisions_count
					})
		else:
			# Just try to move closer to any province owned by the enemy
			var enemy_pids = []
			for enemy_name in enemies:
				var enemy_provinces = MapManager.country_to_provinces.get(enemy_name, [])
				enemy_pids.append_array(enemy_provinces)
			
			if not enemy_pids.is_empty():
				for troop in idle_troops:
					var target_pid = _get_closest_pid(troop.province_id, enemy_pids)
					if target_pid != -1 and target_pid != troop.province_id:
						move_payload.append({
							"troop": troop, 
							"province_id": target_pid, 
							"divisions": troop.divisions_count
						})
	else:
		# Peace-time default logic
		var threatened_pids = _get_active_threat_pids()
		if not threatened_pids.is_empty():
			for troop in idle_troops:
				var target_pid = _get_closest_pid(troop.province_id, threatened_pids)
				if target_pid != -1 and target_pid != troop.province_id:
					move_payload.append({
						"troop": troop, 
						"province_id": target_pid, 
						"divisions": troop.divisions_count
					})
		else:
			if country.provinces_with_city.is_empty(): 
				return
				
			var city_ids = []
			for p in country.provinces_with_city: 
				city_ids.append(p.id)

			for troop in idle_troops:
				if not troop.province_id in city_ids:
					var target_city = _get_closest_pid(troop.province_id, city_ids)
					if target_city != -1:
						move_payload.append({
							"troop": troop, 
							"province_id": target_city, 
							"divisions": troop.divisions_count
						})

	# Execute all moves in one batch call
	if not move_payload.is_empty():
		TroopManager.command_move_assigned(move_payload)


func _get_active_threat_pids() -> Array:
	var hot_spots = []
	for province in country.enemy_border_provinces:
		if province.troops_here.size() > 0:
			hot_spots.append(province.id)
	return hot_spots

func _get_idle_troops() -> Array:
	var idle = []
	var battles_by_prov = {}
	for b in WarManager.active_battles:
		battles_by_prov[b.attacker_pid] = true
		battles_by_prov[b.defender_pid] = true
		
	for t in country.troops_country:
		if not t.is_moving and not battles_by_prov.has(t.province_id):
			idle.append(t)
	return idle

func _get_closest_pid(from_id: int, target_ids: Array) -> int:
	var from_pos = MapManager.province_objects[from_id].center
	var best_id = -1
	var min_dist = INF
	
	for tid in target_ids:
		var target_pos = MapManager.province_objects[tid].center
		var dist = from_pos.distance_squared_to(target_pos)
		if dist < min_dist:
			min_dist = dist
			best_id = tid
			
	return best_id
