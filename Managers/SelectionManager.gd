# res://singletons/SelectionManager.gd
## NOTE(pol): This is only used to store the selected troops in an array, 
## because troop_renderer, TroopSelection and MapManager need it.
extends Node

const TROOP_DATA_TYPE = preload("res://Scripts/TroopData.gd")
var selected_troops: Array[TROOP_DATA_TYPE] = []

func select_troops(new_list: Array[TROOP_DATA_TYPE], append: bool = false) -> void:
	if not append:
		selected_troops.clear()
	
	for t in new_list:
		if not selected_troops.has(t):
			selected_troops.append(t)
			
	get_tree().call_group("TroopRenderer", "queue_redraw")

func is_a_troop_selected() -> bool:
	return len(selected_troops) > 0
