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
	# if CountryManager.countries.has(variable):
	# 	return CountryManager.countries[variable]
	match variable:
		"player":
			return CountryManager.player_country.country_name
		"current_date":
			return GameState.current_world.clock.get_date_string()
		_:
			return heap.get(variable, variable)

func get_element(element, laws_grid):
	match element.get("type", ""):
		"button":
			var entry = Button.new()
			entry.text = element["text"]
			
			entry.pressed.connect(func():
				if get_function(element["condition"]):
					get_function(element["finished"])
			)
			laws_grid.add_child(entry)
			entry.material = laws_grid.material
			entry.tooltip_text = "Condition - %s\nFinished - %s" % [
				_format_functions(element["condition"]),
				_format_functions(element["finished"])
			]
		"image":
			var entry = TextureRect.new()
			entry.texture = load(
				PlansManager.current_start_folder + "assets/plans/" + element["path"]
			)
			entry.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			entry.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			entry.custom_minimum_size = Vector2(100, 100)
			laws_grid.add_child(entry)
			entry.material = laws_grid.material
		"paragraph":
			var entry = RichTextLabel.new()
			entry.add_theme_font_size_override("normal_font_size", 18)
			entry.add_text(element["text"])
			entry.fit_content = true
			entry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			entry.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			laws_grid.add_child(entry)

func get_function(expression, country: CountryData = null):
	if !expression: return

	if country == null:
		country = CountryManager.player_country
	
	#for loop
	if expression.has("for"):
		for item in expression["in"]:
			heap[expression["for"]] = item 
			get_function(expression["do"])
		heap.erase(expression["for"])
	
	#match statement
	if expression.has("match"):
		print(str(get_function(expression["match"])))
		get_function(expression.get(str(get_function(expression["match"])), {}))
		

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

	match expression.get("func", ""):
		# idk stuff
		"return":
			if evaled_args.size() == 1:
				result = evaled_args[0]
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
		"probability":
			result = bool(randi() % int(evaled_args[0]))

		# Country stuff
		"is_at_war":
			if evaled_args.size() >= 2:
				result = WarManager.is_at_war_names(
					get_variable(evaled_args[0]),
					get_variable(evaled_args[1])
				)
		"add_ideology_drift":
			country.driftTargets[args[0]] = IdeologyDriftTarget.FromDict(args[1])
			result = country.driftTargets
		"change_hourly_money":
			country.hourly_money_income += evaled_args[0]
			result = country.hourly_money_income
		"change_manpower":
			country.manpower += evaled_args[0]
			result = country.manpower
		"change_daily_pp":
			country.daily_pp_gain += evaled_args[0]
			result = country.daily_pp_gain
		"change_stability":
			country.stability = min(1.0, country.stability + evaled_args[0])
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
		"make_puppet":
			if evaled_args.size() >= 2:
				print(evaled_args)
				var puppeter = CountryManager.countries.get(get_variable(evaled_args[0]))
				var puppetee = CountryManager.countries.get(get_variable(evaled_args[1]))
				CountryManager.make_puppet(puppeter, puppetee)
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
			var tmp = (province_owner == (MapManager.province_objects[int(evaled_args[i])].GetFunctionalOwner()))
			i += 1
			print(tmp)
			if tmp:
				while i < evaled_args.size():
					if !tmp:
						result = false
					print(province_owner, evaled_args[i])
					tmp = tmp and (province_owner == (MapManager.province_objects[evaled_args[i]].GetFunctionalOwner()))
					i += 1
					print(tmp)

	if store_key != "":
		heap[store_key] = result
	
	return result

# shitty helper function
func _format_functions(function_array: Array) -> String:
	var formatted: String = ""
	for function in function_array:
		if function.has("func") and function.has("args"):
			formatted += "%s: %s\n" % [function["func"], function["args"]]
	return formatted
