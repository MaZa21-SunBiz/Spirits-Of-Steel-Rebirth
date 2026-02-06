extends CanvasLayer

# --- CONFIGURATION ---
const MOVE_SPEED = 800.0
const GRID_SIZE = 60.0
const LINE_WIDTH = 4.0
const NODE_SIZE = Vector2(220, 90)

# Colors (No transparency)
const COL_BG = Color(0.05, 0.05, 0.05, 1.0)  # Solid Black-Grey
const COL_GRID = Color(0.2, 0.2, 0.2, 1.0)  # Visible Grey Grid
const COL_LINE_INACTIVE = Color(0.3, 0.3, 0.3)
const COL_LINE_ACTIVE = Color(0.2, 0.8, 0.2)

# --- NODES ---
var tree_canvas: Node2D
var tabs_container: HBoxContainer
var info_text: RichTextLabel
var info_panel: Panel

var tooltip_panel: Panel
var tooltip_label: RichTextLabel


var current_category: String = "Economy"
var node_buttons: Dictionary = {}
var connection_lines: Array = []


func _ready():
	layer = 100
	hide()
	DecisionManager.ui_overlay = self
	tree_canvas = Node2D.new()
	_create_full_ui()


func _process(delta: float) -> void:
	if visible:
		var input = Input.get_vector("move_left", "move_right", "move_up", "move_down")
		if input != Vector2.ZERO:
			tree_canvas.position -= input * MOVE_SPEED * delta
			tree_canvas.queue_redraw()
		
		# --- UPDATE CUSTOM TOOLTIP POSITION ---
		if tooltip_panel and tooltip_panel.visible:
			var mouse_pos = get_viewport().get_mouse_position()
			tooltip_panel.global_position = mouse_pos + Vector2(20, 20)  # Offset from cursor



func _create_full_ui():
	# 1. SOLID BACKGROUND
	var bg = ColorRect.new()
	bg.color = COL_BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# 2. THE MOVABLE CANVAS WRAPPER (This is the "ui_layer" / Anchor)
	# This node stays at 0,0 and lets the tree_canvas move inside it
	var canvas_anchor = Control.new()
	canvas_anchor.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas_anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas_anchor.clip_contents = false  # IMPORTANT: This allows negative coordinates to show up
	add_child(canvas_anchor)

	# Add the Node2D tree_canvas to the anchor
	tree_canvas.draw.connect(_on_draw_canvas)
	canvas_anchor.add_child(tree_canvas)

	# 3. STATIC UI LAYER (Header/Footer/Close Button)
	# We create a separate container for these so they don't move with the canvas
	var static_ui = Control.new()
	static_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	static_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(static_ui)

	# --- HEADER ---
	var header = Panel.new()
	header.custom_minimum_size.y = 80
	header.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	static_ui.add_child(header)  # Changed from ui_layer to static_ui

	tabs_container = HBoxContainer.new()
	tabs_container.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	tabs_container.position = Vector2(20, 0)
	tabs_container.add_theme_constant_override("separation", 15)
	header.add_child(tabs_container)

	# --- CLOSE BUTTON ---
	var close_btn = Button.new()
	close_btn.text = "  CLOSE MENU [X]  "
	close_btn.custom_minimum_size = Vector2(150, 40)
	close_btn.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	close_btn.position.x -= 20
	close_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close_btn.pressed.connect(close_menu)
	header.add_child(close_btn)

	# --- FOOTER (Description Box) ---
	info_panel = Panel.new()
	info_panel.custom_minimum_size.y = 160
	info_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	static_ui.add_child(info_panel)  # Changed from ui_layer to static_ui

	info_text = RichTextLabel.new()
	info_text.bbcode_enabled = true
	info_text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	info_text.offset_left = 30
	info_text.offset_top = 20
	info_text.offset_right = -30
	info_text.offset_bottom = -10
	info_text.text = "[center][color=gray]Hover over a node to see info[/color][/center]"
	info_panel.add_child(info_text)

	# --- 4. CUSTOM TOOLTIP LAYER ---
	tooltip_panel = Panel.new()
	tooltip_panel.visible = false
	tooltip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tooltip_panel.custom_minimum_size = Vector2(200, 40)
	static_ui.add_child(tooltip_panel)


	tooltip_label = RichTextLabel.new()
	tooltip_label.bbcode_enabled = true
	tooltip_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tooltip_label.offset_left = 10
	tooltip_label.offset_right = -10
	tooltip_label.offset_top = 5
	tooltip_label.offset_bottom = -5
	tooltip_label.fit_content = true
	tooltip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tooltip_panel.add_child(tooltip_label)



# --- LOGIC ---
func open_menu():
	show()
	_rebuild_tabs()
	_load_category(current_category)
	GameState.decision_menu_open = true
	_toggle_pause(true)


func close_menu():
	hide()
	GameState.decision_menu_open = false
	_toggle_pause(false)


func _toggle_pause(pause: bool):
	var world = GameState.current_world
	if world:
		world.set_process(!pause)
		world.clock.set_process(!pause)
		var cam = world.find_child("CameraController", true, false)
		if cam:
			cam.set_process(!pause)
	TroopManager.set_process(!pause)


func _rebuild_tabs():
	for c in tabs_container.get_children():
		c.queue_free()
	
	var all_decisions = DecisionManager.get_country_categories(CountryManager.player_country.country_name)
	
	for cat in all_decisions.keys():
		var btn = Button.new()
		btn.text = " " + cat.to_upper() + " "
		btn.toggle_mode = true
		btn.button_pressed = (cat == current_category)
		btn.pressed.connect(
			func():
				current_category = cat
				_rebuild_tabs()
				_load_category(cat)
		)
		tabs_container.add_child(btn)


func _load_category(cat_name: String):
	for c in tree_canvas.get_children():
		c.queue_free()
	node_buttons.clear()
	connection_lines.clear()
	tree_canvas.position = Vector2.ZERO

	var player = CountryManager.player_country
	var all_decisions = DecisionManager.get_country_categories(player.country_name)
	var nodes = all_decisions.get(cat_name, [])

	for i in range(nodes.size()):
		_create_node(nodes[i], i, player)

	for node in nodes:
		if node.has("prereq"):
			var start = _get_node_center(nodes, node["prereq"])
			var end = Vector2(node["pos"][0], node["pos"][1]) + (NODE_SIZE / 2)
			if start != Vector2.ZERO:
				connection_lines.append(
					{
						"from": start,
						"to": end,
						"active": player.has_meta("finished_" + node["prereq"])
					}
				)
	tree_canvas.queue_redraw()


func _create_node(data: Dictionary, idx: int, player: CountryData):
	var btn = Button.new()
	btn.position = Vector2(data["pos"][0], data["pos"][1])
	btn.custom_minimum_size = NODE_SIZE
	btn.mouse_filter = Control.MOUSE_FILTER_STOP  # Ensures hover works
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	# Events
	btn.mouse_entered.connect(func(): _show_info(data))
	btn.mouse_exited.connect(func(): _reset_info())
	btn.pressed.connect(func(): DecisionManager.start_decision(player, current_category, idx))

	_apply_node_style(btn, data, player)
	btn.set_meta("id", data["id"])
	btn.set_meta("idx", idx)

	node_buttons[data["id"]] = btn
	tree_canvas.add_child(btn)



func _show_info(data: Dictionary):
	info_text.text = "[b][font_size=26][color=yellow]%s[/color][/font_size][/b]\n" % data["title"]
	info_text.text += "[font_size=18][i]%s[/i][/font_size]\n\n" % data.get("desc", "")
	info_text.text += (
		"[color=orange]Time: %d Days | Cost: %d Political Power[/color]"
		% [data["days"], data["cost_pp"]]
	)

	if data.has("reqs"):
		var reqs = data["reqs"]
		if not reqs is Array:
			reqs = [reqs]
		
		var final_req_texts = []
		for req in reqs:
			if not req is Dictionary: continue
			
			var f_name = req.get("func", "Unknown").capitalize()
			var args = req.get("args", [])
			var req_line = f_name
			if args.size() > 0:
				var arg_strs = []
				for a in args:
					arg_strs.append(str(a).capitalize())
				req_line += ": " + ", ".join(arg_strs)
			final_req_texts.append(req_line)
			
		if not final_req_texts.is_empty():
			var full_text = "\n".join(final_req_texts)
			info_text.text += "\n[color=red]Requirement: %s[/color]" % full_text
			
			# Update custom tooltip
			tooltip_label.text = "[center]%s[/center]" % full_text
			tooltip_panel.show()



func _reset_info():
	info_text.text = "[center][color=gray]Hover over a node to see info[/color][/center]"
	if tooltip_panel:
		tooltip_panel.hide()



func _apply_node_style(btn: Button, data: Dictionary, player: CountryData):
	var id = data["id"]
	var finished = player.has_meta("finished_" + id)
	var progressing = DecisionManager.is_in_progress(player, id)
	var style = StyleBoxFlat.new()
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.border_width_bottom = 4

	if finished:
		btn.text = data["title"] + "\n[DONE]"
		style.bg_color = Color(0.1, 0.4, 0.1)
		btn.disabled = true
	elif progressing:
		var days_left = DecisionManager.get_days_left(player, id)
		btn.text = data["title"] + "\n⌛ %d Days" % days_left
		style.bg_color = Color(0.1, 0.2, 0.5)  # Dark Blue
		btn.disabled = true
	else:
		var parent_done = true
		if data.has("prereq"):
			parent_done = player.has_meta("finished_" + data["prereq"])

		if not parent_done:
			btn.text = data["title"]
			style.bg_color = Color(0.241, 0.102, 0.101, 1.0)
			btn.disabled = true
		else:
			btn.text = data["title"] + "\n%d PP" % data["cost_pp"]
			style.bg_color = Color(0.2, 0.2, 0.2)
			# Also check if another decision is already running
			btn.disabled = (
				player.political_power < data["cost_pp"] or DecisionManager.is_country_busy(player)
			)

	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("disabled", style)
	btn.add_theme_stylebox_override("hover", style)


func _on_draw_canvas():
	var vp_size = get_viewport().size
	# Where is the (0,0) of the screen relative to our moving canvas?
	var rel_origin = -tree_canvas.position

	# Find the first grid line to the left/top of the current view
	var start_x = floor(rel_origin.x / GRID_SIZE) * GRID_SIZE
	var start_y = floor(rel_origin.y / GRID_SIZE) * GRID_SIZE

	# Draw enough lines to fill the screen + 1 extra for safety
	var end_x = start_x + vp_size.x + GRID_SIZE
	var end_y = start_y + vp_size.y + GRID_SIZE

	# Grid logic
	var x = start_x
	while x <= end_x:
		tree_canvas.draw_line(Vector2(x, start_y), Vector2(x, end_y), COL_GRID, 1.0)
		x += GRID_SIZE

	var y = start_y
	while y <= end_y:
		tree_canvas.draw_line(Vector2(start_x, y), Vector2(end_x, y), COL_GRID, 1.0)
		y += GRID_SIZE

	# Connections
	for line in connection_lines:
		var col = COL_LINE_ACTIVE if line["active"] else COL_LINE_INACTIVE
		tree_canvas.draw_line(line["from"], line["to"], col, LINE_WIDTH, true)


func _get_node_center(nodes: Array, id: String) -> Vector2:
	for n in nodes:
		if n["id"] == id:
			return Vector2(n["pos"][0], n["pos"][1]) + (NODE_SIZE / 2)
	return Vector2.ZERO


func refresh_status_only():
	if not visible:
		return
	var player = CountryManager.player_country
	var all_decisions = DecisionManager.get_country_categories(player.country_name)
	var nodes = all_decisions.get(current_category, [])
	for btn in node_buttons.values():
		_apply_node_style(btn, nodes[btn.get_meta("idx")], player)
	tree_canvas.queue_redraw()
