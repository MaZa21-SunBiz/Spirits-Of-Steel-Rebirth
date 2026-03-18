extends CanvasLayer

# --- CONFIGURATION ---
const MOVE_SPEED = 800.0
const GRID_SIZE = 60.0
const LINE_WIDTH = 4.0
const NODE_SIZE = Vector2(220, 90)
const ZOOM_STEP = 0.1
const MIN_ZOOM = 0.2
const MAX_ZOOM = 3.0

# Colors (No transparency)
const COL_BG = Color(0.05, 0.05, 0.05, 1.0) # Solid Black-Grey
const COL_GRID = Color(0.2, 0.2, 0.2, 1.0) # Visible Grey Grid
const COL_LINE_INACTIVE = Color(0.3, 0.3, 0.3)
const COL_LINE_ACTIVE = Color(0.2, 0.8, 0.2)
const COL_LINE_EXCLUSIVE = Color(0.8, 0.2, 0.2)
const DAMAGED_MAT = preload("res://Materials/damaged.tres")

# --- NODES ---
@onready var tree_canvas: Node2D = $CanvasAnchor/TreeCanvas
@onready var tabs_container: HBoxContainer = $StaticUI/Header/TabsContainer
@onready var info_text: RichTextLabel = $StaticUI/InfoPanel/InfoText
@onready var info_panel: Panel = $StaticUI/InfoPanel
# @onready var tooltip_panel := $StaticUI/TooltipPanel/TooltipLabel
@onready var close_button: Button = $StaticUI/Header/CloseButton


var current_category: String = "Economy"
var node_buttons: Dictionary = {}
var connection_lines: Array = []
var current_zoom: float = 1.0


func _ready():
	DecisionManager.ui_overlay = self


func _process(delta: float) -> void:
	if visible:
		var input = Input.get_vector("move_left", "move_right", "move_up", "move_down")
		if input != Vector2.ZERO:
			tree_canvas.position -= input * MOVE_SPEED * delta / current_zoom
			tree_canvas.queue_redraw()
		

func _input(event: InputEvent) -> void:
	if not visible:
		return
		
	if event is InputEventMouseMotion:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
			tree_canvas.position += event.relative
			tree_canvas.queue_redraw()
	
	if event is InputEventMouseButton:
		if event.is_pressed():
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				_zoom_at_mouse(1.0 + ZOOM_STEP)
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_zoom_at_mouse(1.0 - ZOOM_STEP)


func _zoom_at_mouse(factor: float):
	var old_zoom = current_zoom
	current_zoom = clamp(current_zoom * factor, MIN_ZOOM, MAX_ZOOM)
	var final_factor = current_zoom / old_zoom
	
	var mouse_pos = tree_canvas.get_local_mouse_position()
	
	tree_canvas.scale = Vector2(current_zoom, current_zoom)
	# Adjust position to zoom towards the mouse cursor
	tree_canvas.position -= mouse_pos * (final_factor - 1.0) * old_zoom
	tree_canvas.queue_redraw()


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
	
	var player_country = CountryManager.player_country
	var all_decisions = DecisionManager.get_country_categories(player_country.country_name)
	
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
		btn.material = DAMAGED_MAT


func _load_category(cat_name: String):
	for c in tree_canvas.get_children():
		c.queue_free()
	node_buttons.clear()
	connection_lines.clear()
	# tree_canvas.position = Vector2.ZERO

	var player = CountryManager.player_country
	var nodes = DecisionManager.get_country_categories(player.country_name).get(cat_name, [])

	for i in range(nodes.size()):
		_create_node(nodes[i], i, player)

	for node in nodes:
		if node.has("prereq"):
			var start = _get_node_center(nodes, node["prereq"])
			if start != Vector2.ZERO:
				connection_lines.append(
					{
						"type": "prereq",
						"from": start,
						"to": Vector2(node["pos"][0], node["pos"][1]) \
							+ (NODE_SIZE * 0.5),
						"active": player.has_meta("finished_" + node["prereq"])
					}
				)
				
		if node.has("exclusive"):
			var exclusives = node["exclusive"]
			if not exclusives is Array:
				exclusives = [exclusives]
			for ex_id in exclusives:
				var start = _get_node_center(nodes, ex_id)
				if start != Vector2.ZERO:
					# Only draw one line between mutually exclusive nodes
					if node["id"] > ex_id:
						connection_lines.append(
							{
								"type": "exclusive",
								"from": start,
								"to": Vector2(node["pos"][0], node["pos"][1]) \
									+ (NODE_SIZE * 0.5),
								"active": false
							}
						)
	tree_canvas.queue_redraw()


func _create_node(data: Dictionary, idx: int, player: CountryData):
	var btn = Button.new()
	btn.position = Vector2(data["pos"][0], data["pos"][1])
	btn.custom_minimum_size = NODE_SIZE
	btn.mouse_filter = Control.MOUSE_FILTER_STOP # Ensures hover works
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	# Events
	btn.mouse_entered.connect(func(): _show_info(data))
	btn.mouse_exited.connect(func(): _reset_info())
	btn.pressed.connect(func(): DecisionManager.start_decision(player, current_category, idx))
	
	var tt = data["title"]
	if data.has("desc") and data["desc"] != "":
		tt += "\n" + data["desc"]
	
	var reqs_text = InterpreterManager.format_functions(data.get("reqs", []))
	if reqs_text != "":
		tt += "\n\n[ Requirements ]\n" + reqs_text

	var action_text = InterpreterManager.format_functions(data.get("action", []))
	if action_text != "":
		tt += "\n\n[ On Finished ]\n" + action_text
	
	btn.tooltip_text = tt

	_apply_node_style(btn, data, player)
	btn.set_meta("id", data["id"])
	btn.set_meta("idx", idx)

	node_buttons[data["id"]] = btn
	tree_canvas.add_child(btn)
	btn.material = DAMAGED_MAT


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
			
			var args = req.get("args", [])
			var req_line = req.get("func", "Unknown").capitalize()
			if args.size() > 0:
				var arg_strs = []
				for a in args:
					arg_strs.append(str(a).capitalize())
				req_line += ": " + ", ".join(arg_strs)
			final_req_texts.append(req_line)
			
		if not final_req_texts.is_empty():
			var full_text = "\n".join(final_req_texts)
			info_text.text += "\n[color=red]Requirement: %s[/color]" % full_text


func _reset_info():
	info_text.text = "[center][color=gray]Hover over a node to see info[/color][/center]"


func _apply_node_style(btn: Button, data: Dictionary, player: CountryData):
	var id = data["id"]
	var style = StyleBoxFlat.new()
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.border_width_bottom = 4

	if player.has_meta("finished_" + id):
		btn.text = data["title"] + "\n[DONE]"
		style.bg_color = Color(0.1, 0.4, 0.1)
		btn.disabled = true
	elif DecisionManager.is_in_progress(player, id):
		btn.text = data["title"] + "\n⌛ %d Days" % DecisionManager.get_days_left(player, id)
		style.bg_color = Color(0.1, 0.2, 0.5) # Dark Blue
		btn.disabled = true
	else:
		var is_mutually_locked = false
		if data.has("exclusive"):
			var exclusives = data["exclusive"]
			if not exclusives is Array:
				exclusives = [exclusives]
			for ex_id in exclusives:
				if player.has_meta("finished_" + ex_id) or \
					DecisionManager.is_in_progress(player, ex_id):
					is_mutually_locked = true
					break
		
		if is_mutually_locked:
			btn.text = data["title"] + "\n[LOCKED]"
			style.bg_color = Color(0.4, 0.1, 0.1)
			btn.disabled = true
		elif data.has("prereq") and not player.has_meta("finished_" + data["prereq"]):
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
	# Viewport rect in local canvas space
	var rel_origin = - tree_canvas.position / current_zoom
	var view_size = vp_size / current_zoom

	# Find the first grid line to the left/top of the current view
	var start_x = floor(rel_origin.x / GRID_SIZE) * GRID_SIZE
	var start_y = floor(rel_origin.y / GRID_SIZE) * GRID_SIZE

	# Draw enough lines to fill the screen
	var end_x = start_x + view_size.x + GRID_SIZE
	var end_y = start_y + view_size.y + GRID_SIZE

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
		if line.get("type", "prereq") == "exclusive":
			_draw_dashed_line(
				tree_canvas, line["from"], line["to"], COL_LINE_EXCLUSIVE, LINE_WIDTH, 15.0
			)
		else:
			var color = COL_LINE_ACTIVE if line["active"] else COL_LINE_INACTIVE
			tree_canvas.draw_line(line["from"], line["to"], color, LINE_WIDTH, true)

func _draw_dashed_line(
	canvas: Node2D,
	from: Vector2,
	to: Vector2,
	color: Color,
	width: float,
	dash_length: float = 10.0
):
	var length = (to - from).length()
	var normal = (to - from).normalized()
	var current_pos = from
	var drawn_length = 0.0

	while drawn_length < length:
		var step_end = current_pos + normal * dash_length
		if drawn_length + dash_length > length:
			step_end = to
		
		# Draw dash
		canvas.draw_line(current_pos, step_end, color, width, true)
		
		# Move past dash and gap
		current_pos = step_end + normal * dash_length
		drawn_length += dash_length * 2.0


func _get_node_center(nodes: Array, id: String) -> Vector2:
	for n in nodes:
		if n["id"] == id:
			return Vector2(n["pos"][0], n["pos"][1]) + (NODE_SIZE * 0.5)
	return Vector2.ZERO


func refresh_status_only():
	if not visible:
		return
	var player = CountryManager.player_country
	var country_categories = DecisionManager.get_country_categories(player.country_name)
	var nodes = country_categories.get(current_category, [])
	for btn in node_buttons.values():
		_apply_node_style(btn, nodes[btn.get_meta("idx")], player)
	tree_canvas.queue_redraw()


func _on_reload_decisions_pressed():
	DecisionManager._load_decisions("res://starts/"+GameState.current_start+"/decisions/")
	_load_category(current_category)
