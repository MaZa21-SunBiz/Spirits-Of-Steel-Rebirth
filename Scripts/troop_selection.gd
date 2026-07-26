extends Node2D
class_name TroopSelection

signal selection_changed

var font: Font = preload("res://font/TTT-Regular.otf")

# --- Constants ---
const CLICK_THRESHOLD := 2.0
const SPREAD_DRAG_THRESHOLD := 15.0

# --- State ---
var dragging: bool = false
var drag_start: Vector2 = Vector2.ZERO
var drag_end: Vector2 = Vector2.ZERO

var right_dragging: bool = false
var right_drag_start: Vector2 = Vector2.ZERO
var right_drag_current: Vector2 = Vector2.ZERO
var right_drag_path: Array[Vector2] = []

@onready var map_sprite: Sprite2D = $"../../../MapContainer/CultureSprite"

var selected_troops: Array[TroopData] = []

func _input(event) -> void:
	if not map_sprite or Console.is_visible():
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_handle_left_mouse(event)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_handle_right_mouse(event)

	elif event is InputEventMouseMotion:
		_handle_mouse_motion()

var selection_ui_layer: CanvasLayer
var selection_menu_panel: PanelContainer

func _ready() -> void:
	_setup_selection_ui()

func _setup_selection_ui() -> void:
	selection_ui_layer = CanvasLayer.new()
	selection_ui_layer.layer = 100
	add_child(selection_ui_layer)

	selection_menu_panel = PanelContainer.new()
	selection_menu_panel.custom_minimum_size = Vector2(360, 240)
	selection_menu_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	selection_menu_panel.visible = false

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.04, 0.05, 0.99) # Sleek HOI4 dark panel
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.85, 0.45, 0.15, 1.0) # Copper accent border
	style.set_corner_radius_all(0)
	selection_menu_panel.add_theme_stylebox_override("panel", style)

	selection_ui_layer.add_child(selection_menu_panel)
	selection_changed.connect(_on_selection_changed_update_ui)

func _on_selection_changed_update_ui() -> void:
	if not is_instance_valid(selection_menu_panel):
		return

	if selected_troops.is_empty():
		selection_menu_panel.visible = false
		return

	_update_selection_menu_content()
	selection_menu_panel.visible = true

	# Position panel at bottom right
	var vp_size = get_viewport_rect().size
	selection_menu_panel.position = Vector2(vp_size.x - 380, vp_size.y - 260)

func _update_selection_menu_content() -> void:
	for child in selection_menu_panel.get_children():
		child.queue_free()

	var margin = MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	selection_menu_panel.add_child(margin)

	var main_vbox = VBoxContainer.new()
	main_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main_vbox.add_theme_constant_override("separation", 8)
	margin.add_child(main_vbox)

	# Header Row
	var header_hbox = HBoxContainer.new()
	header_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main_vbox.add_child(header_hbox)

	var title = Label.new()
	title.text = "⚔️ ARMY COMMAND (%d UNIT%s)" % [selected_troops.size(), "S" if selected_troops.size() > 1 else ""]
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", Color(0.9, 0.5, 0.15))
	header_hbox.add_child(title)

	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(spacer)

	var delete_all_btn = Button.new()
	delete_all_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	delete_all_btn.text = "🗑️ Disband All"
	_apply_ui_btn_style(delete_all_btn, Color(0.9, 0.25, 0.2))
	delete_all_btn.pressed.connect(func():
		var troops_copy = selected_troops.duplicate()
		deselect_all()
		for t in troops_copy:
			TroopManager.delete_troop(t)
	)
	header_hbox.add_child(delete_all_btn)

	# Scroll Container for Units
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(336, 180)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main_vbox.add_child(scroll)

	var list_vbox = VBoxContainer.new()
	list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_vbox.add_theme_constant_override("separation", 6)
	scroll.add_child(list_vbox)

	for troop_idx in range(selected_troops.size()):
		var troop: TroopData = selected_troops[troop_idx]
		if not is_instance_valid(troop):
			continue

		var item_panel = PanelContainer.new()
		var p_style = StyleBoxFlat.new()
		p_style.bg_color = Color(0.08, 0.09, 0.12, 0.95)
		p_style.border_width_left = 3
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

		# Top Row: Unit Name & Single Delete
		var top_row = HBoxContainer.new()
		item_vbox.add_child(top_row)

		var type_icon = "🟩" if troop.cached_main_type == "infantry" else ("🔺" if troop.cached_main_type == "artillery" else "🔵")
		var u_name = Label.new()
		u_name.text = "%s Unit #%d (%s)" % [type_icon, troop_idx + 1, troop.cached_main_type.capitalize()]
		u_name.add_theme_font_size_override("font_size", 11)
		u_name.add_theme_color_override("font_color", Color.WHITE)
		top_row.add_child(u_name)

		var sp_item = Control.new()
		sp_item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top_row.add_child(sp_item)

		var del_single = Button.new()
		del_single.mouse_filter = Control.MOUSE_FILTER_STOP
		del_single.text = "✖"
		_apply_ui_btn_style(del_single, Color(0.8, 0.2, 0.2))
		del_single.custom_minimum_size = Vector2(24, 20)
		del_single.pressed.connect(func():
			selected_troops.erase(troop)
			TroopManager.delete_troop(troop)
			_on_selection_changed_update_ui()
		)
		top_row.add_child(del_single)

		# Health Progress Bar
		var hp_percent = troop.get_average_hp_percent()
		var hp_bar = ProgressBar.new()
		hp_bar.custom_minimum_size = Vector2(0, 8)
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

		# Divisions Info
		var div_info = Label.new()
		div_info.text = "Health: %d%% | Divisions: %d" % [int(hp_percent * 100.0), troop.divisions_count]
		div_info.add_theme_font_size_override("font_size", 9)
		div_info.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
		item_vbox.add_child(div_info)

func _apply_ui_btn_style(btn: Button, border_color: Color) -> void:
	var s = StyleBoxFlat.new()
	s.bg_color = Color(0.12, 0.14, 0.18, 0.95)
	s.border_width_bottom = 2
	s.border_color = border_color
	s.set_corner_radius_all(0)
	btn.add_theme_stylebox_override("normal", s)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_font_size_override("font_size", 10)
	btn.custom_minimum_size = Vector2(70, 24)

func deselect_all() -> void:
	selected_troops.clear()
	selection_changed.emit()

func _handle_mouse_motion() -> void:
	if dragging:
		drag_end = get_global_mouse_position()

	if right_dragging:
		right_drag_current = get_global_mouse_position()
		if right_drag_path.is_empty() or right_drag_path[-1].distance_to(right_drag_current) > 10.0:
			right_drag_path.append(right_drag_current)

func _handle_left_mouse(event: InputEventMouseButton) -> void:
	if !dragging and is_instance_valid(MapManager) and MapManager._is_mouse_over_ui():
		return
	if event.pressed:
		dragging = true
		drag_start = get_global_mouse_position()
		drag_end = drag_start
	else:
		if not dragging:
			return

		drag_end = get_global_mouse_position()
		dragging = false

		if drag_start.distance_to(drag_end) < CLICK_THRESHOLD:
			_perform_single_click_selection()
		else:
			_perform_selection()

		if selected_troops.size() > 0:
			MusicManager.play_sfx(MusicManager.SFX.TROOP_SELECTED)

func _handle_right_mouse(event: InputEventMouseButton) -> void:
	if selected_troops.is_empty():
		return

	if event.pressed:
		right_dragging = true
		right_drag_start = get_global_mouse_position()
		right_drag_current = right_drag_start
		right_drag_path.clear()
		right_drag_path.append(right_drag_start)
	else:
		if not right_dragging:
			return

		right_drag_current = get_global_mouse_position()
		right_dragging = false

		var drag_distance = right_drag_start.distance_to(right_drag_current)

		if drag_distance >= SPREAD_DRAG_THRESHOLD and right_drag_path.size() > 1:
			_spread_troops_along_freeform_path()
		else:
			var start_local = (right_drag_start - map_sprite.position) / map_sprite.scale
			_move_troops_to_single_point(start_local)

		right_drag_path.clear()
		MusicManager.play_sfx(MusicManager.SFX.TROOP_SELECTED)

func _spread_troops_along_freeform_path() -> void:
	if selected_troops.is_empty() or right_drag_path.size() < 2:
		return

	var count = selected_troops.size()

	# Convert screen path points to local map coordinates
	var local_path: Array[Vector2] = []
	for pt in right_drag_path:
		local_path.append((pt - map_sprite.position) / map_sprite.scale)

	# Calculate total path length
	var total_length = 0.0
	var segment_lengths: Array[float] = []
	for i in range(local_path.size() - 1):
		var seg_len = local_path[i].distance_to(local_path[i + 1])
		segment_lengths.append(seg_len)
		total_length += seg_len

	for i in range(count):
		var target_dist = (float(i) / float(max(1, count - 1))) * total_length if count > 1 else 0.5 * total_length
		var target_point = _get_point_at_distance_along_path(local_path, segment_lengths, target_dist)
		TroopManager.move_troop_to_position(selected_troops[i], target_point)

func _get_point_at_distance_along_path(path: Array[Vector2], segment_lengths: Array[float], target_dist: float) -> Vector2:
	if path.is_empty():
		return Vector2.ZERO
	if target_dist <= 0.0:
		return path[0]

	var accumulated = 0.0
	for i in range(segment_lengths.size()):
		var seg_len = segment_lengths[i]
		if accumulated + seg_len >= target_dist:
			var remaining = target_dist - accumulated
			var factor = remaining / seg_len if seg_len > 0 else 0.0
			return path[i].lerp(path[i + 1], factor)
		accumulated += seg_len

	return path[-1]

func _move_troops_to_single_point(base_point: Vector2) -> void:
	if selected_troops.is_empty():
		return

	var count = selected_troops.size()
	if count == 1:
		TroopManager.move_troop_to_position(selected_troops[0], base_point)
		return

	# Arrange multiple troops in a compact formation circle around the clicked point
	var radius = 22.0
	for i in range(count):
		var angle = (float(i) / float(count)) * TAU
		var offset = Vector2(cos(angle), sin(angle)) * radius
		var target_point = base_point + offset
		TroopManager.move_troop_to_position(selected_troops[i], target_point)

func _perform_single_click_selection() -> void:
	if not map_sprite or not CountryManager.player_country:
		return

	var click_pos = get_global_mouse_position()
	var local_pos = (click_pos - map_sprite.position) / map_sprite.scale
	var player_troops = CountryManager.player_country.troops_country

	var clicked_troop: TroopData = null
	for t in player_troops:
		var dist = t.position.distance_to(local_pos)
		if dist <= max(14.0, t.get_influence_radius()):
			clicked_troop = t
			break

	var additive = Input.is_key_pressed(KEY_SHIFT)
	if not additive:
		selected_troops.clear()

	if clicked_troop:
		if not selected_troops.has(clicked_troop):
			selected_troops.append(clicked_troop)

	selection_changed.emit()

func _perform_selection() -> void:
	if not map_sprite or not CountryManager.player_country:
		return

	var world_rect := Rect2(drag_start, drag_end - drag_start).abs()
	var player_troops = CountryManager.player_country.troops_country

	var selected_list: Array[TroopData] = []
	for t in player_troops:
		var t_world_pos = t.position + map_sprite.position
		if world_rect.has_point(t_world_pos) or world_rect.grow(t.get_influence_radius()).has_point(t_world_pos):
			selected_list.append(t)

	var additive = Input.is_key_pressed(KEY_SHIFT)
	if not additive:
		selected_troops.clear()

	for t in selected_list:
		if not selected_troops.has(t):
			selected_troops.append(t)

	selection_changed.emit()
	var main_node = get_tree().root.find_child("CustomRenderer", true, false)
	if is_instance_valid(main_node) and main_node.has_method("rebuild_troops"):
		main_node.rebuild_troops()
