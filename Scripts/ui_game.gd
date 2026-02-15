extends CanvasLayer
class_name GameUI

# ── Enums ─────────────────────────────────────────────
enum Context {PLAYER, ENEMY, NEUTRAL, PUPPET, ALLY}
enum Category {GENERAL, ECONOMY, MILITARY}

# ── Top Bar Nodes ─────────────────────────────────────
@onready var topbar: HBoxContainer = $Control/Topbar/HBoxContainer

@onready var nation_flag: TextureRect = topbar.get_node("nation_flag")
@onready var label_date: Label = topbar.get_node("PanelContainer/HBoxContainer2/ProgressBar/label_date")
@onready var stats_labels := {
	"pp": topbar.get_node("PoliticalPower/HBoxContainer/label_politicalpower"),
	"manpower": topbar.get_node("Manpower/HBoxContainer/label_manpower"),
	"money": topbar.get_node("Money/HBoxContainer/label_money"),
	"industry": topbar.get_node("Industry/HBoxContainer/label_industry"),
	"stability": topbar.get_node("Stability/HBoxContainer/label_stability"),
	"war_support": topbar.get_node("WarSupport/HBoxContainer/label_war_support"),
}

# ── Speed Controls ────────────────────────────────────
@onready var plus: Button = topbar.get_node("PanelContainer/HBoxContainer2/HBoxContainer/GameSpeedControl/Plus")
@onready var minus: Button = topbar.get_node("PanelContainer/HBoxContainer2/HBoxContainer/GameSpeedControl/Minus")
@onready var progress_bar: ProgressBar = topbar.get_node("PanelContainer/HBoxContainer2/ProgressBar")

# ── Side Menu Nodes ───────────────────────────────────
@onready var sidemenu: Control = $Control/SidemenuBG
@onready var sidemenu_flag: TextureRect = sidemenu.get_node("VBoxContainer2/PanelContainer/VBoxContainer/Flag/HBoxContainer/Flag")
@onready var sidemenu_pointer: Sprite2D = sidemenu.get_node("VBoxContainer2/PanelContainer/VBoxContainer/Flag/HBoxContainer/compass/pointer")
@onready var sidemenu_country_label: Label = sidemenu.get_node("VBoxContainer2/PanelContainer/VBoxContainer/Label")
@onready var sidemenu_context: TabContainer = sidemenu.get_node("VBoxContainer2/Context")
@onready var sidemenu_trooplist: VBoxContainer = sidemenu.get_node("VBoxContainer2/Context/Player/Military/ScrollContainer/ActionsList/TroopList")

@onready var troop_container: PanelContainer = $Control/TroopContainer
@onready var relations_hbox: HBoxContainer = $Control/SidemenuBG/VBoxContainer2/PanelContainer/VBoxContainer/RelationsHbox
@onready var faction_prompt: PanelContainer = $CreateFaction

# Use the class_name of your action scene if available, or load strictly as packed scene
@export var action_scene: PackedScene = preload("res://Scenes/action.tscn")

@onready var radio_list: VBoxContainer = $Radios

# ── State Variables ───────────────────────────────────
var selected_country: CountryData = null

# Animation State
@export var slide_duration: float = 0.2
var is_open := false
var pos_open := Vector2.ZERO
var pos_closed := Vector2.ZERO

# Navigation State
var current_context: Context = Context.PLAYER
var current_category: Category = Category.GENERAL

@export var military_access_label: Label

# ── Constants ──────────────────────────────────────────
const ACTION_COSTS := {
	"_declare_war": 100,
	"_request_access": 25,
	"_force_puppet": 150,
	"improve_stability": 50,
	"_improve_relations": 50,
	"_propose_peace": 0, # Should be free or handled by peace process
	"_launch_nuke": 250,
	"_form_alliance": 100,
	"_demand_tribute": 75,
	"_trade_deal": 25,
	"open_research_tree": 0,
	"open_decisions_tree": 0,
	"_open_faction": 0,
	"open_manage_country": 0,
	"_build_factory": 0, # Uses money/time
	"_build_port": 0 # Uses money/time
}

func _enter_tree() -> void:
	GameState.game_ui = self

func _ready() -> void:
	pos_open = sidemenu.position
	pos_closed = Vector2(pos_open.x - sidemenu.size.x, pos_open.y)
	sidemenu.position = pos_closed

	GameState.game_ui = self

	MapManager.country_clicked.connect(_on_province_clicked)
	MapManager.close_sidemenu.connect(close_menu)

	KeyboardManager.toggle_menu.connect(toggle_menu)

	GameState.current_world.clock.hour_passed.connect(_on_hour_passed)
	CountryManager.player_country_changed.connect(_on_player_change)
	if CountryManager.player_country:
		if CountryManager.player_country.ideology_changed.is_connected(_update_flag):
			CountryManager.player_country.ideology_changed.disconnect(_update_flag)
		CountryManager.player_country.ideology_changed.connect(_update_flag)
	
	_update_flag()
	updateProgressBar()
	update_division_menu()
	military_extra_panel.visible = false
	var clock := GameState.current_world.clock
	clock.hour_passed.connect(_on_time_passed)
	plus.pressed.connect(clock.increase_speed)
	minus.pressed.connect(clock.decrease_speed)
	label_date.text = clock.get_datetime_string()

	# NOTE(soi): its soiladin time
	const music_path = "res://assets/music/"
	for radio in MusicManager.music_map[0]:
		var entry = Button.new()
		entry.text = "\n\n\n" + radio
		entry.icon = load(music_path + radio + "/thumbnail.png")
		entry.expand_icon = true
		entry.set_meta("radio_name", radio)
		entry.pressed.connect(
		func():
			if radio in MusicManager.radios:
				MusicManager.radios.erase(radio)
			else:
				MusicManager.radios.append(radio)
			_update_radio_visuals()
			print(MusicManager.radios)
		)
		radio_list.add_child(entry)
	
	_update_radio_visuals()

func _update_radio_visuals() -> void:
	for child in radio_list.get_children():
		var radio_name = child.get_meta("radio_name", "")
		if radio_name == "":
			continue
			
		if radio_name in MusicManager.radios:
			child.modulate = Color.WHITE
		else:
			child.modulate = Color(0.5, 0.5, 0.5)


func _update_sidemenu_visuals(country_name: String) -> void:
	sidemenu_flag.texture = TroopManager.get_flag(country_name, selected_country.ideology_name)
	sidemenu_country_label.text = IdeologyManager.get_ideology_name(selected_country.ideology).capitalize() + " " + country_name.capitalize()
	
	sidemenu_pointer.position.x = remap(selected_country.ideology[0], -100, 100, 3, 97)
	sidemenu_pointer.position.y = remap(selected_country.ideology[1], -100, 100, 3, 97)
	
	_update_relations_visuals()

func _on_selected_country_ideology_changed():
	if selected_country:
		_update_sidemenu_visuals(selected_country.country_name)

func _on_player_change() -> void:
	if CountryManager.player_country:
		if CountryManager.player_country.ideology_changed.is_connected(_update_flag):
			CountryManager.player_country.ideology_changed.disconnect(_update_flag)
		CountryManager.player_country.ideology_changed.connect(_update_flag)

	_update_flag()
	update_topbar_stats()


func _on_province_clicked(country_name: String) -> void:
	if selected_country and selected_country.ideology_changed.is_connected(_on_selected_country_ideology_changed):
		selected_country.ideology_changed.disconnect(_on_selected_country_ideology_changed)

	selected_country = CountryManager.get_country(country_name)
	selected_country.ideology_changed.connect(_on_selected_country_ideology_changed)

	_update_sidemenu_visuals(country_name)

	if (
		!GameState.choosing_deploy_city
		|| GameState.industry_building == GameState.IndustryType.DEFAULT
	):
		var new_context = Context.NEUTRAL

		if country_name == CountryManager.player_country.country_name:
			new_context = Context.PLAYER
		elif WarManager.is_at_war(CountryManager.player_country, selected_country):
			new_context = Context.ENEMY
		elif selected_country.country_name in CountryManager.player_country.puppets:
			new_context = Context.PUPPET
		elif FactionManager.in_faction(CountryManager.player_country, selected_country):
			new_context = Context.ALLY
		# elif selected_country.country_name in CountryManager.player_country.puppets:
		# 	new_context = Context.PUPPET

		var has_military_access := (
			selected_country.country_name in CountryManager.player_country.allowedCountries
		)
		self.military_access_label.text = (
			"Military Access: " + String("Yes" if has_military_access else "No")
		)

		sidemenu_context.current_tab = new_context
		open_menu(new_context, Category.GENERAL)
		_update_context_actions_visuals()


func toggle_menu(context := Context.PLAYER) -> void:
	if is_open:
		close_menu()
	else:
		selected_country = CountryManager.player_country
		sidemenu_country_label.text = CountryManager.player_country.country_name
		sidemenu_flag.texture = nation_flag.texture
		open_menu(context, Category.GENERAL)
		_update_context_actions_visuals()

var custom_font = load("res://font/Google_Sans/GoogleSans-VariableFont_GRAD,opsz,wght.ttf")

func open_menu(context: Context, category: Category) -> void:
	if (
		GameState.choosing_deploy_city
		or GameState.industry_building != GameState.IndustryType.DEFAULT
	):
		return
	current_context = context
	current_category = category

	sidemenu_pointer.position.x = remap(selected_country.ideology[0], -100, 100, 3, 97)
	sidemenu_pointer.position.y = remap(selected_country.ideology[1], -100, 100, 3, 97)
	
	_update_relations_visuals()
	# _build_action_list()

	if !is_open:
		MusicManager.play_sfx(MusicManager.SFX.OPEN_MENU)
		slide_in()
	
	_update_context_actions_visuals()

func _update_relations_visuals() -> void:
	if current_category != Category.GENERAL:
		return

	for child in relations_hbox.get_children():
		child.queue_free()
	
	var player = CountryManager.player_country
	var target = selected_country

	if player and target and player != target:
		relations_hbox.visible = true
		
		# 1. FAR LEFT: Player Flag
		relations_hbox.add_child(_get_simple_flag(player.country_name, player.ideology_name))

		# 2. SPACER (Justify-Between)
		var spacer1 = Control.new()
		spacer1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		relations_hbox.add_child(spacer1)
		
		# 3. CENTER: Dual Opinions
		var our_val = player.get_relation_with(target.country_name)
		var their_val = target.get_relation_with(player.country_name)
		
		# "Our view"
		relations_hbox.add_child(_create_styled_label(str(our_val), 20, our_val))
		
		# Visual Divider
		var mid_icon = _create_styled_label(" ↔ ", 20, 50) # Neutral color for divider
		mid_icon.modulate.a = 0.4
		relations_hbox.add_child(mid_icon)
		
		# "Their view"
		relations_hbox.add_child(_create_styled_label(str(their_val), 20, their_val))

		# 4. SECOND SPACER
		var spacer2 = Control.new()
		spacer2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		relations_hbox.add_child(spacer2)

		# 5. FAR RIGHT: Target Flag
		relations_hbox.add_child(_get_simple_flag(target.country_name, target.ideology_name))
	else:
		relations_hbox.visible = false

func _update_context_actions_visuals() -> void:
	var player = CountryManager.player_country
	if not player: return

	# Iterate through all context tabs to find action buttons
	for context_node in sidemenu_context.get_children():
		# Try to find ScrollContainer/ActionsList/ in each tab
		var actions_list = context_node.find_child("ActionsList", true, false)
		if actions_list:
			for child in actions_list.get_children():
				if child is Button:
					var method = ""
					# Find which method this button calls by looking at connections
					for connection in child.pressed.get_connections():
						if connection.callable.get_object() == self:
							method = connection.callable.get_method()
							break
					
					if method != "" and ACTION_COSTS.has(method):
						var cost = ACTION_COSTS[method]
						var can_afford = player.political_power >= cost
						
						child.disabled = !can_afford
						
						# Update text to show cost if > 0
						var base_text = child.text.split(" (")[0] # Strip existing cost
						if cost > 0:
							child.text = base_text + " (%d PP)" % cost
						else:
							child.text = base_text
						
						# Visual feedback for disabled buttons
						if !can_afford:
							child.modulate = Color(1, 0.5, 0.5, 0.7)
						else:
							child.modulate = Color.WHITE

func _create_styled_label(text_content: String, size: int, score_ref: int) -> Label:
	var l = Label.new()
	l.text = text_content
	
	# Apply the Custom Font
	if custom_font:
		l.add_theme_font_override("font", custom_font)
	
	# Apply Font Size
	l.add_theme_font_size_override("font_size", size)
	
	# Apply Color based on score_ref
	if score_ref >= 70:
		l.modulate = Color.SPRING_GREEN
	elif score_ref <= 30:
		l.modulate = Color.ORANGE_RED
	else:
		l.modulate = Color.WHITE
		
	return l

func _get_simple_flag(c_name: String, ideology: String = "") -> TextureRect:
	var tr = TextureRect.new()
	tr.texture = TroopManager.get_flag(c_name, ideology)
	tr.custom_minimum_size = Vector2(42, 26)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return tr
func _on_tab_changed(new_category_index: int) -> void:
	current_category = new_category_index as Category
	# _build_action_list()
	MusicManager.play_sfx(MusicManager.SFX.HOVERED)


func _on_menu_button_button_up(_menu_index: int) -> void:
	current_category = _menu_index as Category
	if !CountryManager.player_country: return
	if current_context == Context.PLAYER:
		if _menu_index == Category.ECONOMY:
			MapManager.show_industry_country(CountryManager.player_country.country_name)
		else:
			MapManager.set_country_color(CountryManager.player_country.country_name, Color.TRANSPARENT)
			GameState.industry_building = GameState.IndustryType.DEFAULT
			MapManager.show_countries_map()

		if _menu_index == Category.MILITARY:
			military_extra_panel.visible = true
		else:
			military_extra_panel.visible = false
	# _build_action_list()


# Note Z21 Some of the things here are outdated and not used and overall bad way to do things ngl
func _build_trooplist() -> void:
	for child in sidemenu_trooplist.get_children():
		child.queue_free()

	var player = CountryManager.player_country

	for troop in player.ongoing_training:
		var btn = action_scene.instantiate()
		sidemenu_trooplist.add_child(btn)
		btn.setup_training(troop)
		# We connect the signal emitted by ActionRow when days_left <= 0
		if not btn.training_finished.is_connected(_build_trooplist):
			btn.training_finished.connect(_build_trooplist)

	# Ready to Deploy
	for troop in player.ready_troops:
		var btn = action_scene.instantiate()
		sidemenu_trooplist.add_child(btn)
		# Callable points to deploy_troop, passing the specific troop object
		var deploy_call = Callable(self, "deploy_troop").bind(troop)
		btn.setup_ready(troop, deploy_call)

func update_topbar_stats() -> void:
	if !CountryManager.player_country:
		return
	stats_labels.pp.text = str(floori(CountryManager.player_country.political_power))
	stats_labels.stability.text = str(round(CountryManager.player_country.stability * 100)) + "%"
	stats_labels.manpower.text = format_number(CountryManager.player_country.manpower)
	stats_labels.money.text = format_number(CountryManager.player_country.money)
	stats_labels.industry.text = str(CountryManager.player_country.factories_amount)
	stats_labels.war_support.text = str(CountryManager.player_country.war_support * 100) + "%"


func _on_hour_passed() -> void:
	update_topbar_stats()
	if is_open:
		_update_context_actions_visuals()


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


func _on_time_passed() -> void:
	label_date.text = GameState.current_world.clock.get_datetime_string()


func updateProgressBar():
	var clock = GameState.current_world.clock
	progress_bar.value = (clock.time_scale / clock.MAX_SPEED) * 100.0
	var bg_style = progress_bar.get_theme_stylebox("background")
	if clock.paused:
		bg_style.border_color = Color.DARK_RED
		label_date.add_theme_color_override("font_color", Color.GRAY)
	else:
		bg_style.border_color = Color.DARK_CYAN
		label_date.add_theme_color_override("font_color", Color.WHITE)


func _update_flag() -> void:
	if !CountryManager.player_country:
		return
	nation_flag.texture = TroopManager.get_flag(CountryManager.player_country.country_name, CountryManager.player_country.ideology_name)
	_update_relations_visuals()


func close_menu() -> void:
	if is_open:
		MusicManager.play_sfx(MusicManager.SFX.CLOSE_MENU)
	GameState.reset_industry_building()
	military_extra_panel.visible = false # just to be sure
	slide_out()


func slide_in() -> void:
	if is_open:
		return
	is_open = true
	var tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(sidemenu, "position", pos_open, slide_duration)


func slide_out() -> void:
	if not is_open:
		return
	is_open = false
	var tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(sidemenu, "position", pos_closed, slide_duration)


func _choose_deploy_city():
	GameState.choosing_deploy_city = true


func _declare_war():
	var cost = ACTION_COSTS.get("_declare_war", 0)
	if CountryManager.player_country.political_power < cost:
		return
	CountryManager.player_country.political_power -= cost
	
	WarManager.declare_war(CountryManager.player_country, selected_country)

	var has_military_access := (
		selected_country.country_name in CountryManager.player_country.allowedCountries
	)
	GameState.game_ui.military_access_label.text = (
		"Military Access: " + String("Yes" if has_military_access else "No")
	)

	open_menu(Context.ENEMY, Category.GENERAL)


func _conscript(data: Dictionary):
	var manpower = data.manpower / 10000
	CountryManager.player_country.train_troops(1, "infantry")
	update_topbar_stats()
	# _build_action_list()


func deploy_troop(troop):
	CountryManager.player_country.deploy_ready_troop(
		troop, CountryManager.player_country.deploy_pid
	)
	_build_trooplist()


func improve_stability():
	var cost = ACTION_COSTS.get("improve_stability", 0)
	if CountryManager.player_country.political_power < cost:
		return
	CountryManager.player_country.political_power -= cost
	
	CountryManager.player_country.stability += 0.02
	update_topbar_stats()
	_update_context_actions_visuals()


func _build_factory():
	GameState.industry_building = GameState.IndustryType.FACTORY
	#MapManager.show_industry_country(player.country_name)


func _build_port():
	GameState.industry_building = GameState.IndustryType.PORT
	#MapManager.show_industry_country(player.country_name)


func _request_access():
	var cost = ACTION_COSTS.get("_request_access", 0)
	if CountryManager.player_country.political_power < cost:
		return
	CountryManager.player_country.political_power -= cost
	
	CountryManager.player_country.allowedCountries.append(selected_country.country_name)
	_update_context_actions_visuals()

func _force_puppet():
	var cost = ACTION_COSTS.get("_force_puppet", 0)
	if CountryManager.player_country.political_power < cost:
		return
	CountryManager.player_country.political_power -= cost
	
	CountryManager.make_puppet(CountryManager.player_country, selected_country)
	_update_context_actions_visuals()
	close_menu()

func _on_release_puppet_pressed():
	var cost = ACTION_COSTS.get("_release_puppet", 0)
	if CountryManager.player_country.political_power < cost:
		return
	CountryManager.player_country.political_power -= cost
	
	CountryManager.release_puppet(CountryManager.player_country, selected_country)
	_update_context_actions_visuals()
	close_menu()


func _improve_relations():
	var cost = ACTION_COSTS.get("_improve_relations", 0)
	if CountryManager.player_country.political_power < cost:
		return
	CountryManager.player_country.political_power -= cost
	
	print("Improving relations")
	_update_context_actions_visuals()


func _propose_peace():
	print("Proposing peace")


func _launch_nuke():
	print("NUKE!")

func _demand_tribute():
	print("Pay up!")


func _trade_deal():
	print("Trading...")


func open_research_tree():
	print("Opening Research")


func open_decisions_tree():
	get_tree().root.find_child("DecisionTreeUI", true, false).open_menu()

func _open_faction():
	faction_prompt.visible = !faction_prompt.visible

func open_manage_country():
	get_tree().root.find_child("CountryManageUI", true, false).open_menu(
		CountryManager.player_country
	)

	#GameState.current_world.set_process(false)
	#GameState.current_world.clock.set_process(false)
	#TroopManager.set_process(false)
	#GameState.current_world.find_child("CameraController").set_process(false)


# Note (Z21)
# Everything below is made by a Clanker. I am way too lazy for UI stuff
@onready var troop_list_parent: VBoxContainer = $Control/TroopContainer/ScrollContainer/VBoxContainer

# Theme colors for the military look

# 1. Add this variable at the top with your other @onready variables
var selected_division_objects: Array[DivisionData] = []
const DIVISION_CARD_SCENE = preload("res://Scenes/DivisionItem.tscn") # Path to your card


func make_troop_container(selected_troops: Array[TroopData]) -> void:
	troop_container.visible = true
	for child in troop_list_parent.get_children():
		child.queue_free()

	for troop in selected_troops:
		# --- Create a Province Header ---
		var header_panel = PanelContainer.new()
		var h_style = StyleBoxFlat.new()
		h_style.bg_color = Color(0.12, 0.13, 0.15, 0.95) # Cleaner military dark
		h_style.border_width_bottom = 2
		h_style.border_color = Color.GOLD
		header_panel.add_theme_stylebox_override("panel", h_style)

		var header_label = Label.new()
		header_label.text = "  PROVINCE %d" % troop.province_id
		header_label.add_theme_color_override("font_color", Color.GOLD)
		header_panel.add_child(header_label)
		troop_list_parent.add_child(header_panel)

		# --- Group Divisions by Type ---
		# Resulting dict will look like: {"infantry": [div1, div2], "tank": [div3]}
		var groups: Dictionary = {}

		for div in troop.stored_divisions:
			if not groups.has(div.type):
				groups[div.type] = []
			groups[div.type].append(div)

		# --- Draw One Card Per Type ---
		for type in groups.keys():
			var divisions_of_type: Array = groups[type]

			var card = DIVISION_CARD_SCENE.instantiate()
			troop_list_parent.add_child(card)

			# Check if the group is selected based on the first element
			var is_selected = divisions_of_type[0] in selected_division_objects

			# FIX: Pass 'divisions_of_type' (the Array) as the second argument
			# We no longer pass 'count' here because the card calculates it from the array
			card.setup_grouped(type, divisions_of_type, is_selected)

			# Update the signal connection
			if not card.is_connected("clicked", _on_group_clicked):
				# We pass the card node (self) and the array to the handler
				card.clicked.connect(_on_group_clicked)


func _on_group_clicked(card_node: Control, divs_in_group: Array):
	# Check the first div to see if we are selecting or deselecting the group
	var is_already_selected = divs_in_group[0] in selected_division_objects

	for div in divs_in_group:
		if is_already_selected:
			if div in selected_division_objects:
				selected_division_objects.erase(div)
		else:
			if not div in selected_division_objects:
				selected_division_objects.append(div)

	# Toggle the card's visual state
	card_node.is_selected = !is_already_selected
	card_node.update_visuals()


func _on_card_clicked(div: DivisionData, card_node: Control):
	if div in selected_division_objects:
		selected_division_objects.erase(div)
		card_node.is_selected = false
	else:
		selected_division_objects.append(div)
		card_node.is_selected = true

	card_node.update_visuals()
	print("Selected divisions count: ", selected_division_objects.size())


func close_troop_container() -> void:
	troop_container.visible = false


# --- References ---
@onready var military_extra_panel: PanelContainer = $Control/MilitaryExtraPanel
# @onready var input_division: SpinBox = $VBoxContainer/VBoxContainer/Count/HBoxContainer/input_division
@onready var input_division: SpinBox = military_extra_panel.get_node("VBoxContainer/VBoxContainer/Count/HBoxContainer/input_division")
@onready var button_train: Button = military_extra_panel.get_node("VBoxContainer/Button_Train")

# Grouping UI labels makes them easier to manage
@onready var ui_labels = {
	"type": military_extra_panel.get_node("VBoxContainer/VBoxContainer/Type/type"),
	"div_stats": military_extra_panel.get_node("VBoxContainer/VBoxContainer/Stats/amount"),
	"costs": military_extra_panel.get_node("VBoxContainer/VBoxContainer/Cost/amount"),
	"manpower": military_extra_panel.get_node("VBoxContainer/VBoxContainer/Manpower/amount")
}

# --- State ---
var division_type_selected: String = "infantry"


# --- Main Update Logic ---
func update_division_menu():
	var count = int(input_division.value)
	var stats = DivisionData.TEMPLATES.get(division_type_selected)

	if not stats:
		return # Safety check

	ui_labels.type.text = division_type_selected.capitalize()
	ui_labels.div_stats.text = "%s : %s : %s" % [stats.attack, stats.defense, stats.hp]

	var total_cost = stats.cost * count
	var total_manpower = stats.manpower * count

	ui_labels.costs.text = format_number(total_cost)
	ui_labels.manpower.text = format_number(total_manpower)

	# 4. Check Affordability
	var player = CountryManager.player_country
	var can_afford = false

	if player:
		# You can check Money here too if you want: "and player.money >= total_cost"
		can_afford = player.manpower >= total_manpower

	# 5. Update Button State & Visuals
	button_train.disabled = not can_afford
	_update_train_button_visuals(can_afford)


# --- Button Styling Helper ---
func _update_train_button_visuals(is_affordable: bool) -> void:
	# Create a new StyleBoxFlat to override the background color
	var style = StyleBoxFlat.new()
	style.set_corner_radius_all(4) # Optional: match your game's rounded corners

	if is_affordable:
		style.bg_color = Color("#394f39") # Greenish
		# Apply to Normal and Hover states
		button_train.add_theme_stylebox_override("normal", style)
		button_train.add_theme_stylebox_override("hover", style)
		button_train.remove_theme_stylebox_override("disabled")
	else:
		style.bg_color = Color("#5a3f39") # Reddish
		# Apply specifically to the Disabled state
		button_train.add_theme_stylebox_override("disabled", style)


func _on_button_train_troops() -> void:
	var divisions = int(input_division.value)
	var success = CountryManager.player_country.train_troops(divisions, division_type_selected)

	if success:
		_build_trooplist()
	update_division_menu()


func _on_division_type_button(type: String) -> void:
	division_type_selected = type
	update_division_menu()

func _on_input_division_text_changed(new_text: float) -> void:
	update_division_menu()

func _on_music_pressed():
	radio_list.visible = !radio_list.visible

func _on_create_faction_pressed() -> void:
	FactionManager.create_faction(CountryManager.player_country.country_name, faction_prompt.get_node("HBoxContainer/TextEdit").text)
	faction_prompt.get_node("HBoxContainer/TextEdit").text = ""
	faction_prompt.visible = !faction_prompt.visible

func _on_invite_faction_pressed() -> void:
	FactionManager.invite_faction(CountryManager.player_country, selected_country)
	# MapManager.show_faction_map()

func _on_steal_manpower_pressed() -> void:
	if selected_country.total_population > 0:
		CountryManager.player_country.total_population += 1_000
		selected_country.total_population -= 1_000
		CountryManager.player_country.update_manpower_pool()
		selected_country.update_manpower_pool()


func _on_steal_money_pressed() -> void:
	if selected_country.money > 0:
		CountryManager.player_country.money += 1_000
		selected_country.money -= 1_000


func _on_annex_country_pressed() -> void:
	MapManager.annex_country(CountryManager.player_country.country_name, selected_country.country_name)

func _on_call_to_arms_pressed() -> void:
	WarManager.call_to_arms(CountryManager.player_country, selected_country)
