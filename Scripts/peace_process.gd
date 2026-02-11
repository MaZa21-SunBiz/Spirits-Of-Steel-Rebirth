extends CanvasLayer

@onready var stats_label: Label = $PanelContainer/VBoxContainer/PanelContainer/HBoxContainer/Label2
@onready var loser_label: Label = $PanelContainer/VBoxContainer/Label2
@onready var sidebar_panel: PanelContainer = $PanelContainer

var current_winner: CountryData
var current_loser: CountryData
var provinces_to_take: Array = []
var hovered_pid: int = -1

const COLOR_SELECT = Color(0.0, 1.0, 1.0) # Cyan for selection

func _ready() -> void:
	self.hide()

func open_menu(winner: CountryData, loser: CountryData):
	self.show()
	current_winner = winner
	current_loser = loser
	provinces_to_take.clear()
	
	var game_ui = get_tree().root.find_child("ui_game", true, false)
	if game_ui:
		game_ui.visible = false
	
	GameState.current_world.clock.pause()
	loser_label.text = "Negotiations: %s" % loser.country_name
	GameState.in_peace_process = true
	_update_summary()

func _input(event: InputEvent) -> void:
	if not self.visible:
		return

	# 1. Ignore input if clicking on the sidebar itself
	var mouse_pos = get_viewport().get_mouse_position()
	if mouse_pos.x < sidebar_panel.size.x:
		return

	# 2. Convert Screen position to Map/World position
	var world = GameState.current_world
	if not world:
		return

	var map_pos = world.get_global_mouse_position()

	# 3. Handle Hover/Click using the world-mapped coordinates
	if event is InputEventMouseMotion:
		_process_hover(map_pos)

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_process_click(map_pos)


func _process_hover(map_pos: Vector2):
	var pid = get_province_with_radius(map_pos, GameState.current_world.map_sprite, 5)

	if pid != hovered_pid:
		if hovered_pid > 1:
			_reset_province_visual(hovered_pid)

		hovered_pid = pid

		if hovered_pid > 1:
			var owner = MapManager.province_to_country.get(hovered_pid, "")
			if owner == current_loser.country_name:
				_update_map_visual(hovered_pid, Color(1.5, 1.5, 1.5))
				Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)
			else:
				Input.set_default_cursor_shape(Input.CURSOR_ARROW)
		else:
			Input.set_default_cursor_shape(Input.CURSOR_ARROW)


func _process_click(map_pos: Vector2):
	var pid = get_province_with_radius(map_pos, GameState.current_world.map_sprite, 5)
	if pid <= 1:
		return

	var owner_name = MapManager.province_to_country.get(pid, "")
	if owner_name != current_loser.country_name:
		return

	if provinces_to_take.has(pid):
		provinces_to_take.erase(pid)
		_update_map_visual(pid, Color(1.5, 1.5, 1.5))
	else:
		provinces_to_take.append(pid)
		_update_map_visual(pid, COLOR_SELECT)

	_update_summary()


func _on_annex_all_pressed():
	provinces_to_take.clear()
	for pid in MapManager.province_to_country.keys():
		if MapManager.province_to_country[pid] == current_loser.country_name:
			provinces_to_take.append(pid)
			_update_map_visual(pid, COLOR_SELECT)
	_update_summary()


func _on_puppet_pressed():
	current_winner.allowedCountries.append(current_loser.country_name)
	current_winner.puppets.append(current_loser.country_name)
	current_loser.is_puppet = true
	_update_summary()

func _on_clear_selection_pressed():
	for pid in provinces_to_take:
		_reset_province_visual_immediate(pid)
	provinces_to_take.clear()
	_update_summary()

func _reset_province_visual_immediate(pid: int):
	var owner = MapManager.province_to_country[pid]
	var original_color = MapManager.country_colors.get(owner, Color.WHITE)
	_update_map_visual(pid, original_color)

func _on_confirm_pressed():
	for pid in provinces_to_take:
		MapManager.transfer_ownership(pid, current_winner.country_name)

	var game_ui = get_tree().root.find_child("ui_game", true, false)
	if game_ui:
		game_ui.visible = true
	GameState.in_peace_process = false
	GameState.current_world.clock.resume()
	self.hide()

func _update_summary():
	var total_loser_provinces = 0
	for p in MapManager.province_to_country.values():
		if p == current_loser.country_name:
			total_loser_provinces += 1

	if total_loser_provinces > 0:
		var percent = (float(provinces_to_take.size()) / total_loser_provinces) * 100
		stats_label.text = "%d\n%d%%" % [provinces_to_take.size(), int(percent)]

func get_province_with_radius(global_pos: Vector2, map_sprite: Sprite2D, radius: int) -> int:
	return MapManager.get_province_with_radius(global_pos, map_sprite, radius)


func _update_map_visual(pid: int, color: Color):
	if MapManager.has_method("update_lookup"):
		MapManager.update_lookup(pid, color)


func _reset_province_visual(pid: int):
	if provinces_to_take.has(pid):
		_update_map_visual(pid, COLOR_SELECT)
	else:
		var country = MapManager.province_to_country.get(pid, "sea")
		if country != "sea":
			var original_color = MapManager.country_colors.get(country, Color.WHITE)
			_update_map_visual(pid, original_color)
