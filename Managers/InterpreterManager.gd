extends Node

var heap: Dictionary = {}

func all(...args) -> bool:
	for arg in args:
		if not arg:
			return false
	return true

func any(...args) -> bool:
	for arg in args:
		if arg:
			return true
	return false

func get_variable(variable):
	if not variable is String:
		return variable
	match variable:
		"player":
			return CountryManager.player_country.country_name
		"current_date":
			return GameState.current_world.clock.get_date_string()
		_:
			return heap.get(variable, variable)

func get_function(expression, country: CountryData = null):
	if country == null:
		country = CountryManager.player_country
	
	# Handle multiple functions (Recusive Array Support)
	if expression is Array:
		var last_result = null
		for item in expression:
			last_result = get_function(item, country)
		return last_result

	if not expression is Dictionary:
		push_error("Interpreter: Expression must be a Dictionary or Array.")
		return null

	var args: Array = expression.get("args", []).duplicate()
	for i in range(args.size()):
		if (args[i] is Dictionary and args[i].has("func")) or args[i] is Array:
			args[i] = get_function(args[i], country)
	var evaled_args = args
	var store_key: String = expression.get("store", "")
	var result = null

	print(expression)
	match expression.get("func", ""):
		# Comparison stuff
		"and":
			if evaled_args.size() >= 2:
				result = get_variable(evaled_args[0]) and get_variable(evaled_args[1])
		"not":
			if evaled_args.size() >= 2:
				result = get_variable(evaled_args[0])
		"or":
			if evaled_args.size() >= 2:
				result = get_variable(evaled_args[0]) or get_variable(evaled_args[1])
		"xor":
			if evaled_args.size() >= 2:
				result = get_variable(evaled_args[0]) ^ get_variable(evaled_args[1])
		"eq":
			if evaled_args.size() >= 2:
				result = get_variable(evaled_args[0]) == get_variable(evaled_args[1])
		"gt":
			if evaled_args.size() >= 2:
				result = get_variable(evaled_args[0]) > get_variable(evaled_args[1])
		"lt":
			if evaled_args.size() >= 2:
				result = get_variable(evaled_args[0]) < get_variable(evaled_args[1])
		"all":
			result = all(evaled_args)
		"any":
			result = any(evaled_args)

		# Country stuff
		"is_at_war":
			if evaled_args.size() >= 2:
				result = WarManager.is_at_war_names(
					get_variable(evaled_args[0]),
					get_variable(evaled_args[1])
				)
		"increase_hourly_money":
			country.hourly_money_income += evaled_args[0] if evaled_args.size() > 0 else 0
			result = country.hourly_money_income
		"increase_manpower":
			country.manpower += evaled_args[0] if evaled_args.size() > 0 else 0
			result = country.manpower
		"increase_daily_pp":
			country.daily_pp_gain += evaled_args[0] if evaled_args.size() > 0 else 0
			result = country.daily_pp_gain
		"increase_stability":
			country.stability = min(1.0, country.stability + (evaled_args[0] if evaled_args.size() > 0 else 0))
			result = country.stability
		"army_level_up":
			country.army_level += 1
			result = country.army_level
		"build_factory":
			country.factories_amount += evaled_args[0] if evaled_args.size() > 0 else 1
			result = country.factories_amount
		"declare_war":
			if evaled_args.size() >= 2:
				var attacker = CountryManager.countries.get(get_variable(evaled_args[0]))
				var defender = CountryManager.countries.get(get_variable(evaled_args[1]))
				if attacker and defender:
					WarManager.declare_war(attacker, defender)
					result = true
				else:
					result = false
		"release":
			if evaled_args.size() >= 1:
				MapManager.ReleaseCountry(evaled_args[0])
				result = true
		"play_as":
			if evaled_args.size() >= 1:
				CountryManager.set_player_country(evaled_args[0])
				result = true
		"annex":
			if evaled_args.size() >= 2:
				MapManager.annex_country(evaled_args[0], evaled_args[1])
				result = true
		"has_pid":
			if evaled_args.size() >= 2:
				print(int(evaled_args[1]), MapManager.province_objects[int(evaled_args[1])].city)
				# for province in MapManager.province_objects:
				# 	if MapManager.province_objects[province].GetFunctionalOwner() == "Pakistan":
				# 		print(MapManager.province_objects[province].GetFunctionalOwner(), province - evaled_args[1])
				result = (evaled_args[0] == MapManager.province_objects[evaled_args[1]].GetFunctionalOwner())
		"has_pids":
			var i = 0
			var province_owner = evaled_args[i]
			i += 1
			print(province_owner)
			var tmp = (province_owner == (MapManager.province_objects[int(evaled_args[i])].GetFunctionalprovince_owner()))
			i += 1
			print(tmp)
			if tmp:
				while i < evaled_args.size():
					if !tmp:
						result = false
					print(province_owner, evaled_args[i])
					tmp = tmp and (province_owner == (MapManager.province_objects[evaled_args[i]].GetFunctionalprovince_owner()))
					i += 1
					print(tmp)

	if store_key != "":
		heap[store_key] = result
	
	return result
