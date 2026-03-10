extends Node2D
class_name TroopSelection

var font: Font = preload("res://font/TTT-Regular.otf")

# --- Constants ---
const FLAG_WIDTH_BASE := 24.0
const FLAG_HEIGHT_BASE := 20.0
const PADDING_BASE := 6.0
const GAP_BASE := 8.0
const CLICK_THRESHOLD := 2.0 # pixels – how far mouse can move and still count as a "click"

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
	var inv_zoom = 1.0 / cam.zoom.x if cam else 1.0

	var selected_list: Array[TroopData] = []
	var flag_size = Vector2(FLAG_WIDTH_BASE, FLAG_HEIGHT_BASE) * inv_zoom
	var pad = PADDING_BASE * inv_zoom

	for t in CountryManager.player_country.troops_country:
		var label = str(t.divisions_count)
		var font_size := CustomRenderer.LAYOUT.font_size
		var text_size = (
			font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size) * inv_zoom
		)

		var w = flag_size.x + (GAP_BASE * inv_zoom) + text_size.x + (pad * 2)
		var h = max(flag_size.y, text_size.y) + (pad * 2)
		var box_size = Vector2(w, h)
		var troop_world_center = t.position + map_sprite.position
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
	for troop in selected_list:
		max_path_length += troop.divisions_count


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


# --- Helper functions for the logic above ---
func _cleanup_empty_troops():
	# If a troop gave away all its divisions, delete it from the world
	for t in selected_troops:
		if t.stored_divisions.is_empty():
			TroopManager.remove_troop(t)


# --- Helpers to keep logic clean ---


func _find_template_troop_for_divs(batch: Array[DivisionData]) -> TroopData:
	# Find which troop currently owns the first division in this batch
	# to use as a template (country name, flag, etc)
	for t in selected_troops:
		if batch[0] in t.stored_divisions:
			return t
	return selected_troops[0]


# --- MODE A: Move only the units clicked in the UI ---
func _handle_selective_ui_move(div_objects: Array[DivisionData], path: Array) -> void:
	# Group the divisions by their current "parent" troop so we can split them
	var split_map = {} # { TroopData: Array[DivisionData] }
	for div in div_objects:
		var owner = TroopManager.find_troop_owning_division(div)
		if owner:
			if not split_map.has(owner):
				split_map[owner] = []
			split_map[owner].append(div)

	for original_troop in split_map:
		var divs_to_move = split_map[original_troop]

		# Remove these objects from the original stack
		for d in divs_to_move:
			original_troop.stored_divisions.erase(d)

		# Create the new troop instance for the split-off units
		var new_troop = TroopManager._create_new_split_troop(original_troop, divs_to_move)
		new_troop.path = path.duplicate()
		TroopManager._start_next_leg(new_troop)

		# If the original troop is now empty, delete it from the map
		if original_troop.stored_divisions.is_empty():
			TroopManager.remove_troop(original_troop)


# --- MODE B: Spread the whole selected army across the path ---
func _handle_frontline_spread(path: Array) -> void:
	# Collect ALL division objects from all selected troops
	var all_divs: Array[DivisionData] = []
	for t in selected_troops:
		all_divs.append_array(t.stored_divisions)
		# We will effectively "re-distribute" all these, so clear the originals
		t.stored_divisions.clear()

	@warning_ignore("integer_division")
	var divs_per_prov = max(1, all_divs.size() / path.size())
	var remainder = all_divs.size() % path.size()

	var div_index = 0
	for i in range(path.size()):
		var target_pid = path[i]
		var count = divs_per_prov + (1 if i < remainder else 0)

		var batch: Array[DivisionData] = []
		for j in range(count):
			if div_index < all_divs.size():
				batch.append(all_divs[div_index])
				div_index += 1

		if batch.is_empty():
			continue

		# Create a new troop for this province's portion of the frontline
		# We use the first selected troop as a template for country/flag
		var template = selected_troops[0]
		var new_troop = TroopManager._create_new_split_troop(template, batch)

		# Generate a path to that specific point on the frontline
		# (Assuming you have a pathfinder, otherwise just use the path subset)
		new_troop.path = path.slice(0, i + 1)
		TroopManager._start_next_leg(new_troop)

	# Clean up the now-empty original troops
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
