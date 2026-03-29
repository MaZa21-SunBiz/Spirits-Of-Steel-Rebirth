extends Node

func m_GatesOfHell() -> void:
	var sizer: int = CountryManager.countryNames.size()
	for countryA: int in range(sizer):
		for countryB: int in range(countryA, sizer):
			m_StartWarSilent(CountryManager.countryNames[countryA], CountryManager.countryNames[countryB])

func m_Editor() -> void:
	print("Current Scene: %d" % SceneSwitcher._current_type)
	if SceneSwitcher._current_type == SceneSwitcher.Type.WORLD:
		SceneSwitcher.switch_to(SceneSwitcher.Type.EDITOR)
	elif SceneSwitcher._current_type == SceneSwitcher.Type.EDITOR:
		SceneSwitcher.switch_to(SceneSwitcher.Type.WORLD)
	
func _ready() -> void:
	Console.add_command("play_country", _play_country, ["country_name"], 1, "Change player country")
	# Console.add_command("play_as", _play_country, ["country_name"], 1, "Change player country")
	# Console.add_command_autocomplete_list("play_as", CountryManager.)
	# Console.add_command("play", _play_country, ["country_name"], 1, "Change player country")
	Console.add_command("tag", _play_country, ["country_name"], 1, "Change player country")
	Console.add_command("drew_durnil_mode", _drew_durnil_mode, [], 0, "Lets u spectate the map")
	Console.add_command("puppet", _puppet_country, ["country_name"], 1, "Change player country")
	Console.add_command("invite", _invite_country, ["country_name"], 1, "Change player country")
	Console.add_command("debug_decisions", _debug_decisions, [], 0, "Lets u do any focus and does it instantly")
	Console.add_command("set_ideology", _set_ideology, ["x", "y"], 2, "Change player ideology")
	Console.add_command("reload_decisions", _reload_decisions, [], 0, "Reloads all the decision trees")

	Console.add_command("gates_of_hell", m_GatesOfHell, [], 0, "Start armageddon")
	Console.add_command("start_war", _start_war, ["a", "b"], 2, "Start a war between 2 countries")
	Console.add_command("annex", _annex, ["annexer", "annexee"], 2, "Annex Country for Player")
	Console.add_command("pp", _add_pp, ["amount"], 1, "Add Poltical power to player")
	Console.add_command("manpower", _add_manpower, ["amount"], 1, "Add Manpower to Country")
	Console.add_command(
		"set_manpower", _set_manpower, ["amount"], 1, "Sets manpower to a specific amount"
	)
	Console.add_command(
		"peace_treaty", _peace_treaty, ["country"], 1, "Spawns a peace treaty with country"
	)
	# TODO: Rework this.
	Console.add_command(
		"release", _release_country, ["country"], 1, "Releases a country based on all its claims; the country must exist, to create a new country, look to instantiate_country"
	)
	Console.add_command(
		"releasables", _show_releasables_country, ["country"], 1, "Shows the releasables of a country"
	)
	Console.add_command(
		"cta", _call_to_arms, ["caller", "target"], 2, "Call a country to arms"
	)
	Console.add_command("editor", m_Editor, [], 0, "Swap Editor")
	


func _show_releasables_country(country):
	var releasables = MapManager.get_all_releasables(country)
	Console.print_info(JSON.stringify(releasables))


func _release_country(country):
	MapManager.ReleaseCountry(country)


func _add_pp(amount):
	CountryManager.player_country.political_power += float(amount)


func _set_ideology(x, y):
	CountryManager.player_country.ideology = Vector2(int(x), int(y))


func _add_manpower(amount):
	CountryManager.player_country.manpower += int(amount)


func _set_manpower(amount):
	CountryManager.player_country.manpower = int(amount)


func _peace_treaty(country):
	WarManager._handle_total_collapse(country, CountryManager.player_country.country_name)


func _annex(annexer: String, annexee) -> void:
	if CountryManager.countries.has(annexee):
		MapManager.annex_country(annexer, annexee)
		return

	Console.print_line("Unknown country: " + annexee)


func _play_country(country_name: String) -> void:
	if CountryManager.countries.has(country_name):
		CountryManager.set_player_country(country_name)
		return

	Console.print_line("Unknown country: " + country_name)


func _start_war(country_name1: String, country_name2: String) -> void:
	var country1 := CountryManager.get_country(country_name1)
	var country2 := CountryManager.get_country(country_name2)

	if country1 and country2:
		WarManager.declare_war(country1, country2)
		return

	if not country1:
		Console.print_line("Unknown country: " + country_name1)
	if not country2:
		Console.print_line("Unknown country: " + country_name2)

func m_StartWarSilent(country_name1: String, country_name2: String) -> void:
	var country1 := CountryManager.get_country(country_name1)
	var country2 := CountryManager.get_country(country_name2)

	if country1 and country2:
		WarManager.declare_war(country1, country2, true)
		return

	if not country1:
		Console.print_line("Unknown country: " + country_name1)
	if not country2:
		Console.print_line("Unknown country: " + country_name2)

func _call_to_arms(caller_name: String, target_name: String) -> void:
	var caller := CountryManager.get_country(caller_name)
	var target := CountryManager.get_country(target_name)

	if caller and target:
		WarManager.call_to_arms(caller, target)
		return

	if not caller:
		Console.print_line("Unknown country: " + caller_name)
	if not target:
		Console.print_line("Unknown country: " + target_name)

func _reload_decisions():
	DecisionManager._load_decisions("res://starts/"+GameState.current_start+"/decisions/")

func _debug_decisions():
	DecisionManager.debug = !DecisionManager.debug


func _puppet_country(country_name: String):
	CountryManager.make_puppet(CountryManager.player_country, CountryManager.countries[country_name])


func _invite_country(country_name: String):
	FactionManager.invite_faction(CountryManager.player_country, CountryManager.countries[country_name])


func _drew_durnil_mode():
	CountryManager.player_country.is_player = false
	CountryManager.player_country.setup_ai()
