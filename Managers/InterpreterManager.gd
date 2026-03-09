extends Node

var heap: Dictionary = {}

func get_variable(variable: String):
	match variable:
		"player":
			return CountryManager.player_country.country_name
		"current_date":
			return GameState.current_world.clock.get_date_string()
		_: 
			returna heap.get(variable, variable)

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

	var args: Array = expression.get("args", [])
	var store_key: String = expression.get("store", "")
	var result = null

	match expression.get("func", ""):
		"eq":
			if args.size() >= 2:
				result = get_variable(args[0]) == get_variable(args[1])
		"gt":
			if args.size() >= 2:
				result = get_variable(args[0]) > get_variable(args[1])
		"lt":
			if args.size() >= 2:
				result = get_variable(args[0]) < get_variable(args[1])
		"is_at_war":
			if args.size() >= 2:
				result = WarManager.is_at_war_names(
					get_variable(args[0]),
					get_variable(args[1])
				)
		"increase_hourly_money":
			country.hourly_money_income += args[0] if args.size() > 0 else 0
			result = country.hourly_money_income
		"increase_manpower":
			country.manpower += args[0] if args.size() > 0 else 0
			result = country.manpower
		"increase_daily_pp":
			country.daily_pp_gain += args[0] if args.size() > 0 else 0
			result = country.daily_pp_gain
		"increase_stability":
			country.stability = min(1.0, country.stability + (args[0] if args.size() > 0 else 0))
			result = country.stability
		"army_level_up":
			country.army_level += 1
			result = country.army_level
		"build_factory":
			country.factories_amount += args[0] if args.size() > 0 else 1
			result = country.factories_amount
		"declare_war":
			if args.size() >= 2:
				var attacker = CountryManager.countries.get(get_variable(args[0]))
				var defender = CountryManager.countries.get(get_variable(args[1]))
				if attacker and defender:
					WarManager.declare_war(attacker, defender)
					result = true
				else:
					result = false
		"release":
			if args.size() >= 1:
				MapManager.ReleaseCountry(args[0])
				result = true
		"play_as":
			if args.size() >= 1:
				CountryManager.set_player_country(args[0])
				result = true
		"annex":
			if args.size() >= 2:
				MapManager.annex_country(args[0], args[1])
				result = true
		"all":
			if args.size() >= 2:
				var tmp = get_variable(args[0]+"0")
				for count in range(int(args[1])):
					tmp = tmp and get_variable(args[0]+str(count))
					if !tmp:
						result = false
						break
		"has_pid":
			if args.size() >= 2:
				print(int(args[1]), MapManager.province_objects[int(args[1])].city)
				# for province in MapManager.province_objects:
				# 	if MapManager.province_objects[province].GetFunctionalOwner() == "Pakistan":
				# 		print(MapManager.province_objects[province].GetFunctionalOwner(), province - args[1])
				result = (args[0] == MapManager.province_objects[args[1]].GetFunctionalOwner())
		"has_pids":
			var i = 0
			var owner = args[i]
			i += 1
			print(owner)
			var tmp = (owner == (MapManager.province_objects[int(args[i])].GetFunctionalOwner()))
			i += 1
			print(tmp)
			if tmp:
				while i < args.size():
					if !tmp:
						result = false
					print(owner,args[i])
					tmp = tmp and (owner == (MapManager.province_objects[args[i]].GetFunctionalOwner()))
					i += 1
					print(tmp)

	if store_key != "":
		heap[store_key] = result
	
	return result
