extends Node
# Autoload Name: DecisionManager

# var categories: Dictionary = {}  <-- REMOVED
var default_categories: Dictionary = {}
var country_decisions_map: Dictionary = {} # { "China": { "Economy": [...] } }

var active_decisions: Dictionary = {}  # { "Germany": { "eco_1": 5 } }
var ui_overlay = null


func _ready():
	_load_decisions()


func _load_decisions():
	# 1. Load Default
	var default_text = FileAccess.get_file_as_string("res://decisions/default.json")
	if default_text:
		default_categories = JSON.parse_string(default_text).get("categories", {})
	
	# 2. Load Country Specific
	var dir = DirAccess.open("res://decisions/")
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".json") and file_name != "default.json":
				var country_key = file_name.replace(".json", "").to_lower() # e.g. "India.json" -> "india"
				
				var content = FileAccess.get_file_as_string("res://decisions/" + file_name)
				var json = JSON.parse_string(content)
				if json and json.has("categories"):
					country_decisions_map[country_key] = json["categories"]
			
			file_name = dir.get_next()


func get_country_categories(country_name: String) -> Dictionary:
	# Store keys as lowercase to match CountryManager pattern
	var key = country_name.to_lower()
	if country_decisions_map.has(key):
		return country_decisions_map[key]
	
	# Fallback to default
	return default_categories


# --- TICKING SYSTEM ---
func process_country_day(country: CountryData):
	if not active_decisions.has(country.country_name):
		return

	var tasks = active_decisions[country.country_name]
	var finished = []

	for key in tasks.keys():
		tasks[key] -= 1
		if tasks[key] <= 0:
			finished.append(key)
			_finalize_decision(country, key)

	for key in finished:
		if country == CountryManager.player_country:
			# 1. Find the decision data to get the title
			var decision_title = "Unknown Decision"
			var country_cats = get_country_categories(country.country_name)

			# Look through all categories to find the matching ID
			for cat_name in country_cats:
				for decision in country_cats[cat_name]:
					if decision["id"] == key:
						decision_title = decision["title"]
						break

			# 2. Show the alert with the actual title
			PopupManager.show_alert("event", country, null, "%s completed" % decision_title)

		tasks.erase(key)

	if ui_overlay and ui_overlay.visible and country.is_player:
		ui_overlay.refresh_status_only()  # Efficient refresh


# --- ACTIONS ---
func can_take_decision(country: CountryData, cat: String, index: int) -> bool:
	var data = get_country_categories(country.country_name)[cat][index]
	var id = data["id"]

	# 1. NEW: Check if busy with ANY decision
	if is_country_busy(country):
		return false

	# 2. Check if already done or currently this specific one (redundant but safe)
	if country.has_meta("finished_" + id) or is_in_progress(country, id):
		return false

	# 3. Check Prerequisite
	if data.has("prereq"):
		var parent_id = data["prereq"]
		if not country.has_meta("finished_" + parent_id):
			return false

	# 4. Check Cost
	if country.political_power < data.get("cost_pp", 0):
		return false

	# 5. Check Cost
	if data.get("reqs", {}):
		return InterpreterManager.get_function(data.get("reqs", {}))
	return true


func start_decision(country: CountryData, cat: String, index: int):
	if not can_take_decision(country, cat, index):
		return

	var data = get_country_categories(country.country_name)[cat][index]
	country.political_power -= data.get("cost_pp", 0)

	if not active_decisions.has(country.country_name):
		active_decisions[country.country_name] = {}

	active_decisions[country.country_name][data["id"]] = data.get("days", 5)

	if ui_overlay and country.is_player:
		ui_overlay.refresh_status_only()


func _finalize_decision(country: CountryData, id: String):
	country.set_meta("finished_" + id, true)

	# Find the data to get the action (Slow search, but happens rarely)
	var country_cats = get_country_categories(country.country_name)
	for cat in country_cats:
		for node in country_cats[cat]:
			if node["id"] == id:
				_apply_reward(country, node.get("action", {}))
				return

func _apply_reward(country: CountryData, action: Dictionary):
	InterpreterManager.get_function(action, country)

# --- HELPERS ---
func is_in_progress(country: CountryData, id: String) -> bool:
	return active_decisions.get(country.country_name, {}).has(id)


func get_days_left(country: CountryData, id: String) -> int:
	return active_decisions.get(country.country_name, {}).get(id, 0)


# Add/Update these functions in DecisionManager.gd


# Check if the country has ANY active timers
func is_country_busy(country: CountryData) -> bool:
	if not active_decisions.has(country.country_name):
		return false
	return not active_decisions[country.country_name].is_empty()
