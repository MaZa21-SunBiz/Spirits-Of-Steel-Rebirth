extends Node2D
class_name TroopRenderer

# ==============================================================================
# CONFIGURATION
# ==============================================================================

## VISUAL SETTINGS (Colors)
const COLORS = {
	"background":       Color(0, 0, 0, 0.8),
	"text":            Color(1, 1, 1, 1),
	"border_default":  Color(0, 1, 0, 1),   # Green (Yours)
	"border_selected":  Color(0.5, 0.5, 0.5), # Grey (Selected)
	"border_other":    Color(0, 0, 0, 1),    # Black (Others)
	"border_none":     Color(0, 0, 0, 0),
	"path_active":     Color(1, 0.2, 0.2),   # Red (Active path)
	"path_inactive":   Color(0.5, 0.5, 0.5), # Grey (Over limit)
	"movement_active": Color(0, 1, 0, 0.8),  # Green (Current movement)
	"movement_line":   Color(1, 0.2, 0.2, 1),# Red (Target line)
	"battle_positive": Color(0, 1, 0, 1),     # Green (Winning)
	"battle_negative":  Color(1, 0, 0, 1)      # Red (Losing)
}

## LAYOUT SETTINGS (Base sizes in SCREEN PIXELS)
const LAYOUT = {
	"flag_width":       24.0, 
	"flag_height":      20.0,
	"text_padding_x":   8.0,
	"min_text_width":   16.0,
	"border_thickness": 1.0,
	"border_other_px":  1.0,
	"font_size":        18
}

## ZOOM SCALING LIMITS
const ZOOM_LIMITS = {
	"min_scale":  0.12, 
	"max_scale":  4.0 
}

## SYSTEM SETTINGS
const GHOST_MARGIN := 10.0
const STACKING_RADIUS := 1.0
const STACKING_OFFSET_Y := 20

# ==============================================================================
# RESOURCES & STATE
# ==============================================================================

var _font: Font = preload("res://font/TTT-Regular.otf")
const BATTLE_ICON:  Texture2D = preload("res://assets/icons/battle_element_transparent.png")
var BATTLE_ICON_SIZE: Vector2 = BATTLE_ICON.get_size()

var map_sprite: Sprite2D
var map_width: float = 0.0
var troop_selection:  TroopSelection

var _current_inv_zoom := 1.0
var old_cam_x = 0.0


func _ready() -> void:
	add_to_group("TroopRenderer")
	z_index = 20
	
	# Try absolute path first
	troop_selection = get_tree().root.get_node_or_null("Game/UI/TroopSelection")
	
	# If not found, search by name
	if troop_selection == null:
		var found = get_tree().root.find_child("TroopSelection", true, false)
		if found is TroopSelection:
			troop_selection = found


func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_2d()
	
	if cam.zoom.x != old_cam_x:
		old_cam_x = cam.zoom.x
		var raw_scale = 1.0 / old_cam_x
		_current_inv_zoom = clamp(raw_scale, ZOOM_LIMITS.min_scale, ZOOM_LIMITS.max_scale)
	
	queue_redraw()


# ==============================================================================
# MAIN DRAWING LOOP
# ==============================================================================

func _draw() -> void:
	if not _can_draw():
		return

	# Draw in order:  background elements → troops → UI elements
	_draw_selection_box()
	_draw_troops()
	_draw_path_preview()
	_draw_active_movements()
	_draw_battles()


func _can_draw() -> bool:
	return (
		not TroopManager.troops.is_empty() 
		and map_sprite != null 
		and map_sprite.texture != null 
		and map_width > 0.0
	)


# ==============================================================================
# DRAWING:  SELECTION BOX
# ==============================================================================

func _draw_selection_box() -> void:
	if not troop_selection or not troop_selection.is_dragging_selection():
		return
	
	var selection_rect = troop_selection.get_selection_rect()
	if selection_rect.size == Vector2.ZERO:
		return
	
	draw_rect(selection_rect, Color(1.0, 1.0, 1.0, 1.0), false, 2.0)


# ==============================================================================
# DRAWING:  TROOPS
# ==============================================================================

func _draw_troops() -> void:
	var player_country = CountryManager.player_country.country_name
	var grouped_troops = _group_troops_by_position(TroopManager.troops, STACKING_RADIUS)

	for base_pos in grouped_troops.keys():
		var stack:  Array = grouped_troops[base_pos]
		var stack_size = stack.size()
		var scaled_offset = STACKING_OFFSET_Y * _current_inv_zoom
		var start_y_offset = (stack_size - 1) * scaled_offset * 0.5

		for i in range(stack_size):
			var t = stack[i]
			var troop_position = base_pos + map_sprite.position
			var current_y_offset = start_y_offset - (i * scaled_offset)
			var offset_pos = troop_position + Vector2(0, current_y_offset)

			# Draw for infinite scroll (-1, 0, 1)
			for j in [-1, 0, 1]: 
				var scroll_offset = Vector2(map_width * j, 0)
				_draw_single_troop_visual(t, offset_pos + scroll_offset, player_country)


func _group_troops_by_position(troops: Array, radius: float) -> Dictionary:
	var groups = {}
	var processed_indices = []

	for i in range(troops.size()):
		if i in processed_indices:
			continue

		var t1 = troops[i]
		var group_key = t1.position
		
		groups[group_key] = [t1]
		processed_indices.append(i)

		# Find all other troops close to t1
		for j in range(i + 1, troops.size()):
			var t2 = troops[j]
			
			if t1.position.distance_to(t2.position) < radius:
				groups[group_key].append(t2)
				processed_indices.append(j)

	return groups


func _draw_single_troop_visual(troop: TroopData, pos: Vector2, player_country:  String) -> void:
	var label_text := str(troop.divisions)
	var scale_factor = _current_inv_zoom
	
	# Determine style (border color & thickness)
	var style = _get_troop_style(troop, player_country)
	var current_border_width = max(0.25, style.width * scale_factor)

	# Calculate dimensions
	var flag_size = Vector2(LAYOUT.flag_width, LAYOUT.flag_height) * scale_factor
	var font_size_world = LAYOUT.font_size * scale_factor
	var raw_text_size = _font.get_string_size(label_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 18) * scale_factor
	
	var min_text_w_world = LAYOUT.min_text_width * scale_factor
	var padding_world = LAYOUT.text_padding_x * scale_factor
	var final_text_area_width = max(raw_text_size.x + padding_world, min_text_w_world)
	
	var total_width = flag_size.x + final_text_area_width
	var total_height = flag_size.y
	var box_size = Vector2(total_width, total_height)
	var box_rect = Rect2(pos - box_size * 0.5, box_size)
	
	# Draw background
	var bg_rect = box_rect.grow(-current_border_width * 0.5)
	if bg_rect.size.x > 0 and bg_rect.size.y > 0:
		draw_rect(bg_rect, COLORS.background, true)
	
	# Draw flag (left side)
	var flag_rect = Rect2(box_rect.position, flag_size)
	if troop.flag_texture: 
		draw_texture_rect(troop.flag_texture, flag_rect, false)
	else:
		draw_rect(flag_rect, Color(0.5, 0.5, 0.5), true)
		
	# Draw text (right side - centered)
	var text_start_x = box_rect.position.x + flag_size.x
	var text_center_x = text_start_x + (final_text_area_width * 0.5)
	var draw_pos_x = text_center_x - (raw_text_size.x * 0.5)
	var text_y_center = box_rect.position.y + (total_height * 0.5)
	var text_y_baseline = text_y_center + (raw_text_size.y * 0.25)
	
	draw_string(
		_font,
		Vector2(draw_pos_x, text_y_baseline),
		label_text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		font_size_world,
		COLORS.text
	)
	
	# Draw border
	if style.color != COLORS.border_none:
		draw_rect(box_rect, style.color, false, current_border_width)


func _get_troop_style(troop: TroopData, player_country: String) -> Dictionary:
	var is_owner = troop.country_name.to_lower() == player_country
	var is_selected = troop_selection and troop_selection.is_troop_selected(troop)
	
	if is_owner:
		if is_selected:
			return { "color": COLORS.border_selected, "width":  LAYOUT.border_thickness }
		else:
			return { "color":  COLORS.border_default, "width": LAYOUT.border_thickness }
	else: 
		return { "color": COLORS.border_other, "width": LAYOUT.border_other_px }


# ==============================================================================
# DRAWING: PATH PREVIEW
# ==============================================================================

func _draw_path_preview() -> void:
	if not troop_selection or not troop_selection.is_tracing_path():
		return
	
	var right_path = troop_selection.get_right_path()
	var max_path_length = troop_selection.get_max_path_length()
	
	if right_path.is_empty():
		return
	
	for i in range(right_path.size()):
		var p = right_path[i]["map_pos"] + map_sprite.position
		var is_over_limit = i >= max_path_length
		var color = COLORS.path_inactive if is_over_limit else COLORS.path_active
		
		draw_circle(p, 1, color)
		
		if i < right_path.size() - 1:
			draw_line(p, right_path[i + 1]["map_pos"] + map_sprite.position, color, 1.5)


# ==============================================================================
# DRAWING: ACTIVE MOVEMENTS
# ==============================================================================

func _draw_active_movements() -> void:
	for troop in TroopManager.troops:
		if not troop.is_moving:
			continue
		
		var start_local = troop.position + map_sprite.position
		var end_local = troop.target_position + map_sprite.position
		var visual_progress = troop.get_meta("visual_progress", 0.0) as float
		var current_visual_pos = start_local.lerp(end_local, visual_progress)
		
		draw_line(start_local, current_visual_pos, COLORS.movement_active, 2.0)
		draw_line(start_local, end_local, COLORS.movement_line, 1.0)


# ==============================================================================
# DRAWING: BATTLES
# ==============================================================================

func _draw_battles() -> void:
	for battle in WarManager.active_battles:
		var pos = battle.position + map_sprite.position
		var tex := BATTLE_ICON
		var size := tex.get_size() * 0.05
		var draw_pos = pos - size * 0.5

		var p = battle.get_player_relative_progress(CountryManager.player_country.country_name)
		var color := COLORS.battle_positive if p >= 0.0 else COLORS.battle_negative
		
		draw_circle(pos, 1.3, color)
		draw_texture_rect(tex, Rect2(draw_pos, size), false)
