extends CanvasLayer
class_name GameUI

@onready var nation_flag: TextureRect = $Control/Topbar/nation_flag

const PROVINCE_POPUP_SCENE = preload("res://Scenes/UI/ProvincePopup.tscn")
var active_popup = null

var label_steel: Label
var label_oil: Label
var btn_messages: Button
var active_messages_popup: PanelContainer = null
var troop_control_card: PanelContainer = null

func _enter_tree() -> void:
	GameState.game_ui = self

func _ready() -> void:
	GameState.game_ui = self
	
	# Make all resource tooltips pop up instantly!
	ProjectSettings.set_setting("gui/timers/tooltip_delay_sec", 0.05)
	
	var clock = GameState.main.clock
	clock.speed_changed.connect(updateProgressBar)
	clock.hour_passed.connect(_on_time_passed)
	%Plus.pressed.connect(clock.increase_speed)
	%Minus.pressed.connect(clock.decrease_speed)
	
	CountryManager.player_country_changed.connect(_on_player_change)
	
	# Spawn Left Side Menu Panel
	var side_panel_scene = load("res://Scenes/UI/ProductionMenu.tscn")
	if side_panel_scene:
		var side_panel = side_panel_scene.instantiate()
		add_child(side_panel)
		GameState.production_menu_instance = side_panel
	
	# Dynamically build resource readouts on topbar
	var parent_hbox = %label_industry.get_parent().get_parent().get_parent() as HBoxContainer
	if parent_hbox:
		# Create Steel Panel
		var steel_panel = %label_industry.get_parent().get_parent().duplicate() as PanelContainer
		steel_panel.tooltip_text = "Steel stock and daily flow"
		var steel_hbox = steel_panel.get_child(0) as HBoxContainer
		var steel_icon = steel_hbox.get_child(0) as TextureRect
		if ResourceLoader.exists("res://assets/icons/steelingot.png"):
			steel_icon.texture = load("res://assets/icons/steelingot.png")
			steel_icon.visible = true
		label_steel = steel_hbox.get_child(1) as Label
		parent_hbox.add_child(steel_panel)
		
		# Create Oil Panel
		var oil_panel = %label_industry.get_parent().get_parent().duplicate() as PanelContainer
		oil_panel.tooltip_text = "Oil stock and daily flow"
		var oil_hbox = oil_panel.get_child(0) as HBoxContainer
		oil_hbox.get_child(0).visible = true
		label_oil = oil_hbox.get_child(1) as Label
		parent_hbox.add_child(oil_panel)
		
		# Create Messages Panel/Button
		btn_messages = Button.new()
		btn_messages.mouse_filter = Control.MOUSE_FILTER_STOP
		btn_messages.custom_minimum_size = Vector2(60, 24)
		btn_messages.text = "✉️ 0"
		btn_messages.add_theme_color_override("font_color", Color.WHITE)
		btn_messages.add_theme_font_size_override("font_size", 14)
		btn_messages.pressed.connect(_on_messages_pressed)
		btn_messages.tooltip_text = "Unread diplomatic alerts"
		
		var ind_style = %label_industry.get_parent().get_parent().get_theme_stylebox("panel")
		if ind_style:
			btn_messages.add_theme_stylebox_override("normal", ind_style)
			var hover_style = ind_style.duplicate()
			hover_style.bg_color = hover_style.bg_color.lightened(0.15)
			btn_messages.add_theme_stylebox_override("hover", hover_style)
			
		parent_hbox.add_child(btn_messages)
		
		# Connect signals
		CountryManager.messages_updated.connect(_update_messages_btn)
	
	_on_time_passed(0)
	updateProgressBar()
	
	MapManager.province_hovered.connect(_on_province_hovered)
	active_popup = PROVINCE_POPUP_SCENE.instantiate()
	add_child(active_popup)
	active_popup.hide()
	
	# Hook troop selection changed signal
	if is_instance_valid(TroopManager) and is_instance_valid(TroopManager.troop_selection):
		TroopManager.troop_selection.selection_changed.connect(_on_troop_selection_changed)
	get_viewport().size_changed.connect(_on_viewport_resized)

func _on_player_change() -> void:
	_update_flag()
	update_topbar_stats()

var custom_font = load("res://font/Google_Sans/GoogleSans-VariableFont_GRAD,opsz,wght.ttf")


func _get_simple_flag(c_name: String) -> TextureRect:
	var tr = TextureRect.new()
	tr.texture = TroopManager.get_flag(c_name)
	tr.custom_minimum_size = Vector2(42, 26)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return tr


func update_topbar_stats() -> void:
	var country: CountryData = CountryManager.player_country
	if not country:
		return
		
	# 1. Clean, minimal text on screen
	%label_politicalpower.text = str(floori(country.political_power))
	%label_stability.text = str(round(country.stability * 100)) + "%"
	%label_manpower.text = format_number(country.manpower)
	%label_money.text = format_number(country.money)
	%label_industry.text = str(country.factories_available) + "/" + str(country.factories_amount)
	
	# 2. Add detailed hover tooltips to the capsules
	if %label_politicalpower.get_parent() and %label_politicalpower.get_parent().get_parent():
		%label_politicalpower.get_parent().get_parent().tooltip_text = "Political Influence (PP)\nUsed to adjust draft laws and recruit generals.\nDaily Increase: +2.0 PP/day"
		
	if %label_stability.get_parent() and %label_stability.get_parent().get_parent():
		%label_stability.get_parent().get_parent().tooltip_text = "National Stability: %d%%\nHigh stability boosts manufacturing output and reduces consumer goods factory requirements." % round(country.stability * 100)
		
	if %label_manpower.get_parent() and %label_manpower.get_parent().get_parent():
		%label_manpower.get_parent().get_parent().tooltip_text = "Manpower Reserves: %s men\nUsed to train new division templates. Increases with conscription laws." % format_number(country.manpower)
		
	if %label_money.get_parent() and %label_money.get_parent().get_parent():
		%label_money.get_parent().get_parent().tooltip_text = "Treasury Balance: $%s\nGross Daily Income: +$%s/day\nHourly tick: +$%s/hour" % [format_number(country.money), format_number(country.income), format_number(country.income / 24.0)]
		
	if %label_industry.get_parent() and %label_industry.get_parent().get_parent():
		%label_industry.get_parent().get_parent().tooltip_text = "Industrial Factories: %d total\nActive construction slots: %d" % [country.factories_amount, country.factories_available]

	if is_instance_valid(label_steel):
		var net_steel = country.steel_production - country.steel_consumption + country.recurring_steel_buy
		var net_steel_sign = "+" if net_steel >= 0 else ""
		label_steel.text = format_number(country.steel)
		if net_steel < 0:
			label_steel.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
		else:
			label_steel.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
			
		var parent_panel = label_steel.get_parent().get_parent()
		if parent_panel:
			parent_panel.tooltip_text = "Steel Stocks: %.1f tonnes\n\nDaily Production: +%.1f/day\nDaily Consumption: -%.1f/day\nMarket flow sub: %s%.1f/day\nNet Daily Flow: %s%.1f/day" % [
				country.steel, country.steel_production, country.steel_consumption,
				("+" if country.recurring_steel_buy >= 0 else ""), country.recurring_steel_buy,
				net_steel_sign, net_steel
			]
			
	if is_instance_valid(label_oil):
		var net_oil = country.oil_production - country.oil_consumption + country.recurring_oil_buy
		var net_oil_sign = "+" if net_oil >= 0 else ""
		label_oil.text = "🛢️ " + format_number(country.oil)
		if net_oil < 0:
			label_oil.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
		else:
			label_oil.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
			
		var parent_panel = label_oil.get_parent().get_parent()
		if parent_panel:
			parent_panel.tooltip_text = "Crude Oil Stocks: %.1f barrels\n\nDaily Production: +%.1f/day\nDaily Consumption: -%.1f/day\nMarket flow sub: %s%.1f/day\nNet Daily Flow: %s%.1f/day" % [
				country.oil, country.oil_production, country.oil_consumption,
				("+" if country.recurring_oil_buy >= 0 else ""), country.recurring_oil_buy,
				net_oil_sign, net_oil
			]
			
	_update_messages_btn()


func _on_hour_passed(_total_ticks) -> void:
	update_topbar_stats()


func _on_time_passed(x) -> void:
	%label_date.text = GameState.main.clock.get_datetime_string()
	update_topbar_stats()

func _on_province_hovered(pid: int):
	if pid in [-1, 0, 1]:
		active_popup.hide_popup()
		return

	var data = MapManager.province_objects[pid]
	active_popup.show_popup(data)

func updateProgressBar():
	var clock = GameState.main.clock

	%ProgressBar.value = clock.current_speed_level
	var bg_style = %ProgressBar.get_theme_stylebox("background")
	if clock.paused:
		bg_style.border_color = Color.DARK_RED
		%label_date.add_theme_color_override("font_color", Color.RED)
	else:
		bg_style.border_color = Color.DARK_CYAN
		%label_date.add_theme_color_override("font_color", Color.WHITE)


func _update_flag() -> void:
	if !CountryManager.player_country:
		return
	var path = (
		"res://assets/flags/%s_flag.png" % CountryManager.player_country.country_name.to_lower()
	)
	if ResourceLoader.exists(path):
		nation_flag.texture = load(path)

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


func _update_messages_btn() -> void:
	if is_instance_valid(btn_messages):
		var count = CountryManager.active_messages.size()
		if count > 0:
			btn_messages.text = "✉️ %d" % count
			btn_messages.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		else:
			btn_messages.text = "✉️ 0"
			btn_messages.add_theme_color_override("font_color", Color.WHITE)


func _on_messages_pressed() -> void:
	if is_instance_valid(active_messages_popup):
		active_messages_popup.queue_free()
		return
		
	active_messages_popup = PanelContainer.new()
	active_messages_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	active_messages_popup.custom_minimum_size = Vector2(350, 400)
	
	active_messages_popup.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	active_messages_popup.position = Vector2(get_viewport().get_visible_rect().size.x - 370, 45)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.12, 0.98)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.85, 0.45, 0.15, 1.0)
	style.set_corner_radius_all(0)
	active_messages_popup.add_theme_stylebox_override("panel", style)
	
	var margin = MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 15)
	margin.add_theme_constant_override("margin_top", 15)
	margin.add_theme_constant_override("margin_right", 15)
	margin.add_theme_constant_override("margin_bottom", 15)
	active_messages_popup.add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)
	
	# Header
	var header = HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var title = Label.new()
	title.text = "DIPLOMATIC MESSAGES"
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(0.85, 0.45, 0.15))
	header.add_child(title)
	
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	
	var close_btn = Button.new()
	close_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	close_btn.text = "X"
	close_btn.flat = true
	close_btn.pressed.connect(func(): active_messages_popup.queue_free())
	header.add_child(close_btn)
	vbox.add_child(header)
	
	# Scroll area
	var scroll = ScrollContainer.new()
	scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)
	
	var list_box = VBoxContainer.new()
	list_box.mouse_filter = Control.MOUSE_FILTER_PASS
	list_box.add_theme_constant_override("separation", 12)
	list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list_box)
	
	var msgs = CountryManager.active_messages
	if msgs.is_empty():
		var empty_lbl = Label.new()
		empty_lbl.text = "No pending diplomatic messages."
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		list_box.add_child(empty_lbl)
	else:
		for msg in msgs:
			var item_panel = PanelContainer.new()
			item_panel.mouse_filter = Control.MOUSE_FILTER_STOP
			var item_style = StyleBoxFlat.new()
			item_style.bg_color = Color(0.05, 0.05, 0.06, 1.0)
			item_style.border_width_left = 2
			item_style.border_color = Color(0.85, 0.45, 0.15, 1.0)
			item_style.set_corner_radius_all(0)
			item_panel.add_theme_stylebox_override("panel", item_style)
			
			var item_margin = MarginContainer.new()
			item_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
			item_margin.add_theme_constant_override("margin_left", 8)
			item_margin.add_theme_constant_override("margin_top", 8)
			item_margin.add_theme_constant_override("margin_right", 8)
			item_margin.add_theme_constant_override("margin_bottom", 8)
			item_panel.add_child(item_margin)
			
			var item_vbox = VBoxContainer.new()
			item_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
			item_vbox.add_theme_constant_override("separation", 6)
			item_margin.add_child(item_vbox)
			
			# Sender flag and title
			var sender_hbox = HBoxContainer.new()
			sender_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
			sender_hbox.add_theme_constant_override("separation", 6)
			var flag = TextureRect.new()
			flag.texture = TroopManager.get_flag(msg.sender)
			flag.custom_minimum_size = Vector2(24, 15)
			flag.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			sender_hbox.add_child(flag)
			
			var t_lbl = Label.new()
			t_lbl.text = msg.title
			t_lbl.add_theme_font_size_override("font_size", 12)
			t_lbl.add_theme_color_override("font_color", Color.WHITE)
			sender_hbox.add_child(t_lbl)
			item_vbox.add_child(sender_hbox)
			
			# Content
			var c_lbl = Label.new()
			c_lbl.text = msg.content
			c_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			c_lbl.add_theme_font_size_override("font_size", 11)
			c_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
			item_vbox.add_child(c_lbl)
			
			# Action Buttons
			var action_hbox = HBoxContainer.new()
			action_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
			action_hbox.alignment = BoxContainer.ALIGNMENT_END
			action_hbox.add_theme_constant_override("separation", 8)
			
			var acc_btn = Button.new()
			acc_btn.mouse_filter = Control.MOUSE_FILTER_STOP
			acc_btn.text = "Accept"
			acc_btn.pressed.connect(func():
				CountryManager.accept_message(msg.id)
				active_messages_popup.queue_free()
				_on_messages_pressed()
			)
			action_hbox.add_child(acc_btn)
			
			var dec_btn = Button.new()
			dec_btn.mouse_filter = Control.MOUSE_FILTER_STOP
			dec_btn.text = "Decline"
			dec_btn.pressed.connect(func():
				CountryManager.decline_message(msg.id)
				active_messages_popup.queue_free()
				_on_messages_pressed()
			)
			action_hbox.add_child(dec_btn)
			
			item_vbox.add_child(action_hbox)
			list_box.add_child(item_panel)
			
	add_child(active_messages_popup)


func _process(_delta: float) -> void:
	if not is_instance_valid(GameState) or not is_instance_valid(GameState.main) or not is_instance_valid(GameState.main.clock):
		return
		
	var clock = GameState.main.clock
	if clock:
		%label_date.text = ("⏸️ " if clock.paused else "▶️ ") + clock.get_datetime_string()


func _on_viewport_resized() -> void:
	if is_instance_valid(troop_control_card) and troop_control_card.visible:
		var size = get_viewport().get_visible_rect().size
		troop_control_card.position = Vector2(size.x - 375, size.y - 260)


func _on_troop_selection_changed() -> void:
	pass


func _draw_troop_control_card(selected_list: Array) -> void:
	# Clear old layout
	for child in troop_control_card.get_children():
		child.queue_free()
		
	var margin = MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	troop_control_card.add_child(margin)
	
	var main_vbox = VBoxContainer.new()
	main_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main_vbox.add_theme_constant_override("separation", 10)
	margin.add_child(main_vbox)
	
	# Header Row: Title & Bulk Delete Button
	var header_hbox = HBoxContainer.new()
	header_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main_vbox.add_child(header_hbox)

	var title = Label.new()
	title.text = "⚔️ ARMY COMMAND (%d UNIT%s)" % [selected_list.size(), "S" if selected_list.size() > 1 else ""]
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", Color(0.9, 0.5, 0.15))
	header_hbox.add_child(title)

	var spacer_h = Control.new()
	spacer_h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(spacer_h)

	var delete_all_btn = Button.new()
	delete_all_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	delete_all_btn.text = "🗑️ Disband All"
	_apply_popup_btn_style(delete_all_btn, Color(0.9, 0.25, 0.2))
	delete_all_btn.pressed.connect(func():
		var troops_copy = selected_list.duplicate()
		for t in troops_copy:
			TroopManager.delete_troop(t)
	)
	header_hbox.add_child(delete_all_btn)

	# Scroll Container for Division Cards
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(340, 180)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main_vbox.add_child(scroll)

	var list_vbox = VBoxContainer.new()
	list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_vbox.add_theme_constant_override("separation", 6)
	scroll.add_child(list_vbox)

	for troop_idx in range(selected_list.size()):
		var troop: TroopData = selected_list[troop_idx]
		if not is_instance_valid(troop):
			continue

		var item_panel = PanelContainer.new()
		var p_style = StyleBoxFlat.new()
		p_style.bg_color = Color(0.08, 0.09, 0.12, 0.95)
		p_style.border_width_left = 2
		p_style.border_color = Color(0.2, 0.65, 0.35) if troop.cached_main_type == "infantry" else (Color(0.85, 0.3, 0.2) if troop.cached_main_type == "artillery" else Color(0.2, 0.5, 0.85))
		p_style.set_corner_radius_all(0)
		item_panel.add_theme_stylebox_override("panel", p_style)
		list_vbox.add_child(item_panel)

		var item_margin = MarginContainer.new()
		item_margin.add_theme_constant_override("margin_left", 8)
		item_margin.add_theme_constant_override("margin_top", 6)
		item_margin.add_theme_constant_override("margin_right", 8)
		item_margin.add_theme_constant_override("margin_bottom", 6)
		item_panel.add_child(item_margin)

		var item_vbox = VBoxContainer.new()
		item_vbox.add_theme_constant_override("separation", 4)
		item_margin.add_child(item_vbox)

		# Unit Name & Disband Single Unit
		var top_row = HBoxContainer.new()
		item_vbox.add_child(top_row)

		var type_icon = "🟩" if troop.cached_main_type == "infantry" else ("🔺" if troop.cached_main_type == "artillery" else "🔵")
		var u_name = Label.new()
		u_name.text = "%s Unit #%d (%s)" % [type_icon, troop_idx + 1, troop.cached_main_type.capitalize()]
		u_name.add_theme_font_size_override("font_size", 11)
		u_name.add_theme_color_override("font_color", Color.WHITE)
		top_row.add_child(u_name)

		var sp_row = Control.new()
		sp_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top_row.add_child(sp_row)

		var del_single = Button.new()
		del_single.mouse_filter = Control.MOUSE_FILTER_STOP
		del_single.text = "✖"
		_apply_popup_btn_style(del_single, Color(0.8, 0.2, 0.2))
		del_single.custom_minimum_size = Vector2(24, 20)
		del_single.pressed.connect(func():
			TroopManager.delete_troop(troop)
		)
		top_row.add_child(del_single)

		# Health / HP Progress Bar
		var hp_percent = troop.get_average_hp_percent()
		var hp_bar = ProgressBar.new()
		hp_bar.custom_minimum_size = Vector2(0, 10)
		hp_bar.show_percentage = false
		hp_bar.value = hp_percent * 100.0

		var bar_style = StyleBoxFlat.new()
		bar_style.bg_color = Color(0.15, 0.8, 0.35) if hp_percent > 0.5 else (Color(0.9, 0.7, 0.1) if hp_percent > 0.25 else Color(0.85, 0.2, 0.2))
		bar_style.set_corner_radius_all(0)
		hp_bar.add_theme_stylebox_override("fill", bar_style)

		var bg_bar_style = StyleBoxFlat.new()
		bg_bar_style.bg_color = Color(0.04, 0.04, 0.05, 1.0)
		bg_bar_style.set_corner_radius_all(0)
		hp_bar.add_theme_stylebox_override("background", bg_bar_style)

		item_vbox.add_child(hp_bar)

		# Divisions breakdown list inside this unit
		var div_info = Label.new()
		div_info.text = "Health: %d%% | Divisions: %d" % [int(hp_percent * 100.0), troop.divisions_count]
		div_info.add_theme_font_size_override("font_size", 9)
		div_info.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
		item_vbox.add_child(div_info)


func _apply_popup_btn_style(btn: Button, border_color: Color) -> void:
	var s = StyleBoxFlat.new()
	s.bg_color = Color(0.12, 0.14, 0.18, 0.95)
	s.border_width_bottom = 2
	s.border_color = border_color
	s.set_corner_radius_all(0)
	btn.add_theme_stylebox_override("normal", s)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_font_size_override("font_size", 10)
	btn.custom_minimum_size = Vector2(70, 26)
