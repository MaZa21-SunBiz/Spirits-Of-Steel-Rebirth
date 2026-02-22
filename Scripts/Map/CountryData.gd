extends Resource
class_name CountryData

var economy_law_penalty: float = 0.0 # 0.10 means 10% income loss
var army_composition_cache: Dictionary = {"infantry": 0, "tank": 0, "artillery": 0}
#region --- Configuration & Constants ---
const MANPOWER_RECOVERY_PER_YEAR := 0.10
const MANPOWER_RECOVERY_PER_DAY := MANPOWER_RECOVERY_PER_YEAR / 365.0
var military_size_ratio := 0.005
const BASE_ARMY_COST := 20
#endregion

#region --- Properties ---
var country_name: String
var country_color: Color
var is_player: bool = false
var is_puppet: bool = false
var is_exiled: bool = false

var relations: Dictionary = {}

var factory_port_daily_cost = 0.2 # The less the better. It's percentage based

# Economy
var money: float = 0.0
var gdp: int = 0
var income: float = 0.0
var factories_amount: int = 0
var factory_income = 100
var hourly_money_income: float = 0.0 # Calculated value

signal ideology_changed

# Politics
var political_power: float = 5000.0
var daily_pp_gain: float = 0.04
var stability: float = 0.5
var war_support: float = 0.5
var ideology: Vector2 = Vector2(randi_range(-100, 100), randi_range(-100, 100))
var ideology_name: String = "neutral"

func set_ideology(value: Vector2) -> void:
	ideology = value
	refresh_ideology_name()
	ideology_changed.emit()


# Population & Manpower
var total_population: int = 0
var manpower: int = 0

# Military State
var army_level: int = 1
var army_cost: float = 0.0
var troop_speed_modifier: float = 1.0

# Deployment & Training State
var allowedCountries: Array[String] = []
var puppets: Array = []
var hostedGovernments: Array = []
var owner: String
var host: String
var factions: Array[String] = []
var ongoing_training: Array[TroopTraining] = []
var ready_troops: Array[ReadyTroop] = []
var deploy_pid: int = -1 # ID of province to deploy to
var pre_war_provinces: Array = [] # Snapshotted provinces before a war
#endregion

var _is_loading := false


#region --- Inner Classes ---
class TroopTraining:
	var divisions_count: int
	var division_type: String
	var days_left: int
	var daily_cost: float

	func _init(_count: int, _type: String, _days: int, _cost: float):
		divisions_count = _count
		division_type = _type
		days_left = _days
		daily_cost = _cost


class ReadyTroop:
	var stored_divisions: Array[DivisionData] = []

	func _init(_divisions_array: Array[DivisionData]):
		stored_divisions = _divisions_array


#endregion


#region --- Lifecycle ---
#func _init(p_country_name: String = "") -> void:
#	if p_country_name != "":
#		country_name = p_country_name
#	if _is_loading:
#		return
#	allowedCountries.append_array([p_country_name, "sea"])
#	_refresh_economic_stats()
#	refresh_ideology_name()
#
#	# Initial Manpower Calculation
#	var manpower_used = CountryManager.get_country_used_manpower(self)
#	manpower = int((total_population * military_size_ratio) - manpower_used)
#	_setup_starting_army()

static func FromDict(a_data: Dictionary) -> CountryData:
	var country: CountryData = CountryData.new()
	
	country.country_name = a_data["name"]
	country.country_color = Color.html(a_data.get("color", "#FFFFFF"))
	country.money = a_data.get("money", 0)
	country.ideology = Vector2(a_data.get("ideology", [0, 0])[0], a_data.get("ideology", [0, 0])[1])
	country.political_power = a_data.get("political_power", 5000)
	country.stability = a_data.get("stability", 0.5)
	country.war_support = a_data.get("war_support", 0.5)
	country.puppets = a_data.get("puppets", [])
	country.hostedGovernments = a_data.get("hosted_governments", [])
	country.allowedCountries.append_array([country.country_name, "Sea"])
	country._refresh_economic_stats()
	country.refresh_ideology_name()
	
	# NOTE(Sockmit2007): Urgh...
	#country.manpower = int((country.total_population * country.military_size_ratio) - CountryManager.get_country_used_manpower(country))
	
	return country

func process_hour() -> void:
	if _is_loading:
		return

	political_power += daily_pp_gain

	# Economic Cycle
	# (GDP / Hours in a year) * Tax Rate + Factory Output
	hourly_money_income = ((gdp * 0.0000228310502) + (factories_amount * factory_income)) * (1.0 - economy_law_penalty)
	army_cost = calculate_army_upkeep()
	income = hourly_money_income - army_cost
	money += income

	troop_speed_modifier = 1.0 + (army_level * 0.1)

	update_manpower_pool()
	_process_reinforcements()
	if not is_player:
		AiManager.ai_tick(self)
		pass


func process_day() -> void:
	if _is_loading:
		return

	# Refresh stats that change daily/weekly
	_refresh_economic_stats()
	_process_training()
	DecisionManager.process_country_day(self)
	if not is_player:
		pass


func _refresh_economic_stats() -> void:
	total_population = CountryManager.get_country_population(country_name)
	factories_amount = CountryManager.get_factories_amount(country_name)
	# GDP calculation based on population (Simplified for performance)
	gdp = int(CountryManager.get_country_gdp(country_name) * total_population * 0.000001)


#endregion


func refresh_ideology_name() -> void:
	ideology_name = IdeologyManager.get_ideology_name(ideology)


#region --- Military Management ---
func train_troops(count: int, type: String = "infantry") -> bool:
	var template = DivisionData.TEMPLATES.get(type)
	if not template:
		push_error("Unknown division type: %s" % type)
		return false

	var total_manpower_needed = count * template["manpower"]

	# Check affordability (Manpower + First day of cost)
	if manpower < total_manpower_needed or money < count * template["cost"]:
		return false

	manpower -= total_manpower_needed

	# Add to training queue
	ongoing_training.append(TroopTraining.new(count, type, template["days"], template["cost"]))
	return true


func _process_training() -> void:
	# Loop backwards so we can safely remove finished batches
	for i in range(ongoing_training.size() - 1, -1, -1):
		var training = ongoing_training[i]
		var batch_daily_cost = training.divisions_count * training.daily_cost

		if money >= batch_daily_cost:
			money -= batch_daily_cost
			training.days_left -= 1

		if training.days_left <= 0:
			_graduate_troops(training)
			ongoing_training.remove_at(i)


func _graduate_troops(training: TroopTraining) -> void:
	var new_divisions: Array[DivisionData] = []
	for d in range(training.divisions_count):
		new_divisions.append(DivisionData.create_division(training.division_type))

	ready_troops.append(ReadyTroop.new(new_divisions))


#endregion


#region --- Stats & Manpower ---
func update_manpower_pool() -> void:
	var max_allowed_manpower = int(total_population * military_size_ratio)

	var used_manpower = CountryManager.get_country_used_manpower(self)

	if manpower + used_manpower < max_allowed_manpower:
		manpower += max(1, int(total_population * 0.0001))

	if manpower + used_manpower > max_allowed_manpower:
		manpower = max(0, max_allowed_manpower - used_manpower)

	# HARD SAFETY: Never let the variable itself be negative
	manpower = max(0, manpower)


func get_army_pressure() -> float:
	var army_size = 0
	for troop in TroopManager.get_troops_for_country(country_name):
		army_size += troop.divisions # assuming .divisions property exists on TroopData

	var capacity = max(1.0, (gdp * 0.03) + factories_amount * 5)
	return army_size / capacity


func get_max_morale() -> float:
	return (60.0 + (stability * 40.0) + (army_level * 5.0)) * (0.5 if money < 0 else 1.0)


func get_attack_efficiency() -> float:
	return (0.9 + (war_support * 0.3) + (army_level * 0.05)) * (0.7 if money < 0 else 1.0)


func get_defense_efficiency() -> float:
	return (1.0 + (stability * 0.15) + (army_level * 0.05)) * (0.8 if money < 0 else 1.0)

#endregion


#region --- Deployment Helper ---
func deploy_ready_troop(troop: ReadyTroop, specific_pid: int = -1) -> bool:
	var index = ready_troops.find(troop)
	if index == -1:
		return false

	var target_pid = specific_pid

	# If no specific ID provided, pick random
	if target_pid == -1:
		var provinces = MapManager.country_to_provinces.get(country_name, [])
		if provinces.is_empty():
			return false
		target_pid = provinces.pick_random()

	TroopManager.deploy_specific_divisions(country_name, troop.stored_divisions, target_pid)
	ready_troops.remove_at(index)
	return true


#endregion

var cached_garrison_hubs: Array = []


func demobilize_troop(troop: TroopData, count: int = -1) -> void:
	if not troop or troop.country_name != country_name:
		return

	var divs_to_reserve: Array[DivisionData] = []

	if count == -1 or count >= troop.divisions_count:
		# Full Demobilization
		divs_to_reserve = troop.stored_divisions.duplicate()
		TroopManager.remove_troop(troop)
	else:
		# Partial Demobilization (Peel off the surplus)
		for i in range(count):
			divs_to_reserve.append(troop.stored_divisions.pop_back())
		# Update the TroopManager's view of this troop (re-calculate strength)
		# No need to remove from map, just update the existing object.

	if not divs_to_reserve.is_empty():
		var reserve = ReadyTroop.new(divs_to_reserve)
		ready_troops.append(reserve)


## Enhanced upkeep: Reserves cost 25% of active troops
func calculate_army_upkeep() -> float:
	var active_divisions = 0
	for troop in TroopManager.get_troops_for_country(country_name):
		active_divisions += troop.divisions_count

	var reserve_divisions = 0
	for rt in ready_troops:
		reserve_divisions += rt.stored_divisions.size()

	var active_cost = active_divisions * (army_level * BASE_ARMY_COST)
	var reserve_cost = reserve_divisions * (army_level * BASE_ARMY_COST * 0.25)

	return active_cost + reserve_cost


func _setup_starting_army() -> void:
	# 1. Economic Safety: Calculate what we can actually afford
	# We use the same math as process_hour to see our projected income
	# Don't spend more than 25% of hourly income on starting upkeep
	# 2. Determine count (Strictly capped to prevent icon spam)
	var final_count = clampi(int(((((gdp / 8760.0) * 0.2) + factories_amount * factory_income) * 0.25) / max(1.0, (army_level * BASE_ARMY_COST))), 1, 6) # Start very small (1-6 divs)

	# 3. Manpower Check
	var template = DivisionData.TEMPLATES.get("infantry")

	if manpower < final_count * template["manpower"]:
		final_count = int(manpower / max(1, template["manpower"]))

	if final_count <= 0:
		return

	# 4. Create the DivisionData objects
	var starting_divisions: Array[DivisionData] = []
	for i in range(final_count):
		starting_divisions.append(DivisionData.create_division("infantry"))

	# 5. Safety: Deduct manpower now
	manpower -= (final_count * template["manpower"])

	# 6. Deploy via a safe call
	# Using 'call_deferred' ensures that MapManager/TroopManager are fully loaded
	# before we try to place troops in provinces.
	_deploy_initial_force.call_deferred(starting_divisions)


func _deploy_initial_force(divisions: Array[DivisionData]) -> void:
	var provinces = MapManager.country_to_provinces.get(country_name, [])
	if provinces.is_empty():
		return

	# Get cities specifically to look more "organized"
	var cities = MapManager.get_cities_province_country(country_name)
	var deploy_targets = cities if not cities.is_empty() else provinces

	# If we have a lot of divisions, split them into small stacks (e.g., 5 per stack)
	var stack_size = 5
	var current_batch: Array[DivisionData] = []

	for i in range(divisions.size()):
		current_batch.append(divisions[i])

		# Once batch is full OR it's the last division
		if current_batch.size() >= stack_size or i == divisions.size() - 1:
			var target_pid = deploy_targets.pick_random()
			TroopManager.deploy_specific_divisions(country_name, current_batch, target_pid)
			current_batch = [] # Reset for next stack


func _process_reinforcements():
	var all_my_troops = TroopManager.get_troops_for_country(country_name)

	for troop in all_my_troops:
		if troop.is_moving:
			continue

		for div in troop.stored_divisions:
			if div.hp < div.max_hp:
				var template = DivisionData.TEMPLATES[div.type]
				var men_needed = int(template["manpower"] * 0.05) # 5% reinforcement

				# REINFORCEMENT SAFETY: Stop if it would drop us below zero
				if manpower >= men_needed and money >= (template["cost"] * 0.05):
					money -= (template["cost"] * 0.05)
					manpower -= men_needed
					div.hp = min(div.max_hp, div.hp + 5.0)
					
					
func set_relation_with(other_country_name: String, value: int) -> void:
	relations[other_country_name] = clampi(value, 0, 100)
	#var finish_game = true


func update_relations() -> void:
	for otherName in relations:
		if CountryManager.countries.has(otherName):
			relations[otherName] = 141 - ideology.distance_to(CountryManager.countries[otherName].ideology)
		else:
			print(otherName)
			relations[otherName] = 50

func get_relation_with(other_country_name: String) -> int:
	if CountryManager.countries.has(other_country_name):
		return relations.get(other_country_name, 50)
	else:
		relations.erase(other_country_name)
		return 0
