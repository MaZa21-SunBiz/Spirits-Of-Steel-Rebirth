extends Node2D
class_name TroopSelection

signal selection_changed

var font: Font = preload("res://font/TTT-Regular.otf")

# --- Constants ---
const FLAG_WIDTH_BASE := 24.0
const FLAG_HEIGHT_BASE := 20.0
const PADDING_BASE := 6.0
const GAP_BASE := 8.0
const CLICK_THRESHOLD := 1.0  # pixels – how far mouse can move and still count as a "click"

# --- State ---
var dragging: bool = false
var drag_start: Vector2 = Vector2.ZERO
var drag_end: Vector2 = Vector2.ZERO

var right_dragging: bool = false
var right_path: Array = []

@onready var map_sprite: Sprite2D = $"../../../MapContainer/CultureSprite"

# --- Path Length Limit ---
var max_path_length: int = 0
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


func deselect_all() -> void:
	selected_troops.clear()
	selection_changed.emit()


func _handle_mouse_motion() -> void:
	if dragging:
		drag_end = get_global_mouse_position()
		var drag_distance = drag_start.distance_to(drag_end)

		if drag_distance >= CLICK_THRESHOLD:
			_perform_selection()

	if right_dragging:
		if drag_start.distance_to(get_global_mouse_position()) >= CLICK_THRESHOLD:
			_sample_province_under_mouse()


func _handle_left_mouse(event: InputEventMouseButton) -> void:
	if !dragging and MapManager._is_mouse_over_ui():
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

		if selected_troops.size() > 0:
			MusicManager.play_sfx(MusicManager.SFX.TROOP_SELECTED)


func _handle_right_mouse(event: InputEventMouseButton) -> void:
	if event.pressed and not selected_troops.is_empty():
		right_dragging = true
		drag_start = get_global_mouse_position()
		right_path.clear()
		_sample_province_under_mouse()
	else:
		if not right_dragging:
			return

		_perform_path_assignment()
		right_path.clear()
		right_dragging = false


func _perform_selection() -> void:
	if not map_sprite:
		return

	var world_rect := Rect2(drag_start, drag_end - drag_start).abs()
	var texture_width := map_sprite.texture.get_width()
	var cam = get_viewport().get_camera_2d()
	var inv_zoom: float = 1.0 / cam.zoom.x if cam else 1.0

	var player_troops = CountryManager.player_country.troops_country
	var troops_by_province = {} # { province_id: [TroopData, ...] }
	for t in player_troops:
		if t.is_moving:
			continue
		if not troops_by_province.has(t.province_id):
			troops_by_province[t.province_id] = []
		troops_by_province[t.province_id].append(t)

	var troop_offsets = {}
	var scaled_vertical_offset := 20.0 * inv_zoom
	var card_offset := Vector2(3.0, -3.0) * inv_zoom

	for pid in troops_by_province:
		var p_troops = troops_by_province[pid]
		
		# Separate them by type
		var typed_groups = {} # { type: [TroopData, ...] }
		for t in p_troops:
			var t_type = t.get_main_type()
			if not typed_groups.has(t_type):
				typed_groups[t_type] = []
			typed_groups[t_type].append(t)
			
		var group_keys = typed_groups.keys()
		var start_y = (group_keys.size() - 1) * scaled_vertical_offset * 0.5
		
		for g_idx in range(group_keys.size()):
			var t_type = group_keys[g_idx]
			var group = typed_groups[t_type]
			
			var group_base_pos = Vector2(0, start_y - (g_idx * scaled_vertical_offset))
			
			for t_idx in range(group.size()):
				var t = group[t_idx]
				troop_offsets[t] = group_base_pos + (card_offset * t_idx)

	var selected_list: Array[TroopData] = []
	var box_size = Vector2(76.0, 32.0) * inv_zoom

	for t in player_troops:
		var visual_center = t.position
		if t.is_moving:
			var progress = t.get_meta("progress", 0.0)
			visual_center = t.position.lerp(t.target_position, progress)
		else:
			visual_center = t.position + troop_offsets.get(t, Vector2.ZERO)

		var troop_world_center = visual_center + map_sprite.position
		var troop_rect = Rect2(troop_world_center - box_size * 0.5, box_size)

		if _check_rect_intersection(world_rect, troop_rect, t.position.x, texture_width):
			selected_list.append(t)

	# Apply selection
	var additive = Input.is_key_pressed(KEY_SHIFT)
	if not additive:
		selected_troops.clear()

	for t in selected_list:
		if not selected_troops.has(t):
			selected_troops.append(t)

	# Update max_path_length based on current live selection
	max_path_length = 0
	for troop in selected_troops:
		max_path_length += troop.divisions_count
	selection_changed.emit()


func _check_rect_intersection(
	selection_rect: Rect2, troop_rect: Rect2, tx: float, tex_w: float
) -> bool:
	# Standard check
	if selection_rect.intersects(troop_rect):
		return true

	# Ghost check (Wrapping)
	var GHOST_MARGIN = 600.0
	if tx < GHOST_MARGIN:
		var wrapped = troop_rect
		wrapped.position.x += tex_w
		if selection_rect.intersects(wrapped):
			return true
	elif tx > tex_w - GHOST_MARGIN:
		var wrapped = troop_rect
		wrapped.position.x -= tex_w
		if selection_rect.intersects(wrapped):
			return true

	return false


func _sample_province_under_mouse() -> void:
	if not map_sprite:
		return

	# Stop sampling if we've reached max provinces
	if right_path.size() >= max_path_length:
		return

	var local_pos = get_global_mouse_position()
	var pid = MapManager.get_province_at_pos(local_pos, map_sprite)

	if pid <= 0:
		return

	# Don't add duplicate consecutive provinces
	if right_path.size() > 0 and right_path[-1]["pid"] == pid:
		return

	var center_tex = MapManager.province_centers.get(pid)
	if not center_tex:
		return

	right_path.append({"pid": pid, "map_pos": center_tex, "texture_pos": center_tex})

	print("Sampled province %d. Path length: %d/%d" % [pid, right_path.size(), max_path_length])


func _perform_path_assignment() -> void:
	if right_path.is_empty() or selected_troops.is_empty():
		return

	var path_pids = []
	for entry in right_path:
		if path_pids.is_empty() or path_pids[-1] != entry["pid"]:
			path_pids.append(entry["pid"])

	if path_pids.is_empty():
		return

	# =========================================================
	# PRE-CALC: Map each division to its owning troop (O(1))
	# =========================================================
	var div_owner_map: Dictionary = {}
	for t in selected_troops:
		for div in t.stored_divisions:
			div_owner_map[div] = t
	# =========================================================

	# 1. Cast the moving pool correctly
	var moving_pool: Array[DivisionData] = []

	for t in selected_troops:
		moving_pool.append_array(t.stored_divisions)

	# 2. Ensure the Dictionary values are typed arrays
	var pool_by_origin = {}

	for div in moving_pool:
		var owner = TroopManager.find_troop_owning_division(div)
		if owner:
			var origin_id = owner.province_id
			if not pool_by_origin.has(origin_id):
				var new_list: Array[DivisionData] = []
				pool_by_origin[origin_id] = new_list
			pool_by_origin[origin_id].append(div)

	var all_assignments = []

	for origin_id in pool_by_origin:
		var origin_batch = pool_by_origin[origin_id] as Array[DivisionData]

		var template = null
		for t in selected_troops:
			if t.province_id == origin_id:
				template = t
				break

		if not template:
			var troops_at_origin = TroopManager.get_troops_in_province(origin_id)
			if not troops_at_origin.is_empty():
				template = troops_at_origin[0]

		if not template:
			continue

		@warning_ignore("integer_division")
		var divs_per_target = int(origin_batch.size() / path_pids.size())  #
		var remainder = origin_batch.size() % path_pids.size()
		var current_batch_idx = 0

		for province_idx in range(path_pids.size()):
			var target_pid = path_pids[province_idx]
			var count_needed = divs_per_target + (1 if province_idx < remainder else 0)

			var final_divs: Array[DivisionData] = []

			for i in range(count_needed):
				if current_batch_idx < origin_batch.size():
					var div = origin_batch[current_batch_idx]

					# O(1) removal instead of scanning all troops
					if div_owner_map.has(div):
						var owner_troop = div_owner_map[div]
						owner_troop.stored_divisions.erase(div)
						div_owner_map.erase(div)
					# =============================================

					final_divs.append(div)
					current_batch_idx += 1

			if final_divs.is_empty():
				continue

			var new_troop = TroopManager._create_new_split_troop(template, final_divs)
			all_assignments.append({"troop": new_troop, "province_id": target_pid})

	TroopManager.command_move_assigned(all_assignments)
	_cleanup_empty_troops()

	selected_troops.clear()
	right_path.clear()
	selection_changed.emit()


# --- Helper functions for the logic above ---
func _cleanup_empty_troops():
	# If a troop gave away all its divisions, delete it from the world
	for t in selected_troops:
		if t.stored_divisions.is_empty():
			TroopManager.remove_troop(t)


func _print_troop_details(troop: TroopData) -> void:
	print("--- Selected Troop (Prov: %d) ---" % troop.province_id)
	for div in troop.stored_divisions:
		var hp_percent = int(div.hp)
		var exp_level = "Green"
		if div.experience > 0.7:
			exp_level = "Veteran"
		elif div.experience > 0.3:
			exp_level = "Trained"

		print(
			(
				" > %s [%s] - HP: %d%% - Exp: %s"
				% [div.name, div.type.to_upper(), hp_percent, exp_level]
			)
		)
