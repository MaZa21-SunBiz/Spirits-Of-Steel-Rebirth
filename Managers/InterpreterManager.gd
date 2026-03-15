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
		"null":
			return null
		_:
			return heap.get(variable, variable)

func get_element(element, grid):
	match element.get("type", ""):
		"country_header":
			var entry = HBoxContainer.new()
			entry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			
			var tr1 = TextureRect.new()
			tr1.texture = TroopManager.get_flag(element["country1"])
			tr1.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr1.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tr1.custom_minimum_size = Vector2(80, 50)
			entry.add_child(tr1)
			
			var spacer = Control.new()
			spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			entry.add_child(spacer)
			
			var tr2 = TextureRect.new()
			tr2.texture = TroopManager.get_flag(element["country2"])
			tr2.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr2.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tr2.custom_minimum_size = Vector2(80, 50)
			entry.add_child(tr2)
			
			grid.add_child(entry)
			entry.material = grid.material
			tr1.material = grid.material
			tr2.material = grid.material

		"button":
			var entry = Button.new()
			entry.text = element["text"]
			
			if not get_function(element["condition"]):
				entry.disabled = true
			
			entry.pressed.connect(func():
				if get_function(element["condition"]):
					get_function(element["finished"])
			)
			grid.add_child(entry)
			entry.material = grid.material
			entry.tooltip_text = "Condition - %s\nFinished - %s" % [
				format_functions(element["condition"]),
				format_functions(element["finished"])
			]
		"image":
			var entry = TextureRect.new()
			entry.texture = load(
				PlansManager.current_start_folder + "assets/plans/" + element["path"]
			)
			entry.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			entry.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			entry.custom_minimum_size = Vector2(100, 100)
			grid.add_child(entry)
			entry.material = grid.material
		"paragraph":
			var entry = RichTextLabel.new()
			entry.add_theme_font_size_override("normal_font_size", 18)
			entry.add_text(element["text"])
			entry.fit_content = true
			entry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			entry.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			grid.add_child(entry)

func get_function(expression, country: CountryData = null):
	# print(expression)
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
		args[i] = get_variable(args[i])
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
				result = evaled_args[0] and evaled_args[1]
		"not":
			if evaled_args.size() >= 2:
				result = !evaled_args[0]
		"or":
			if evaled_args.size() >= 2:
				result = evaled_args[0] or evaled_args[1]
		"xor":
			if evaled_args.size() >= 2:
				result = evaled_args[0] ^ evaled_args[1]
		"eq":
			if evaled_args.size() >= 2:
				result = evaled_args[0] == evaled_args[1]
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
				var attacker = CountryManager.countries[evaled_args[0]]
				var defender = CountryManager.countries[evaled_args[1]]
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
				if CountryManager.countries.has(args[0]):
					print("player country now " + (args[0]))
					CountryManager.set_player_country((args[0]))

				print("Unknown country: " + (args[0]))
				result = true
		"annex":
			if evaled_args.size() >= 2:
				MapManager.annex_country(evaled_args[0], evaled_args[1])
				result = true
		"add_ideology_drift":
			var country_obj = CountryManager.countries[evaled_args[0]]
			country_obj.driftTargets[args[1]] = IdeologyDriftTarget.FromDict(args[2])
			result = country_obj.driftTargets
		"make_puppet":
			if evaled_args.size() >= 2:
				var puppeter = CountryManager.countries[evaled_args[0]]
				var puppetee = CountryManager.countries[evaled_args[1]]
				CountryManager.make_puppet(puppeter, puppetee)
				result = true
		"has_pids":
			if evaled_args.size() >= 2:
				var i = 1
				var province_owner = evaled_args[0]
				var all_owned = true
				while i < evaled_args.size():
					var pid = int(evaled_args[i])
					var prov_obj = MapManager.province_objects[pid]
					if province_owner != prov_obj.GetFunctionalOwner():
						all_owned = false
						break
					i += 1
				result = all_owned
		"add_plans":
			PlansManager.plans[country.country_name].append_array(args)
		"remove_plan":
			PlansManager.plans[country.country_name].remove_at(
				PlansManager.plans[country.country_name].find_custom(
					func(element): return element == args[0]
				)
			)
		"event":
			# New Support: If the first arg is a dictionary, pass it directly
			if evaled_args.size() > 0 and evaled_args[0] is Dictionary:
				EventManager.show_alert(evaled_args[0])
				result = true
			else:
				# Legacy Support: Handle positional args [type, c1, c2, text, params]
				if evaled_args.size() > 1 and evaled_args[1] is String:
					evaled_args[1] = CountryManager.get_country(evaled_args[1])
				if evaled_args.size() > 2 and evaled_args[2] is String:
					evaled_args[2] = CountryManager.get_country(evaled_args[2])
				
				EventManager.callv("show_alert", evaled_args)
				result = true

	if store_key != "":
		heap[store_key] = result
	
	return result

func format_functions(expression, indent: String = "", no_bullet: bool = false) -> String:
	var functions = []
	if expression is Array:
		functions = expression
	elif expression is Dictionary:
		functions = [expression]
	else:
		return ""

	var formatted: String = ""
	for function in functions:
		if not function is Dictionary: continue
		
		# Handle 'for' loop
		if function.has("for"):
			formatted += indent + ("• " if not no_bullet else "") + "For each " + str(function["for"]).capitalize()
			formatted += " in " + str(function.get("in", "[]")) + ":\n"
			formatted += format_functions(function.get("do", {}), indent + "  ") + "\n"
			continue
			
		# Handle 'match' statement
		if function.has("match"):
			var match_header = format_functions(function["match"], "", true).strip_edges()
			formatted += indent + ("• " if not no_bullet else "") + "Match " + match_header + ":\n"
			for key in function.keys():
				if key in ["match", "func", "args", "store"]: continue
				formatted += indent + "  - " + str(key).capitalize() + ":\n"
				formatted += format_functions(function[key], indent + "    ") + "\n"
			continue

		if function.has("func"):
			var func_name = function["func"]
			var args = function.get("args", [])
			if not args is Array:
				args = [args]
			
			formatted += indent + ("• " if not no_bullet else "") + func_name.capitalize()
			
			# Check if args contain nested functions (like in 'and', 'or', 'all', 'any')
			var nested_found = false
			for arg in args:
				if (arg is Dictionary and arg.has("func")) or arg is Array:
					nested_found = true
					break
			
			if nested_found:
				formatted += ":\n"
				formatted += format_functions(args, indent + "  ") + "\n"
			else:
				var formatted_args: Array = []
				for arg in args:
					var is_number = typeof(arg) == TYPE_INT or typeof(arg) == TYPE_FLOAT
					# Only lookup province names for specific functions to avoid constant collisions
					var should_lookup_prov = func_name in ["has_pids", "annex", "release"]
					if should_lookup_prov and is_number and MapManager.province_objects.has(int(arg)):
						var prov = MapManager.province_objects[int(arg)]
						formatted_args.append(prov.city if prov.city != "" else prov.name)
					else:
						formatted_args.append(str(arg))
				
				if not formatted_args.is_empty():
					formatted += ": " + ", ".join(formatted_args)
				formatted += "\n"
				
	return formatted.strip_edges() if indent == "" else formatted
