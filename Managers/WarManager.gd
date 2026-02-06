extends Node

# --- Constants ---
const BATTLE_TICK := 1.0
const MORALE_DECAY_RATE := 0.02  # Adjusted for better flow
const MORALE_BOOST_DEFENDER := 10.0

# --- State ---
var wars := {}
var active_battles := []
var original_territories := {}


class Battle:
	var attacker_pid: int
	var defender_pid: int
	var attacker_country: String
	var defender_country: String

	var attacker_stats: CountryData
	var defender_stats: CountryData

	var attack_progress := 0.0
	var att_morale: float
	var def_morale: float
	var initial_def_morale: float

	# These now represent the total combined HP of all divisions in the battle
	var current_def_hp: float = 0.0
	var total_starting_hp: float = 0.0

	var timer := 0.0
	var position: Vector2
	var manager  # Reference to WarManager

	func _init(atk_pid: int, def_pid: int, atk_c: String, def_c: String, pos: Vector2, m):
		attacker_pid = atk_pid
		defender_pid = def_pid
		attacker_country = atk_c
		defender_country = def_c
		position = pos
		manager = m

		attacker_stats = CountryManager.get_country(attacker_country)
		defender_stats = CountryManager.get_country(defender_country)

		# Sync morale
		att_morale = attacker_stats.get_max_morale() if attacker_stats else 80.0
		initial_def_morale = (
			(defender_stats.get_max_morale() if defender_stats else 80.0)
			+ manager.MORALE_BOOST_DEFENDER
		)
		def_morale = initial_def_morale

		# Set initial HP snapshot
		_update_hp_totals()
		total_starting_hp = current_def_hp

	func _update_hp_totals():
		# This sums up the current HP of every division the defender has in the province
		var total := 0.0
		var def_troops = TroopManager.get_troops_in_province(defender_pid).filter(
			func(t): return t.country_name == defender_country
		)
		for t in def_troops:
			for div in t.stored_divisions:
				total += div.hp
		current_def_hp = total

	func tick(delta: float):
		timer += delta
		if timer >= manager.BATTLE_TICK:
			timer -= manager.BATTLE_TICK
			_resolve_round()

	func _resolve_round():
		var att_troops = TroopManager.get_troops_in_province(attacker_pid).filter(
			func(t): return t.country_name == attacker_country
		)
		var def_troops = TroopManager.get_troops_in_province(defender_pid).filter(
			func(t): return t.country_name == defender_country
		)
		if att_troops.is_empty():
			manager.end_battle(self)
			return

		# --- NEW: SUPPLY & MONEY CHECK ---
		# Calculate how much it costs to keep these divisions fighting this round
		# We'll use 1% of their recruitment cost as a "per-round" supply cost
		var att_supply_cost = 0.0
		for t in att_troops:
			for div in t.stored_divisions:
				var template = div.TEMPLATES.get(div.type, div.TEMPLATES["infantry"])
				att_supply_cost += template["cost"] * 0.5
		attacker_stats.money -= att_supply_cost

		var def_supply_cost = 0.0
		for t in def_troops:
			for div in t.stored_divisions:
				var template = div.TEMPLATES.get(div.type, div.TEMPLATES["infantry"])
				def_supply_cost += template["cost"] * 0.1

		defender_stats.money -= def_supply_cost
		# Apply costs and determine penalties
		var att_supply_mult = 1.0
		var def_supply_mult = 1.0

		if attacker_stats:
			if attacker_stats.money >= att_supply_cost:
				attacker_stats.money -= att_supply_cost
			else:
				att_supply_mult = 0.4
				att_morale -= 2.0  # Extra morale penalty for hungry troops

		if defender_stats:
			if defender_stats.money >= def_supply_cost:
				defender_stats.money -= def_supply_cost
			else:
				def_supply_mult = 0.4
				def_morale -= 2.0

		# --- 1. Calculate Power (Now including Supply Penalty) ---
		var total_atk_power = 0.0
		for t in att_troops:
			for div in t.stored_divisions:
				total_atk_power += div.get_attack_power() * (div.hp / div.max_hp) * att_supply_mult

		var total_def_power = 0.0
		for t in def_troops:
			for div in t.stored_divisions:
				total_def_power += div.get_defense_power() * (div.hp / div.max_hp) * def_supply_mult

		# --- 2. Modifiers (Morale and Efficiency) ---
		var att_eff = attacker_stats.get_attack_efficiency() if attacker_stats else 1.0
		var def_eff = defender_stats.get_defense_efficiency() if defender_stats else 1.0

		var final_attack = total_atk_power * (att_morale / 100.0) * att_eff
		var final_defense = total_def_power * (def_morale / 100.0) * def_eff

		# --- 3. Apply Damage ---
		manager.apply_casualties(defender_pid, defender_country, final_attack)
		manager.apply_casualties(attacker_pid, attacker_country, final_defense * 0.5)

		# --- 4. Update Morale Decay ---
		att_morale -= (final_defense * manager.MORALE_DECAY_RATE)
		def_morale -= (final_attack * manager.MORALE_DECAY_RATE)

		# --- 5. Wrap up Round ---
		_update_hp_totals()

		if current_def_hp <= 0 or def_morale <= 5.0:
			_defender_loses()
			return

		if att_morale <= 5.0:
			manager.end_battle(self)
			return

		# Progress Calculation
		var hp_ratio = 1.0 - (current_def_hp / total_starting_hp) if total_starting_hp > 0 else 1.0
		var morale_ratio = 1.0 - (def_morale / initial_def_morale)
		attack_progress = clamp(max(hp_ratio, morale_ratio), 0.0, 1.0)

	func _defender_loses():
		var troops = TroopManager.get_troops_in_province(defender_pid)
		var retreat_pid = _find_retreat_province(defender_pid, defender_country)

		for t in troops.duplicate():  # Duplicate to avoid modification errors during loop
			if t.country_name != defender_country:
				continue

			# If no where to run or bad luck, unit is destroyed
			if retreat_pid == -1 or randf() < 0.2:
				TroopManager.remove_troop(t)
			else:
				# RETREAT: Lose 20% of strength then move
				var shatter_count = ceil(t.stored_divisions.size() * 0.2)
				for i in range(shatter_count):
					if not t.stored_divisions.is_empty():
						t.stored_divisions.remove_at(randi() % t.stored_divisions.size())

				if t.stored_divisions.is_empty():
					TroopManager.remove_troop(t)
				else:
					TroopManager.teleport_troop_to_province(t, retreat_pid)

		MapManager.transfer_ownership(defender_pid, attacker_country)
		manager._check_country_collapse(defender_country, attacker_country)
		manager.end_battle(self)

	func _find_retreat_province(from_pid: int, country: String) -> int:
		if not MapManager.adjacency_list.has(from_pid):
			return -1

		for n in MapManager.adjacency_list[from_pid]:
			# Retreat logic: Must be owned by self and not currently under attack
			if MapManager.province_to_country[n] == country:
				return n
		return -1

	func _get_divisions(pid: int, country: String) -> float:
		return float(TroopManager.get_province_strength(pid, country))


func _process(delta: float):
	if active_battles.is_empty():
		return
	var current_intensity = delta * GameState.current_world.clock.time_scale
	if current_intensity <= 0:
		return

	for battle in active_battles:
		battle.tick(current_intensity)


func start_battle(attacker_pid: int, defender_pid: int):
	# Prevent duplicate battles
	for b in active_battles:
		if b.attacker_pid == attacker_pid and b.defender_pid == defender_pid:
			return

	var att_troops = TroopManager.get_troops_in_province(attacker_pid)
	var def_troops = TroopManager.get_troops_in_province(defender_pid)

	if att_troops.is_empty() or def_troops.is_empty():
		return

	var atk_country = att_troops[0].country_name
	var def_country = def_troops[0].country_name
	var midpoint = get_province_midpoint(attacker_pid, defender_pid)

	var battle = Battle.new(attacker_pid, defender_pid, atk_country, def_country, midpoint, self)
	active_battles.append(battle)


func end_battle(battle: Battle):
	if active_battles.has(battle):
		active_battles.erase(battle)


func apply_casualties(pid: int, country: String, damage_amount: float):
	var troops_list = TroopManager.get_troops_in_province(pid).filter(
		func(t): return t.country_name == country
	)

	if troops_list.is_empty() or damage_amount <= 0:
		return

	# Distribute total damage among all army stacks in the province
	var damage_per_troop = damage_amount / troops_list.size()

	for t in troops_list:
		if t.stored_divisions.is_empty():
			continue

		# Distribute troop damage among all divisions in that stack
		var damage_per_div = damage_per_troop / t.stored_divisions.size()

		for i in range(t.stored_divisions.size() - 1, -1, -1):
			var div = t.stored_divisions[i]

			# Deduct HP
			div.hp -= damage_per_div

			# Gain Experience based on how much damage they took/dealt
			# More fighting = faster elite status
			div.experience = min(1.0, div.experience + 0.005)

			# Remove division if it hits 0 HP
			if div.hp <= 0:
				t.stored_divisions.remove_at(i)

		# If the entire stack is gone, remove the troop icon from the map
		if t.stored_divisions.is_empty():
			TroopManager.remove_troop(t)


func resolve_province_arrival(pid: int, troop: TroopData):
	var target_country = MapManager.province_to_country.get(pid)

	if target_country != troop.country_name and is_at_war_names(troop.country_name, target_country):
		var enemies = TroopManager.get_province_strength(pid, target_country)

		if enemies <= 0:
			MapManager.transfer_ownership(pid, troop.country_name)
			_check_country_collapse(target_country, troop.country_name)


func declare_war(a: CountryData, b: CountryData) -> void:
	if a == b or is_at_war(a, b):
		return
	_snapshot_country_territory(a.country_name)
	_snapshot_country_territory(b.country_name)
	var ok := add_war_silent(a, b)
	if not ok:
		return

	if a.is_player or b.is_player:
		PopupManager.show_alert("war", a, b)
		MusicManager.play_music(MusicManager.MUSIC.BATTLE_THEME)
		MusicManager.play_sfx(MusicManager.SFX.DECLARE_WAR)


func _snapshot_country_territory(c_name: String) -> void:
	if not original_territories.has(c_name):
		var pids = MapManager.country_to_provinces.get(c_name, []).duplicate()
		original_territories[c_name] = pids


func add_war_silent(a: CountryData, b: CountryData) -> bool:
	if a == b or is_at_war(a, b):
		return false
	if not wars.has(a):
		wars[a] = {}
	if not wars.has(b):
		wars[b] = {}

	wars[a][b] = true
	wars[b][a] = true

	if not a.allowedCountries.has(b.country_name):
		a.allowedCountries.append(b.country_name)
	if not b.allowedCountries.has(a.country_name):
		b.allowedCountries.append(a.country_name)

	return true


func is_at_war(a: CountryData, b: CountryData) -> bool:
	return wars.has(a) and wars[a].has(b)


func is_country_at_war(country_name: String) -> bool:
	var country_data = CountryManager.get_country(country_name)
	if not country_data:
		return false

	return wars.has(country_data) and not wars[country_data].is_empty()


func is_at_war_names(a_name: String, b_name: String) -> bool:
	if not CountryManager:
		return false
	var a_data = CountryManager.get_country(a_name)
	var b_data = CountryManager.get_country(b_name)
	if a_data and b_data:
		return is_at_war(a_data, b_data)
	return false


# API for AI Manager
func get_countries_at_war() -> Array:
	return wars.keys()


## Returns an array of country names that are currently at war with the given country name
func get_enemies_of(country_name: String) -> Array[String]:
	var enemies: Array[String] = []
	var country_data = CountryManager.get_country(country_name)

	if not country_data or not wars.has(country_data):
		return enemies

	# wars[country_data] returns a Dictionary where keys are enemy CountryData objects
	for enemy_data in wars[country_data].keys():
		enemies.append(enemy_data.country_name)

	MapManager.get_cities_province_country(country_name)

	return enemies


func get_province_midpoint(pid1: int, pid2: int) -> Vector2:
	if not MapManager:
		return Vector2.ZERO
	var c1 = MapManager.province_centers.get(pid1, Vector2.ZERO)
	var c2 = MapManager.province_centers.get(pid2, Vector2.ZERO)
	return (c1 + c2) * 0.5


func _check_country_collapse(country_name: String, victor_name: String):
	var cities = MapManager.get_cities_province_country(country_name)

	if cities.size() == 0:
		_handle_total_collapse(country_name, victor_name)


func _handle_total_collapse(fallen_name: String, victor_name: String) -> void:
	var loser := CountryManager.get_country(fallen_name)
	var winner := CountryManager.get_country(victor_name)
	
	# NOTE Z21: Fixes some bug that makes this function run multiple times. Idk how to fix it
	if !wars.has(loser):
		return

	# --- 0. Remove all remaining troops ---
	var remaining_troops = TroopManager.get_troops_for_country(fallen_name).duplicate()
	for t in remaining_troops:
		TroopManager.remove_troop(t)

# --- 1. Clean up wars and permissions ---
	if wars.has(loser):
		wars.erase(loser)
		if loser.allowedCountries.has(victor_name):
			loser.allowedCountries.erase(victor_name)

	for c in wars:
		if wars[c].has(loser):
			wars[c].erase(loser)

		if c.allowedCountries.has(fallen_name):
			c.allowedCountries.erase(fallen_name)
	
	var player_involved := loser.is_player or winner.is_player
	if player_involved:
		MusicManager.play_sfx(MusicManager.SFX.POPUP)

		PopupManager.show_alert("capitulated", loser, loser)

	if loser.is_player:
		MusicManager.play_sfx(MusicManager.SFX.GAME_OVER)
		MusicManager.play_music(MusicManager.MUSIC.MAIN_THEME)
	elif winner.is_player:
		if !is_country_at_war(victor_name):
			MusicManager.play_music(MusicManager.MUSIC.MAIN_THEME)

	# --- 3. Territory preview (for peace UI only) ---
	var provinces_to_negotiate = (
		original_territories
		. get(fallen_name, MapManager.country_to_provinces.get(fallen_name, []))
		. duplicate()
	)

	if winner.is_player:
		for pid in provinces_to_negotiate:
			MapManager.transfer_ownership(pid, fallen_name)

	# --- 4. Player peace OR AI annexation ---
	if winner.is_player:
		var peace_ui = get_tree().root.find_child("PeaceProcessUI", true, false)
		if peace_ui:
			peace_ui.open_menu(winner, loser)
			original_territories.erase(fallen_name)
		return

	# --- 5. AI takes everything ---
	var all_provinces = MapManager.country_to_provinces.get(fallen_name, []).duplicate()
	for pid in all_provinces:
		MapManager.transfer_ownership(pid, victor_name)
	original_territories.erase(fallen_name)
	CountryManager._cleanup_empty_countries()
