extends Resource
class_name CountryData

signal process_day_complete

const BASE_ARMY_COST := 20

# Important
var country_name: String
var is_player: bool = false
var daily_process_hour: int = 0
var ai_controller: CountryAI = null

var allowedCountries: Array[String] = []  # Countries allowed to have Troop Presence

# Useful for AI and other things in the future
var border_provinces = []
var enemy_border_provinces = []
var neighbor_countries = []
var provinces_with_city = []
var provinces = []

var economy_law_penalty: float = 0.0  # 0.10 means 10% income loss
var military_size_ratio := 0.005

#region --- ECONOMY ---
var money: float = 0.0
var income: float = 0.0
var factories_amount: int = 1
var factories_available: int = 1
var factory_income = 100
var hourly_money_income: float = 0.0  # Calculated value
var steel: float = 50.0
var oil: float = 30.0
var steel_production: float = 0.0
var oil_production: float = 0.0
var steel_consumption: float = 0.0
var oil_consumption: float = 0.0
var trade_deals: Dictionary = {}
var base_troop_speed_modifier: float = 1.0
var generals: Array = []
#endregion

#region --- POLITICAL ---
var political_power: float = 100.0
var daily_pp_gain: float = 0.08
var stability: float = 0.5
var war_support: float = 0.5
var relations: Dictionary = {}
#endregion

# Population & Manpower
var total_population: int = 0
var manpower: int = 100
var troops_in_field = 0

#region --- MILITARY ---
var army_level: int = 1
var army_cost: float = 0.0
var troop_speed_modifier: float = 1.0
var deploy_pid: int = -1  # ID of province to deploy to
var recurring_steel_buy: float = 0.0
var recurring_oil_buy: float = 0.0
#endregion

var active_constructions: Array = []
var enemies = []

var ongoing_training: Array[Training.TroopTraining] = []
var ready_troops: Array[Training.ReadyTroop] = []
var troops_country: Array[TroopData] = []


func setup_ai():
	if not is_player:
		ai_controller = CountryAI.new(self)


#region --- Lifecycle ---
func _init(p_country_name: String = "") -> void:
	if p_country_name != "":
		country_name = p_country_name
		
	allowedCountries.append_array([p_country_name, "sea"])
	total_population = CountryManager.get_country_population(self.country_name)
	
	get_income()
	reset_factories()
	reset_cities()
	setup_ai()
	
	# Starting resources based on size/ports & historical values
	var starting_steel_val = 30.0 + factories_amount * 10.0
	var ports_count = 0
	if is_instance_valid(MapManager) and MapManager.country_to_provinces_obj.has(self.country_name):
		for province in MapManager.country_to_provinces_obj[self.country_name]:
			if province.port == Province.PORT_BUILT:
				ports_count += 1
	var starting_oil_val = 20.0 + ports_count * 15.0
	
	if is_instance_valid(CountryManager) and CountryManager.HISTORICAL_RESOURCES.has(country_name.to_lower()):
		var hist = CountryManager.HISTORICAL_RESOURCES[country_name.to_lower()]
		starting_steel_val = hist.get("starting_steel", starting_steel_val)
		starting_oil_val = hist.get("starting_oil", starting_oil_val)
		
	steel = starting_steel_val
	oil = starting_oil_val

	# Starting Money based on industry & population
	money = 2500.0 + (factories_amount * 1200.0) + clamp(total_population * 0.002, 0.0, 50000.0)

	# Generate starting generals
	generate_general()
	generate_general()

	update_manpower_pool()


func process_hour() -> void:
	update_political_power()
	if is_player:
		_process_constructions_hour()
		_process_training_hour()
	update_money()
	update_manpower_pool()
	
	if not is_player:
		ai_controller.think_hour()


func _process_training_hour() -> void:
	for i in range(ongoing_training.size() - 1, -1, -1):
		var training = ongoing_training[i]
		var batch_hourly_cost = (training.divisions_count * training.daily_cost) / 24.0

		if money >= batch_hourly_cost:
			money -= batch_hourly_cost
			var speed_mult = 1.0
			if steel <= 0.0:
				speed_mult *= 0.5
			if oil <= 0.0:
				speed_mult *= 0.5
			training.days_left -= (1.0 / 24.0) * speed_mult

		if training.days_left <= 0:
			_graduate_troops(training)
			ongoing_training.remove_at(i)



func process_day() -> void:
	_process_constructions()
	update_resources()
	_process_training()
	_process_reinforcements()

	process_day_complete.emit()
	if not is_player:
		ai_controller.think_day()


func _process_constructions_hour() -> void:
	for i in range(active_constructions.size() - 1, -1, -1):
		var c = active_constructions[i]
		var hourly_cost = c.get("hourly_cost", c.get("daily_cost", 1000.0) / 24.0)
		money -= hourly_cost
		var hl = c.get("hours_left", c.get("days_left", 5) * 24) - 1
		c["hours_left"] = hl
		c["days_left"] = int(ceil(hl / 24.0))
		if hl <= 0:
			active_constructions.remove_at(i)


func _process_constructions() -> void:
	if not is_player:
		for i in range(active_constructions.size() - 1, -1, -1):
			var c = active_constructions[i]
			var dl = c.get("days_left", 5) - 1
			c["days_left"] = dl
			if dl <= 0:
				active_constructions.remove_at(i)


func update_resources() -> void:
	# Calculate Consumer Goods factor based on stability
	var consumer_goods_ratio = clamp(0.4 - stability * 0.3, 0.1, 0.4)
	var factories_utilization = ceil(factories_amount * consumer_goods_ratio)
	factories_available = max(0, factories_amount - factories_utilization)

	# 1. Base resource extraction + factories/ports
	var base_steel_rate = 3.0
	var base_oil_rate = 1.5

	if is_instance_valid(CountryManager) and CountryManager.HISTORICAL_RESOURCES.has(country_name.to_lower()):
		var hist = CountryManager.HISTORICAL_RESOURCES[country_name.to_lower()]
		base_steel_rate = hist.get("base_steel", 3.0)
		base_oil_rate = hist.get("base_oil", 1.5)

	steel_production = base_steel_rate + factories_available * 1.5

	var ports_count = 0
	var my_provinces = MapManager.country_to_provinces_obj.get(country_name) if is_instance_valid(MapManager) else null
	if my_provinces:
		for province in my_provinces:
			if province.port == Province.PORT_BUILT:
				ports_count += 1
	oil_production = base_oil_rate + ports_count * 2.5

	# 2. Consumption from active troops in field
	var troop_steel_cost = 0.0
	var troop_oil_cost = 0.0

	for troop in troops_country:
		if is_instance_valid(troop):
			var general_log_mod = 1.0 - (troop.general_logistics * 0.05) if troop.general_id != "" else 1.0
			var moving_mult = 2.0 if troop.is_moving else 1.0
			for div in troop.stored_divisions:
				var temp = DivisionData.TEMPLATES.get(div.type, DivisionData.TEMPLATES["infantry"])
				troop_steel_cost += temp.get("steel", 0.0) * 0.1 * general_log_mod
				troop_oil_cost += temp.get("oil", 0.0) * 0.1 * general_log_mod * moving_mult

	# Consumption from training queue
	for training in ongoing_training:
		var temp = DivisionData.TEMPLATES.get(training.division_type, DivisionData.TEMPLATES["infantry"])
		var t_days = max(1.0, float(temp.get("days", 1.0)))
		troop_steel_cost += (temp.get("steel", 0.0) / t_days) * training.divisions_count
		troop_oil_cost += (temp.get("oil", 0.0) / t_days) * training.divisions_count

	steel_consumption = troop_steel_cost
	oil_consumption = troop_oil_cost
	
	# 3. Trade deals balance
	var trade_steel = 0.0
	var trade_oil = 0.0
	var trade_money = 0.0
	
	for deal_id in trade_deals:
		var deal = trade_deals[deal_id]
		var is_sender = (deal.sender.to_lower() == country_name.to_lower())
		var is_recipient = (deal.recipient.to_lower() == country_name.to_lower())
		
		# Amount is daily rate
		if deal.resource == "steel":
			if is_sender:
				trade_steel -= deal.amount
				trade_money += deal.price
			elif is_recipient:
				trade_steel += deal.amount
				trade_money -= deal.price
		elif deal.resource == "oil":
			if is_sender:
				trade_oil -= deal.amount
				trade_money += deal.price
			elif is_recipient:
				trade_oil += deal.amount
				trade_money -= deal.price
				
	# Apply recurring market flows
	var recurring_cost = 0.0
	var recurring_steel_flow = 0.0
	var recurring_oil_flow = 0.0
	
	if recurring_steel_buy > 0.0:
		recurring_cost += recurring_steel_buy * CountryManager.market_steel_price
		recurring_steel_flow = recurring_steel_buy
	elif recurring_steel_buy < 0.0:
		recurring_cost -= abs(recurring_steel_buy) * CountryManager.market_steel_price * 0.8
		recurring_steel_flow = recurring_steel_buy
		
	if recurring_oil_buy > 0.0:
		recurring_cost += recurring_oil_buy * CountryManager.market_oil_price
		recurring_oil_flow = recurring_oil_buy
	elif recurring_oil_buy < 0.0:
		recurring_cost -= abs(recurring_oil_buy) * CountryManager.market_oil_price * 0.8
		recurring_oil_flow = recurring_oil_buy
		
	money = max(0.0, money + trade_money - recurring_cost)
	
	# Update stocks
	steel = max(0.0, steel + steel_production - steel_consumption + trade_steel + recurring_steel_flow)
	oil = max(0.0, oil + oil_production - oil_consumption + trade_oil + recurring_oil_flow)
	
	# Apply speed modifier
	if oil <= 0.0:
		troop_speed_modifier = base_troop_speed_modifier * 0.5
	else:
		troop_speed_modifier = base_troop_speed_modifier

#endregion
func reset_factories():
	# In case a country doesn't have cities
	factories_amount = 1
	factories_available = 1
	if MapManager.country_to_provinces_obj.has(self.country_name):
		for province in MapManager.country_to_provinces_obj[self.country_name]:
			if province.city.length() > 0 or province.factory == province.FACTORY_BUILT:
				factories_amount += 1
				factories_available += 1
func reset_cities():
	provinces_with_city.clear()
	if MapManager.country_to_provinces_obj.has(self.country_name):
		for province in MapManager.country_to_provinces_obj[self.country_name]:
			if province.city.length() > 0:
				provinces_with_city.append(province)

func build_factory(province):
	if factories_available <= 0 or money < 1000.0: return
	province.factory = province.FACTORY_BUILDING
	factories_available -= 1
	var loc_name = province.city.capitalize() if province.city != "" else ("Province " + str(province.id))
	active_constructions.append({
		"type": "Factory",
		"location": loc_name,
		"hours_left": 120,
		"total_hours": 120,
		"days_left": 5,
		"daily_cost": 1000.0,
		"hourly_cost": 1000.0 / 24.0,
		"province": province
	})
	if not is_player:
		EventManager.repeat_task_for_days(5, "money -= 1000", self)
	EventManager.add_event_after_days(5, [
		{province: "factory = FACTORY_BUILT"},
		{self: "factories_amount += 1"},
		{self: "factories_available += 2"}
	])

func build_port(province):
	if factories_available <= 0 or money < 100.0: return
	province.port = Province.PORT_BUILDING
	factories_available -= 1
	var loc_name = province.city.capitalize() if province.city != "" else ("Province " + str(province.id))
	active_constructions.append({
		"type": "Naval Port",
		"location": loc_name,
		"hours_left": 120,
		"total_hours": 120,
		"days_left": 5,
		"daily_cost": 100.0,
		"hourly_cost": 100.0 / 24.0,
		"province": province
	})
	if not is_player:
		EventManager.repeat_task_for_days(5, "money -= 100", self)
	EventManager.add_event_after_days(5, [ 
		{province: "port = PORT_BUILT"},
		{self: "factories_available += 1"}
	])

#region --- Stats & Manpower ---
func update_political_power() -> void:
	political_power += daily_pp_gain

func update_army_cost() -> float:
	var total_cost = 0.0
	if is_instance_valid(TroopManager):
		var my_troops = TroopManager.get_troops_for_country(country_name)
		for troop in my_troops:
			for div in troop.stored_divisions:
				var temp = DivisionData.TEMPLATES.get(div.type, {})
				total_cost += temp.get("cost", 100) * 0.05
	army_cost = total_cost
	return army_cost

func update_money():
	update_army_cost()
	var factories_income = factories_available * factory_income
	var gross_income = income + factories_income - army_cost
	money += (gross_income / 24.0) * (1.0 - economy_law_penalty)

# Run only once
func get_income():
	income = 0
	var provinces = MapManager.country_to_provinces_obj.get(country_name)
	if provinces == null:
		return
	for province in provinces:
		income += province.gdp

func get_fielded_manpower() -> int:
	var total_men = 0
	if is_instance_valid(TroopManager):
		var my_troops = TroopManager.get_troops_for_country(country_name)
		for troop in my_troops:
			for div in troop.stored_divisions:
				var temp = DivisionData.TEMPLATES.get(div.type, {})
				total_men += temp.get("manpower", 1000)
	
	for ready in ready_troops:
		for div in ready.stored_divisions:
			var temp = DivisionData.TEMPLATES.get(div.type, {})
			total_men += temp.get("manpower", 1000)

	for training in ongoing_training:
		var temp = DivisionData.TEMPLATES.get(training.division_type, {})
		total_men += temp.get("manpower", 1000) * training.divisions_count

	return total_men

func update_manpower_pool() -> void:
	if total_population <= 0 and is_instance_valid(CountryManager):
		total_population = CountryManager.get_country_population(country_name)
	troops_in_field = get_fielded_manpower()
	var max_eligible = int(total_population * military_size_ratio)
	manpower = max(0, max_eligible - troops_in_field)
#endregion


#region --- Military Management ---
func train_troops(count: int, type: String = "infantry") -> bool:
	var template = DivisionData.TEMPLATES.get(type)
	if not template:
		push_error("Unknown division type: %s" % type)
		return false

	var total_manpower_needed = count * template["manpower"]
	var daily_cost = count * template["cost"]

	# Check affordability (Manpower + First day of cost)
	if manpower < total_manpower_needed or money < daily_cost:
		return false

	manpower -= total_manpower_needed
	# Add to training queue
	var training_batch = Training.TroopTraining.new(count, type, template["days"], template["cost"])
	ongoing_training.append(training_batch)
	return true


func _process_training() -> void:
	# Loop backwards so we can safely remove finished batches
	for i in range(ongoing_training.size() - 1, -1, -1):
		var training = ongoing_training[i]
		var batch_daily_cost = training.divisions_count * training.daily_cost

		if money >= batch_daily_cost:
			money -= batch_daily_cost
			var speed_mult = 1.0
			if steel <= 0.0:
				speed_mult *= 0.5
			if oil <= 0.0:
				speed_mult *= 0.5
			training.days_left -= 1.0 * speed_mult

		if training.days_left <= 0:
			_graduate_troops(training)
			ongoing_training.remove_at(i)


func _graduate_troops(training: Training.TroopTraining) -> void:
	var new_divisions: Array[DivisionData] = []
	for d in range(training.divisions_count):
		new_divisions.append(DivisionData.create_division(training.division_type))

	ready_troops.append(Training.ReadyTroop.new(new_divisions))
#endregion

func get_army_pressure() -> float:
	var army_size = 0
	for troop in TroopManager.get_troops_for_country(country_name):
		army_size += troop.divisions_count
	return army_size

	#var capacity = max(1.0, (gdp * 0.03) + factories_amount * 5)
	return 0.5

func get_max_morale() -> float:
	var base = 60.0 + (stability * 40.0) + (army_level * 5.0)
	var mult = 1.0
	if money < 0: mult *= 0.5
	if steel <= 0: mult *= 0.8
	if oil <= 0: mult *= 0.8
	return base * mult

func get_attack_efficiency() -> float:
	var eff = 0.9 + (war_support * 0.3) + (army_level * 0.05)
	var mult = 1.0
	if money < 0: mult *= 0.7
	if steel <= 0: mult *= 0.9
	if oil <= 0: mult *= 0.7
	return eff * mult


func get_defense_efficiency() -> float:
	var eff = 1.0 + (stability * 0.15) + (army_level * 0.05)
	var mult = 1.0
	if money < 0: mult *= 0.8
	if steel <= 0: mult *= 0.75
	if oil <= 0: mult *= 0.9
	return eff * mult
#endregion


#region --- Deployment Helper ---
func deploy_ready_troop(troop: Training.ReadyTroop, specific_pid: int = -1) -> bool:
	var index = ready_troops.find(troop)
	if index == -1:
		return false

	var target_pid = specific_pid
	if target_pid == -1:
		if deploy_pid != -1 and MapManager.province_objects[deploy_pid].country == country_name:
			target_pid = deploy_pid
		else:
			var provinces = MapManager.country_to_provinces.get(country_name, [])
			if provinces.is_empty():
				return false
			target_pid = provinces.pick_random()

	TroopManager.deploy_specific_divisions(country_name, troop.stored_divisions, target_pid)
	ready_troops.remove_at(index)
	return true


#endregion

var cached_garrison_hubs: Array = []

# Regenerates Army. Needs Money and Manpower
func _process_reinforcements():
	var all_my_troops = TroopManager.get_troops_for_country(country_name)

	for troop in all_my_troops:
		if troop.is_moving:
			continue

		for div in troop.stored_divisions:
			if div.hp < div.max_hp:
				var template = DivisionData.TEMPLATES[div.type]
				var men_needed = int(template["manpower"] * 0.05)  # 5% reinforcement

				# REINFORCEMENT SAFETY: Stop if it would drop us below zero
				if manpower >= men_needed and money >= (template["cost"] * 0.05):
					money -= (template["cost"] * 0.05)
					manpower -= men_needed
					div.hp = min(div.max_hp, div.hp + 5.0)


func set_relation_with(other_country_name: String, value: int) -> void:
	other_country_name = other_country_name.to_lower()
	relations[other_country_name] = clampi(value, 0, 100)


func get_relation_with(other_country_name: String) -> int:
	other_country_name = other_country_name.to_lower()
	return relations.get(other_country_name, 50)


# --- GENERALS MANAGEMENT ---

func generate_general(g_name: String = "") -> Dictionary:
	if g_name == "":
		var first_names = ["Arthur", "George", "Charles", "Erwin", "Douglas", "Bernard", "Dwight", "Georgy", "Philippe", "Rodion", "Gerd", "Heinz", "Tomoyuki", "Isoroku"]
		var last_names = ["Montgomery", "Patton", "Rommel", "MacArthur", "Eisenhower", "Zhukov", "Leclerc", "Malinovsky", "Rundstedt", "Guderian", "Yamashita", "Yamamoto", "De Gaulle", "Bradley"]
		g_name = "Gen. " + first_names.pick_random() + " " + last_names.pick_random()
	var gen = {
		"id": "gen_" + str(randi()),
		"name": g_name,
		"attack": randi_range(1, 4),
		"defense": randi_range(1, 4),
		"logistics": randi_range(1, 4),
		"level": 1,
		"xp": 0.0,
		"assigned_troop_id": ""
	}
	generals.append(gen)
	return gen


func assign_general(gen_id: String, troop: TroopData) -> void:
	for g in generals:
		if g.id == gen_id:
			# Unassign from old troop first
			if g.assigned_troop_id != "":
				var old_troop = instance_from_id(int(g.assigned_troop_id))
				if is_instance_valid(old_troop):
					old_troop.general_id = ""
					old_troop.general_name = ""
					old_troop.general_attack = 0
					old_troop.general_defense = 0
					old_troop.general_logistics = 0
			
			# Assign to new troop
			g.assigned_troop_id = str(troop.get_instance_id())
			troop.general_id = g.id
			troop.general_name = g.name
			troop.general_attack = g.attack
			troop.general_defense = g.defense
			troop.general_logistics = g.logistics
			break


func unassign_general(gen_id: String) -> void:
	for g in generals:
		if g.id == gen_id:
			if g.assigned_troop_id != "":
				var old_troop = instance_from_id(int(g.assigned_troop_id))
				if is_instance_valid(old_troop):
					old_troop.general_id = ""
					old_troop.general_name = ""
					old_troop.general_attack = 0
					old_troop.general_defense = 0
					old_troop.general_logistics = 0
				g.assigned_troop_id = ""
			break


func add_general_xp(gen_id: String, xp_gain: float) -> void:
	for g in generals:
		if g.id == gen_id:
			g.xp += xp_gain
			var target_xp = g.level * 100.0
			if g.xp >= target_xp:
				g.xp -= target_xp
				g.level += 1
				var stat = randi() % 3
				if stat == 0:
					g.attack += 1
				elif stat == 1:
					g.defense += 1
				else:
					g.logistics += 1
				print("General %s leveled up to %d!" % [g.name, g.level])
			break
