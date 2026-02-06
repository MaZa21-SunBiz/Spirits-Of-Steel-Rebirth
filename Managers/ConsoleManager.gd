extends Node


func _ready() -> void:
	Console.add_command("play_country", _play_country, ["country_name"], 1, "Change player country")
	Console.add_command("play_as", _play_country, ["country_name"], 1, "Change player country")
	Console.add_command("play", _play_country, ["country_name"], 1, "Change player country")

	Console.add_command("start_war", _start_war, ["a", "b"], 2, "Start a war between 2 countries")
	Console.add_command("annex", _annex, ["country_name"], 1, "Annex Country for Player")
	Console.add_command("pp", _add_pp, ["amount"], 1, "Add Poltical power to player")
	Console.add_command("manpower", _add_manpower, ["amount"], 1, "Add Manpower to Country")
	Console.add_command(
		"set_manpower", _set_manpower, ["amount"], 1, "Sets manpower to a specific amount"
	)
	Console.add_command(
		"peace_treaty", _peace_treaty, ["country"], 1, "Spawns a peace treaty with country"
	)
	Console.add_command(
		"release", _release_country, ["country"], 1, "Releases a country based on all its cores"
	)
	Console.add_command(
		"releasables", _show_releasables_country, ["country"], 1, "Shows the releasables of a country"
	)
	

func _show_releasables_country(country):
	var releasables = MapManager.get_all_releasables(country)
	Console.print_info(JSON.stringify(releasables))

func _release_country(country):
	MapManager.release_country(country)


func _add_pp(amount):
	CountryManager.player_country.political_power += float(amount)


func _add_manpower(amount):
	CountryManager.player_country.manpower += int(amount)


func _set_manpower(amount):
	CountryManager.player_country.manpower = int(amount)


func _peace_treaty(country):
	WarManager._handle_total_collapse(country, CountryManager.player_country.country_name)


func _annex(country_name: String) -> void:
	if CountryManager.countries.has(country_name):
		MapManager.annex_country(country_name)
		return

	Console.print_line("Unknown country: " + country_name)


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
