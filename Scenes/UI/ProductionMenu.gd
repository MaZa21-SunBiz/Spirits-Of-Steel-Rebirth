extends Control

# --- Sleek, Dark Pixel-Art Theme ---
const COLOR_BG = Color(0.04, 0.04, 0.05, 0.99) # Premium pixel black
const COLOR_PANEL_INNER = Color(0.10, 0.10, 0.12, 0.98) # Dark charcoal card
const COLOR_ACCENT = Color(0.85, 0.45, 0.15, 1.0) # Copper orange highlight
const COLOR_TEXT_WHITE = Color(0.95, 0.95, 0.95) # Aged white text
const COLOR_ALERT = Color(0.80, 0.20, 0.20)   # Rust red
const COLOR_SUCCESS = Color(0.25, 0.65, 0.30) # Olive green

var player_country: CountryData
var target_country: CountryData = null
var current_tab: int = 0 # 0=Production, 1=Politics, 2=Commanders, 3=Diplomacy

# --- Nodes ---
var main_panel: PanelContainer
var content_area: VBoxContainer
var tab_buttons_container: HBoxContainer
var toggle_tab_btn: Button

var is_menu_collapsed: bool = false
var selected_div_type: String = "infantry"
var training_amount: int = 1

func _ready() -> void:
	set_as_top_level(true) # Bypass BottomHUD parent positioning
	
	# Connect to viewport resizing to span full screen height
	get_viewport().size_changed.connect(_on_viewport_resized)
	
	# Listen for player country being initialized or changed
	CountryManager.player_country_changed.connect(_on_player_country_changed)
	
	_build_ui()
	_on_viewport_resized()
	
	if CountryManager.player_country:
		_on_player_country_changed()


func _on_player_country_changed() -> void:
	var new_country = CountryManager.player_country
	if player_country and player_country.process_day_complete.is_connected(_refresh_ui):
		player_country.process_day_complete.disconnect(_refresh_ui)
		
	player_country = new_country
	target_country = GameState.chosen_diplomacy_country
	
	if player_country:
		player_country.process_day_complete.connect(_refresh_ui)
		
	_switch_tab(current_tab)

func _on_viewport_resized() -> void:
	var screen_size = get_viewport().get_visible_rect().size
	main_panel.custom_minimum_size = Vector2(400, screen_size.y - 45)
	if is_menu_collapsed:
		main_panel.position = Vector2(-380, 45)
	else:
		main_panel.position = Vector2(0, 45)

func _build_ui() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Main Left Panel Container
	main_panel = PanelContainer.new()
	main_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var style = StyleBoxFlat.new()
	style.bg_color = COLOR_BG
	style.border_width_right = 2
	style.border_color = COLOR_ACCENT
	style.set_corner_radius_all(0)
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.shadow_size = 8
	style.shadow_color = Color(0, 0, 0, 0.4)
	main_panel.add_theme_stylebox_override("panel", style)
	add_child(main_panel)
	
	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 0)
	main_panel.add_child(main_vbox)
	
	# Header Row (Title and Collapse Tab)
	var header_margin = MarginContainer.new()
	header_margin.add_theme_constant_override("margin_left", 15)
	header_margin.add_theme_constant_override("margin_top", 10)
	header_margin.add_theme_constant_override("margin_right", 15)
	header_margin.add_theme_constant_override("margin_bottom", 10)
	main_vbox.add_child(header_margin)
	
	var header_hbox = HBoxContainer.new()
	header_margin.add_child(header_hbox)
	
	var title_lbl = Label.new()
	title_lbl.text = "DOMESTIC COMMAND"
	title_lbl.add_theme_font_size_override("font_size", 14)
	title_lbl.add_theme_color_override("font_color", COLOR_TEXT_WHITE)
	header_hbox.add_child(title_lbl)
	
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(spacer)
	
	# Collapse Button (Sits at edge)
	toggle_tab_btn = Button.new()
	toggle_tab_btn.text = "◀"
	toggle_tab_btn.add_theme_font_size_override("font_size", 13)
	var tab_style = StyleBoxFlat.new()
	tab_style.bg_color = COLOR_ACCENT
	tab_style.set_corner_radius_all(0)
	toggle_tab_btn.add_theme_stylebox_override("normal", tab_style)
	toggle_tab_btn.add_theme_stylebox_override("hover", tab_style)
	toggle_tab_btn.add_theme_color_override("font_color", Color.BLACK)
	toggle_tab_btn.pressed.connect(_toggle_collapse)
	header_hbox.add_child(toggle_tab_btn)
	
	# Tab Selection Row (HBox)
	var tabs_margin = MarginContainer.new()
	tabs_margin.add_theme_constant_override("margin_left", 10)
	tabs_margin.add_theme_constant_override("margin_right", 10)
	tabs_margin.add_theme_constant_override("margin_bottom", 10)
	main_vbox.add_child(tabs_margin)
	
	tab_buttons_container = HBoxContainer.new()
	tab_buttons_container.add_theme_constant_override("separation", 8)
	tabs_margin.add_child(tab_buttons_container)
	
	main_vbox.add_child(HSeparator.new())
	
	# Scroll Container for long content
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main_vbox.add_child(scroll)
	
	var content_margin = MarginContainer.new()
	content_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_margin.add_theme_constant_override("margin_left", 15)
	content_margin.add_theme_constant_override("margin_top", 15)
	content_margin.add_theme_constant_override("margin_right", 15)
	content_margin.add_theme_constant_override("margin_bottom", 15)
	scroll.add_child(content_margin)
	
	content_area = VBoxContainer.new()
	content_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_area.add_theme_constant_override("separation", 20)
	content_margin.add_child(content_area)
	
	_rebuild_tab_buttons()

func _rebuild_tab_buttons() -> void:
	for child in tab_buttons_container.get_children():
		child.queue_free()
		
	if target_country and target_country != player_country:
		_add_tab_button("🌐 DIP", 3)
		if current_tab != 3:
			current_tab = 3
	else:
		if current_tab == 3:
			current_tab = 0
		_add_tab_button("🔨 PROD", 0)
		_add_tab_button("⚖️ LAWS", 1)
		_add_tab_button("💼 GENS", 2)

func _add_tab_button(label: String, tab_id: int) -> void:
	var btn = Button.new()
	btn.text = label
	btn.custom_minimum_size = Vector2(80, 36)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var style = StyleBoxFlat.new()
	style.bg_color = COLOR_PANEL_INNER if current_tab == tab_id else Color(0.12, 0.14, 0.18, 0.3)
	style.border_width_bottom = 3 if current_tab == tab_id else 0
	style.border_color = COLOR_ACCENT
	style.set_corner_radius_all(0)
	
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", style)
	btn.add_theme_color_override("font_color", COLOR_TEXT_WHITE)
	btn.add_theme_font_size_override("font_size", 11)
	
	btn.pressed.connect(func(): _switch_tab(tab_id))
	tab_buttons_container.add_child(btn)

func _switch_tab(tab_id: int) -> void:
	current_tab = tab_id
	_rebuild_tab_buttons()
	
	# Clear placement indicators
	GameState.industry_building = GameState.IndustryType.DEFAULT
	GameState.choosing_deploy_city = false
	
	if current_tab == 0:
		MapManager.show_industry_country(player_country.country_name)
	else:
		MapManager.show_countries_map()
		
	_refresh_ui()


func open_and_switch_to_tab(tab_id: int, new_target_country: CountryData = null) -> void:
	target_country = new_target_country
	current_tab = tab_id
	if is_menu_collapsed:
		_toggle_collapse()
	else:
		_switch_tab(tab_id)

func _refresh_ui() -> void:
	for child in content_area.get_children():
		child.queue_free()
		
	match current_tab:
		0: _draw_production_tab()
		1: _draw_politics_tab()
		2: _draw_generals_tab()
		3: _draw_diplomacy_tab()

func _toggle_collapse() -> void:
	is_menu_collapsed = !is_menu_collapsed
	toggle_tab_btn.text = "▶" if is_menu_collapsed else "◀"
	
	if is_menu_collapsed:
		MapManager.show_countries_map()
	else:
		if current_tab == 0 and player_country:
			MapManager.show_industry_country(player_country.country_name)
	
	var target_x = -380 if is_menu_collapsed else 0
	var tween = create_tween()
	tween.tween_property(main_panel, "position:x", target_x, 0.3).set_trans(Tween.TRANS_SINE)

func _apply_large_btn_style(btn: Button, border_color: Color) -> void:
	var s = StyleBoxFlat.new()
	s.bg_color = COLOR_PANEL_INNER
	s.border_width_bottom = 3
	s.border_color = border_color
	s.set_corner_radius_all(0)
	btn.add_theme_stylebox_override("normal", s)
	btn.add_theme_stylebox_override("hover", s)
	btn.add_theme_color_override("font_color", COLOR_TEXT_WHITE)
	btn.add_theme_font_size_override("font_size", 12)
	btn.custom_minimum_size = Vector2(170, 44) # Big, easy click

# --- Tab 0: Production (Build, Train, and Trade) ---
func _draw_production_tab() -> void:
	# A. Infrastructure header & buttons
	_add_header("🏭 INFRASTRUCTURE BUILDER")
	
	var infra_hbox = HBoxContainer.new()
	infra_hbox.add_theme_constant_override("separation", 15)
	content_area.add_child(infra_hbox)
	
	var build_fact = Button.new()
	build_fact.text = "🔨 FACTORY ($500)"
	_apply_large_btn_style(build_fact, COLOR_ACCENT)
	build_fact.pressed.connect(func():
		GameState.industry_building = GameState.IndustryType.FACTORY
		_update_status("FACTORY (Heavy Industry)")
	)
	infra_hbox.add_child(build_fact)
	
	var build_port = Button.new()
	build_port.text = "⚓ NAVAL PORT ($500)"
	_apply_large_btn_style(build_port, COLOR_ACCENT)
	build_port.pressed.connect(func():
		GameState.industry_building = GameState.IndustryType.PORT
		_update_status("PORT (Maritime Extraction)")
	)
	infra_hbox.add_child(build_port)
	
	# B. Army training header & controls
	_add_header("⚔️ MILITARY COMMAND")
	
	var army_card = PanelContainer.new()
	var army_style = StyleBoxFlat.new()
	army_style.bg_color = COLOR_PANEL_INNER
	army_style.set_corner_radius_all(0)
	army_card.add_theme_stylebox_override("panel", army_style)
	
	var army_margin = MarginContainer.new()
	army_margin.add_theme_constant_override("margin_all", 10)
	army_card.add_child(army_margin)
	
	var army_vbox = VBoxContainer.new()
	army_vbox.add_theme_constant_override("separation", 8)
	army_margin.add_child(army_vbox)
	
	var opt = OptionButton.new()
	opt.add_item("🏃 Infantry Division", 0)
	opt.add_item("🚜 Tank Division", 1)
	opt.add_item("💥 Artillery Division", 2)
	opt.custom_minimum_size = Vector2(0, 36)
	
	match selected_div_type:
		"infantry": opt.selected = 0
		"tank": opt.selected = 1
		"artillery": opt.selected = 2
		
	var update_opt_tooltip = func():
		var temp = DivisionData.TEMPLATES.get(selected_div_type, {})
		opt.tooltip_text = "%s Stats:\n- Manpower cost: %s men\n- Treasury cost: $%s\n- Steel needed: %d tonnes\n- Oil needed: %d barrels\n- Training time: %d days" % [
			selected_div_type.capitalize(),
			GameState.format_number(temp.get("manpower", 1000)),
			GameState.format_number(temp.get("cost", 100)),
			temp.get("steel", 0),
			temp.get("oil", 0),
			temp.get("days", 10)
		]
	update_opt_tooltip.call()
	
	opt.item_selected.connect(func(idx):
		match idx:
			0: selected_div_type = "infantry"
			1: selected_div_type = "tank"
			2: selected_div_type = "artillery"
		update_opt_tooltip.call()
	)
	army_vbox.add_child(opt)
	
	var qty_hbox = HBoxContainer.new()
	qty_hbox.add_theme_constant_override("separation", 15)
	qty_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	army_vbox.add_child(qty_hbox)
	
	var minus = Button.new()
	minus.text = " - "
	minus.custom_minimum_size = Vector2(30, 30)
	minus.pressed.connect(func():
		training_amount = max(1, training_amount - 1)
		_refresh_ui()
	)
	qty_hbox.add_child(minus)
	
	var qty_lbl = Label.new()
	qty_lbl.text = "Batch Size: %d" % training_amount
	qty_lbl.add_theme_color_override("font_color", COLOR_TEXT_WHITE)
	qty_lbl.add_theme_font_size_override("font_size", 12)
	qty_hbox.add_child(qty_lbl)
	
	var plus = Button.new()
	plus.text = " + "
	plus.custom_minimum_size = Vector2(30, 30)
	plus.pressed.connect(func():
		training_amount = min(10, training_amount + 1)
		_refresh_ui()
	)
	qty_hbox.add_child(plus)
	
	var train_btn = Button.new()
	train_btn.text = "⚡ TRAIN DIVISION FORMATION"
	_apply_large_btn_style(train_btn, COLOR_SUCCESS)
	train_btn.pressed.connect(_train_troops)
	army_vbox.add_child(train_btn)
	
	# B. Ongoing Training Queue
	var ongoing = player_country.ongoing_training
	if not ongoing.is_empty():
		var queue_lbl = Label.new()
		queue_lbl.text = "⏳ TRAINING IN PROGRESS"
		queue_lbl.add_theme_font_size_override("font_size", 10)
		queue_lbl.add_theme_color_override("font_color", COLOR_ACCENT)
		army_vbox.add_child(queue_lbl)
		
		for t_idx in range(ongoing.size()):
			var batch = ongoing[t_idx]
			var temp = DivisionData.TEMPLATES.get(batch.division_type, {})
			var total_days = temp.get("days", 10.0)
			
			var batch_hbox = HBoxContainer.new()
			army_vbox.add_child(batch_hbox)
			
			var name_lbl = Label.new()
			name_lbl.text = "%s (%d x)" % [batch.division_type.capitalize(), batch.divisions_count]
			name_lbl.add_theme_font_size_override("font_size", 11)
			name_lbl.add_theme_color_override("font_color", COLOR_TEXT_WHITE)
			batch_hbox.add_child(name_lbl)
			
			var space = Control.new()
			space.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			batch_hbox.add_child(space)
			
			var days_lbl = Label.new()
			days_lbl.text = "%.1fd left" % batch.days_left
			days_lbl.add_theme_font_size_override("font_size", 10)
			days_lbl.add_theme_color_override("font_color", Color(0.7,0.7,0.7))
			batch_hbox.add_child(days_lbl)
			
			var pbar = ProgressBar.new()
			pbar.min_value = 0
			pbar.max_value = total_days
			pbar.value = total_days - batch.days_left
			pbar.show_percentage = false
			pbar.custom_minimum_size.y = 4
			
			var pbar_style = StyleBoxFlat.new()
			pbar_style.bg_color = COLOR_SUCCESS
			pbar_style.set_corner_radius_all(0)
			pbar.add_theme_stylebox_override("fill", pbar_style)
			army_vbox.add_child(pbar)
			
	content_area.add_child(army_card)
	
	# C. Market / Trade Header
	_add_header("📊 GLOBAL RAW MATERIALS MARKET")
	
	var market_grid = GridContainer.new()
	market_grid.columns = 2
	market_grid.add_theme_constant_override("h_separation", 10)
	market_grid.add_theme_constant_override("v_separation", 10)
	content_area.add_child(market_grid)
	
	market_grid.add_child(_build_market_item("Steel (⛓️)", CountryManager.market_steel_price, "steel"))
	market_grid.add_child(_build_market_item("Crude Oil (🛢️)", CountryManager.market_oil_price, "oil"))
	
	# D. Deployment Depot
	_add_header("🚩 DEPLOYMENT DEPOT")
	
	var ready_size = player_country.ready_troops.size()
	if ready_size > 0:
		var troop = player_country.ready_troops[0]
		var count = troop.stored_divisions.size()
		var type = troop.stored_divisions[0].type.capitalize()
		
		var ready_lbl = Label.new()
		ready_lbl.text = "Ready to deploy: %d %s divisions" % [count, type]
		ready_lbl.add_theme_font_size_override("font_size", 11)
		ready_lbl.add_theme_color_override("font_color", COLOR_SUCCESS)
		content_area.add_child(ready_lbl)
		
		var prov_lbl = Label.new()
		if player_country.deploy_pid != -1:
			var prov = MapManager.province_objects.get(player_country.deploy_pid)
			if prov and prov.country == player_country.country_name:
				prov_lbl.text = "Selected target: " + (prov.city.capitalize() if prov.city != "" else ("Province " + str(prov.id)))
				prov_lbl.add_theme_color_override("font_color", COLOR_ACCENT)
			else:
				prov_lbl.text = "Target: Random province (default)"
				prov_lbl.add_theme_color_override("font_color", Color(0.6,0.6,0.6))
		else:
			prov_lbl.text = "Target: Random province (default)"
			prov_lbl.add_theme_color_override("font_color", Color(0.6,0.6,0.6))
		prov_lbl.add_theme_font_size_override("font_size", 10)
		content_area.add_child(prov_lbl)
		
		var deploy_btn_hbox = HBoxContainer.new()
		deploy_btn_hbox.add_theme_constant_override("separation", 10)
		content_area.add_child(deploy_btn_hbox)
		
		var sel_btn = Button.new()
		sel_btn.text = "📍 SELECT PROVINCE"
		_apply_large_btn_style(sel_btn, COLOR_ACCENT)
		sel_btn.pressed.connect(func():
			GameState.choosing_deploy_city = true
			prov_lbl.text = "📍 Tap any owned province on the map..."
			prov_lbl.add_theme_color_override("font_color", Color.YELLOW)
		)
		deploy_btn_hbox.add_child(sel_btn)
		
		var dep_btn = Button.new()
		dep_btn.text = "🚩 DEPLOY BATCH"
		_apply_large_btn_style(dep_btn, COLOR_SUCCESS)
		dep_btn.pressed.connect(func():
			player_country.deploy_ready_troop(troop, player_country.deploy_pid)
			player_country.deploy_pid = -1
			_refresh_ui()
		)
		deploy_btn_hbox.add_child(dep_btn)
	else:
		var empty = Label.new()
		empty.text = "No finished units waiting to deploy."
		empty.add_theme_font_size_override("font_size", 11)
		empty.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		content_area.add_child(empty)

	# Active trade agreements list
	var deals = player_country.trade_deals
	if not deals.is_empty():
		_add_header("📈 ACTIVE DEALS")
		for deal_id in deals:
			var deal = deals[deal_id]
			var is_sender = (deal.sender == player_country.country_name.to_lower())
			var other = deal.recipient if is_sender else deal.sender
			
			var card = PanelContainer.new()
			card.add_theme_stylebox_override("panel", army_style)
			var margin = MarginContainer.new()
			margin.add_theme_constant_override("margin_all", 8)
			card.add_child(margin)
			
			var hbox = HBoxContainer.new()
			margin.add_child(hbox)
			
			var desc = Label.new()
			desc.text = "%s %.1f %s/d (%s$%d)" % [("Export" if is_sender else "Import"), deal.amount, deal.resource, ("+" if is_sender else "-"), deal.price]
			desc.add_theme_color_override("font_color", COLOR_SUCCESS if is_sender else COLOR_ALERT)
			desc.add_theme_font_size_override("font_size", 10)
			hbox.add_child(desc)
			
			var sp = Control.new()
			sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			hbox.add_child(sp)
			
			var cancel = Button.new()
			cancel.text = "×"
			cancel.custom_minimum_size = Vector2(25, 25)
			cancel.pressed.connect(func():
				CountryManager.cancel_trade_deal(player_country, deal.id)
				_refresh_ui()
				if GameState.game_ui:
					GameState.game_ui.update_topbar_stats()
			)
			hbox.add_child(cancel)
			content_area.add_child(card)

	# Build placement indicator
	var build_status = Label.new()
	build_status.name = "BuildStatusLabel"
	build_status.text = ""
	build_status.add_theme_font_size_override("font_size", 10)
	build_status.add_theme_color_override("font_color", Color.YELLOW)
	content_area.add_child(build_status)

func _update_status(type: String) -> void:
	var status = content_area.get_node_or_null("BuildStatusLabel")
	if status:
		status.text = "🔨 PLACING: Tap owned province on the map to build %s." % type

func _build_market_item(label: String, price: float, key: String) -> PanelContainer:
	var card = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = COLOR_PANEL_INNER
	style.set_corner_radius_all(0)
	card.add_theme_stylebox_override("panel", style)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_all", 8)
	card.add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)
	
	var title = Label.new()
	title.text = "%s ($%d)" % [label, round(price)]
	title.add_theme_font_size_override("font_size", 11)
	title.add_theme_color_override("font_color", COLOR_TEXT_WHITE)
	vbox.add_child(title)
	
	var btn_hbox = HBoxContainer.new()
	btn_hbox.add_theme_constant_override("separation", 10)
	vbox.add_child(btn_hbox)
	
	var buy = Button.new()
	buy.text = "BUY 5"
	_apply_large_btn_style(buy, COLOR_ACCENT)
	buy.custom_minimum_size = Vector2(70, 28)
	buy.pressed.connect(func(): _transaction(key, true, 5.0))
	btn_hbox.add_child(buy)
	
	var sell = Button.new()
	sell.text = "SELL 5"
	_apply_large_btn_style(sell, COLOR_ALERT)
	sell.custom_minimum_size = Vector2(70, 28)
	sell.pressed.connect(func(): _transaction(key, false, 5.0))
	btn_hbox.add_child(sell)
	
	# Recurring Flow Adjustment Row
	var rec_flow = player_country.recurring_steel_buy if key == "steel" else player_country.recurring_oil_buy
	var rec_hbox = HBoxContainer.new()
	rec_hbox.add_theme_constant_override("separation", 8)
	rec_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(rec_hbox)
	
	var sub_lbl = Label.new()
	sub_lbl.text = "Sub: %s%.1f/d" % [("+" if rec_flow >= 0 else ""), rec_flow]
	sub_lbl.add_theme_font_size_override("font_size", 10)
	sub_lbl.add_theme_color_override("font_color", COLOR_SUCCESS if rec_flow > 0 else (COLOR_ALERT if rec_flow < 0 else COLOR_TEXT_WHITE))
	rec_hbox.add_child(sub_lbl)
	
	var rec_minus = Button.new()
	rec_minus.text = "-1"
	rec_minus.custom_minimum_size = Vector2(30, 24)
	rec_minus.pressed.connect(func():
		if key == "steel":
			player_country.recurring_steel_buy -= 1.0
		else:
			player_country.recurring_oil_buy -= 1.0
		_refresh_ui()
		if GameState.game_ui:
			GameState.game_ui.update_topbar_stats()
	)
	rec_hbox.add_child(rec_minus)
	
	var rec_plus = Button.new()
	rec_plus.text = "+1"
	rec_plus.custom_minimum_size = Vector2(30, 24)
	rec_plus.pressed.connect(func():
		if key == "steel":
			player_country.recurring_steel_buy += 1.0
		else:
			player_country.recurring_oil_buy += 1.0
		_refresh_ui()
		if GameState.game_ui:
			GameState.game_ui.update_topbar_stats()
	)
	rec_hbox.add_child(rec_plus)
	
	return card

# --- Tab 1: Politics & Laws ---
func _draw_politics_tab() -> void:
	_add_header("⚖️ CONSERVED MILITARY DRAFT LAWS")
	
	# Current active settings
	var status = Label.new()
	status.text = "Current Draft Ratio: %.1f%%\nIncome Modifier Penalty: -%.0f%%" % [player_country.military_size_ratio * 100.0, player_country.economy_law_penalty * 100.0]
	status.add_theme_font_size_override("font_size", 11)
	status.add_theme_color_override("font_color", COLOR_TEXT_WHITE)
	content_area.add_child(status)
	
	# 3 basic simplified laws
	_add_law_row("Volunteer Only", 0.005, 0.0, 0)
	_add_law_row("Limited Draft", 0.015, 0.15, 150)
	_add_law_row("Total Draft", 0.04, 0.50, 150)
	
	_add_header("📢 CABINET DECISIONS")
	
	_add_decision_row("Stability Campaign", 50, "Boost stability relations +15%", func():
		player_country.stability = min(1.0, player_country.stability + 0.15)
	)
	
	_add_decision_row("War Support Rally", 50, "Boost support +15%", func():
		player_country.war_support = min(1.0, player_country.war_support + 0.15)
	)
	
	_add_decision_row("Industrial Effort", 100, "+1 Factory ($5K cost)", func():
		if player_country.money >= 5000:
			player_country.money -= 5000
			player_country.factories_amount += 1
			player_country.factories_available += 1
	)

func _add_law_row(law_name: String, ratio: float, penalty: float, cost: int) -> void:
	var card = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = COLOR_PANEL_INNER
	style.set_corner_radius_all(0)
	card.add_theme_stylebox_override("panel", style)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_all", 8)
	card.add_child(margin)
	
	var hbox = HBoxContainer.new()
	margin.add_child(hbox)
	
	var lbl = Label.new()
	var active = is_equal_approx(player_country.military_size_ratio, ratio)
	lbl.text = law_name + (" (Active)" if active else " (%d PP)" % cost)
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", COLOR_SUCCESS if active else COLOR_TEXT_WHITE)
	hbox.add_child(lbl)
	
	var sp = Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(sp)
	
	var apply = Button.new()
	apply.text = "SELECT"
	apply.disabled = active or player_country.political_power < cost
	_apply_large_btn_style(apply, COLOR_ACCENT)
	apply.custom_minimum_size = Vector2(80, 26)
	apply.pressed.connect(func():
		player_country.political_power -= cost
		player_country.military_size_ratio = ratio
		player_country.economy_law_penalty = penalty
		player_country.update_manpower_pool()
		_refresh_ui()
		if is_instance_valid(MusicManager):
			MusicManager.play_sfx(MusicManager.SFX.TROOP_SELECTED)
	)
	hbox.add_child(apply)
	content_area.add_child(card)

func _add_decision_row(dec_name: String, cost: int, desc: String, exec: Callable) -> void:
	var card = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = COLOR_PANEL_INNER
	style.set_corner_radius_all(0)
	card.add_theme_stylebox_override("panel", style)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_all", 8)
	card.add_child(margin)
	
	var hbox = HBoxContainer.new()
	margin.add_child(hbox)
	
	var vbox = VBoxContainer.new()
	hbox.add_child(vbox)
	
	var name_lbl = Label.new()
	name_lbl.text = dec_name + " (%d PP)" % cost
	name_lbl.add_theme_font_size_override("font_size", 11)
	name_lbl.add_theme_color_override("font_color", COLOR_TEXT_WHITE)
	vbox.add_child(name_lbl)
	
	var desc_lbl = Label.new()
	desc_lbl.text = desc
	desc_lbl.add_theme_font_size_override("font_size", 9)
	desc_lbl.add_theme_color_override("font_color", Color(0.65,0.65,0.65))
	vbox.add_child(desc_lbl)
	
	var sp = Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(sp)
	
	var run_btn = Button.new()
	run_btn.text = "ACTIVATE"
	run_btn.disabled = player_country.political_power < cost
	_apply_large_btn_style(run_btn, COLOR_SUCCESS)
	run_btn.custom_minimum_size = Vector2(80, 30)
	run_btn.pressed.connect(func():
		player_country.political_power -= cost
		exec.call()
		_refresh_ui()
		if is_instance_valid(MusicManager):
			MusicManager.play_sfx(MusicManager.SFX.UPGRADE)
	)
	hbox.add_child(run_btn)
	content_area.add_child(card)

# --- Tab 2: Generals Management ---
func _draw_generals_tab() -> void:
	var top = HBoxContainer.new()
	content_area.add_child(top)
	
	var pp = Label.new()
	pp.text = "Political Power: %.1f PP" % player_country.political_power
	pp.add_theme_font_size_override("font_size", 11)
	pp.add_theme_color_override("font_color", COLOR_TEXT_WHITE)
	top.add_child(pp)
	
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	
	var rec_btn = Button.new()
	rec_btn.text = "+ HIRE GENERAL (50 PP)"
	rec_btn.disabled = player_country.political_power < 50.0
	_apply_large_btn_style(rec_btn, COLOR_ACCENT)
	rec_btn.custom_minimum_size = Vector2(160, 32)
	rec_btn.pressed.connect(func():
		player_country.political_power -= 50.0
		player_country.generate_general()
		_refresh_ui()
	)
	top.add_child(rec_btn)
	
	# Generals list
	for gen in player_country.generals:
		var card = PanelContainer.new()
		var style = StyleBoxFlat.new()
		style.bg_color = COLOR_PANEL_INNER
		style.set_corner_radius_all(0)
		card.add_theme_stylebox_override("panel", style)
		
		var margin = MarginContainer.new()
		margin.add_theme_constant_override("margin_all", 10)
		card.add_child(margin)
		
		var vbox = VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 4)
		margin.add_child(vbox)
		
		var name_lbl = Label.new()
		name_lbl.text = "%s (Lvl %d)" % [gen.name, gen.level]
		name_lbl.add_theme_font_size_override("font_size", 12)
		name_lbl.add_theme_color_override("font_color", COLOR_TEXT_WHITE)
		vbox.add_child(name_lbl)
		
		var stats = Label.new()
		stats.text = "⚔️ Atk: +%d0%% | 🛡️ Def: +%d0%% | 📦 Log: -%d%%" % [gen.attack, gen.defense, gen.logistics * 5]
		stats.add_theme_font_size_override("font_size", 10)
		stats.add_theme_color_override("font_color", COLOR_ACCENT)
		vbox.add_child(stats)
		
		var act_hbox = HBoxContainer.new()
		vbox.add_child(act_hbox)
		
		if gen.assigned_troop_id != "":
			var troop = instance_from_id(int(gen.assigned_troop_id))
			var loc = "Unknown"
			if is_instance_valid(troop) and is_instance_valid(MapManager):
				var prov = MapManager.province_objects.get(troop.province_id)
				loc = prov.city if (prov and prov.city != "") else ("Prov " + str(troop.province_id))
				
			var loc_lbl = Label.new()
			loc_lbl.text = "Commanding at: " + loc
			loc_lbl.add_theme_font_size_override("font_size", 10)
			loc_lbl.add_theme_color_override("font_color", COLOR_SUCCESS)
			act_hbox.add_child(loc_lbl)
			
			var unsp = Control.new()
			unsp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			act_hbox.add_child(unsp)
			
			var dismiss = Button.new()
			dismiss.text = "Dismiss"
			_apply_large_btn_style(dismiss, COLOR_ALERT)
			dismiss.custom_minimum_size = Vector2(80, 26)
			dismiss.pressed.connect(func():
				player_country.unassign_general(gen.id)
				_refresh_ui()
			)
			act_hbox.add_child(dismiss)
		else:
			var opt = OptionButton.new()
			opt.add_item("Select Troop Stack...", 0)
			opt.custom_minimum_size = Vector2(160, 26)
			
			var troops = TroopManager.get_troops_for_country(player_country.country_name)
			for t in troops:
				var prov = MapManager.province_objects.get(t.province_id)
				var loc = prov.city if (prov and prov.city != "") else ("Prov " + str(t.province_id))
				opt.add_item("Troop at %s (%d Divs)" % [loc, t.divisions_count], t.get_instance_id())
			act_hbox.add_child(opt)
			
			var assign = Button.new()
			assign.text = "Assign"
			assign.disabled = true
			_apply_large_btn_style(assign, COLOR_ACCENT)
			assign.custom_minimum_size = Vector2(80, 26)
			
			opt.item_selected.connect(func(idx):
				assign.disabled = (idx == 0)
			)
			assign.pressed.connect(func():
				var sel_id = opt.get_item_id(opt.selected)
				var troop = instance_from_id(sel_id) as TroopData
				if is_instance_valid(troop):
					player_country.assign_general(gen.id, troop)
				_refresh_ui()
			)
			act_hbox.add_child(assign)
			
		content_area.add_child(card)

# --- Tab 3: Foreign Diplomacy ---
func _draw_diplomacy_tab() -> void:
	if not target_country:
		return
		
	var title = Label.new()
	title.text = target_country.country_name.capitalize() + " Relations"
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", COLOR_TEXT_WHITE)
	content_area.add_child(title)
	
	var rel = player_country.get_relation_with(target_country.country_name)
	var progress = ProgressBar.new()
	progress.min_value = 0
	progress.max_value = 100
	progress.value = rel
	progress.show_percentage = false
	progress.custom_minimum_size.y = 8
	var fill = StyleBoxFlat.new()
	fill.bg_color = COLOR_SUCCESS if rel > 50 else (COLOR_ALERT if rel < 30 else COLOR_ACCENT)
	fill.set_corner_radius_all(0)
	progress.add_theme_stylebox_override("fill", fill)
	content_area.add_child(progress)
	
	var apply_actions_btn = func(btn: Button, border: Color, call: Callable):
		_apply_large_btn_style(btn, border)
		btn.custom_minimum_size = Vector2(0, 40)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(call)
		content_area.add_child(btn)
		
	# Propose Peace Pact
	var nap_active = player_country.relations.get(target_country.country_name.to_lower() + "_nap", false)
	var pact_btn = Button.new()
	pact_btn.text = "Pact Signed (Borders Secured)" if nap_active else "Sign Non-Aggression Pact (50 PP)"
	pact_btn.disabled = nap_active or rel < 50 or player_country.political_power < 50.0
	apply_actions_btn.call(pact_btn, COLOR_ACCENT, func():
		player_country.political_power -= 50.0
		CountryManager.send_diplomatic_message(
			player_country.country_name,
			target_country.country_name,
			"NON_AGGRESSION",
			"Peace Pact Proposed",
			"The player country proposes a Non-Aggression pact to secure borders.",
			{}
		)
		_refresh_ui()
	)
	
	# Send aid gift
	var gift_btn = Button.new()
	gift_btn.text = "Send Financial Aid Gift ($5,000)"
	gift_btn.disabled = player_country.money < 5000.0
	apply_actions_btn.call(gift_btn, COLOR_SUCCESS, func():
		player_country.money -= 5000.0
		CountryManager.send_diplomatic_message(
			player_country.country_name,
			target_country.country_name,
			"GIFT",
			"Foreign Aid Received",
			"Sender country has gifted us $5,000.",
			{"gift_type": "money", "gift_amount": 5000.0}
		)
		_refresh_ui()
	)

	# Spying action
	var spy_btn = Button.new()
	spy_btn.text = "🕵️ SPY ON MILITARY (25 PP)"
	spy_btn.disabled = player_country.political_power < 25.0
	apply_actions_btn.call(spy_btn, COLOR_ACCENT, func():
		player_country.political_power -= 25.0
		if is_instance_valid(MusicManager):
			MusicManager.play_sfx(MusicManager.SFX.UPGRADE)
			
		var divisions_count = 0
		var target_troops = TroopManager.get_troops_for_country(target_country.country_name)
		for t in target_troops:
			divisions_count += t.divisions_count
			
		var report = "🕵️ REPORT: Divs: %d | Money: $%s | Stab: %d%% | War: %d%%" % [
			divisions_count, 
			GameState.format_number(target_country.money), 
			round(target_country.stability * 100), 
			round(target_country.war_support * 100)
		]
		
		PopupManager.show_alert("alert", player_country, target_country, report)
		_refresh_ui()
	)
	
	# Declare War action
	var war_active = target_country.country_name.to_lower() in WarManager.get_enemies_of(player_country.country_name.to_lower())
	var war_btn = Button.new()
	war_btn.text = "Already at War!" if war_active else "⚔️ DECLARE WAR NOW"
	war_btn.disabled = war_active
	apply_actions_btn.call(war_btn, COLOR_ALERT, func():
		WarManager.declare_war(player_country, target_country)
		if is_instance_valid(MusicManager):
			MusicManager.play_sfx(MusicManager.SFX.DECLARE_WAR)
		_refresh_ui()
	)

func _add_header(text: String) -> void:
	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", COLOR_ACCENT)
	content_area.add_child(lbl)


func _train_troops() -> void:
	var ok = player_country.train_troops(training_amount, selected_div_type)
	if ok:
		_refresh_ui()
		if is_instance_valid(MusicManager):
			MusicManager.play_sfx(MusicManager.SFX.UPGRADE)
	else:
		var stats = DivisionData.TEMPLATES[selected_div_type]
		var total_manpower = training_amount * stats["manpower"]
		var total_cost = training_amount * stats["cost"]
		var reason = "Insufficient resources!"
		if player_country.manpower < total_manpower:
			reason = "Not enough manpower! (Need %d)" % total_manpower
		elif player_country.money < total_cost:
			reason = "Not enough money! (Need $%d)" % total_cost
			
		PopupManager.show_alert("alert", player_country, player_country, reason)


func _transaction(resource: String, buy: bool, amount: float) -> void:
	var price = CountryManager.market_steel_price if resource == "steel" else CountryManager.market_oil_price
	if buy:
		var cost = price * amount
		if player_country.money >= cost:
			player_country.money -= cost
			if resource == "steel":
				player_country.steel += amount
				CountryManager.market_steel_price = clamp(CountryManager.market_steel_price + (0.04 * amount), 8.0, 70.0)
			else:
				player_country.oil += amount
				CountryManager.market_oil_price = clamp(CountryManager.market_oil_price + (0.05 * amount), 12.0, 95.0)
	else:
		var gain = price * amount * 0.8
		if resource == "steel" and player_country.steel >= amount:
			player_country.steel -= amount
			player_country.money += gain
			CountryManager.market_steel_price = clamp(CountryManager.market_steel_price - (0.03 * amount), 8.0, 70.0)
		elif resource == "oil" and player_country.oil >= amount:
			player_country.oil -= amount
			player_country.money += gain
			CountryManager.market_oil_price = clamp(CountryManager.market_oil_price - (0.04 * amount), 12.0, 95.0)
			
	if is_instance_valid(MusicManager):
		MusicManager.play_sfx(MusicManager.SFX.UPGRADE)
	_refresh_ui()
	if GameState.game_ui:
		GameState.game_ui.update_topbar_stats()


func _close_menu() -> void:
	MapManager.show_countries_map()
	GameState.industry_building = GameState.IndustryType.DEFAULT
	GameState.choosing_deploy_city = false
	if get_parent().has_method("_close_submenu"):
		get_parent()._close_submenu()
