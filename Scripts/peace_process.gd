extends CanvasLayer

@onready var stats_label: Label = $PanelContainer/VBoxContainer/PanelContainer/HBoxContainer/Label2
@onready var loser_label: Label = $PanelContainer/VBoxContainer/Label2
@onready var sidebar_panel: PanelContainer = $PanelContainer
@onready var belligerents_list: VBoxContainer = \
		$PanelContainer/VBoxContainer/ScrollContainer/Beligerents

var current_winner: CountryData
var current_loser: CountryData
var current_beneficiary: CountryData
var provinces_to_take: Dictionary = {} # pid -> beneficiary_name
var hovered_pid: int = -1

const COLOR_SELECT = Color(0.0, 1.0, 1.0) # Cyan for selection

func _ready() -> void:
	self.hide()

func open_menu(winner: CountryData, loser: CountryData, winners_list: Array = []):
	self.show()
	current_winner = winner
	current_loser = loser
	current_beneficiary = winner
	provinces_to_take.clear()
	
	_populate_belligerents(winners_list)
	
	if GameState.game_ui:
		GameState.game_ui.visible = false
	
	GameState.current_world.clock.pause()
	loser_label.text = "Negotiations: %s" % loser.country_name
	GameState.in_peace_process = true
	_update_summary()

func _populate_belligerents(winners_list: Array = []):
	# Clear existing buttons
	for child in belligerents_list.get_children():
		child.queue_free()
	
	var enemies = winners_list
	if enemies.is_empty():
		enemies = WarManager.get_enemies_of(current_loser.country_name)
	
	# Ensure the original winner is included (it should be, but just in case)
	if not current_winner.country_name in enemies:
		enemies.append(current_winner.country_name)
	
	for enemy_name in enemies:
		var btn = Button.new()
		btn.text = enemy_name.capitalize()
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.material = preload("res://damaged.tres")
		btn.pressed.connect(_on_belligerent_selected.bind(enemy_name))
		belligerents_list.add_child(btn)
		
		# Set initial theme/style if needed
		if enemy_name == current_beneficiary.country_name:
			btn.modulate = Color.CYAN

func _on_belligerent_selected(country_name: String):
	var country = CountryManager.get_country(country_name)
	if country:
		current_beneficiary = country
		for child in belligerents_list.get_children():
			if child is Button:
				var is_selected = child.text.to_lower() == country_name
				child.modulate = Color.CYAN if is_selected else Color.WHITE

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
	if pid <= 1:
		if hovered_pid > 1:
			_reset_province_visual(hovered_pid)
			hovered_pid = -1
		return

	var p_owner_name = MapManager.province_to_country.get(pid, "sea")
	var p_owner = CountryManager.get_country(p_owner_name)
	var is_puppet = p_owner and p_owner.is_puppet

	if pid in provinces_to_take or is_puppet:
		if hovered_pid > 1 and pid != hovered_pid:
			_reset_province_visual(hovered_pid)
			hovered_pid = -1
		return

	if pid != hovered_pid:
		if hovered_pid > 1:
			_reset_province_visual(hovered_pid)

		hovered_pid = pid

		if p_owner_name == current_loser.country_name:
			_update_map_visual(hovered_pid, Color(1.5, 1.5, 1.5))
			Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)
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
		var prev_beneficiary = provinces_to_take[pid]
		if prev_beneficiary == current_beneficiary.country_name:
			provinces_to_take.erase(pid)
			_update_map_visual(pid, Color(1.5, 1.5, 1.5))
		else:
			var b_name = current_beneficiary.country_name
			var b_color = MapManager.country_colors.get(b_name, COLOR_SELECT)
			provinces_to_take[pid] = b_name
			_update_map_visual(pid, b_color)
	else:
		var b_name = current_beneficiary.country_name
		var b_color = MapManager.country_colors.get(b_name, COLOR_SELECT)
		provinces_to_take[pid] = b_name
		_update_map_visual(pid, b_color)

	_update_summary()


func _on_annex_all_pressed():
	provinces_to_take.clear()
	var b_name = current_beneficiary.country_name
	var b_color = MapManager.country_colors.get(b_name, COLOR_SELECT)
	
	for pid in MapManager.province_to_country.keys():
		if MapManager.province_to_country[pid] == current_loser.country_name:
			provinces_to_take[pid] = b_name
			_update_map_visual(pid, b_color)
	_update_summary()


func _on_puppet_pressed():
	CountryManager.make_puppet(current_beneficiary, current_loser)
	# Re-apply highlights after MapManager.show_countries_map() wiped them
	for pid in provinces_to_take:
		var beneficiary = provinces_to_take[pid]
		var color = MapManager.country_colors.get(beneficiary, COLOR_SELECT)
		_update_map_visual(pid, color)
	_update_summary()

func _on_clear_selection_pressed():
	for pid in provinces_to_take.keys():
		_reset_province_visual_immediate(pid)
	provinces_to_take.clear()
	_update_summary()

func _reset_province_visual_immediate(pid: int):
	var p_owner = MapManager.province_to_country[pid]
	if pid in provinces_to_take or (p_owner is CountryData and p_owner.is_puppet):
		return
	var original_color = MapManager.country_colors.get(p_owner, Color.WHITE)
	_update_map_visual(pid, original_color)

func _on_confirm_pressed():
	for pid in provinces_to_take:
		MapManager.transfer_ownership(pid, provinces_to_take[pid])

	if GameState.game_ui:
		GameState.game_ui.visible = true
	GameState.in_peace_process = false
	MapManager.show_countries_map()
	GameState.current_world.clock.resume()
	self.hide()

func _update_summary():
	var total_loser_provinces = 0
	for p in MapManager.province_to_country.values():
		if p == current_loser.country_name:
			total_loser_provinces += 1

	if total_loser_provinces > 0:
		var count = provinces_to_take.size()
		var percent = (float(count) / total_loser_provinces) * 100
		stats_label.text = "%d\n%d%%" % [count, int(percent)]

func get_province_with_radius(global_pos: Vector2, map_sprite: Sprite2D, radius: int) -> int:
	return MapManager.get_province_with_radius(global_pos, map_sprite, radius)


func _update_map_visual(pid: int, color: Color):
	if MapManager.has_method("update_lookup"):
		MapManager.update_lookup(pid, color)


func _reset_province_visual(pid: int):
	if provinces_to_take.has(pid):
		var beneficiary = provinces_to_take[pid]
		var color = MapManager.country_colors.get(beneficiary, COLOR_SELECT)
		_update_map_visual(pid, color)
	else:
		var country = MapManager.province_to_country.get(pid, "sea")
		if country != "sea":
			var original_color = MapManager.country_colors.get(country, Color.WHITE)
			_update_map_visual(pid, original_color)
