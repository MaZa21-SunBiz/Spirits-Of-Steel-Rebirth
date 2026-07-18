extends CanvasLayer

@onready var main_panel = $MainPanel
@onready var flag_rect = $MainPanel/Margin/Layout/NationModule/FlagRect
@onready var country_label = $MainPanel/Margin/Layout/NationModule/VBox/CountryName
@onready var status_label = $MainPanel/Margin/Layout/NationModule/VBox/StatusLabel
@onready var action_container = $MainPanel/Margin/Layout/ScrollActions/ActionContainer

var is_visible: bool = false
var tween: Tween


func _ready() -> void:
	hide() # Bottom HUD is completely hidden/removed from display

	if is_instance_valid(MapManager):
		MapManager.country_clicked.connect(_on_country_selected)
		MapManager.close_sidemenu.connect(_on_menu_close)


func _on_menu_close() -> void:
	if GameState.production_menu_instance and not GameState.production_menu_instance.is_menu_collapsed:
		GameState.production_menu_instance._toggle_collapse()


func _on_country_selected(country_id: String) -> void:
	var country = CountryManager.get_country(country_id)
	if country and GameState.production_menu_instance:
		if country == CountryManager.player_country:
			GameState.production_menu_instance.open_and_switch_to_tab(0, null)
		else:
			GameState.production_menu_instance.open_and_switch_to_tab(3, country)


func _update_ui(country) -> void:
	country_label.text = country.country_name.to_upper()
	flag_rect.texture = TroopManager.get_flag(country.country_name)
	status_label.text = "Stability: %d%% | War Support: %d%%" % [int(country.stability * 100.0), int(country.war_support * 100.0)]

	# Clear old buttons
	for child in action_container.get_children():
		child.free()

	# Add context-specific buttons
	if country == CountryManager.player_country:
		_add_action("Manage Country", open_manage_country, Color(0.08, 0.16, 0.22))  # Dark steel blue
		_add_action("POLITICS", func(): 
			var dt_ui = get_tree().root.find_child("DecisionTreeUI", true, false)
			if dt_ui:
				dt_ui.open_menu()
		, Color(0.18, 0.08, 0.28))  # Deep royal purple
		_add_action(
			"INDUSTRY",
			func():
				GameState.chosen_production_tab = 0
				_toggle_submenu("res://Scenes/UI/ProductionMenu.tscn")
		, Color(0.08, 0.22, 0.10))  # Dark emerald
		_add_action(
			"MILITARY",
			func():
				GameState.chosen_production_tab = 1
				_toggle_submenu("res://Scenes/UI/ProductionMenu.tscn")
		, Color(0.30, 0.05, 0.05))  # Blood crimson
		_add_action(
			"MARKET & TRADE",
			func():
				GameState.chosen_diplomacy_country = country
				GameState.chosen_production_tab = 2
				_toggle_submenu("res://Scenes/UI/ProductionMenu.tscn")
		, Color(0.12, 0.20, 0.28))
		_add_action("RESEARCH", func(): print("Open Res"), Color(0.05, 0.18, 0.32))  # Midnight blue

	else:
		_add_action("DIPLOMACY & TRADE", func():
			GameState.chosen_diplomacy_country = country
			GameState.chosen_production_tab = 4
			_toggle_submenu("res://Scenes/UI/ProductionMenu.tscn")
		, Color(0.1, 0.25, 0.2))
		_add_action("SEND SPY", func(): print("War"), Color(0.6, 0.2, 0.2))


func open_manage_country():
	get_tree().root.find_child("CountryManageUI", true, false).open_menu(
		CountryManager.player_country
	)


# ======== FORGET EVERYTHING BELOW UNLESS YOU TRYING TO CHANGE IMPORTANT THINGS	======


func _animate_appearance(show: bool) -> void:
	is_visible = show
	if tween:
		tween.kill()

	tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)

	# Calculate target Y (floating 30px from bottom)
	var screen_h = get_viewport().get_visible_rect().size.y
	var target_y = screen_h - 100

	if show:
		tween.tween_property(main_panel, "modulate:a", 1.0, 0.4)
		tween.tween_property(main_panel, "position:y", target_y, 0.5)
	else:
		tween.tween_property(main_panel, "modulate:a", 0.0, 0.3)
		tween.tween_property(main_panel, "position:y", target_y + 50, 0.4)


func _add_action(
	label: String, callback: Callable, base_color: Color = Color(0.12, 0.14, 0.18, 0.85)
) -> void:
	var btn = Button.new()
	btn.text = label.to_upper()
	btn.custom_minimum_size = Vector2(140, 54)  # slightly taller = easier to read/tap

	var normal = StyleBoxFlat.new()
	normal.bg_color = base_color
	normal.set_corner_radius_all(0)
	normal.border_width_bottom = 2
	normal.border_color = Color(0.72, 0.58, 0.38, 0.8)

	var hover = normal.duplicate()
	hover.bg_color = base_color.lightened(0.12)
	hover.border_color = Color(0.72, 0.58, 0.38, 1.0)

	var pressed = normal.duplicate()
	pressed.bg_color = base_color.darkened(0.15)

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)

	# Font & alignment
	btn.add_theme_font_size_override("font_size", 13)
	btn.add_theme_constant_override("outline_size", 1)  # tiny dark outline helps a lot
	btn.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))

	btn.pressed.connect(callback)
	action_container.add_child(btn)


func _apply_modern_styling() -> void:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.18, 0.16, 0.14, 0.98) # Warm hand-painted wood panel
	style.set_corner_radius_all(0)  # Sharp edges
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.72, 0.58, 0.38, 1.0) # Brass border
	style.shadow_size = 8
	style.shadow_color = Color(0, 0, 0, 0.5)

	main_panel.add_theme_stylebox_override("panel", style)


@onready var submenu_anchor = $SubMenuAnchor
var current_submenu: Node = null
var current_submenu_path: String = ""
var submenu_tween: Tween


func _toggle_submenu(scene_path: String) -> void:
	if current_submenu_path == scene_path:
		_close_submenu()  # If already open, go back to Nav Bar
		return

	# 1. Hide the Bottom Bar first
	_animate_appearance(false)

	# 2. Wait a split second, then bring up the Sub-Menu
	get_tree().create_timer(0.1).timeout.connect(func(): _load_new_menu(scene_path))


func _load_new_menu(path: String) -> void:
	if current_submenu:
		current_submenu.queue_free()

	var packed = load(path)
	if not packed:
		return

	current_submenu = packed.instantiate()
	current_submenu_path = path

	# Add it as a child.
	# If the submenu scene is set to "Full Rect" or "Bottom Center"
	# in its own editor, it will now stay there.
	add_child(current_submenu)

	# --- ANIMATION ONLY ---
	current_submenu.modulate.a = 0
	if submenu_tween:
		submenu_tween.kill()

	submenu_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUART).set_ease(
		Tween.EASE_OUT
	)
	submenu_tween.tween_property(current_submenu, "modulate:a", 1.0, 0.4)

	# If you want a slight "pop up" effect without breaking the layout:
	current_submenu.modulate.a = 0
	current_submenu.scale = Vector2(1, 0.95)

	submenu_tween.tween_property(current_submenu, "modulate:a", 1.0, 0.3)
	submenu_tween.parallel().tween_property(current_submenu, "scale", Vector2.ONE, 0.35)

func _close_submenu() -> void:
	if not current_submenu:
		return

	var menu = current_submenu
	current_submenu = null
	current_submenu_path = ""

	if submenu_tween:
		submenu_tween.kill()
	submenu_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUART).set_ease(
		Tween.EASE_OUT
	)

	# 1. Slide the menu down and fade it out
	submenu_tween.tween_property(menu, "modulate:a", 0.0, 0.3)
	submenu_tween.tween_property(menu, "position:y", 100, 0.4)

	# 2. Delete the menu once the animation is done
	submenu_tween.chain().tween_callback(menu.queue_free)

	# 3. Bring the Bottom Bar back after a tiny delay so they don't overlap awkwardly
	# Using a simple timer on the scene tree instead of chaining to the tween
	get_tree().create_timer(0.2).timeout.connect(func(): _animate_appearance(true))


func _animate_submenu_in(menu: Control) -> void:
	# Setup starting position (hidden lower down, invisible)
	menu.position.y = 50
	menu.modulate.a = 0.0

	if submenu_tween:
		submenu_tween.kill()
	submenu_tween = create_tween().set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)

	# Slide UP to original position (0 relative to the anchor) and fade in
	submenu_tween.tween_property(menu, "position:y", 0, 0.4)
	submenu_tween.parallel().tween_property(menu, "modulate:a", 1.0, 0.3)
