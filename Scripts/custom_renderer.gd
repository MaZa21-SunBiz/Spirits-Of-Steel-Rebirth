extends Node2D
class_name CustomRenderer

# --- Constants & Config ---
const COLORS = {
	"background": Color(0, 0, 0, 0.8),
	"text": Color(1, 1, 1, 1),
	"border_default": Color(1.0, 1.0, 1.0, 1.0),
	"border_selected": Color(0, 1, 0),
	"border_other": Color(0, 0, 0, 1),
	"movement_active": Color(0, 1, 0, 0.8),
	"path_active": Color(1, 0.2, 0.2),
	"path_inactive": Color(0.5, 0.5, 0.5)
}

const ZOOM_LIMITS = {"min_scale": 0.05, "max_scale": 0.5}
const STACKING_OFFSET_Y := 20.0

# --- Variables ---
var _font: Font = preload("res://font/arial.TTF")
var map_sprite: Sprite2D
var map_width: float = 0.0
var _current_inv_zoom := 1.0
var _screen_rect: Rect2

# Reference to the GPU node
var troop_multimesh: MultiMeshInstance2D

var _last_cam_pos := Vector2.INF
var _last_cam_zoom := Vector2.INF


# --- Lifecycle ---
func _ready() -> void:
	z_index = 20 # Keep renderer high
	_setup_multimesh()

func _process(_delta: float) -> void:
	# Use is_instance_valid in case the map sprite is from the deleted scene
	if !is_instance_valid(map_sprite) or map_width <= 0:
		return

	var cam := get_viewport().get_camera_2d()
	if cam:
		var zoom_changed := cam.zoom != _last_cam_zoom
		var pos_changed := cam.global_position != _last_cam_pos

		if zoom_changed or pos_changed:
			var raw_scale := 1.0 / cam.zoom.x
			_current_inv_zoom = clamp(raw_scale, ZOOM_LIMITS.min_scale, ZOOM_LIMITS.max_scale)
			_update_screen_rect()
			_last_cam_zoom = cam.zoom
			_last_cam_pos = cam.global_position
	elif _screen_rect.size == Vector2.ZERO:
		# FALLBACK: If the camera is missing for a frame, draw a giant area
		# so troops don't suddenly vanish or fail `has_point` checks
		_screen_rect = Rect2(-100000, -100000, 200000, 200000)

	# Continue updating even if camera isn't ready
	if is_instance_valid(troop_multimesh) and troop_multimesh.material:
		var shader_clock = GameState.main.clock.total_game_seconds
		troop_multimesh.material.set_shader_parameter("game_time", shader_clock)

	_update_multimesh_buffer()
	queue_redraw()


func rebuild_troops():
	if not map_sprite or map_width <= 0:
		push_warning("CustomRenderer: Map not ready")
		return

	if not troop_multimesh:
		_setup_multimesh()

	var mm = troop_multimesh.multimesh
	if not mm:
		_setup_multimesh()
		mm = troop_multimesh.multimesh

	# Force MultiMesh instance_count to match troops
	var total_instances = TroopManager.troops.size() + TroopManager.moving_troops.size()
	mm.instance_count = total_instances

	_update_multimesh_buffer()

	queue_redraw()


# --- MultiMesh Setup ---
func _setup_multimesh():
	if not troop_multimesh:
		troop_multimesh = MultiMeshInstance2D.new()
		troop_multimesh.name = "TroopMultiMesh"
#		troop_multimesh.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# Crucial: Move the boxes behind the labels
		troop_multimesh.z_index = -1
		add_child(troop_multimesh)

	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.use_colors = true
	mm.use_custom_data = false # Simplified to avoid data corruption

	var q_mesh = QuadMesh.new()
	q_mesh.size = Vector2(LAYOUT.box_w + LAYOUT.box_w * 0.15, LAYOUT.box_h + LAYOUT.box_h * 0.15)
	mm.mesh = q_mesh

	# SHADER: Using modern Godot 4.5 canvas_item logic
	var mat = ShaderMaterial.new()
	mat.shader = Shader.new()
	mat.shader.code = """
	shader_type canvas_item;
	void fragment() {
		float zoom = max(0.4, COLOR.a); // we’ll encode zoom in alpha
		float tx = 0.05 * zoom;
		float ty = 0.1 * zoom;

uniform float game_time;

void vertex() {
    vec2 start_pos = INSTANCE_CUSTOM.xy;
    float start_time = INSTANCE_CUSTOM.z;
    float duration = INSTANCE_CUSTOM.w;
    float progress = 1.0;
    if (duration > 0.0) {
        progress = clamp((game_time - start_time) / duration, 0.0, 1.0);
    }
    vec2 target_pos = vec2(MODEL_MATRIX[3][0], MODEL_MATRIX[3][1]);
    vec2 offset = (start_pos - target_pos) * (1.0 - progress);
    VERTEX += offset;
}

void fragment() {
    // We adjust the border based on the zoom factor
    float zoom = max(0.4, COLOR.a);
    
    // Use smaller, more precise values for a wide rectangle
    // For a 64x32 rect, these values keep the border looking uniform
    float border_width = 0.04 * zoom; 
    float border_height = 0.08 * zoom;

    bool is_border = UV.x < border_width || UV.x > (1.0 - border_width) || 
                     UV.y < border_height || UV.y > (1.0 - border_height);
    
    if (is_border) {
        COLOR = vec4(COLOR.rgb, 1.0); // The selection/country color
    } else {
        COLOR = vec4(0.0, 0.0, 0.0, 0.85); // Your black background
    }
}
	"""
	# Apply material to the Instance, not the Mesh (more reliable for updates)
	troop_multimesh.material = mat
	troop_multimesh.multimesh = mm


## CustomRenderer.gd


func _update_multimesh_buffer():
	var mm = troop_multimesh.multimesh
	var total_troops = TroopManager.troops.size()

	if mm.instance_count != total_troops * 3:
		mm.instance_count = total_troops * 3

	var idx = 0
	var player_country = CountryManager.player_country.country_name
	var selected_troops = []
	if is_instance_valid(TroopManager.troop_selection):
		selected_troops = TroopManager.troop_selection.selected_troops
	var stacks_to_draw = {}  # { province_id: [TroopData, ...] }

	for troop in TroopManager.troops:
		if troop.is_moving:
			continue

		var pid = troop.province_id
		if not stacks_to_draw.has(pid):
			stacks_to_draw[pid] = []
		stacks_to_draw[pid].append(troop)

	for pid in stacks_to_draw:
		var stack = stacks_to_draw[pid]
		var base_pos = MapManager.province_centers.get(pid, Vector2.ZERO)
		idx = _write_stack_to_multimesh(stack, base_pos, idx, player_country, selected_troops)

	for troop in TroopManager.moving_troops:
		idx = _write_stack_to_multimesh(
			[troop], troop.position, idx, player_country, selected_troops
		)

	_hide_unused_instances(idx, mm)


func _hide_unused_instances(start_idx: int, mm: MultiMesh) -> void:
	for i in range(start_idx, mm.instance_count):
		mm.set_instance_transform_2d(i, Transform2D().scaled(Vector2.ZERO))


func _write_stack_to_multimesh(
	stack: Array, base_pos: Vector2, idx: int, player: String, selected: Array
) -> int:
	var mm = troop_multimesh.multimesh
	var scaled_offset := STACKING_OFFSET_Y * _current_inv_zoom
	var start_y = (stack.size() - 1) * scaled_offset * 0.5
	var mm_scale := Vector2(_current_inv_zoom, _current_inv_zoom)

	for i in range(stack.size()):
		var troop = stack[i]
		var vertical_pos = base_pos + Vector2(0, start_y - (i * scaled_offset))

		var col = COLORS.border_other
		if troop.country_name == player:
			col = COLORS.border_selected if selected.has(troop) else COLORS.border_default

		for m in [0]:
			var final_pos = vertical_pos + Vector2(map_width * m, 0) + map_sprite.position
			mm.set_instance_transform_2d(idx, Transform2D(0, mm_scale, 0, final_pos))
			mm.set_instance_color(idx, col)
			idx += 1
	return idx



func _draw() -> void:
	if !map_sprite or map_width <= 0:
		return
	if !GameState.in_peace_process:
		_draw_path_preview()
		_draw_active_movements()
		_draw_selection_box()
		_draw_troops()
	_draw_cities()
	if !GameState.in_peace_process:
		draw_battles()


func _draw_troops() -> void:
	if _current_inv_zoom > 1.5:
		return

	var static_stacks = {}  # { province_id: [TroopData, ...] }

	for troop in TroopManager.troops:
		if troop.is_moving:
			continue

		var pid = troop.province_id
		if not static_stacks.has(pid):
			static_stacks[pid] = []
		static_stacks[pid].append(troop)

	for pid in static_stacks:
		var stack = static_stacks[pid]
		var base_pos = MapManager.province_centers.get(pid, Vector2.ZERO)
		_draw_stack_labels(stack, base_pos)

	for troop in TroopManager.moving_troops:
		_draw_stack_labels([troop], troop.position)


func _draw_stack_labels(stack: Array, base_pos: Vector2) -> void:
	var scaled_offset := STACKING_OFFSET_Y * _current_inv_zoom
	var start_y = (stack.size() - 1) * scaled_offset * 0.5

	for i in range(stack.size()):
		var troop = stack[i]
		var vertical_pos = base_pos + Vector2(0, start_y - (i * scaled_offset))

		for m in [-1, 0, 1]:
			var d_pos = vertical_pos + Vector2(map_width * m, 0) + map_sprite.position
			if _screen_rect.has_point(d_pos):
				_draw_troop(troop, d_pos)


const HP_COLORS = {
	"bg": Color(0.1, 0.1, 0.1, 0.9),
	"healthy": Color(0.1, 0.9, 0.1),
	"damaged": Color(0.9, 0.8, 0.1),
	"critical": Color(0.9, 0.1, 0.1)
}
const LAYOUT = {"box_w": 64.0, "box_h": 32.0, "hp_bar_h": 3.0, "font_size": 18}  # Wide rectangle  # Shorter height  # Visible strip at the bottom
# Add this to your variables or constants
var show_division_icon: bool = false


func _draw_troop(troop: TroopData, pos: Vector2) -> void:
	var t := Transform2D(0, Vector2(_current_inv_zoom, _current_inv_zoom), 0, pos)
	draw_set_transform_matrix(t)

	var w = LAYOUT.box_w
	var h = LAYOUT.box_h
	var hp_h = LAYOUT.hp_bar_h
	var top_left = Vector2(-w * 0.5, -h * 0.5)

	# --- 1. THE MAIN PLATE ---
	# Solid dark background
	var plate_rect = Rect2(top_left, Vector2(w, h - hp_h))
	draw_rect(plate_rect, Color(0.08, 0.08, 0.08, 0.95), true)

	# --- 2. LEFT SLOT (Flag OR Icon) ---
	var slot_size = (h - hp_h) - 4.0  # Padding of 2px top/bottom
	var slot_pos = top_left + Vector2(3, 2)
	var slot_rect = Rect2(slot_pos, Vector2(slot_size, slot_size))

	if show_division_icon:
		# MODE A: Division Icon
		var type = troop.get_main_type()
		var icon_tex = load("res://assets/icons/hoi4/%s.png" % type)
		if icon_tex:
			draw_texture_rect(icon_tex, slot_rect, false)
	else:
		# MODE B: Country Flag
		var flag_tex = TroopManager.get_flag(troop.country_name)
		if flag_tex:
			draw_texture_rect(flag_tex, slot_rect, false)

	# --- 3. THE NUMBER (Right Side) ---
	var label = str(troop.divisions_count)
	var font_size = 18
	var text_size = _font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)

	# Position the number centered in the remaining space on the right
	var text_pos = Vector2(
		top_left.x + slot_size + (w - slot_size - text_size.x) / 2.0 + 2,
		top_left.y + (h - hp_h + text_size.y * 0.35) / 2.0
	)

	draw_string_outline(
		_font, text_pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 3, Color.BLACK
	)
	draw_string(_font, text_pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)

	# --- 4. THE HP BAR ---
	var hp_pct = troop.get_average_hp_percent()
	var hp_bg_rect = Rect2(top_left + Vector2(0, h - hp_h), Vector2(w, hp_h))
	draw_rect(hp_bg_rect, Color(0, 0, 0, 1.0), true)

	if hp_pct > 0:
		# Use your HP_COLORS constant if available, otherwise fallback
		var hp_col = HP_COLORS.healthy if hp_pct > 0.5 else HP_COLORS.critical
		draw_rect(Rect2(hp_bg_rect.position, Vector2(w * hp_pct, hp_h)), hp_col, true)

	draw_set_transform_matrix(Transform2D())


func _group_troops_by_visual_position(troops: Array) -> Dictionary:
	var g = {}
	for t in troops:
		# Get interpolated position if moving, else static position
		var visual_pos = t.position.lerp(t.target_position, t.get_meta("progress", 0.0)) if t.is_moving else t.position

		if not g.has(visual_pos):
			g[visual_pos] = []
		g[visual_pos].append(t)
	return g


func _draw_selection_box() -> void:
	if not is_instance_valid(TroopManager.troop_selection):
		return
	if not TroopManager.troop_selection.dragging:
		return

	var ts = TroopManager.troop_selection
	var rect = Rect2(ts.drag_start, ts.drag_end - ts.drag_start).abs()
	draw_rect(rect, Color(1, 1, 1, 0.3), true)
	draw_rect(rect, Color(1, 1, 1, 1), false, 1.0)


func _draw_path_preview() -> void:
	if not is_instance_valid(TroopManager.troop_selection):
		return
	if not TroopManager.troop_selection.right_dragging:
		return
	var path = TroopManager.troop_selection.right_path
	for i in range(path.size()):
		draw_circle(
			path[i]["map_pos"] + map_sprite.position, 
			1.0, 
			(
				COLORS.path_active
				if i < TroopManager.troop_selection.max_path_length
				else COLORS.path_inactive
			)
		)


func _draw_active_movements() -> void:
	var now = GameState.main.clock.total_game_seconds

	for troop in TroopManager.troops:
		if !troop.is_moving:
			continue
		var start = troop.position + map_sprite.position
		var end = troop.target_position + map_sprite.position
		if _screen_rect.has_point(start) or _screen_rect.has_point(end):
			draw_line(start, end, Color(1, 0, 0, 0.2), 1.0)
			draw_line(start, start.lerp(end, troop.get_meta("visual_progress", 0.0)), COLORS.movement_active, 1.5)

func _update_screen_rect():
	var canvas_xform := get_canvas_transform()

	_screen_rect = Rect2(
		- canvas_xform.origin / canvas_xform.get_scale(),
		get_viewport_rect().size / canvas_xform.get_scale()
	).grow(200.0)


func _draw_cities() -> void:
	if not MapManager.id_map_image:
		return

	var hovered_pid = MapManager.current_hovered_pid
	const base_dot_radius = 4.0
	const base_font_size = 24
	const offset = Vector2(10, base_font_size * 0.3)

	var zoom_vec = Vector2(_current_inv_zoom, _current_inv_zoom)

	for city_data in MapManager.all_cities:
		var pid = city_data[0]
		var city_name = city_data[1]

		var base_pos = MapManager.province_centers.get(pid, Vector2.ZERO)
		if base_pos == Vector2.ZERO:
			continue

		for j in range(-1, 2):
			var world_pos = base_pos + map_sprite.position + Vector2(map_width * j, 0)
			if not _screen_rect.has_point(world_pos):
				continue

			var t := Transform2D(0, zoom_vec, 0, world_pos)
			draw_set_transform_matrix(t)

			draw_circle(Vector2.ZERO, base_dot_radius, Color.WHITE)

			if pid == hovered_pid:
				draw_string_outline(
					_font,
					offset,
					city_name,
					HORIZONTAL_ALIGNMENT_LEFT,
					-1,
					base_font_size,
					4,
					Color(0, 0, 0, 0.8)
				)
				draw_string(
					_font,
					offset,
					city_name,
					HORIZONTAL_ALIGNMENT_LEFT,
					-1,
					base_font_size,
					Color.WHITE
				)

	draw_set_transform_matrix(Transform2D())


func draw_battles():
	var player_country = CountryManager.player_country.country_name if !GameState.selectingCountry else ""
	const base_radius = 1.0
	const ring_radius = 1.2
	const line_width = 0.5
	const start_angle = - PI * 0.5 # Top

	for battle in WarManager.active_battles:
		if not battle:
			continue

		var pos: Vector2 = battle.position
		var progress: float = battle.attack_progress

		# 1. Determine Win/Loss relative to player
		var is_player_involved = false
		var is_winning = false
		var display_ratio = progress

		if battle.attacker_country == player_country:
			is_player_involved = true
			is_winning = progress > 0.5
			display_ratio = progress
		elif battle.defender_country == player_country:
			is_player_involved = true
			is_winning = (1.0 - progress) > 0.5
			display_ratio = 1.0 - progress
		else:
			is_winning = true
			display_ratio = progress

		# 2. Your Exact Sizes

		# 3. Colors
		var arc_color = (Color(0.0, 1.0, 0.0) if is_winning else Color(1.0, 0.0, 0.0)) if is_player_involved else Color(0.8, 0.5, 0.0)

		# 4. Draw Background/Outline (Crucial for tiny icons)
		# We draw a slightly larger black circle first so the icon "pops"
		draw_circle(pos, ring_radius + 0.3, Color(0, 0, 0, 0.8))

		# 5. Draw Progress Arc
		var end_angle: float
		if is_winning:
			# Clockwise Green
			end_angle = start_angle + (display_ratio * TAU)
			draw_arc(pos, ring_radius, start_angle, end_angle, 16, arc_color, line_width, true)
		else:
			# Counter-Clockwise Red
			end_angle = start_angle - (display_ratio * TAU)
			draw_arc(pos, ring_radius, end_angle, start_angle, 16, arc_color, line_width, true)

		# 6. Static Center White Dot (No Pulse)
		draw_circle(pos, base_radius, Color.WHITE)
