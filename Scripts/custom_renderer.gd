extends Node2D
class_name CustomRenderer

# --- Constants & Config ---
const COLORS = {
	"background": Color(0, 0, 0, 0.8),
	"text": Color(1, 1, 1, 1),
	"border_default": Color(0, 1, 0, 1),
	"border_selected": Color(0.8, 0.8, 0.8),
	"border_other": Color(0, 0, 0, 1),
	"movement_active": Color(0, 1, 0, 0.8),
	"path_active": Color(1, 0.2, 0.2),
	"path_inactive": Color(0.5, 0.5, 0.5)
}

const LAYOUT = {"flag_width": 24.0, "flag_height": 20.0, "min_text_width": 16.0, "font_size": 16}

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
	z_index = 20  # Keep renderer high
	_setup_multimesh()


func _process(_delta: float) -> void:
	if !map_sprite: return

	var cam := get_viewport().get_camera_2d()
	if not cam: return

	# Camera/Zoom checks
	var zoom_changed := cam.zoom != _last_cam_zoom
	var pos_changed := cam.global_position != _last_cam_pos

	if zoom_changed or pos_changed:
		var raw_scale := 1.0 / cam.zoom.x
		_current_inv_zoom = clamp(raw_scale, ZOOM_LIMITS.min_scale, ZOOM_LIMITS.max_scale)
		_update_screen_rect()
		_last_cam_zoom = cam.zoom
		_last_cam_pos = cam.global_position

	var shader_clock = GameState.current_world.clock.total_game_seconds
	troop_multimesh.material.set_shader_parameter("game_time", shader_clock)
	# Always update the buffer because moving_troops change position every frame
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
	mm.use_custom_data = true

	var q_mesh = QuadMesh.new()
	q_mesh.size = Vector2(LAYOUT.flag_width + LAYOUT.min_text_width, LAYOUT.flag_height)
	mm.mesh = q_mesh

	# SHADER: Using modern Godot 4.5 canvas_item logic
	var mat = ShaderMaterial.new()
	mat.shader = Shader.new()
	mat.shader.code = """
shader_type canvas_item;

uniform float game_time; // Set this from GDScript every frame

void vertex() {
    // 1. Extract data from INSTANCE_CUSTOM
    vec2 start_pos = INSTANCE_CUSTOM.xy;
    float start_time = INSTANCE_CUSTOM.z;
    float duration = INSTANCE_CUSTOM.w;

    // 2. Calculate Progress
    float progress = 1.0;
    if (duration > 0.0) {
        // Use the uniform game_time so it stays in sync with your logic
        progress = clamp((game_time - start_time) / duration, 0.0, 1.0);
    }

    // 3. Get the Target Position
    // In a CanvasItem shader, the MODEL_MATRIX[3].xy gives you 
    // the position of the current instance in world space.
    vec2 target_pos = vec2(MODEL_MATRIX[3][0], MODEL_MATRIX[3][1]);
    
    // 4. Calculate the Offset
    // If progress is 0.0, offset is the full distance from target back to start.
    // If progress is 1.0, offset is vec2(0,0).
    vec2 offset = (start_pos - target_pos) * (1.0 - progress);
    
    // Applying the offset to the VERTEX moves the instance visually
    VERTEX += offset;
}

void fragment() {
    // Your existing border logic...
    float zoom = max(0.4, COLOR.a);
    float tx = 0.05 * zoom;
    float ty = 0.1 * zoom;
    bool is_border = UV.x < tx || UV.x > (1.0 - tx) || UV.y < ty || UV.y > (1.0 - ty);
    
    if (is_border) {
        COLOR = COLOR; 
    } else {
        COLOR = vec4(0.0, 0.0, 0.0, 0.8); 
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
	var selected_troops = TroopManager.troop_selection.selected_troops
	
	var visible_pids = CountryManager.player_country.visibile_pids
	for pid in visible_pids:
		var stack = TroopManager.troops_by_province.get(pid, [])
		var static_stack = stack.filter(func(t): return not t.is_moving)
		if static_stack.is_empty(): continue
		
		var base_pos = MapManager.province_centers.get(pid, Vector2.ZERO)
		idx = _write_stack_to_multimesh(static_stack, base_pos, idx, player_country, selected_troops)

	for troop in TroopManager.moving_troops:
		if visible_pids.has(troop.province_id):
			idx = _write_stack_to_multimesh([troop], troop.position, idx, player_country, selected_troops)

func _write_stack_to_multimesh(stack: Array, base_pos: Vector2, idx: int, player: String, selected: Array) -> int:
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
	_draw_path_preview()
	_draw_active_movements()
	_draw_selection_box()
	_draw_troops()
	_draw_cities()
	draw_battles()


func _draw_troops() -> void:
	if _current_inv_zoom > 1.5:
		return 
	
	var visible_pids = CountryManager.player_country.visibile_pids
	for pid in visible_pids:
		var stack = TroopManager.troops_by_province.get(pid, [])
		var static_stack = stack.filter(func(t): return not t.is_moving)
		if static_stack.is_empty(): continue
		
		var base_pos = MapManager.province_centers.get(pid, Vector2.ZERO)
		_draw_stack_labels(static_stack, base_pos)

	# 2. Draw Moving Troops (Individual)
	for troop in TroopManager.moving_troops:
		if visible_pids.has(troop.province_id): 
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

func _draw_troop(troop: TroopData, pos: Vector2) -> void:
	var t := Transform2D(0, Vector2(_current_inv_zoom, _current_inv_zoom), 0, pos)
	draw_set_transform_matrix(t)

	var total_w = LAYOUT.flag_width + LAYOUT.min_text_width
	var total_h = LAYOUT.flag_height
	var top_left = Vector2(-total_w / 2.0, -total_h / 2.0)

	# Draw Text (Right side)
	var label = str(troop.divisions_count)
	# Use the base font size; the transform handles the zoom-scaling for us!
	var font_size := LAYOUT.font_size
	var text_size := _font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)

	# Position text relative to the flag's right edge
	var text_area_x = top_left.x + LAYOUT.flag_width
	var tx = text_area_x + (LAYOUT.min_text_width - text_size.x) * 0.5
	var ty = text_size.y * 0.3  # Vertical center relative to (0,0)

	var flag_rect = Rect2(top_left, Vector2(LAYOUT.flag_width, total_h)).grow(-1.0)
	draw_texture_rect(TroopManager.get_flag(troop.country_name), flag_rect, false)

	draw_string(
		_font, Vector2(tx, ty), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, COLORS.text
	)

	# 3. Reset transform so other things draw correctly
	draw_set_transform_matrix(Transform2D())

func _draw_selection_box() -> void:
	if not TroopManager.troop_selection.dragging:
		return
	var ts = TroopManager.troop_selection
	var rect = Rect2(ts.drag_start, ts.drag_end - ts.drag_start).abs()
	draw_rect(rect, Color(1, 1, 1, 0.3), true)
	draw_rect(rect, Color(1, 1, 1, 1), false, 1.0)


func _draw_path_preview() -> void:
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
	var now := GameState.current_world.clock.total_game_seconds

#	var visible_pids = CountryManager.player_country.visibile_pids
	for troop in TroopManager.troops:
		if not troop.is_moving:# or !visible_pids.has(troop.province_id):
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

	var hovered_pid = MapManager.current_hovered_pid
	var base_dot_radius := 4.0
	var base_font_size := 24
	var s := _current_inv_zoom

	for city_data in MapManager.all_cities:
		var pid = city_data[0]
		var city_name = city_data[1]

		var base_pos: Vector2 = MapManager.province_centers.get(pid, Vector2.ZERO)
		if base_pos == Vector2.ZERO:
			continue

		var world_pos := base_pos + map_sprite.position
		if not _screen_rect.has_point(world_pos):
			continue

		var t := Transform2D(0, Vector2(s, s), 0, world_pos)
		draw_set_transform_matrix(t)

		draw_circle(Vector2.ZERO, base_dot_radius, Color.WHITE)

		if pid == hovered_pid:
			var offset := Vector2(10, base_font_size * 0.3)

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
	var player_country = CountryManager.player_country.country_name

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
		var base_radius = 1.0
		var ring_radius = 1.2
		var line_width = 0.5
		var start_angle = -PI / 2  # Top

		# 3. Colors
		var arc_color = Color.GOLD
		if is_player_involved:
			# High-saturation colors work better at tiny scales
			arc_color = Color(0.0, 1.0, 0.0) if is_winning else Color(1.0, 0.0, 0.0)
		else:
			arc_color = Color(0.8, 0.5, 0.0)

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
