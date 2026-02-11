extends Node

# Use the same names as your MapManager functions for clarity
enum MapView { COUNTRIES, POPULATION, GDP, ETHNICITY, FACTION }
var current_view = MapView.COUNTRIES

var settings = null

signal toggle_menu

var _debounce := false

func _ready() -> void:
	settings = get_tree().root.find_child("Settings", true, false)

func _process(_delta: float) -> void:
	if Console.is_visible():
		return
	if Input.is_action_just_pressed("deselect_troops"):
		if !TroopManager.troop_selection.selected_troops.is_empty():
			TroopManager.troop_selection.deselect_all()
		else:
			# get_tree().root.find_child("Menu", true, false).toggle_menu()
			settings.visible = !settings.visible

	if Input.is_action_just_pressed("open_menu"):
		if not _debounce:
			_debounce = true
			toggle_menu.emit()

	if Input.is_action_just_released("open_menu"):
		_debounce = false

	# --- 2. MAP MODE CYCLING (Independent of Menu) ---
	if Input.is_action_just_pressed("cycle_map_mode"):
		_cycle_map_mode()

	if GameState.current_world:
		var clock := GameState.current_world.clock
		if Input.is_action_just_pressed("pause_game"):
			clock.toggle_pause()

		if Input.is_action_just_pressed("increase_speed"):
			clock.increase_speed()

		if Input.is_action_just_pressed("decrease_speed"):
			clock.decrease_speed()


func _cycle_map_mode() -> void:
	match current_view:
		MapView.COUNTRIES:
			current_view = MapView.POPULATION
			MapManager.show_population_map()
			print("Map Mode: Population")

		MapView.POPULATION:
			current_view = MapView.GDP
			MapManager.show_gdp_map()
			print("Map Mode: GDP")

		MapView.GDP:
			current_view = MapView.ETHNICITY
			MapManager.show_ethnic_map()
			print("Map Mode: Ethnicity")

		MapView.ETHNICITY:
			current_view = MapView.FACTION
			MapManager.show_faction_map()
			print("Map Mode: Factions")

		MapView.FACTION:
			current_view = MapView.COUNTRIES
			MapManager.show_countries_map()
			print("Map Mode: Countries")

