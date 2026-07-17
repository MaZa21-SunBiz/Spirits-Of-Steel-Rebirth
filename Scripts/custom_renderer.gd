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
var icon_cache: Dictionary = {}


func _get_division_icon(type: String) -> Texture2D:
	if icon_cache.has(type):
		return icon_cache[type]
	var path = "res://assets/icons/hoi4/%s.png" % type.to_lower()
	if ResourceLoader.exists(path):
		var tex = load(path) as Texture2D
		icon_cache[type] = tex
		return tex
	icon_cache[type] = null
	return null


# --- Lifecycle ---
func _ready() -> void:
	z_index = 20  # Keep renderer high
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

	_update_multimesh_buffer()
	queue_redraw()


# --- MultiMesh Setup ---
func _setup_multimesh():
	if not troop_multimesh:
		troop_multimesh = MultiMeshInstance2D.new()
		troop_multimesh.name = "TroopMultiMesh"
		# Crucial: Move the boxes behind the labels
		troop_multimesh.z_index = -1
		add_child(troop_multimesh)

	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.use_colors = true
	mm.use_custom_data = true

	var q_mesh = QuadMesh.new()
	q_mesh.size = Vector2(LAYOUT.box_w + LAYOUT.box_w * 0.15, LAYOUT.box_h + LAYOUT.box_h * 0.15)
	mm.mesh = q_mesh

	# SHADER: Using modern Godot 4.5 canvas_item logic
	var mat = ShaderMaterial.new()
	mat.shader = Shader.new()
	mat.shader.code = """
shader_type canvas_item;

void vertex() {
	// Standard passthrough
}

void fragment() {
    float zoom = max(0.4, COLOR.a);
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
	troop_multimesh.material = mat
	troop_multimesh.multimesh = mm


func _update_multimesh_buffer():
	var mm = troop_multimesh.multimesh
	if not mm:
		return

	var player_country = CountryManager.player_country.country_name if CountryManager.player_country else ""
	var selected_dict = {}
	if is_instance_valid(TroopManager.troop_selection):
		for t in TroopManager.troop_selection.selected_troops:
			selected_dict[t] = true

	# Filter player troops and group by province
	var player_stacks = {} # { province_id: [TroopData, ...] }
	for troop in TroopManager.troops:
		if troop.country_name != player_country or troop.is_moving:
			continue
		var pid = troop.province_id
		if not player_stacks.has(pid):
			player_stacks[pid] = []
		player_stacks[pid].append(troop)

	# Calculate player moving troops
	var player_moving = []
	for troop in TroopManager.moving_troops:
		if troop.country_name == player_country:
			player_moving.append(troop)

	var idx = 0
	
	# For static player troops, we group them by main division type per province
	for pid in player_stacks:
		var stack = player_stacks[pid]
		var typed_groups = {} # { type_string: [TroopData, ...] }
		for troop in stack:
			var t_type = troop.get_main_type()
			if not typed_groups.has(t_type):
				typed_groups[t_type] = []
			typed_groups[t_type].append(troop)

		# Offset each typed group's stacks vertically
		var group_keys = typed_groups.keys()
		var scaled_vertical_offset := STACKING_OFFSET_Y * _current_inv_zoom
		var start_y = (group_keys.size() - 1) * scaled_vertical_offset * 0.5

		for g_idx in range(group_keys.size()):
			var t_type = group_keys[g_idx]
			var group = typed_groups[t_type]
			var group_pos = MapManager.province_centers.get(pid, Vector2.ZERO) + Vector2(0, start_y - (g_idx * scaled_vertical_offset))
			idx = _write_player_group_to_multimesh(group, group_pos, idx, selected_dict)

	for troop in player_moving:
		var visual_pos = troop.position
		if troop.is_moving:
			var progress = troop.get_meta("progress", 0.0)
			visual_pos = troop.position.lerp(troop.target_position, progress)
		idx = _write_player_group_to_multimesh([troop], visual_pos, idx, selected_dict)

	# Update mm instance count to fit idx exactly
	if mm.instance_count != idx:
		mm.instance_count = idx


func _write_player_group_to_multimesh(
	group: Array, base_pos: Vector2, idx: int, selected_dict: Dictionary
) -> int:
	var mm = troop_multimesh.multimesh
	var card_offset := Vector2(3.0, -3.0) * _current_inv_zoom
	var mm_scale := Vector2(_current_inv_zoom, _current_inv_zoom)

	for i in range(group.size()):
		var troop = group[i]
		# Bottom-to-top stacking: i = 0 is bottom, group.size()-1 is top
		var offset_pos = base_pos + (card_offset * i)
		var final_pos = offset_pos + map_sprite.position

		var col = COLORS.border_selected if selected_dict.has(troop) else COLORS.border_default

		mm.set_instance_transform_2d(idx, Transform2D(0, mm_scale, 0, final_pos))
		mm.set_instance_color(idx, col)
		
		var start_time = troop.get_meta("start_time") if troop.has_meta("start_time") else 0.0
		var duration = troop.get_meta("duration") if troop.has_meta("duration") else 0.0
		var start_pos = troop.get_meta("start_pos") if troop.has_meta("start_pos") else final_pos
		mm.set_instance_custom_data(idx, Color(start_pos.x, start_pos.y, start_time, duration))
		
		idx += 1
	return idx


func _draw() -> void:
	if !map_sprite or map_width <= 0:
		return
	_draw_path_preview()
	_draw_active_movements()
	_draw_selection_box()
	_draw_cities()
	_draw_troops()
	draw_battles()


func _draw_troops() -> void:
	if _current_inv_zoom > 1.5:
		return

	var player_country = CountryManager.player_country.country_name if CountryManager.player_country else ""

	# Group ALL static troops by province
	var static_stacks = {} # { province_id: [TroopData, ...] }

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
		_draw_province_troop_stack(stack, base_pos, player_country)

	# Draw moving troops
	for troop in TroopManager.moving_troops:
		var visual_pos = troop.position
		if troop.is_moving:
			var progress = troop.get_meta("progress", 0.0)
			visual_pos = troop.position.lerp(troop.target_position, progress)

		var d_pos = visual_pos + map_sprite.position
		if _screen_rect.has_point(d_pos):
			if troop.country_name == player_country:
				_draw_player_troop(troop, d_pos, true)
			else:
				_draw_ai_troop_circle(troop.country_name, troop.divisions_count, d_pos)


func _draw_province_troop_stack(province_troops: Array, base_pos: Vector2, player_country: String) -> void:
	var player_troops = []
	var ai_troops_by_country = {} # { country_name: [TroopData, ...] }

	for troop in province_troops:
		if troop.country_name == player_country:
			player_troops.append(troop)
		else:
			var c = troop.country_name
			if not ai_troops_by_country.has(c):
				ai_troops_by_country[c] = []
			ai_troops_by_country[c].append(troop)

	var visual_elements = []

	# Player groups by type
	var player_by_type = {}
	for troop in player_troops:
		var t = troop.get_main_type()
		if not player_by_type.has(t):
			player_by_type[t] = []
		player_by_type[t].append(troop)

	for t in player_by_type:
		visual_elements.append({
			"type": "player",
			"group": player_by_type[t]
		})

	# AI groups by country
	for c in ai_troops_by_country:
		visual_elements.append({
			"type": "ai",
			"country": c,
			"group": ai_troops_by_country[c]
		})

	var scaled_offset := STACKING_OFFSET_Y * _current_inv_zoom
	var start_y = (visual_elements.size() - 1) * scaled_offset * 0.5

	for i in range(visual_elements.size()):
		var elem = visual_elements[i]
		var elem_pos = base_pos + Vector2(0, start_y - (i * scaled_offset))
		var d_pos = elem_pos + map_sprite.position

		if _screen_rect.has_point(d_pos):
			if elem["type"] == "player":
				var group = elem["group"]
				var card_offset := Vector2(3.0, -3.0) * _current_inv_zoom
				var top_idx = group.size() - 1
				var top_pos = d_pos + (card_offset * top_idx)
				# Draw only the top card fully
				_draw_player_troop(group[top_idx], top_pos, true)
			else:
				var total_divs = 0
				for troop in elem["group"]:
					total_divs += troop.divisions_count
				_draw_ai_troop_circle(elem["country"], total_divs, d_pos)


const HP_COLORS = {
	"bg": Color(0.1, 0.1, 0.1, 0.95),
	"healthy": Color("#2ecc71"),   # Flat UI emerald green
	"damaged": Color("#f1c40f"),   # Flat UI sun yellow
	"critical": Color("#e74c3c")   # Flat UI alizarin red
}
const LAYOUT = {"box_w": 76.0, "box_h": 32.0, "hp_bar_h": 4.0, "font_size": 14}
var show_division_icon: bool = true   # Default to showing division icons for clear gameplay feedback


func _draw_player_troop(troop: TroopData, pos: Vector2, is_top: bool) -> void:
	# If we are zoomed out, we rely solely on the GPU-rendered MultiMesh plate 
	# and skip drawing any detailed overlays (flag, icon, text, HP bar) to save performance.
	if _current_inv_zoom >= 0.25:
		return

	var t := Transform2D(0, Vector2(_current_inv_zoom, _current_inv_zoom), 0, pos)
	draw_set_transform_matrix(t)

	var w = LAYOUT.box_w
	var h = LAYOUT.box_h
	var hp_h = LAYOUT.hp_bar_h
	var top_left = Vector2(-w / 2.0, -h / 2.0)

	# --- 1. THE STYLIZED PLATE ---
	# MultiMesh draws the background plate for player troops!
	if not is_top:
		draw_set_transform_matrix(Transform2D())
		return

	# --- 2. LEFT SLOT (Country Flag) ---
	var flag_w = 18.0
	var flag_h = 12.0
	var flag_pos = top_left + Vector2(6, (h - hp_h - flag_h) / 2.0)
	var flag_rect = Rect2(flag_pos, Vector2(flag_w, flag_h))

	var flag_tex = TroopManager.get_flag(troop.country_name)
	if flag_tex:
		draw_texture_rect(flag_tex, flag_rect, false)

	# --- 3. MIDDLE SLOT (Division Type Icon) ---
	var icon_size = 16.0
	var icon_pos = top_left + Vector2(28, (h - hp_h - icon_size) / 2.0)
	var icon_rect = Rect2(icon_pos, Vector2(icon_size, icon_size))

	var type = troop.get_main_type()
	var icon_tex = _get_division_icon(type)
	if icon_tex:
		draw_texture_rect(icon_tex, icon_rect, false)

	# --- 4. RIGHT SLOT (Division Count Number) ---
	var label = str(troop.divisions_count)
	var font_size = LAYOUT.font_size
	var text_size = _font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)

	# Position centered in the remaining right slot
	var text_pos = Vector2(
		top_left.x + 46.0 + (w - 46.0 - text_size.x) / 2.0,
		top_left.y + (h - hp_h + text_size.y * 0.35) / 2.0
	)

	draw_string_outline(
		_font, text_pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 3, Color(0, 0, 0, 0.85)
	)
	draw_string(_font, text_pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)

	# --- 5. THE HP BAR ---
	var hp_pct = troop.get_average_hp_percent()
	var hp_bg_rect = Rect2(top_left + Vector2(0, h - hp_h), Vector2(w, hp_h))
	
	# Draw HP background
	var hp_sb_bg = StyleBoxFlat.new()
	hp_sb_bg.bg_color = HP_COLORS.bg
	hp_sb_bg.set_corner_radius_all(0)
	hp_sb_bg.corner_radius_bottom_left = 4
	hp_sb_bg.corner_radius_bottom_right = 4
	draw_style_box(hp_sb_bg, hp_bg_rect)

	if hp_pct > 0:
		var hp_col = HP_COLORS.healthy
		if hp_pct < 0.35:
			hp_col = HP_COLORS.critical
		elif hp_pct < 0.75:
			hp_col = HP_COLORS.damaged

		var hp_fill_rect = Rect2(hp_bg_rect.position, Vector2(w * hp_pct, hp_h))
		var hp_sb_fill = StyleBoxFlat.new()
		hp_sb_fill.bg_color = hp_col
		hp_sb_fill.set_corner_radius_all(0)
		hp_sb_fill.corner_radius_bottom_left = 4
		if hp_pct >= 0.98:
			hp_sb_fill.corner_radius_bottom_right = 4
		draw_style_box(hp_sb_fill, hp_fill_rect)

	draw_set_transform_matrix(Transform2D())


func _draw_ai_troop_circle(country_name: String, divisions_count: int, pos: Vector2) -> void:
	var t := Transform2D(0, Vector2(_current_inv_zoom, _current_inv_zoom), 0, pos)
	draw_set_transform_matrix(t)

	var radius = 13.0
	
	if _current_inv_zoom >= 0.25:
		# Zoomed out: Draw a simple country-colored dot with a black outline and skip flag/badge
		var country_color = MapManager.country_colors.get(country_name, Color(0.5, 0.5, 0.5))
		draw_circle(Vector2.ZERO, radius + 2.0, Color.BLACK)
		draw_circle(Vector2.ZERO, radius, country_color)
		draw_set_transform_matrix(Transform2D())
		return

	# Draw background circle shadow/border
	draw_circle(Vector2.ZERO, radius + 2.0, Color(0, 0, 0, 0.8))
	
	# Draw country border
	var country_color = MapManager.country_colors.get(country_name, Color(0.5, 0.5, 0.5))
	draw_circle(Vector2.ZERO, radius + 1.0, country_color)
	
	# Draw circular flag
	var flag_tex = TroopManager.get_flag(country_name)
	if flag_tex:
		draw_circle_texture(flag_tex, radius)
	else:
		draw_circle(Vector2.ZERO, radius, country_color.darkened(0.2))

	# Draw division count badge in the top-right corner
	var badge_radius = 8.0
	var badge_pos = Vector2(9.0, -9.0)
	
	# Draw badge background
	draw_circle(badge_pos, badge_radius, Color(0, 0, 0, 0.9))
	draw_circle(badge_pos, badge_radius - 1.0, Color(0.18, 0.8, 0.44)) # Sleek green notification badge!
	
	# Draw badge text
	var badge_label = str(divisions_count)
	var badge_font_size = 11
	var badge_text_size = _font.get_string_size(badge_label, HORIZONTAL_ALIGNMENT_CENTER, -1, badge_font_size)
	
	# Center the text inside the badge
	var badge_text_pos = badge_pos + Vector2(-badge_text_size.x / 2.0, badge_text_size.y * 0.3)
	draw_string(_font, badge_text_pos, badge_label, HORIZONTAL_ALIGNMENT_LEFT, -1, badge_font_size, Color.WHITE)

	draw_set_transform_matrix(Transform2D())


func draw_circle_texture(tex: Texture2D, radius: float) -> void:
	var points = PackedVector2Array()
	var uvs = PackedVector2Array()
	var num_sides = 32
	for i in range(num_sides):
		var angle = i * TAU / num_sides
		var dir = Vector2(cos(angle), sin(angle))
		points.append(dir * radius)
		uvs.append(dir * 0.5 + Vector2(0.5, 0.5))
	draw_polygon(points, [Color.WHITE], uvs, tex)


func _group_troops_by_visual_position(troops_list: Array) -> Dictionary:
	var g = {}
	for t in troops_list:
		var visual_pos = t.position
		if t.is_moving:
			var progress = t.get_meta("progress", 0.0)
			visual_pos = t.position.lerp(t.target_position, progress)

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
		var p = path[i]["map_pos"] + map_sprite.position
		var col = (
			COLORS.path_active
			if i < TroopManager.troop_selection.max_path_length
			else COLORS.path_inactive
		)
		draw_circle(p, 1.0, col)


func _draw_active_movements() -> void:
	var now = GameState.main.clock.total_game_seconds

	for troop in TroopManager.troops:
		if not troop.is_moving:
			continue

		var start = troop.position + map_sprite.position
		var end = troop.target_position + map_sprite.position

		if not (_screen_rect.has_point(start) or _screen_rect.has_point(end)):
			continue

		var start_time = troop.get_meta("start_time", 0.0)
		var duration = troop.get_meta("duration", 0.0)

		var progress := 1.0
		if duration > 0.0:
			progress = clamp((now - start_time) / duration, 0.0, 1.0)

		var current = start.lerp(end, progress)

		# Full planned path (faint)
		draw_line(start, end, Color(1, 0, 0, 0.2), 1.0)

		# Active traveled portion (bright)
		draw_line(start, current, COLORS.movement_active, 1.5)


func _update_screen_rect():
	var canvas_xform := get_canvas_transform()
	var viewport_rect := get_viewport_rect()

	_screen_rect = Rect2(
		-canvas_xform.origin / canvas_xform.get_scale(),
		viewport_rect.size / canvas_xform.get_scale()
	)

	_screen_rect = _screen_rect.grow(200.0)


func _draw_cities() -> void:
	if not MapManager.id_map_image:
		return

	var s := _current_inv_zoom
	var dot_radius := 4.0 * s

	for city in MapManager.all_cities:
		var pid: int = city.id

		var base_pos: Vector2 = MapManager.province_centers.get(pid, Vector2.ZERO)
		if base_pos == Vector2.ZERO:
			continue

		var draw_pos := (base_pos * map_sprite.scale) + map_sprite.position

		if not _screen_rect.has_point(draw_pos):
			continue

		draw_circle(draw_pos, dot_radius, Color.WHITE)

func draw_battles():
	var player_country = CountryManager.player_country.country_name

	for battle in WarManager.active_battles:
		if not battle:
			continue

		var pos: Vector2 = battle.position
		var draw_pos = pos + map_sprite.position

		if not _screen_rect.has_point(draw_pos):
			continue

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

		# 2. Proportional Sizes based on Zoom
		var base_radius = 12.0 * _current_inv_zoom
		var ring_radius = 16.0 * _current_inv_zoom
		var line_width = 3.5 * _current_inv_zoom
		var start_angle = -PI / 2  # Top

		# 3. Colors
		var arc_color = Color.GOLD
		if is_player_involved:
			# High-saturation colors work better at tiny scales
			arc_color = Color(0.18, 0.8, 0.44) if is_winning else Color(0.9, 0.3, 0.23)
		else:
			arc_color = Color(0.95, 0.6, 0.1)

		# 4. Draw Background/Outline
		draw_circle(draw_pos, ring_radius + 3.0 * _current_inv_zoom, Color(0, 0, 0, 0.85))

		# 5. Draw Progress Arc
		var end_angle: float
		if is_winning:
			# Clockwise Green
			end_angle = start_angle + (display_ratio * TAU)
			draw_arc(draw_pos, ring_radius, start_angle, end_angle, 24, arc_color, line_width, true)
		else:
			# Counter-Clockwise Red
			end_angle = start_angle - (display_ratio * TAU)
			draw_arc(draw_pos, ring_radius, end_angle, start_angle, 24, arc_color, line_width, true)

		# 6. Pulse effect and center dot
		var pulse = 1.0 + 0.12 * sin(Time.get_ticks_msec() * 0.007)
		draw_circle(draw_pos, base_radius * pulse, Color.WHITE)
		draw_circle(draw_pos, base_radius * 0.5 * pulse, Color(0.75, 0.15, 0.15))
