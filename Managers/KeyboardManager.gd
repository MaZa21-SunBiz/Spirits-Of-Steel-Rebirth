extends Node

# Use the same names as your MapManager functions for clarity
var current_view = MapManager.MapMode.POLITICAL

signal toggle_menu

var _debounce := false


func _process(_delta: float) -> void:
	if Console.is_visible() or !SceneSwitcher.is_world_active():
		return
	if Input.is_action_just_pressed("deselect_troops"):
		if !TroopManager.troop_selection.selected_troops.is_empty():
			TroopManager.troop_selection.deselect_all()
		else:
			get_tree().root.find_child("Menu", true, false).toggle_menu()

	if Input.is_action_just_pressed("open_menu"):
		if not _debounce:
			_debounce = true
			var menu = get_tree().root.find_child("Menu", true, false)
			if menu:
				menu.toggle_menu()

	if Input.is_action_just_released("open_menu"):
		_debounce = false

	# --- 2. MAP MODE CYCLING (Independent of Menu) ---
	if Input.is_action_just_pressed("cycle_map_mode"):
		_cycle_map_mode()

	if GameState.current_world:
		var clock = GameState.main.clock
		if Input.is_action_just_pressed("pause_game"):
			clock.toggle_pause()

		if Input.is_action_just_pressed("increase_speed"):
			clock.increase_speed()

		if Input.is_action_just_pressed("decrease_speed"):
			clock.decrease_speed()


func _cycle_map_mode() -> void:
	current_view = (current_view + 1) % MapManager.MapMode.size() as MapManager.MapMode
	MapManager.update_map_view(current_view)
