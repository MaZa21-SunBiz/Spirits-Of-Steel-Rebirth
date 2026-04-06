extends Node

# NOTE(soi): we are no longer in kansas anymore dorothy
enum IndustryType { DEFAULT = 0, FACTORY = 1, PORT = 2, INFRASTRUCTURE = 3 }

var current_world: World
var current_start: String
# var current_scenario_path: String

var choosing_deploy_city := false
var industry_building := IndustryType.DEFAULT
var selected_building_template_name: String = ""

var game_ui: GameUI

var decision_menu_open: bool = false
var in_peace_process: bool = false
var lostTerritory: bool = false
var selectingCountry: bool = true

@export var showingTooltip: bool = false
@export var tooltip: Tooltip

func reset_industry_building():
	industry_building = IndustryType.DEFAULT
	selected_building_template_name = ""
	MapManager.show_countries_map()

var is_loading_game := false
var pending_load_save: String = ""
