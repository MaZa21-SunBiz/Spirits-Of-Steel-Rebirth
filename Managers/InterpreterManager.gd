extends Node

var debug: bool:
	get:
		return SettingsManager.settings.debug_mode
var heap: Dictionary = {}
const DUMMY_FUNC = ""
var country: CountryData

# NOTE(soi): jst copied this straight up frm the dics
func evaluate(command, variable_names = [], variable_values = []):
	var expression = Expression.new()
	var error = expression.parse(command, variable_names)
	if error != OK:
		push_error(expression.get_error_text())
		return

	var result = expression.execute(variable_values, self)

	if not expression.has_execute_failed():
		return result

func all(args: Array) -> bool:
	for arg in args:
		if not arg:
			return false
	return true

func any(args: Array) -> bool:
	for arg in args:
		if arg:
			return true
	return false

func get_variable(variable):
	if !variable is String:
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

func get_element(element, grid, _country: CountryData = null):
	var text: String
	if element.has("text"):
		if element["text"] is Array:
			text = get_function(element["text"])
		elif element["text"] is String:
			text = element["text"]

	var condition = element.get("condition", DUMMY_FUNC)
	var finished = element.get("finished", DUMMY_FUNC)

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
			entry.text = text
			
			if not get_function(condition):
				entry.disabled = true
			
			entry.pressed.connect(func():
				if get_function(condition, country):
					get_function(finished, country)
			)
			grid.add_child(entry)
			entry.material = grid.material
			entry.tooltip_text = "Condition - %s\nFinished - %s" % [
				condition,
				finished
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
			entry.add_text(text)
			entry.fit_content = true
			entry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			entry.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			grid.add_child(entry)




func get_function(block, _country: CountryData = null):
	# print(block)
	if !block: return

	country = CountryManager.player_country if country == null else _country

	var result
	for expr in block:
		print(expr)
		result = evaluate(expr) 
		print(result)

	return result
	

# Country stuff
func is_at_war(warer: String, waree: String) -> bool:
		return WarManager.is_at_war_names(warer ,waree)

func set_country_attr(attr: String, val):
	country[attr] = val
	return country[attr]

func add_country_attr(attr: String, val):
	country[attr] += val
	return country[attr]

func army_level_up():
	country.army_level += 1
	return country.army_level

func build_factory(count: int):
	country.factories_amount += count
	return country.factories_amount

func declare_war(warer: String, waree: String):
	var attacker: CountryData = CountryManager.countries[warer]
	var defender: CountryData = CountryManager.countries[waree]
	WarManager.declare_war(attacker, defender)

func release(_country: String):
	MapManager.ReleaseCountry(_country)

func play_as(_country: String):
	if CountryManager.countries.has(_country):
		print("player country now " + _country)
		CountryManager.set_player_country(_country)

func annex(annexer: String, annexee: String):
	MapManager.annex_country(annexer, annexee)

func add_ideology_drift(id: String, _country: String, direction):
	var country_obj: CountryData = CountryManager.countries[_country]
	country_obj.driftTargets[id] = IdeologyDriftTarget.FromDict(direction)
	return country_obj.driftTargets

func make_puppet(puppeter: String, puppetee: String):
	CountryManager.make_puppet(CountryManager.countries[puppeter], CountryManager.countries[puppetee])

func has_pids(_country: String, ...pids):
	var all_owned = true
	for pid in pids:
		if _country != MapManager.province_objects[pid].GetFunctionalOwner():
			all_owned = false
			break
	return all_owned

func add_plans(_country: String, plan: Dictionary):
	if !PlansManager.plans.has(country):
		PlansManager.plans[country] = []
	PlansManager.plans[country].append(plan)

func remove_plan(_country: String, plan: Dictionary):
	PlansManager.plans[country].remove_at(
		PlansManager.plans[country].find_custom(
			func(element): return element == plan
		)
	)

func event(_event: Dictionary):
	EventManager.show_alert(_event)

func invite(inviter, invtee):
	FactionManager.invite_faction(CountryManager.countries[inviter], CountryManager.countries[invtee])

func change_province_types(_country: String, type: int,...pids):
	MapManager.change_province_types(pids.map(func(a): return int(a)), type, _country)
