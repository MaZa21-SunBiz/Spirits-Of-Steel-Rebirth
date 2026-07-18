extends Control

# --- Painted / Pixel Retro Board Game Theme ---
const COLOR_BG = Color(0.18, 0.16, 0.14, 0.98) # Warm hand-painted wood panel
const COLOR_PANEL_INNER = Color(0.11, 0.10, 0.09, 1.0) # Inset slate board
const COLOR_ACCENT = Color(0.72, 0.58, 0.38) # Burnished brass/gold border
const COLOR_TEXT_PAPER = Color(0.92, 0.88, 0.82) # Aged typewriter paper white
const COLOR_ALERT = Color(0.70, 0.25, 0.25)   # Rust red
const COLOR_SUCCESS = Color(0.35, 0.50, 0.30) # Olive drab military green

var custom_font = load("res://font/Google_Sans/GoogleSans-VariableFont_GRAD,opsz,wght.ttf")

enum Tab { MARKET, DIPLOMACY, AGREEMENTS, GENERALS }
var current_tab: Tab = Tab.MARKET

# --- Nodes ---
var main_panel: PanelContainer
var content_area: VBoxContainer
var tab_buttons_container: VBoxContainer

var target_country: CountryData = null
var player_country: CountryData = null

func _ready() -> void:
	player_country = CountryManager.player_country
	target_country = GameState.chosen_diplomacy_country
	
	if target_country and target_country != player_country:
		current_tab = Tab.DIPLOMACY
	else:
		current_tab = Tab.MARKET
		
	_build_ui()
	_switch_tab(current_tab)

func _build_ui() -> void:
	# Overlay dimmer background
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.6)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	
	# Main Centered Panel
	main_panel = PanelContainer.new()
	main_panel.custom_minimum_size = Vector2(820, 550)
	main_panel.set_anchors_preset(Control.PRESET_CENTER)
	main_panel.set_anchor_and_offset(SIDE_LEFT, 0.5, -410)
	main_panel.set_anchor_and_offset(SIDE_TOP, 0.5, -275)
	
	var style = StyleBoxFlat.new()
	style.bg_color = COLOR_BG
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.border_color = COLOR_ACCENT
	style.set_corner_radius_all(0) # Retro sharp corners
	style.shadow_size = 12
	style.shadow_color = Color(0, 0, 0, 0.6)
	main_panel.add_theme_stylebox_override("panel", style)
	add_child(main_panel)
	
	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 0)
	main_panel.add_child(main_vbox)
	
	# Header
	var header_margin = MarginContainer.new()
	header_margin.add_theme_constant_override("margin_left", 20)
	header_margin.add_theme_constant_override("margin_top", 10)
	header_margin.add_theme_constant_override("margin_right", 20)
	header_margin.add_theme_constant_override("margin_bottom", 10)
	main_vbox.add_child(header_margin)
	
	var header_hbox = HBoxContainer.new()
	header_margin.add_child(header_hbox)
	
	var title_lbl = Label.new()
	title_lbl.text = "WAR OFFICE & MARKET CONTROL"
	title_lbl.add_theme_font_size_override("font_size", 16)
	title_lbl.add_theme_color_override("font_color", COLOR_TEXT_PAPER)
	if custom_font:
		title_lbl.add_theme_font_override("font", custom_font)
	header_hbox.add_child(title_lbl)
	
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(spacer)
	
	var close_btn = Button.new()
	close_btn.text = " DISMISS "
	close_btn.custom_minimum_size = Vector2(90, 30)
	
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = COLOR_PANEL_INNER
	btn_style.border_width_bottom = 2
	btn_style.border_color = COLOR_ALERT
	btn_style.set_corner_radius_all(0)
	close_btn.add_theme_stylebox_override("normal", btn_style)
	close_btn.add_theme_stylebox_override("hover", btn_style)
	
	close_btn.pressed.connect(_close_menu)
	header_hbox.add_child(close_btn)
	
	var separator = HSeparator.new()
	main_vbox.add_child(separator)
	
	# Split View (Left Tab List, Right Content)
	var split_hbox = HBoxContainer.new()
	split_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(split_hbox)
	
	# Sidebar
	var sidebar_margin = MarginContainer.new()
	sidebar_margin.add_theme_constant_override("margin_left", 15)
	sidebar_margin.add_theme_constant_override("margin_top", 20)
	sidebar_margin.add_theme_constant_override("margin_right", 15)
	sidebar_margin.add_theme_constant_override("margin_bottom", 20)
	split_hbox.add_child(sidebar_margin)
	
	tab_buttons_container = VBoxContainer.new()
	tab_buttons_container.custom_minimum_size = Vector2(180, 0)
	tab_buttons_container.add_theme_constant_override("separation", 10)
	sidebar_margin.add_child(tab_buttons_container)
	
	# Tab Content Panel
	var content_margin = MarginContainer.new()
	content_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_margin.add_theme_constant_override("margin_left", 20)
	content_margin.add_theme_constant_override("margin_top", 20)
	content_margin.add_theme_constant_override("margin_right", 20)
	content_margin.add_theme_constant_override("margin_bottom", 20)
	split_hbox.add_child(content_margin)
	
	content_area = VBoxContainer.new()
	content_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_area.add_theme_constant_override("separation", 15)
	content_margin.add_child(content_area)
	
	_rebuild_tab_buttons()

func _rebuild_tab_buttons() -> void:
	for child in tab_buttons_container.get_children():
		child.queue_free()
		
	_add_tab_button("GLOBAL MARKET", Tab.MARKET, false)
	
	var disable_dip = (target_country == null or target_country == player_country)
	_add_tab_button("DIPLOMACY & TRADE", Tab.DIPLOMACY, disable_dip)
	
	_add_tab_button("ACTIVE DEALS", Tab.AGREEMENTS, false)
	_add_tab_button("COMMANDERS", Tab.GENERALS, false)

func _add_tab_button(label: String, tab: Tab, disabled: bool) -> void:
	var btn = Button.new()
	btn.text = label
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.custom_minimum_size = Vector2(0, 42)
	btn.disabled = disabled
	
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = COLOR_PANEL_INNER
	style_normal.border_width_left = 3
	style_normal.border_color = COLOR_ACCENT if current_tab == tab else COLOR_PANEL_INNER
	style_normal.set_corner_radius_all(0)
	
	var style_hover = style_normal.duplicate()
	style_hover.bg_color = Color(0.2, 0.18, 0.16, 0.9)
	
	btn.add_theme_stylebox_override("normal", style_normal)
	btn.add_theme_stylebox_override("hover", style_hover)
	btn.add_theme_stylebox_override("pressed", style_normal)
	btn.add_theme_color_override("font_color", COLOR_TEXT_PAPER)
	
	if custom_font:
		btn.add_theme_font_override("font", custom_font)
		
	btn.pressed.connect(func(): _switch_tab(tab))
	tab_buttons_container.add_child(btn)

func _switch_tab(tab: Tab) -> void:
	current_tab = tab
	_rebuild_tab_buttons()
	
	# Clear content area
	for child in content_area.get_children():
		child.queue_free()
		
	match current_tab:
		Tab.MARKET:
			_draw_market_tab()
		Tab.DIPLOMACY:
			_draw_diplomacy_tab()
		Tab.AGREEMENTS:
			_draw_agreements_tab()
		Tab.GENERALS:
			_draw_generals_tab()

# --- Tab 1: Global Market ---
func _draw_market_tab() -> void:
	var title = Label.new()
	title.text = "GLOBAL RAW MATERIALS MARKET"
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", COLOR_ACCENT)
	content_area.add_child(title)
	
	var inv_panel = PanelContainer.new()
	var inv_style = StyleBoxFlat.new()
	inv_style.bg_color = COLOR_PANEL_INNER
	inv_style.set_corner_radius_all(0)
	inv_style.border_width_left = 1
	inv_style.border_color = Color(0.25, 0.25, 0.25)
	inv_panel.add_theme_stylebox_override("panel", inv_style)
	
	var inv_margin = MarginContainer.new()
	inv_margin.add_theme_constant_override("margin_all", 10)
	inv_panel.add_child(inv_margin)
	
	var inv_hbox = HBoxContainer.new()
	inv_hbox.add_theme_constant_override("separation", 40)
	inv_margin.add_child(inv_hbox)
	
	var steel_stock = Label.new()
	steel_stock.text = "Domestic Steel Stock: %.1f units" % player_country.steel
	steel_stock.add_theme_color_override("font_color", COLOR_TEXT_PAPER)
	inv_hbox.add_child(steel_stock)
	
	var oil_stock = Label.new()
	oil_stock.text = "Domestic Oil Stock: %.1f units" % player_country.oil
	oil_stock.add_theme_color_override("font_color", COLOR_TEXT_PAPER)
	inv_hbox.add_child(oil_stock)
	content_area.add_child(inv_panel)
	
	var grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 20)
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_area.add_child(grid)
	
	# Steel Box
	var steel_card = _build_resource_card("STEEL", "⛓️", CountryManager.market_steel_price, func(buy: bool, amount: float):
		_transaction("steel", buy, amount)
	)
	grid.add_child(steel_card)
	
	# Oil Box
	var oil_card = _build_resource_card("CRUDE OIL", "🛢️", CountryManager.market_oil_price, func(buy: bool, amount: float):
		_transaction("oil", buy, amount)
	)
	grid.add_child(oil_card)

func _build_resource_card(res_name: String, icon: String, price: float, callback: Callable) -> PanelContainer:
	var card = PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	var card_style = StyleBoxFlat.new()
	card_style.bg_color = COLOR_PANEL_INNER
	card_style.set_corner_radius_all(0)
	card_style.border_width_left = 1
	card_style.border_width_top = 1
	card_style.border_width_right = 1
	card_style.border_width_bottom = 1
	card_style.border_color = COLOR_ACCENT
	card.add_theme_stylebox_override("panel", card_style)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_all", 15)
	card.add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)
	
	var title_hbox = HBoxContainer.new()
	var res_icon = Label.new()
	res_icon.text = icon
	res_icon.add_theme_font_size_override("font_size", 20)
	title_hbox.add_child(res_icon)
	
	var res_lbl = Label.new()
	res_lbl.text = " " + res_name
	res_lbl.add_theme_font_size_override("font_size", 14)
	res_lbl.add_theme_color_override("font_color", COLOR_TEXT_PAPER)
	title_hbox.add_child(res_lbl)
	vbox.add_child(title_hbox)
	
	var price_lbl = Label.new()
	price_lbl.text = "Market Price: $%d / unit" % round(price)
	price_lbl.add_theme_color_override("font_color", COLOR_ACCENT)
	price_lbl.add_theme_font_size_override("font_size", 13)
	vbox.add_child(price_lbl)
	
	vbox.add_child(HSeparator.new())
	
	# Action buttons with painted style
	var apply_custom_button_style = func(btn: Button):
		var b_style = StyleBoxFlat.new()
		b_style.bg_color = Color(0.18, 0.16, 0.14)
		b_style.border_width_bottom = 2
		b_style.border_color = COLOR_ACCENT
		b_style.set_corner_radius_all(0)
		btn.add_theme_stylebox_override("normal", b_style)
		btn.add_theme_stylebox_override("hover", b_style)
		btn.add_theme_color_override("font_color", COLOR_TEXT_PAPER)
		btn.custom_minimum_size = Vector2(100, 32)
	
	var buy_hbox = HBoxContainer.new()
	buy_hbox.add_theme_constant_override("separation", 10)
	
	var buy_5 = Button.new()
	buy_5.text = "Buy 5 ($%d)" % round(price * 5)
	buy_5.pressed.connect(func(): callback.call(true, 5.0))
	apply_custom_button_style.call(buy_5)
	buy_hbox.add_child(buy_5)
	
	var sell_5 = Button.new()
	sell_5.text = "Sell 5 ($%d)" % round(price * 5 * 0.8)
	sell_5.pressed.connect(func(): callback.call(false, 5.0))
	apply_custom_button_style.call(sell_5)
	buy_hbox.add_child(sell_5)
	vbox.add_child(buy_hbox)
	
	var buy_hbox_large = HBoxContainer.new()
	buy_hbox_large.add_theme_constant_override("separation", 10)
	
	var buy_20 = Button.new()
	buy_20.text = "Buy 20 ($%d)" % round(price * 20)
	buy_20.pressed.connect(func(): callback.call(true, 20.0))
	apply_custom_button_style.call(buy_20)
	buy_hbox_large.add_child(buy_20)
	
	var sell_20 = Button.new()
	sell_20.text = "Sell 20 ($%d)" % round(price * 20 * 0.8)
	sell_20.pressed.connect(func(): callback.call(false, 20.0))
	apply_custom_button_style.call(sell_20)
	buy_hbox_large.add_child(sell_20)
	vbox.add_child(buy_hbox_large)
	
	return card

func _transaction(resource: String, buy: bool, amount: float) -> void:
	var price_per_unit = CountryManager.market_steel_price if resource == "steel" else CountryManager.market_oil_price
	
	if buy:
		var total_cost = price_per_unit * amount
		if player_country.money >= total_cost:
			player_country.money -= total_cost
			if resource == "steel":
				player_country.steel += amount
				CountryManager.market_steel_price = clamp(CountryManager.market_steel_price + (0.04 * amount), 8.0, 70.0)
			else:
				player_country.oil += amount
				CountryManager.market_oil_price = clamp(CountryManager.market_oil_price + (0.05 * amount), 12.0, 95.0)
				
			if is_instance_valid(MusicManager):
				MusicManager.play_sfx(MusicManager.SFX.UPGRADE)
	else:
		var total_gain = price_per_unit * amount * 0.8
		if resource == "steel" and player_country.steel >= amount:
			player_country.steel -= amount
			player_country.money += total_gain
			CountryManager.market_steel_price = clamp(CountryManager.market_steel_price - (0.03 * amount), 8.0, 70.0)
		elif resource == "oil" and player_country.oil >= amount:
			player_country.oil -= amount
			player_country.money += total_gain
			CountryManager.market_oil_price = clamp(CountryManager.market_oil_price - (0.04 * amount), 12.0, 95.0)
			
		if is_instance_valid(MusicManager):
			MusicManager.play_sfx(MusicManager.SFX.UPGRADE)
			
	_switch_tab(Tab.MARKET)
	if GameState.game_ui:
		GameState.game_ui.update_topbar_stats()

# --- Tab 2: Diplomacy & Bilateral Trade ---
func _draw_diplomacy_tab() -> void:
	if target_country == null:
		return
		
	var header_hbox = HBoxContainer.new()
	header_hbox.add_theme_constant_override("separation", 10)
	
	var flag = TextureRect.new()
	flag.texture = TroopManager.get_flag(target_country.country_name)
	flag.custom_minimum_size = Vector2(40, 25)
	flag.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	header_hbox.add_child(flag)
	
	var name_lbl = Label.new()
	name_lbl.text = target_country.country_name.capitalize() + " Diplomacy"
	name_lbl.add_theme_font_size_override("font_size", 14)
	name_lbl.add_theme_color_override("font_color", COLOR_TEXT_PAPER)
	header_hbox.add_child(name_lbl)
	content_area.add_child(header_hbox)
	
	var rel = player_country.get_relation_with(target_country.country_name)
	
	var rel_panel = PanelContainer.new()
	var rel_style = StyleBoxFlat.new()
	rel_style.bg_color = COLOR_PANEL_INNER
	rel_style.set_corner_radius_all(0)
	rel_style.border_width_left = 1
	rel_style.border_color = Color(0.25, 0.25, 0.25)
	rel_panel.add_theme_stylebox_override("panel", rel_style)
	
	var rel_margin = MarginContainer.new()
	rel_margin.add_theme_constant_override("margin_all", 12)
	rel_panel.add_child(rel_margin)
	
	var rel_vbox = VBoxContainer.new()
	rel_vbox.add_theme_constant_override("separation", 5)
	rel_margin.add_child(rel_vbox)
	
	var rel_lbl = Label.new()
	rel_lbl.text = "Relations Status: %d / 100" % rel
	rel_lbl.add_theme_font_size_override("font_size", 12)
	rel_lbl.add_theme_color_override("font_color", COLOR_TEXT_PAPER)
	rel_vbox.add_child(rel_lbl)
	
	var progress = ProgressBar.new()
	progress.min_value = 0
	progress.max_value = 100
	progress.value = rel
	progress.custom_minimum_size.y = 12
	progress.show_percentage = false
	
	var fill = StyleBoxFlat.new()
	fill.bg_color = COLOR_SUCCESS if rel > 50 else (COLOR_ALERT if rel < 30 else COLOR_ACCENT)
	fill.set_corner_radius_all(0)
	progress.add_theme_stylebox_override("fill", fill)
	rel_vbox.add_child(progress)
	
	content_area.add_child(rel_panel)
	
	var actions_scroll = ScrollContainer.new()
	actions_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_area.add_child(actions_scroll)
	
	var actions_vbox = VBoxContainer.new()
	actions_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions_vbox.add_theme_constant_override("separation", 15)
	actions_scroll.add_child(actions_vbox)
	
	var apply_action_btn_style = func(btn: Button):
		var b_style = StyleBoxFlat.new()
		b_style.bg_color = Color(0.18, 0.16, 0.14)
		b_style.border_width_bottom = 2
		b_style.border_color = COLOR_ACCENT
		b_style.set_corner_radius_all(0)
		btn.add_theme_stylebox_override("normal", b_style)
		btn.add_theme_stylebox_override("hover", b_style)
		btn.add_theme_color_override("font_color", COLOR_TEXT_PAPER)
		btn.custom_minimum_size = Vector2(160, 36)
	
	# 1. Propose Non-Aggression Pact
	var nap_panel = PanelContainer.new()
	var nap_hbox = HBoxContainer.new()
	nap_hbox.add_theme_constant_override("separation", 15)
	nap_panel.add_theme_stylebox_override("panel", rel_style)
	
	var nap_margin = MarginContainer.new()
	nap_margin.add_theme_constant_override("margin_all", 10)
	nap_panel.add_child(nap_margin)
	nap_margin.add_child(nap_hbox)
	
	var nap_details = VBoxContainer.new()
	var nap_title = Label.new()
	nap_title.text = "Non-Aggression Pact"
	nap_title.add_theme_font_size_override("font_size", 13)
	nap_title.add_theme_color_override("font_color", COLOR_TEXT_PAPER)
	nap_details.add_child(nap_title)
	
	var nap_desc = Label.new()
	var nap_active = player_country.relations.get(target_country.country_name.to_lower() + "_nap", false)
	nap_desc.text = "Status: Pact is active." if nap_active else "Guarantees peace between nations. Requires relations > 50."
	nap_desc.add_theme_font_size_override("font_size", 11)
	nap_desc.add_theme_color_override("font_color", COLOR_ACCENT if nap_active else Color(0.7, 0.7, 0.7))
	nap_details.add_child(nap_desc)
	nap_hbox.add_child(nap_details)
	
	var nap_spacer = Control.new()
	nap_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nap_hbox.add_child(nap_spacer)
	
	var nap_btn = Button.new()
	nap_btn.text = "SIGNED" if nap_active else "PROPOSE (50 PP)"
	nap_btn.disabled = nap_active or rel < 50 or player_country.political_power < 50.0
	apply_action_btn_style.call(nap_btn)
	nap_btn.pressed.connect(func():
		player_country.political_power -= 50.0
		CountryManager.send_diplomatic_message(
			player_country.country_name,
			target_country.country_name,
			"NON_AGGRESSION",
			"Non-Aggression Pact Proposal",
			"The player country proposes a mutual pact to secure our borders and ensure peace.",
			{}
		)
		_switch_tab(Tab.DIPLOMACY)
	)
	nap_hbox.add_child(nap_btn)
	actions_vbox.add_child(nap_panel)
	
	# 2. Establish continuous trade deal
	var trade_panel = PanelContainer.new()
	trade_panel.add_theme_stylebox_override("panel", rel_style)
	var trade_margin = MarginContainer.new()
	trade_margin.add_theme_constant_override("margin_all", 10)
	trade_panel.add_child(trade_margin)
	
	var trade_vbox = VBoxContainer.new()
	trade_vbox.add_theme_constant_override("separation", 10)
	trade_margin.add_child(trade_vbox)
	
	var trade_title = Label.new()
	trade_title.text = "Establish Trade Agreement"
	trade_title.add_theme_font_size_override("font_size", 13)
	trade_title.add_theme_color_override("font_color", COLOR_TEXT_PAPER)
	trade_vbox.add_child(trade_title)
	
	var config_hbox = HBoxContainer.new()
	config_hbox.add_theme_constant_override("separation", 15)
	
	var resource_sel = OptionButton.new()
	resource_sel.add_item("Buy Steel", 0)
	resource_sel.add_item("Buy Oil", 1)
	config_hbox.add_child(resource_sel)
	
	var flow_sel = OptionButton.new()
	flow_sel.add_item("2.0 units/day", 0)
	flow_sel.add_item("4.0 units/day", 1)
	flow_sel.add_item("6.0 units/day", 2)
	flow_sel.add_item("10.0 units/day", 3)
	config_hbox.add_child(flow_sel)
	
	var cost_lbl = Label.new()
	cost_lbl.text = "Daily Cost: $--"
	cost_lbl.add_theme_color_override("font_color", COLOR_TEXT_PAPER)
	config_hbox.add_child(cost_lbl)
	
	var update_cost = func():
		var amount = 2.0
		match flow_sel.selected:
			0: amount = 2.0
			1: amount = 4.0
			2: amount = 6.0
			3: amount = 10.0
		var market_price = CountryManager.market_steel_price if resource_sel.selected == 0 else CountryManager.market_oil_price
		var discount_rate = 1.0 - (rel - 50.0)/200.0
		cost_lbl.text = "Daily Cost: $%d" % round(market_price * amount * discount_rate)
		
	resource_sel.item_selected.connect(func(_x): update_cost.call())
	flow_sel.item_selected.connect(func(_x): update_cost.call())
	
	trade_vbox.add_child(config_hbox)
	update_cost.call()
	
	var propose_trade_btn = Button.new()
	propose_trade_btn.text = "PROPOSE TRADE DEAL"
	propose_trade_btn.disabled = (rel < 30)
	apply_action_btn_style.call(propose_trade_btn)
	propose_trade_btn.pressed.connect(func():
		var amount = 2.0
		match flow_sel.selected:
			0: amount = 2.0
			1: amount = 4.0
			2: amount = 6.0
			3: amount = 10.0
		var res = "steel" if resource_sel.selected == 0 else "oil"
		var market_price = CountryManager.market_steel_price if res == "steel" else CountryManager.market_oil_price
		var discount_rate = 1.0 - (rel - 50.0)/200.0
		var final_price = round(market_price * amount * discount_rate)
		
		CountryManager.send_diplomatic_message(
			player_country.country_name,
			target_country.country_name,
			"TRADE_OFFER",
			"Bilateral Trade Agreement",
			"The player country proposes to buy %.1f %s per day from us in exchange for $%d per day." % [amount, res.capitalize(), final_price],
			{"resource": res, "amount": amount, "price": final_price, "is_buying": false}
		)
		_switch_tab(Tab.DIPLOMACY)
	)
	trade_vbox.add_child(propose_trade_btn)
	actions_vbox.add_child(trade_panel)
	
	# 3. Send diplomatic gift
	var gift_panel = PanelContainer.new()
	gift_panel.add_theme_stylebox_override("panel", rel_style)
	var gift_hbox = HBoxContainer.new()
	gift_hbox.add_theme_constant_override("separation", 15)
	
	var gift_margin = MarginContainer.new()
	gift_margin.add_theme_constant_override("margin_all", 10)
	gift_panel.add_child(gift_margin)
	gift_margin.add_child(gift_hbox)
	
	var gift_details = VBoxContainer.new()
	var gift_title = Label.new()
	gift_title.text = "Send Financial Aid Gift"
	gift_title.add_theme_font_size_override("font_size", 13)
	gift_title.add_theme_color_override("font_color", COLOR_TEXT_PAPER)
	gift_details.add_child(gift_title)
	
	var gift_desc = Label.new()
	gift_desc.text = "Gift $5,000 cash to immediately boost bilateral relations (+20)."
	gift_desc.add_theme_font_size_override("font_size", 11)
	gift_desc.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	gift_details.add_child(gift_desc)
	gift_hbox.add_child(gift_details)
	
	var gift_spacer = Control.new()
	gift_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gift_hbox.add_child(gift_spacer)
	
	var gift_btn = Button.new()
	gift_btn.text = "SEND GIFT ($5K)"
	gift_btn.disabled = player_country.money < 5000.0
	apply_action_btn_style.call(gift_btn)
	gift_btn.pressed.connect(func():
		player_country.money -= 5000.0
		CountryManager.send_diplomatic_message(
			player_country.country_name,
			target_country.country_name,
			"GIFT",
			"Diplomatic Gift Sent",
			"The player country has sent us a diplomatic gift of $5,000 to foster closer friendship.",
			{"gift_type": "money", "gift_amount": 5000.0}
		)
		_switch_tab(Tab.DIPLOMACY)
	)
	gift_hbox.add_child(gift_btn)
	actions_vbox.add_child(gift_panel)

# --- Tab 3: Active agreements ---
func _draw_agreements_tab() -> void:
	var title = Label.new()
	title.text = "ACTIVE BILATERAL TRADE AGREEMENTS"
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", COLOR_ACCENT)
	content_area.add_child(title)
	
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_area.add_child(scroll)
	
	var list = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 10)
	scroll.add_child(list)
	
	var deals = player_country.trade_deals
	if deals.is_empty():
		var empty_lbl = Label.new()
		empty_lbl.text = "No active trade agreements."
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		list.add_child(empty_lbl)
	else:
		for deal_id in deals:
			var deal = deals[deal_id]
			
			var card = PanelContainer.new()
			var card_style = StyleBoxFlat.new()
			card_style.bg_color = COLOR_PANEL_INNER
			card_style.set_corner_radius_all(0)
			card_style.border_width_left = 1
			card_style.border_color = Color(0.25, 0.25, 0.25)
			card.add_theme_stylebox_override("panel", card_style)
			
			var margin = MarginContainer.new()
			margin.add_theme_constant_override("margin_all", 10)
			card.add_child(margin)
			
			var hbox = HBoxContainer.new()
			margin.add_child(hbox)
			
			var is_sender = (deal.sender == player_country.country_name.to_lower())
			var other_nation = deal.recipient if is_sender else deal.sender
			
			var flag = TextureRect.new()
			flag.texture = TroopManager.get_flag(other_nation)
			flag.custom_minimum_size = Vector2(24, 15)
			flag.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			hbox.add_child(flag)
			
			var desc = Label.new()
			var desc_text = ""
			if is_sender:
				desc_text = " EXPORTING %.1f %s/day to %s (+$%d/day)" % [deal.amount, deal.resource.capitalize(), other_nation.capitalize(), deal.price]
				desc.add_theme_color_override("font_color", COLOR_SUCCESS)
			else:
				desc_text = " IMPORTING %.1f %s/day from %s (-$%d/day)" % [deal.amount, deal.resource.capitalize(), other_nation.capitalize(), deal.price]
				desc.add_theme_color_override("font_color", COLOR_ALERT)
				
			desc.text = desc_text
			desc.add_theme_font_size_override("font_size", 12)
			hbox.add_child(desc)
			
			var spacer = Control.new()
			spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			hbox.add_child(spacer)
			
			var cancel_btn = Button.new()
			cancel_btn.text = "CANCEL"
			
			var b_style = StyleBoxFlat.new()
			b_style.bg_color = Color(0.18, 0.16, 0.14)
			b_style.border_width_bottom = 2
			b_style.border_color = COLOR_ALERT
			b_style.set_corner_radius_all(0)
			cancel_btn.add_theme_stylebox_override("normal", b_style)
			cancel_btn.add_theme_stylebox_override("hover", b_style)
			cancel_btn.add_theme_color_override("font_color", COLOR_TEXT_PAPER)
			cancel_btn.custom_minimum_size = Vector2(80, 26)
			
			cancel_btn.pressed.connect(func():
				CountryManager.cancel_trade_deal(player_country, deal.id)
				_switch_tab(Tab.AGREEMENTS)
				if GameState.game_ui:
					GameState.game_ui.update_topbar_stats()
			)
			hbox.add_child(cancel_btn)
			
			list.add_child(card)

# --- Tab 4: Generals Management ---
func _draw_generals_tab() -> void:
	var title = Label.new()
	title.text = "ARMY COMMANDERS & GENERALS"
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", COLOR_ACCENT)
	content_area.add_child(title)
	
	# PP readout and Recruit button
	var top_hbox = HBoxContainer.new()
	top_hbox.add_theme_constant_override("separation", 20)
	content_area.add_child(top_hbox)
	
	var pp_lbl = Label.new()
	pp_lbl.text = "Political Power: %.1f PP" % player_country.political_power
	pp_lbl.add_theme_color_override("font_color", COLOR_TEXT_PAPER)
	pp_lbl.add_theme_font_size_override("font_size", 13)
	top_hbox.add_child(pp_lbl)
	
	var recruit_btn = Button.new()
	recruit_btn.text = "RECRUIT GENERAL (50 PP)"
	recruit_btn.disabled = player_country.political_power < 50.0
	
	var b_style = StyleBoxFlat.new()
	b_style.bg_color = Color(0.18, 0.16, 0.14)
	b_style.border_width_bottom = 2
	b_style.border_color = COLOR_ACCENT
	b_style.set_corner_radius_all(0)
	recruit_btn.add_theme_stylebox_override("normal", b_style)
	recruit_btn.add_theme_stylebox_override("hover", b_style)
	recruit_btn.add_theme_color_override("font_color", COLOR_TEXT_PAPER)
	recruit_btn.custom_minimum_size = Vector2(200, 30)
	
	recruit_btn.pressed.connect(func():
		player_country.political_power -= 50.0
		player_country.generate_general()
		_switch_tab(Tab.GENERALS)
	)
	top_hbox.add_child(recruit_btn)
	
	content_area.add_child(HSeparator.new())
	
	# Scroll list of generals
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_area.add_child(scroll)
	
	var list = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 15)
	scroll.add_child(list)
	
	var gens = player_country.generals
	if gens.is_empty():
		var empty = Label.new()
		empty.text = "No commanders available. Recruit one above!"
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		list.add_child(empty)
	else:
		for gen in gens:
			var card = PanelContainer.new()
			var card_style = StyleBoxFlat.new()
			card_style.bg_color = COLOR_PANEL_INNER
			card_style.set_corner_radius_all(0)
			card_style.border_width_left = 1
			card_style.border_width_top = 1
			card_style.border_width_right = 1
			card_style.border_width_bottom = 1
			card_style.border_color = COLOR_ACCENT
			card.add_theme_stylebox_override("panel", card_style)
			
			var margin = MarginContainer.new()
			margin.add_theme_constant_override("margin_all", 10)
			card.add_child(margin)
			
			var main_hbox = HBoxContainer.new()
			main_hbox.add_theme_constant_override("separation", 15)
			margin.add_child(main_hbox)
			
			# Info column
			var info_vbox = VBoxContainer.new()
			info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			info_vbox.add_theme_constant_override("separation", 4)
			main_hbox.add_child(info_vbox)
			
			var name_lbl = Label.new()
			name_lbl.text = "%s (Lvl %d)" % [gen.name, gen.level]
			name_lbl.add_theme_font_size_override("font_size", 13)
			name_lbl.add_theme_color_override("font_color", COLOR_TEXT_PAPER)
			info_vbox.add_child(name_lbl)
			
			# Stats layout
			var stats_lbl = Label.new()
			stats_lbl.text = "⚔️ Attack Skill: %d | 🛡️ Defense Skill: %d | 📦 Logistics Skill: %d" % [gen.attack, gen.defense, gen.logistics]
			stats_lbl.add_theme_font_size_override("font_size", 11)
			stats_lbl.add_theme_color_override("font_color", COLOR_ACCENT)
			info_vbox.add_child(stats_lbl)
			
			# Modifiers description
			var desc_lbl = Label.new()
			desc_lbl.text = "Combat: +%d%% Attack, +%d%% Defense | Maintenance: -%d%% Supply Costs" % [gen.attack * 10, gen.defense * 10, gen.logistics * 5]
			desc_lbl.add_theme_font_size_override("font_size", 10)
			desc_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
			info_vbox.add_child(desc_lbl)
			
			var xp_lbl = Label.new()
			xp_lbl.text = "XP Progress: %d / %d" % [int(gen.xp), int(gen.level * 100.0)]
			xp_lbl.add_theme_font_size_override("font_size", 10)
			xp_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
			info_vbox.add_child(xp_lbl)
			
			# Assignment actions column
			var act_vbox = VBoxContainer.new()
			act_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
			act_vbox.add_theme_constant_override("separation", 6)
			main_hbox.add_child(act_vbox)
			
			if gen.assigned_troop_id != "":
				var troop_id = int(gen.assigned_troop_id)
				var troop = instance_from_id(troop_id)
				var loc = "Unknown"
				if is_instance_valid(troop) and is_instance_valid(MapManager):
					var prov = MapManager.province_objects.get(troop.province_id)
					if prov:
						loc = prov.city if prov.city != "" else ("Prov " + str(prov.id))
				
				var status_lbl = Label.new()
				status_lbl.text = "Active in: " + loc
				status_lbl.add_theme_font_size_override("font_size", 11)
				status_lbl.add_theme_color_override("font_color", COLOR_SUCCESS)
				act_vbox.add_child(status_lbl)
				
				var unassign_btn = Button.new()
				unassign_btn.text = "DISMISS"
				
				var close_style = StyleBoxFlat.new()
				close_style.bg_color = Color(0.18, 0.16, 0.14)
				close_style.border_width_bottom = 2
				close_style.border_color = COLOR_ALERT
				close_style.set_corner_radius_all(0)
				unassign_btn.add_theme_stylebox_override("normal", close_style)
				unassign_btn.add_theme_stylebox_override("hover", close_style)
				unassign_btn.add_theme_color_override("font_color", COLOR_TEXT_PAPER)
				unassign_btn.custom_minimum_size = Vector2(100, 26)
				
				unassign_btn.pressed.connect(func():
					player_country.unassign_general(gen.id)
					_switch_tab(Tab.GENERALS)
				)
				act_vbox.add_child(unassign_btn)
			else:
				var opt_btn = OptionButton.new()
				opt_btn.add_item("Select Troop Stack...", 0)
				opt_btn.custom_minimum_size = Vector2(160, 26)
				
				var player_troops = TroopManager.get_troops_for_country(player_country.country_name)
				for t in player_troops:
					var prov = MapManager.province_objects.get(t.province_id)
					var loc = prov.city if (prov and prov.city != "") else ("Prov " + str(t.province_id))
					var has_gen = " (Has Gen)" if t.general_id != "" else ""
					opt_btn.add_item("Troop at %s (%d Divs)%s" % [loc, t.divisions_count, has_gen], t.get_instance_id())
					
				act_vbox.add_child(opt_btn)
				
				var assign_btn = Button.new()
				assign_btn.text = "ASSIGN COMMAND"
				assign_btn.disabled = true
				
				var opt_style = StyleBoxFlat.new()
				opt_style.bg_color = Color(0.18, 0.16, 0.14)
				opt_style.border_width_bottom = 2
				opt_style.border_color = COLOR_ACCENT
				opt_style.set_corner_radius_all(0)
				assign_btn.add_theme_stylebox_override("normal", opt_style)
				assign_btn.add_theme_stylebox_override("hover", opt_style)
				assign_btn.add_theme_color_override("font_color", COLOR_TEXT_PAPER)
				assign_btn.custom_minimum_size = Vector2(130, 28)
				
				opt_btn.item_selected.connect(func(idx):
					assign_btn.disabled = (idx == 0)
				)
				
				assign_btn.pressed.connect(func():
					var selected_id = opt_btn.get_item_id(opt_btn.selected)
					var troop = instance_from_id(selected_id) as TroopData
					if is_instance_valid(troop):
						player_country.assign_general(gen.id, troop)
					_switch_tab(Tab.GENERALS)
				)
				act_vbox.add_child(assign_btn)
			
			list.add_child(card)

func _close_menu() -> void:
	if get_parent().has_method("_close_submenu"):
		MapManager.show_countries_map()
		get_parent()._close_submenu()
