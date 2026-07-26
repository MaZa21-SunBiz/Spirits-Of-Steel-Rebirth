extends Node2D
class_name CustomRenderer

# --- Constants & Config ---
const ZOOM_LIMITS = {"min_scale": 0.05, "max_scale": 0.5}

# --- Variables ---
var _font: Font = preload("res://font/arial.TTF")
var map_sprite: Sprite2D
var map_width: float = 0.0
var _current_inv_zoom := 1.0
var _screen_rect: Rect2

var _last_cam_pos := Vector2.INF
var _last_cam_zoom := Vector2.INF


var multimesh_instance: MultiMeshInstance2D
var _multimesh: MultiMesh
var border_multimesh_instance: MultiMeshInstance2D
var _border_multimesh: MultiMesh

func _ready() -> void:
	z_index = 20
	_setup_multimesh()


func _setup_multimesh() -> void:
	# 1. Outer Black Border Mesh
	border_multimesh_instance = MultiMeshInstance2D.new()
	add_child(border_multimesh_instance)

	_border_multimesh = MultiMesh.new()
	_border_multimesh.transform_format = MultiMesh.TRANSFORM_2D
	_border_multimesh.use_colors = true
	var quad_border = QuadMesh.new()
	quad_border.size = Vector2(1, 1)
	_border_multimesh.mesh = quad_border
	border_multimesh_instance.multimesh = _border_multimesh

	# 2. Main Inner Troop Mesh
	multimesh_instance = MultiMeshInstance2D.new()
	add_child(multimesh_instance)

	_multimesh = MultiMesh.new()
	_multimesh.transform_format = MultiMesh.TRANSFORM_2D
	_multimesh.use_colors = true
	var quad = QuadMesh.new()
	quad.size = Vector2(1, 1)
	_multimesh.mesh = quad
	multimesh_instance.multimesh = _multimesh


func _process(_delta: float) -> void:
	if !is_instance_valid(map_sprite) or map_width <= 0:
		return

	var should_redraw := false
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
			should_redraw = true
	elif _screen_rect.size == Vector2.ZERO:
		_screen_rect = Rect2(-100000, -100000, 200000, 200000)

	if is_instance_valid(TroopManager) and not TroopManager.moving_troops.is_empty():
		should_redraw = true

	if is_instance_valid(TroopManager) and is_instance_valid(TroopManager.troop_selection):
		var ts = TroopManager.troop_selection
		if ts.dragging or ts.right_dragging:
			should_redraw = true

	if should_redraw:
		queue_redraw()


func rebuild_troops():
	queue_redraw()


func _draw() -> void:
	if !map_sprite or map_width <= 0:
		return
	_draw_active_movements()
	_draw_selection_box()
	_draw_right_drag_line()
	_draw_cities()
	_draw_shaped_troops()
	_draw_selected_highlights()


var _tri_points: PackedVector2Array = PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])

func _draw_shaped_troops() -> void:
	if not is_instance_valid(TroopManager) or _current_inv_zoom > 1.8 or not map_sprite:
		return

	var troops = TroopManager.troops
	var country_colors = MapManager.country_colors if is_instance_valid(MapManager) else {}

	for troop in troops:
		if not is_instance_valid(troop):
			continue

		var d_pos = troop.position + map_sprite.position
		if not _screen_rect.has_point(d_pos):
			continue

		var radius = clamp(3.5 + (troop.cached_divisions_count * 0.4), 3.5, 9.0) * _current_inv_zoom
		var border_radius = radius + (1.8 * _current_inv_zoom)

		var base_col = country_colors.get(troop.country_name, Color(0.8, 0.8, 0.8))
		var darker_col = base_col.darkened(0.3)
		var main_type = troop.cached_main_type

		if main_type == "artillery":
			# Triangle (Artillery)
			_draw_triangle(d_pos, border_radius, Color(0, 0, 0, 0.95))
			_draw_triangle(d_pos, radius, darker_col)
		elif main_type == "infantry":
			# Square (Infantry)
			var rect_border = Rect2(d_pos.x - border_radius, d_pos.y - border_radius, border_radius * 2.0, border_radius * 2.0)
			var rect_inner = Rect2(d_pos.x - radius, d_pos.y - radius, radius * 2.0, radius * 2.0)
			draw_rect(rect_border, Color(0, 0, 0, 0.95), true)
			draw_rect(rect_inner, darker_col, true)
		else:
			# Circle (Tanks / Armor / Default)
			draw_circle(d_pos, border_radius, Color(0, 0, 0, 0.95))
			draw_circle(d_pos, radius, darker_col)


func _draw_triangle(center: Vector2, radius: float, color: Color) -> void:
	_tri_points[0] = center + Vector2(0.0, -radius)
	_tri_points[1] = center + Vector2(radius * 0.866, radius * 0.5)
	_tri_points[2] = center + Vector2(-radius * 0.866, radius * 0.5)
	draw_colored_polygon(_tri_points, color)




func _draw_selected_highlights() -> void:
	if not is_instance_valid(TroopManager) or not is_instance_valid(TroopManager.troop_selection) or _current_inv_zoom > 1.8:
		return

	for st in TroopManager.troop_selection.selected_troops:
		if is_instance_valid(st):
			var d_pos = st.position + map_sprite.position
			if _screen_rect.has_point(d_pos):
				var radius = clamp(3.5 + (st.divisions_count * 0.4), 3.5, 9.0) * _current_inv_zoom
				draw_arc(d_pos, radius + (2.5 * _current_inv_zoom), 0, TAU, 16, Color(0, 1, 0, 0.95), 2.0 * _current_inv_zoom, true)


func _draw_right_drag_line() -> void:
	if not is_instance_valid(TroopManager.troop_selection):
		return
	var ts = TroopManager.troop_selection
	if not ts.right_dragging or ts.selected_troops.is_empty():
		return

	var path = ts.right_drag_path
	if path.is_empty():
		return

	if path.size() < 2 or ts.right_drag_start.distance_to(ts.right_drag_current) < 15.0:
		draw_circle(ts.right_drag_start, 7.0 * _current_inv_zoom, Color(0, 0, 0, 0.7))
		draw_circle(ts.right_drag_start, 5.0 * _current_inv_zoom, Color(0.1, 0.85, 0.4, 0.9))
	else:
		# Outer Glow/Shadow Path
		draw_polyline(PackedVector2Array(path), Color(0.0, 0.0, 0.0, 0.7), 4.5 * _current_inv_zoom)
		# Main Vibrant Path
		draw_polyline(PackedVector2Array(path), Color(0.15, 0.9, 0.45, 0.95), 2.5 * _current_inv_zoom)

		# Waypoint target nodes along path
		var count = ts.selected_troops.size()
		var total_length = 0.0
		var segment_lengths: Array[float] = []
		for i in range(path.size() - 1):
			var seg_len = path[i].distance_to(path[i + 1])
			segment_lengths.append(seg_len)
			total_length += seg_len

		for i in range(count):
			var target_dist = (float(i) / float(max(1, count - 1))) * total_length if count > 1 else 0.5 * total_length
			var pt = ts._get_point_at_distance_along_path(path, segment_lengths, target_dist)
			# Outer Dark Ring
			draw_circle(pt, 5.5 * _current_inv_zoom, Color(0, 0, 0, 0.9))
			# Inner Vibrant Node
			draw_circle(pt, 4.0 * _current_inv_zoom, Color(0.2, 1.0, 0.5, 1.0))


func _draw_selection_box() -> void:
	if not is_instance_valid(TroopManager.troop_selection):
		return
	var ts = TroopManager.troop_selection
	if not ts.dragging:
		return

	var rect = Rect2(ts.drag_start, ts.drag_end - ts.drag_start).abs()
	draw_rect(rect, Color(1, 1, 1, 0.25), true)
	draw_rect(rect, Color(1, 1, 1, 0.9), false, 1.0)


func _draw_active_movements() -> void:
	for troop in TroopManager.troops:
		if not is_instance_valid(troop) or not troop.is_moving:
			continue

		var start = troop.position + map_sprite.position
		var target = troop.target_position + map_sprite.position

		if _screen_rect.has_point(start) or _screen_rect.has_point(target):
			draw_line(start, target, Color(0.2, 0.9, 0.4, 0.6), 1.5 * _current_inv_zoom)


func _update_screen_rect():
	var canvas_xform := get_canvas_transform()
	var viewport_rect := get_viewport_rect()

	_screen_rect = Rect2(
		-canvas_xform.origin / canvas_xform.get_scale(),
		viewport_rect.size / canvas_xform.get_scale()
	)
	_screen_rect = _screen_rect.grow(200.0)


func _draw_cities() -> void:
	if not is_instance_valid(MapManager) or not MapManager.id_map_image:
		return

	var s := _current_inv_zoom
	var dot_radius := 3.5 * s

	for city in MapManager.all_cities:
		var pid: int = city.id
		var base_pos: Vector2 = MapManager.province_centers.get(pid, Vector2.ZERO)
		if base_pos == Vector2.ZERO:
			continue

		var draw_pos := (base_pos * map_sprite.scale) + map_sprite.position

		if not _screen_rect.has_point(draw_pos):
			continue

		draw_circle(draw_pos, dot_radius, Color(1, 1, 1, 0.75))


func draw_battles():
	var player_country = CountryManager.player_country.country_name if (is_instance_valid(CountryManager) and CountryManager.player_country) else ""

	for battle in WarManager.active_battles:
		if not battle:
			continue

		var pos: Vector2 = battle.position
		var draw_pos = pos + map_sprite.position

		if not _screen_rect.has_point(draw_pos):
			continue

		var progress: float = battle.attack_progress

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

		var base_radius = 10.0 * _current_inv_zoom
		var ring_radius = 14.0 * _current_inv_zoom
		var line_width = 3.0 * _current_inv_zoom
		var start_angle = -PI / 2

		var arc_color = Color.GOLD
		if is_player_involved:
			arc_color = Color(0.18, 0.8, 0.44) if is_winning else Color(0.9, 0.3, 0.23)
		else:
			arc_color = Color(0.95, 0.6, 0.1)

		draw_circle(draw_pos, ring_radius + 2.5 * _current_inv_zoom, Color(0, 0, 0, 0.85))

		var end_angle: float
		if is_winning:
			end_angle = start_angle + (display_ratio * TAU)
			draw_arc(draw_pos, ring_radius, start_angle, end_angle, 20, arc_color, line_width, true)
		else:
			end_angle = start_angle - (display_ratio * TAU)
			draw_arc(draw_pos, ring_radius, end_angle, start_angle, 20, arc_color, line_width, true)

		var pulse = 1.0 + 0.10 * sin(Time.get_ticks_msec() * 0.007)
		draw_circle(draw_pos, base_radius * pulse, Color.WHITE)
		draw_circle(draw_pos, base_radius * 0.5 * pulse, Color(0.75, 0.15, 0.15))
