extends Node

enum IndustryType { DEFAULT = 0, FACTORY = 1, PORT = 2, INFRASTRUCTURE = 3 }

var current_world: World
var current_map: MapContainer
var main
var camera
var choosing_deploy_city := false
var industry_building := IndustryType.DEFAULT

var game_ui: GameUI

var decision_menu_open: bool = false
var in_peace_process: bool = false
var lostTerritory: bool = false
var selectingCountry: bool = true


func reset_industry_building():
	industry_building = IndustryType.DEFAULT
	MapManager.show_countries_map()


var is_loading_game := false


# Note z21: put it somewhere else tbh
func format_number(value: float) -> String:
	var abs_val = abs(value)
	var sign_str = "-" if value < 0 else ""
	if abs_val >= 1_000_000_000:
		return sign_str + "%.2fB" % (abs_val / 1_000_000_000.0)
	elif abs_val >= 1_000_000:
		return sign_str + "%.2fM" % (abs_val / 1_000_000.0)
	elif abs_val >= 1_000:
		return sign_str + "%.1fK" % (abs_val / 1_000.0)
	return sign_str + str(floori(abs_val))
