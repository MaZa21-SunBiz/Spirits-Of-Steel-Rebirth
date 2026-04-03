extends CanvasLayer

@export var sidebar_panel: PanelContainer
@export var summary_label: Label
@export var stats_label: Label
@export var loser_label: Label

var winners: Array[CountryData] = []
var current_selected_winner: CountryData
var current_loser: CountryData
var provinces_to_take: Dictionary = {} # PID -> CountryData
var hovered_pid: int = -1
var puppeting = false
@export var winner_selector: OptionButton

# Color Palette
const COLOR_BG = Color(0.1, 0.1, 0.12, 0.98)
const COLOR_GOLD = Color(0.85, 0.65, 0.2)
const COLOR_SELECT = Color(0.0, 1.0, 0.8)  # Cyan/Teal for treaty selection
const COLOR_DANGER = Color(0.7, 0.2, 0.2)

func _ready() -> void:
	self.hide()
	# If winner_selector is not linked in the inspector, we find/create it
	if not winner_selector:
		_setup_missing_ui_elements()

func _setup_missing_ui_elements():
	# Find the main VBoxContainer in the sidebar
	var main_vbox = sidebar_panel.get_node("VBoxContainer")
	if not main_vbox:
		return

	# Add Beneficiary Selector label and OptionButton to the existing sidebar
	var beneficiary_label = Label.new()
	beneficiary_label.text = "SELECT BENEFICIARY:"
	beneficiary_label.add_theme_font_size_override("font_size", 14)
	
	# Insert before the button container (which is usually the last child)
	var button_container = main_vbox.get_child(main_vbox.get_child_count() - 1)
	main_vbox.add_child(beneficiary_label)
	main_vbox.move_child(beneficiary_label, button_container.get_index())
	
	winner_selector = OptionButton.new()
	winner_selector.item_selected.connect(_on_winner_selected)
	main_vbox.add_child(winner_selector)
	main_vbox.move_child(winner_selector, button_container.get_index())

func _input(event: InputEvent) -> void:
	if not self.visible:
		return

	# 1. Ignore input if clicking on the sidebar itself
	if get_viewport().get_mouse_position().x < sidebar_panel.size.x:
		return

	# 2. Convert Screen position to Map/World position
	# We use the World's camera to get the correct global coordinates
	var world = GameState.current_world
	if not world:
		return

	var map_pos = world.get_global_mouse_position()

	# 3. Handle Hover (Motion) and Click (Button) separately
	if event is InputEventMouseMotion:
		_process_hover(map_pos)
	elif event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_process_click(map_pos)

func _process_hover(map_pos: Vector2):
	# 1. Get the PID using your radius logic
	var pid = get_province_with_radius(map_pos, GameState.current_world.map_sprite, 5)

	if pid != hovered_pid:
		# 2. Reset the visual of the PREVIOUS hovered province
		if hovered_pid > 1:
			_reset_province_visual(hovered_pid)

		hovered_pid = pid

		# 3. Apply NEW hover visual (if it's a valid land province belonging to the loser)
		if hovered_pid > 1:
			var province = MapManager.province_objects.get(hovered_pid)
			if province and province.country == current_loser.country_name:
				_update_map_visual(hovered_pid, Color(1.5, 1.5, 1.5), CountryManager.GetCountryColor(province.country))
				Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)
			else:
				Input.set_default_cursor_shape(Input.CURSOR_ARROW)
		else:
			Input.set_default_cursor_shape(Input.CURSOR_ARROW)

func _process_click(map_pos: Vector2):
	var pid = get_province_with_radius(map_pos, GameState.current_world.map_sprite, 5)
	if pid <= 1:
		return
		
	if MapManager.province_objects[pid].country != current_loser.country_name:
		return

	if provinces_to_take.has(pid):
		provinces_to_take.erase(pid)
		_reset_province_visual(pid)
	else:
		provinces_to_take[pid] = current_selected_winner
		_update_map_visual(pid, current_selected_winner.country_color.lightened(0.2), CountryManager.GetCountryColor(MapManager.province_objects[pid].country))

	_update_summary()


func _on_annex_all_pressed():
	provinces_to_take.clear()
	# Assign all provinces to current beneficiary
	for pid in MapManager.province_objects.keys():
		var province = MapManager.province_objects[pid]
		if province.country == current_loser.country_name:
			provinces_to_take[pid] = current_selected_winner
			var color = current_selected_winner.country_color.lightened(0.2)
			var base_color = CountryManager.GetCountryColor(province.country)
			_update_map_visual(pid, color, base_color)
	_update_summary()

func _on_winner_selected(index: int):
	current_selected_winner = winners[index]

func _on_puppet_pressed():
	puppeting = !puppeting
	print(winners[0].puppets)
	_update_summary()

func _on_clear_selection_pressed():
	var pids = provinces_to_take.keys()
	provinces_to_take.clear()
	for pid in pids:
		_reset_province_visual_immediate(pid)
	_update_summary()

func _reset_province_visual_immediate(pid: int):
	_update_map_visual(pid, CountryManager.GetCountryColor(MapManager.province_objects[pid].GetFunctionalOwner(), Color.WHITE), CountryManager.GetCountryColor(MapManager.province_objects[pid].country, Color.WHITE))

# --- Logic & Integration ---

func open_menu(p_winners: Array[CountryData], p_loser: CountryData):
	self.show()
	winners = p_winners
	current_loser = p_loser
	provinces_to_take.clear()
	puppeting = false
	
	# Setup Winner Selector
	winner_selector.clear()
	var player_index = -1
	for i in range(winners.size()):
		winner_selector.add_item(winners[i].country_name)
		if winners[i].is_player:
			player_index = i
	
	if player_index != -1:
		winner_selector.selected = player_index
		current_selected_winner = winners[player_index]
	else:
		winner_selector.selected = 0
		current_selected_winner = winners[0]

	# AUTO-ANNEX CLAIMS
	for pid in MapManager.province_objects.keys():
		var province = MapManager.province_objects[pid]
		if province.country == current_loser.country_name:
			# Check each winner for a claim
			for w in winners:
				if province.claims.has(w.country_name):
					provinces_to_take[pid] = w
					var color = w.country_color.lightened(0.2)
					var base_color = CountryManager.GetCountryColor(province.country)
					_update_map_visual(pid, color, base_color)
					break # First winner who claims it gets it in auto-assign

	var game_ui = get_tree().root.find_child("ui_game", true, false)
	if game_ui:
		game_ui.visible = false
	GameState.current_world.clock.pause()
	loser_label.text = "Negotations: %s" % p_loser.country_name
	GameState.in_peace_process = true
	_update_summary()

func _update_summary():
	summary_label.text = "Provinces Selected: %d" % provinces_to_take.size()

	# Calculate percentage for flavor
	var total_loser_provinces = 0
	for p in MapManager.province_objects.values():
		if p.country == current_loser.country_name:
			total_loser_provinces += 1

	if total_loser_provinces > 0:
		stats_label.text = "Total Country Loss: %d%%" % int((float(provinces_to_take.size()) / total_loser_provinces) * 100)

func _on_confirm_pressed():
	for pid in provinces_to_take:
		var recipient = provinces_to_take[pid]
		MapManager.transfer_ownership(pid, recipient.country_name)
	
	if puppeting:
		# Use the first winner (usually the war leader/player) to puppet
		CountryManager.make_puppet(winners[0], current_loser)
	
	var game_ui = get_tree().root.find_child("ui_game", true, false)
	if game_ui:
		game_ui.visible = true
	GameState.in_peace_process = false
	GameState.current_world.clock.resume()

	self.hide()


func force_close():
	self.set_process(false)
	self.set_physics_process(false)
	self.hide()
	
	# Clear selections & state
	provinces_to_take.clear()
	winners.clear()
	current_loser = null
	puppeting = false
	hovered_pid = -1
	
	# Reset global flags
	GameState.in_peace_process = false
	
	# Restore standard UI if possible
	var game_ui = get_tree().root.find_child("ui_game", true, false)
	if game_ui:
		game_ui.visible = true
	
	# Essential to resume clock if we were paused by the peace menu
	if GameState.current_world:
		GameState.current_world.clock.resume()

# Your existing logic function
func get_province_with_radius(global_pos: Vector2, map_sprite: Sprite2D, radius: int) -> int:
	# This uses the code logic you already have in MapManager
	return MapManager.get_province_with_radius(global_pos, map_sprite, radius)

func _update_map_visual(pid: int, color: Color, secondary_color: Color):
	# We call MapManager's lookup update to refresh the shader texture
	MapManager.SetProvinceColors(pid, color, secondary_color)

func _reset_province_visual(pid: int):
	# If it's currently selected, keep the selected color
	if provinces_to_take.has(pid):
		var country_data = provinces_to_take[pid]
		var color = country_data.country_color.lightened(0.2)
		var base_color = CountryManager.GetCountryColor(MapManager.province_objects[pid].country)
		_update_map_visual(pid, color, base_color)
	else:
		# Otherwise, revert to the original country color (legal owner)
		var province = MapManager.province_objects.get(pid)
		if province and province.country != "Sea":
			var functional_owner = province.GetFunctionalOwner()
			var color = CountryManager.GetCountryColor(functional_owner)
			var base_color = CountryManager.GetCountryColor(province.country)
			_update_map_visual(pid, color, base_color)


func _on_option_button_item_selected(index: int) -> void:
	pass # Replace with function body.
