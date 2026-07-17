extends Node
var DEBUG_MODE = false

enum MapMode { POLITICAL, POPULATION, GDP, ETHNICITY }

signal province_hovered(province_id: int)
signal country_clicked(country_name: String)

# Emitted when a click couldn't be processed (so likely sea or border)
signal close_sidemenu

# The exact colors you provided
const SEA_MAIN = Color("#7e8e9e")
const SEA_RASTER = Color("#697684")

# --- DATA ---
var id_map_image: Image
var state_color_image: Image
var state_color_texture: ImageTexture
var max_province_id: int = 0

var country_colors: Dictionary = {}
var map_data: Dictionary = {}

var country_to_provinces: Dictionary = {}
var country_to_provinces_obj: Dictionary = {}
var province_objects: Dictionary[int, Province] = {}

var adjacency_list: Dictionary = {}
var current_hovered_pid: int = -1
var last_hovered_pid: int = -1
var original_hover_color: Color
var province_centers: Dictionary = {}

var global_claims_registry: Dictionary = {}

var all_cities = []

const MAP_DATA_PATH = "res://map_data/MapData.tres"
const CACHE_FOLDER = "res://map_data/"

@export var region_texture: Texture2D
@export var culture_texture: Texture2D


func _ready():
	load_world_data()
	_build_global_registry()
	all_cities = get_all_cities()
	CountryManager.initialize_countries()


func load_world_data() -> void:
	_load_country_colors()
	_load_map_data_json("res://map_data/full_map_data.json")
	var dir = DirAccess.open("res://")
	if dir and not dir.dir_exists(CACHE_FOLDER):
		dir.make_dir_recursive(CACHE_FOLDER)

	if !DEBUG_MODE:
		if _try_load_cached_data():
			print("MapManager: Loaded cached data with Province Objects.")
			return

	var region = region_texture if region_texture else preload("res://maps/regions.png")
	var culture = culture_texture if culture_texture else preload("res://maps/cultures.png")

	_generate_and_save(region, culture)


func _generate_and_save(
	region: Texture2D,
	culture: Texture2D,
) -> void:
	initialize_map(region, culture)

	var map_data := MapData.new()
	map_data.province_centers = province_centers.duplicate()
	map_data.adjacency_list = adjacency_list.duplicate(true)
	map_data.country_to_provinces = country_to_provinces.duplicate()
	map_data.max_province_id = max_province_id
	map_data.id_map_image = id_map_image.duplicate()
	map_data.province_objects = province_objects.duplicate()

	ResourceSaver.save(map_data, MAP_DATA_PATH)


func _try_load_cached_data() -> bool:
	if not ResourceLoader.exists(MAP_DATA_PATH):
		return false
	var loaded := ResourceLoader.load(MAP_DATA_PATH) as MapData
	if not loaded:
		return false

	province_centers = loaded.province_centers
	adjacency_list = loaded.adjacency_list
	country_to_provinces = loaded.country_to_provinces
	max_province_id = loaded.max_province_id
	id_map_image = loaded.id_map_image
	province_objects.assign(loaded.province_objects)

	_province_finishing_touches()
	_build_lookup_texture()
	return true


func initialize_map(
	region_tex: Texture2D,
	culture_tex: Texture2D,
) -> void:
	var r_img = region_tex.get_image()
	var c_img = culture_tex.get_image()

	var w = r_img.get_width()
	var h = r_img.get_height()

	id_map_image = Image.create(w, h, false, Image.FORMAT_RGB8)

	var found_regions = {}  # Stores { "ColorString": ProvinceID }
	var next_id = 2

	# Pre-fetch data images so we don't pass textures around
	var data_images = {"culture": c_img}  # Needed for sea/country check

	for y in range(h):
		for x in range(w):
			var r_color = r_img.get_pixel(x, y)

			# 1. Handle Borders immediately
			if r_color.a == 0 or r_color == Color.BLACK:
				_write_id(x, y, 1)
				continue

			# 2. Check if we have seen this region color before
			# Note: We use the hex string as the dictionary key
			var key = r_color.to_html(false)

			if key in found_regions:
				# We know this province, just paint the ID map
				_write_id(x, y, found_regions[key])
			else:
				# 3. NEW PROVINCE FOUND!
				# Register it and sample stats only ONCE at this (x,y)
				var new_pid = next_id
				found_regions[key] = new_pid

				_create_province_from_pixel(new_pid, x, y, r_color, data_images)

				_write_id(x, y, new_pid)
				next_id += 1

	max_province_id = next_id - 1
	_finalize_map_processing()


func _create_province_from_pixel(
	pid: int, x: int, y: int, r_color: Color, images: Dictionary
) -> void:
	var province = Province.new()
	province.id = pid

	# Check Sea/Land using Culture Map at (x,y)
	var c_color = images.culture.get_pixel(x, y)

	if _is_sea(c_color):
		province.type = Province.SEA
		province.country = "sea"
		# Sea has 0 stats, skip other lookups
	else:
		province.type = Province.LAND
		province.country = _identify_country(c_color)

		var province_data = get_data_for_color(r_color)

		province.r_color = r_color
		province.population = province_data.population
		province.gdp = province_data.gdp
		province.city = province_data.city
		province.ethnicity = province_data.ethnicity
		province.claims = province_data.claims

		if len(province.city) > 0:
			province.factory = Province.FACTORY_BUILT

	# Store Logic
	province_objects[pid] = province


func _finalize_map_processing():
	# post-processing
	_calculate_province_centroids()
	_build_country_to_provinces()
	_build_adjacency_list()
	_province_finishing_touches()  # note z21: renamethis to something better
	_build_lookup_texture()


func _province_finishing_touches():
	country_to_provinces_obj.clear()

	for prov in province_objects.values():
		# rebuild neighbor object references
		prov.neighbors_obj.clear()
		for pid in prov.neighbors:
			var neighbor = province_objects.get(int(pid), null)
			if neighbor != null:
				prov.neighbors_obj.append(neighbor)

		# rebuild country -> province object mapping
		var c = prov.country.to_lower()

		if !country_to_provinces_obj.has(c):
			country_to_provinces_obj[c] = []

		country_to_provinces_obj[c].append(prov)


func _build_country_to_provinces():
	var result: Dictionary = {}
	for province in province_objects.values():
		var country = province.country
		if not result.has(country):
			result[country] = []
		result[country].append(province.id)
	country_to_provinces = result
	return


func draw_province_centroids(image: Image, color: Color = Color(0, 1, 0, 1)) -> void:
	if not image:
		push_warning("No Image provided for drawing centroids!")
		return

	for pid in province_centers.keys():
		var center = province_centers[pid]
		var x = int(round(center.x))
		var y = int(round(center.y))

		# stay inside bounds
		if x >= 0 and x < image.get_width() and y >= 0 and y < image.get_height():
			image.set_pixel(x, y, color)


func _write_id(x: int, y: int, pid: int) -> void:
	var r = float(pid % 256) / 255.0
	var g = pid / 256.0 / 255.0
	id_map_image.set_pixel(x, y, Color(r, g, 0.0))


func _build_lookup_texture() -> void:
	state_color_image = Image.create(max_province_id + 1, 1, false, Image.FORMAT_RGBA8)

	for pid in range(max_province_id + 1):
		if pid <= 1:
			state_color_image.set_pixel(pid, 0, Color(0, 0, 0, 0))
			continue
		var province = province_objects.get(pid)

		if province == null or province.type == 0:  # 0 is province.SEA
			state_color_image.set_pixel(pid, 0, Color(0, 0, 0, 0))
			continue

		var country = province.country
		var col = country_colors.get(country, Color.GRAY)
		state_color_image.set_pixel(pid, 0, col)

	state_color_texture = ImageTexture.create_from_image(state_color_image)


func _is_sea(c: Color) -> bool:
	return _dist_sq(c, SEA_RASTER) < 0.001 or _dist_sq(c, SEA_MAIN) < 0.001


func _identify_country(c: Color) -> String:
	var best := ""
	var min_dist := 0.05
	for country_name in country_colors.keys():
		var dist := _dist_sq(c, country_colors[country_name])
		if dist < min_dist:
			min_dist = dist
			best = country_name
	return best


func _dist_sq(c1: Color, c2: Color) -> float:
	return (c1.r - c2.r) ** 2 + (c1.g - c2.g) ** 2 + (c1.b - c2.b) ** 2


func update_province_color(pid: int, country_name: String) -> void:
	if pid <= 1 or pid > max_province_id:
		return

	var new_color = country_colors.get(country_name, Color.GRAY)
	_update_lookup(pid, new_color)

	if pid == last_hovered_pid:
		original_hover_color = new_color
		_update_lookup(pid, new_color + Color(0.15, 0.15, 0.15, 0))


func set_country_color(country_name: String, custom_color: Color = Color.TRANSPARENT) -> void:
	var new_color = custom_color
	if new_color == Color.TRANSPARENT:
		new_color = country_colors.get(country_name, Color.GRAY)

	var provinces = country_to_provinces.get(country_name, [])

	if provinces.is_empty():
		print("Warning: No provinces found for country: ", country_name)
		return

	for pid in provinces:
		_update_lookup(pid, new_color)

		if pid == last_hovered_pid:
			original_hover_color = new_color
			_update_lookup(pid, new_color + Color(0.15, 0.15, 0.15, 0))


func get_province_at_pos(pos: Vector2, map_sprite: Sprite2D = null) -> int:
	if not id_map_image:
		return 0

	var size = id_map_image.get_size()
	var x: int
	var y: int

	if map_sprite:
		var local = map_sprite.to_local(pos)
		var tex_size = map_sprite.texture.get_size()

		if map_sprite.centered:
			local += tex_size / 2.0

		x = posmod(int(local.x), int(tex_size.x))
		y = int(local.y)
	else:
		x = int(pos.x)
		y = int(pos.y)

	if y < 0 or y >= size.y or x < 0 or x >= size.x:
		return 0

	var pixel_index = (y * size.x + x) * 3
	var data = id_map_image.get_data()

	var r = data[pixel_index]  # Red byte (0-255)
	var g = data[pixel_index + 1]  # Green byte (0-255)

	return r + (g << 8)  # Using bit-shift (<< 8) is slightly faster than (g * 256)


func handle_hover(global_pos: Vector2, map_sprite: Sprite2D) -> void:
	if _is_mouse_over_ui():
		_reset_last_hover()
		return

	var pid = get_province_at_pos(global_pos, map_sprite)
	current_hovered_pid = pid
	
	var highlight_color = _get_contextual_highlight(pid)
	province_hovered.emit(pid)

	if pid != last_hovered_pid:
		_reset_last_hover()  # Clean up the old one
		
		if pid > 1 and highlight_color != Color.TRANSPARENT:
			original_hover_color = state_color_image.get_pixel(pid, 0)
			_update_lookup(pid, highlight_color)

			last_hovered_pid = pid
			Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)
		else:
			Input.set_default_cursor_shape(Input.CURSOR_ARROW)
			province_hovered.emit(-1)


func _reset_last_hover() -> void:
	if last_hovered_pid > 1:
		_update_lookup(last_hovered_pid, original_hover_color)
	last_hovered_pid = -1


func _get_contextual_highlight(pid: int) -> Color:
	if pid <= 1:
		return Color.TRANSPARENT

	var player_name = CountryManager.player_country.country_name
	var is_player_owned = province_objects[pid].country == player_name

	if not is_player_owned:
		return Color.TRANSPARENT

	if GameState.industry_building == GameState.IndustryType.PORT:
		var coastal_provinces = get_provinces_near_sea(player_name)
		if pid in coastal_provinces && !province_objects[pid].port == Province.PORT_BUILT:
			return Color.CYAN
		else:
			return Color.TRANSPARENT

	elif GameState.choosing_deploy_city:
		if province_objects[pid].city.length() > 0:
			return Color.CYAN.lightened(0.3)
		return Color.TRANSPARENT  # Don't highlight non-city provinces during deploy

	elif GameState.industry_building != GameState.IndustryType.DEFAULT:
		return state_color_image.get_pixel(pid, 0).lightened(0.2).blend(Color.GREEN_YELLOW)

	return Color.TRANSPARENT


func handle_click_down(global_pos: Vector2, map_sprite: Sprite2D) -> void:
	if _is_mouse_over_ui() or Console.is_visible():
		return

	TroopManager.troop_selection.deselect_all()


func handle_click(global_pos: Vector2, map_sprite: Sprite2D) -> void:
	if _is_mouse_over_ui() or Console.is_visible():
		return

	var pid = get_province_with_radius(global_pos, map_sprite, 5)

	# 1. Handle Clicks on Water or Invalid Areas
	if pid <= 1 or province_objects[pid].type == 0:  # 0 is SEA
		if GameState.industry_building != GameState.IndustryType.DEFAULT:
			GameState.reset_industry_building()
			show_countries_map()
		else:
			close_sidemenu.emit()
		return

	var player_country_name = CountryManager.player_country.country_name
	var is_player_owned = province_objects[pid].country == player_country_name

	if GameState.choosing_deploy_city:
		if is_player_owned:
			_execute_deployment(pid, player_country_name)
		else:
			print("Action Failed: Province not owned by player.")

	elif GameState.industry_building != GameState.IndustryType.DEFAULT:
		if is_player_owned:
			_province_build_industry(pid, player_country_name)
		else:
			print("Action Failed: Cannot build in foreign territory.")
			GameState.reset_industry_building()
			show_countries_map()

	if (
		TroopManager.troop_selection.selected_troops.is_empty()
		and GameState.industry_building == GameState.IndustryType.DEFAULT
	):  # Prevent menu from spawning when selecting troops (annoying)
		country_clicked.emit(province_objects[pid].country)


func highlight_country(country_name: String) -> void:
	if country_name == "" or country_name == "sea":
		return

	var provinces = country_to_provinces.get(country_name, [])
	var base_color = country_colors.get(country_name, Color.GRAY)
	var light_color = base_color.lightened(0.2)

	for pid in provinces:
		var prov = province_objects.get(pid)
		if prov and not prov.troops_here.is_empty():
			continue # Do not highlight provinces with troops on them
		_update_lookup(pid, light_color)

	state_color_texture.update(state_color_image)


## Restores the country to its original data-defined color
func restore_country_color(country_name: String) -> void:
	if country_name == "" or country_name == "sea":
		return

	var provinces = country_to_provinces.get(country_name, [])
	var original_color = country_colors.get(country_name, Color.GRAY)

	for pid in provinces:
		_update_lookup(pid, original_color)

	state_color_texture.update(state_color_image)


func _execute_deployment(pid: int, player_name: String) -> void:
	country_clicked.emit(player_name)
	CountryManager.player_country.deploy_pid = pid
	GameState.choosing_deploy_city = false
	_cleanup_interaction_state()


func _province_build_industry(pid: int, player_name: String) -> void:
	var type := GameState.industry_building
	var province = province_objects[pid]
	var country = CountryManager.get_country(player_name)

	# 1. Safety Check: Is there already something there or currently building?
	# Using your Enums: 0 = NO, 1 = BUILDING, 2 = BUILT
	if type == GameState.IndustryType.FACTORY:
		if province.factory != province.NO_FACTORY:
			print("Cannot build: Factory slot is busy or full.")
			return
		
		country.build_factory(province)

		_cleanup_interaction_state()
		show_industry_country(player_name)

	elif type == GameState.IndustryType.PORT:
		if province.port != province.NO_PORT:
			print("Cannot build: Port slot is busy or full.")
			return

		# 3. Sea check for Ports
		if pid in get_provinces_near_sea(player_name):
			country.build_port(province)
			_cleanup_interaction_state()
			show_industry_country(player_name)
		else:
			print("Action Failed: Port must be on a coast!")
			return


func _cleanup_interaction_state() -> void:
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	if last_hovered_pid > 1:
		_update_lookup(last_hovered_pid, original_hover_color)
		last_hovered_pid = -1


# To probe around and still register a click if we hit province/coutnry border
const PROBE_OFFSETS = [
	Vector2(0, 0),
	Vector2(1, 0),
	Vector2(-1, 0),
	Vector2(0, 1),
	Vector2(0, -1),
	Vector2(1, 1),
	Vector2(1, -1),
	Vector2(-1, 1),
	Vector2(-1, -1)
]


func get_province_with_radius(center: Vector2, map_sprite: Sprite2D, radius: int) -> int:
	var r = float(radius)

	for off in PROBE_OFFSETS:
		var pos = center + off * r
		var pid = get_province_at_pos(pos, map_sprite)
		if pid > 1:
			return pid

	return -1


func get_lighter_country_color(country: String, amount: float = 0.5) -> Color:
	var country_color: Color = country_colors.get(country)
	return country_color.lightened(amount)


func update_province_troop_state(pid):
	var prov_obj = province_objects[pid]
	if prov_obj.troops_here.is_empty():
		update_province_color(pid, prov_obj.country)
	else:
		_update_lookup(pid, get_lighter_country_color(prov_obj.country, 0.3))


func _update_lookup(pid: int, color: Color) -> void:
	state_color_image.set_pixel(pid, 0, color)
	state_color_texture.update(state_color_image)


func _calculate_province_centroids() -> void:
	# Use a dictionary to accumulate data: {ID: [total_x, total_y, pixel_count]}
	var accumulators: Dictionary = {}

	# Initialize accumulators for all valid province IDs (IDs > 1)
	for i in range(2, max_province_id + 1):
		accumulators[i] = [0.0, 0.0, 0]

	var w = id_map_image.get_width()
	var h = id_map_image.get_height()

	# --- Pass 1: Accumulate Coordinates ---
	for y in range(h):
		for x in range(w):
			var pid = get_province_at_pos(Vector2(x, y), null)  # Use direct coordinates, sprite is null

			if pid > 1 and accumulators.has(pid):
				accumulators[pid][0] += x
				accumulators[pid][1] += y
				accumulators[pid][2] += 1

	# --- Pass 2: Calculate Average (Centroid) ---
	for pid in accumulators:
		var data = accumulators[pid]
		var total_pixels = data[2]

		if total_pixels > 0:
			var center_x = data[0] / total_pixels
			var center_y = data[1] / total_pixels

			# Store the resulting centroid as a Vector2
			province_centers[pid] = Vector2(center_x, center_y)
			if province_objects.has(pid):
				province_objects[pid].center = Vector2(center_x, center_y)

	print("MapManager: Centroids calculated for %d provinces." % province_centers.size())


func _build_adjacency_list() -> void:
	var w = id_map_image.get_width()
	var h = id_map_image.get_height()

	adjacency_list.clear()
	var unique_neighbors := {}

	# Helper function to ensure bidirectional recording
	var add_connection = func(a: int, b: int):
		if a == b or a <= 1 or b <= 1:
			return

		# A -> B
		if not unique_neighbors.has(a):
			unique_neighbors[a] = {}
		unique_neighbors[a][b] = true

		# B -> A (The "Force" step)
		if not unique_neighbors.has(b):
			unique_neighbors[b] = {}
		unique_neighbors[b][a] = true

	for y in range(h):
		for x in range(w):
			var pid = _get_pid_fast(x, y)
			if pid <= 1:
				continue

			# 4-directional neighbors
			var dirs = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

			for d in dirs:
				var nx = x + d.x
				var ny = y + d.y
				if nx < 0 or ny < 0 or nx >= w or ny >= h:
					continue

				var neighbor = _get_pid_fast(nx, ny)

				if neighbor > 1 and neighbor != pid:
					add_connection.call(pid, neighbor)

				elif neighbor == 1:
					var across = _scan_across_border(nx, ny, pid)
					if across > 1 and across != pid:
						add_connection.call(pid, across)

	# --- Sync to Objects ---
	for pid in unique_neighbors:
		var neighbors_keys = unique_neighbors[pid].keys()
		var typed_list: Array[int] = []
		for n_id in neighbors_keys:
			typed_list.append(int(n_id))

		adjacency_list[pid] = typed_list

		if province_objects.has(pid):
			province_objects[pid].neighbors = typed_list

	print("MapManager: Adjacency list built (guaranteed bidirectional).")


func _scan_across_border(x: int, y: int, pid: int) -> int:
	var w: int = id_map_image.get_width()
	var h: int = id_map_image.get_height()

	# Check right
	if x + 1 < w:
		var n: int = _get_pid_fast(x + 1, y)
		if n > 1 and n != pid:
			return n

	# Check down
	if y + 1 < h:
		var n: int = _get_pid_fast(x, y + 1)
		if n > 1 and n != pid:
			return n

	return -1


# Faster direct pid fetch
func _get_pid_fast(x: int, y: int) -> int:
	var c = id_map_image.get_pixel(x, y)
	var r = int(c.r * 255.0 + 0.5)
	var g = int(c.g * 255.0 + 0.5)
	return r + g * 256


# --- Pathfinding section kinda. Should be in own file tbh.. ---#

# TODO(pol): This lags when moving a lot of troops. Should be made faster with
# built in AStar2D class.

var path_cache: Dictionary = {}

const HEURISTIC_SCALE: float = 1.0  #/ 50.0


func find_path(start_pid: int, end_pid: int, allowed_countries: Array[String] = []) -> Array[int]:
	if start_pid == end_pid:
		return [start_pid]

	var use_cache = allowed_countries.is_empty()
	var cache_key := Vector2i(start_pid, end_pid)

	if use_cache and path_cache.has(cache_key):
		return path_cache[cache_key].duplicate()

	var path = _find_path_astar(start_pid, end_pid, allowed_countries)

	if use_cache and not path.is_empty():
		path_cache[cache_key] = path.duplicate()

	return path


func _find_path_astar(start_pid: int, end_pid: int, allowed_countries: Array[String]) -> Array[int]:
	# 1. Optimize Allowed Check: O(1) Lookup
	var allowed_dict = {}
	var restricted_mode = not allowed_countries.is_empty()
	if restricted_mode:
		for c in allowed_countries:
			allowed_dict[c] = true

	# 2. Setup
	var open_set: Array[int] = [start_pid]
	var came_from: Dictionary = {}

	var g_score: Dictionary = {start_pid: 0.0}
	var f_score: Dictionary = {start_pid: heuristic(start_pid, end_pid)}
	var open_set_hash: Dictionary = {start_pid: true}

	# For fallback (closest reached node)
	var closest_pid_so_far = start_pid
	var closest_dist_so_far = f_score[start_pid]

	while open_set.size() > 0:
		# --- FIND LOWEST F-SCORE ---
		var current = open_set[0]
		var best_idx = 0
		var best_f = f_score.get(current, INF)

		for i in range(1, open_set.size()):
			var pid = open_set[i]
			var f = f_score.get(pid, INF)
			if f < best_f:
				best_f = f
				current = pid
				best_idx = i

		# --- POP CURRENT ---
		open_set[best_idx] = open_set[-1]
		open_set.pop_back()
		open_set_hash.erase(current)

		# --- SUCCESS CHECK ---
		if current == end_pid:
			return _reconstruct_path(came_from, current)

		# --- GET PROVINCE DATA ---
		# We need the actual object to check Types and Ports
		var current_prov: Province = province_objects[current]

		# Fallback tracking
		var dist_to_target = heuristic(current, end_pid)
		if dist_to_target < closest_dist_so_far:
			closest_dist_so_far = dist_to_target
			closest_pid_so_far = current

		# --- NEIGHBOR LOOP ---
		# We assume adjacency_list is kept in sync with province_objects[pid].neighbors
		var neighbors = adjacency_list.get(current, [])

		for neighbor in neighbors:
			var neighbor_prov: Province = province_objects[neighbor]

			# --- RULE 1: LAND -> SEA REQUIRES PORT ---
			if current_prov.type == Province.LAND and neighbor_prov.type == Province.SEA:
				if not current_prov.port == Province.PORT_BUILT:
					continue  # BLOCKED: No port to launch ships

			# --- RULE 2: POLITICAL RESTRICTIONS ---
			if restricted_mode:
				# Sea is always free
				if neighbor_prov.type == Province.LAND:
					# Strictly check if the country is in the allowed list
					# If it's not there, we can't enter it—even if it's the end_pid
					if not allowed_dict.has(neighbor_prov.country):
						continue

			# --- STANDARD A* CALCULATION ---
			# Cost is 1.0 per hop
			var tentative_g = g_score.get(current, INF) + 1.0

			if tentative_g < g_score.get(neighbor, INF):
				came_from[neighbor] = current
				g_score[neighbor] = tentative_g
				f_score[neighbor] = tentative_g + heuristic(neighbor, end_pid)

				if not open_set_hash.has(neighbor):
					open_set.append(neighbor)
					open_set_hash[neighbor] = true

	# Path not found - Return closest attempt
	if restricted_mode and closest_pid_so_far != start_pid:
		return _reconstruct_path(came_from, closest_pid_so_far)

	return []


func heuristic(a: int, b: int) -> float:
	var prov_a = province_objects.get(a)
	var prov_b = province_objects.get(b)

	var dist_pixels = prov_a.center.distance_to(prov_b.center)
	return dist_pixels * HEURISTIC_SCALE


func _reconstruct_path(came_from: Dictionary, current: int) -> Array[int]:
	var path: Array[int] = [current]
	while came_from.has(current):
		current = came_from[current]
		path.append(current)
	path.reverse()
	return path


func get_path_length(path: Array[int]) -> int:
	return path.size() - 1 if path.size() > 1 else 0


func is_path_possible(start_pid: int, end_pid: int) -> bool:
	return not find_path(start_pid, end_pid).is_empty()


func print_cache_stats() -> void:
	print("Path Cache Stats: %d paths cached" % path_cache.size())


func _is_mouse_over_ui() -> bool:
	var hovered = get_viewport().gui_get_hovered_control()
	return hovered != null


func update_map_view(mode: MapMode) -> void:
	if province_objects.is_empty():
		return

	# 1. Pre-calculate Max Values if the mode requires a heatmap
	var max_val: float = 1.0
	if mode == MapMode.POPULATION or mode == MapMode.GDP:
		for p in province_objects.values():
			var val = p.population if mode == MapMode.POPULATION else p.gdp
			if val > max_val:
				max_val = float(val)

	# 2. Single loop to update the lookup image
	for pid in province_objects.keys():
		if pid <= 1:
			continue  # Skip borders/sea

		var province = province_objects[pid]
		var final_color: Color

		match mode:
			MapMode.POPULATION:
				final_color = _calculate_heat(province.population, max_val, 0.5)
			MapMode.GDP:
				final_color = _calculate_heat(province.gdp, max_val, 0.7)
			#MapMode.ETHNICITY:
			#final_color = ethnic_name_to_color.get(province.ethnicity, Color.BLACK)
			MapMode.POLITICAL:
				final_color = country_colors.get(province.country, Color.GRAY)

		state_color_image.set_pixel(pid, 0, final_color)

	state_color_texture.update(state_color_image)


func _calculate_heat(value: float, max_value: float, power: float = 1.0) -> Color:
	if value <= 0:
		return Color(0.1, 0.1, 0.1)
	var intensity = clamp(pow(value / max_value, power), 0.0, 1.0)
	if intensity < 0.5:
		return Color.DARK_CYAN.lerp(Color.YELLOW, intensity * 2.0)
	return Color.YELLOW.lerp(Color.RED, (intensity - 0.5) * 2.0)


func show_countries_map() -> void:
	state_color_image.set_pixel(0, 0, SEA_MAIN)  # ID 0: Sea
	state_color_image.set_pixel(1, 0, Color.BLACK)  # ID 1: Borders/Grid

	for pid in province_objects.keys():
		if pid <= 1:
			continue

		var province = province_objects[pid]
		var country_name = province.country
		var country_color = country_colors.get(country_name, Color.GRAY)
		state_color_image.set_pixel(pid, 0, country_color)

	state_color_texture.update(state_color_image)


func province_updated():
	if GameState.industry_building:
		show_industry_country(CountryManager.player_country.country_name)


func show_industry_country(country_name: String) -> void:
	if not country_to_provinces.has(country_name):
		push_warning("MapManager: Country " + country_name + " not found.")
		return

	var provinces = country_to_provinces.get(country_name)
	var provinces_near_sea := get_provinces_near_sea(country_name)

	for pid in provinces:
		var province = province_objects[pid]
		var color = Color.WHITE  # Default color

		if province.city.length() > 0:
			color = Color.YELLOW

		elif province.factory == province.FACTORY_BUILT:
			color = Color.GREEN
		elif province.factory == province.FACTORY_BUILDING:
			color = Color.ORANGE  # Show progress

		elif province.port == province.PORT_BUILT:
			color = Color.BLUE
		elif province.port == province.PORT_BUILDING:
			color = Color.CYAN  # Show progress

		elif pid in provinces_near_sea:
			color = Color.LIGHT_SKY_BLUE

		state_color_image.set_pixel(pid, 0, color)

	state_color_texture.update(state_color_image)


func transfer_ownership(pid: int, new_owner_name: String) -> void:
	if not province_objects.has(pid):
		push_error("MapManager: Attempted to transfer ownership of non-existent PID: ", pid)
		return

	var province := province_objects[pid]
	var old_owner_name := province.country

	if old_owner_name == new_owner_name:
		return

	# 1. Update province internal state
	province.country = new_owner_name
	
	var old_country_obj = CountryManager.get_country(old_owner_name)
	var new_country_obj = CountryManager.get_country(new_owner_name)
	
	old_country_obj.income -= province.gdp
	new_country_obj.income += province.gdp
	old_country_obj.total_population -= province.population
	new_country_obj.total_population += province.population
	
	if province.city.length() > 0:
		if not new_country_obj.provinces_with_city.has(province):
			new_country_obj.provinces_with_city.append(province)
		old_country_obj.provinces_with_city.erase(province)
	
	# 2. Handle Old Owner Removal (IDs and Objects)
	if country_to_provinces.has(old_owner_name):
		country_to_provinces[old_owner_name].erase(pid)
	
	if country_to_provinces_obj.has(old_owner_name):
		country_to_provinces_obj[old_owner_name].erase(province)

	# 3. Handle New Owner Addition (IDs and Objects)
	if not country_to_provinces.has(new_owner_name):
		country_to_provinces[new_owner_name] = []
	if not country_to_provinces_obj.has(new_owner_name):
		country_to_provinces_obj[new_owner_name] = []

	if pid not in country_to_provinces[new_owner_name]:
		country_to_provinces[new_owner_name].append(pid)
	
	# We use 'not in' check for safety, though technically erase() should have handled it
	if province not in country_to_provinces_obj[new_owner_name]:
		country_to_provinces_obj[new_owner_name].append(province)

	# Also update the provinces array in Country
	if not new_country_obj.provinces.has(province):
		new_country_obj.provinces.append(province)
	old_country_obj.provinces.erase(province)
	
	var new_color = country_colors.get(new_owner_name, Color.GRAY)
	_update_lookup(pid, new_color)

	# 5. Localized border updates
	CountryManager.update_province_border_status(province)
	for neighbor in province.neighbors_obj:
		CountryManager.update_province_border_status(neighbor)


func _load_country_colors() -> void:
	var file := FileAccess.open("res://assets/countries.json", FileAccess.READ)
	if file == null:
		push_error("Could not open country_colors.json")
		return

	var data = JSON.parse_string(file.get_as_text())
	if data is not Dictionary:
		push_error("Invalid JSON format")
		return

	country_colors.clear()
	for country_name in data.keys():
		var rgb = data[country_name].get("color")
		if rgb == null or rgb.size() != 3:
			continue
		country_colors[country_name] = Color8(rgb[0], rgb[1], rgb[2])


func _load_map_data_json(file_path):
	if not FileAccess.file_exists(file_path):
		printerr("Error: Map data file not found at ", file_path)
		return

	var file = FileAccess.open(file_path, FileAccess.READ)
	var json_text = file.get_as_text()
	file.close()

	var json = JSON.new()
	var error = json.parse(json_text)

	if error == OK:
		if typeof(json.data) == TYPE_DICTIONARY:
			map_data = json.data
			print("Map data loaded successfully. Total regions: ", map_data.size())
		else:
			printerr("Error: JSON top-level is not a Dictionary.")
	else:
		printerr("JSON Parse Error: ", json.get_error_message(), " at line ", json.get_error_line())
	pass


func _parse_color_string(s: String) -> Vector3:
	var cleaned = s.replace("(", "").replace(")", "").replace(" ", "")
	var parts = cleaned.split(",")
	return Vector3(float(parts[0]), float(parts[1]), float(parts[2]))


func get_data_for_color(pixel_color: Color) -> Dictionary:
	var r = int(round(pixel_color.r * 255))
	var g = int(round(pixel_color.g * 255))
	var b = int(round(pixel_color.b * 255))

	var key = "(%d, %d, %d)" % [r, g, b]

	if map_data.has(key):
		return map_data[key]

	return {}  # Return empty if not found


func _force_array(data) -> Array:
	if data is Array:
		return data
	elif data is String:
		return [data]  # Wrap the single country in a list
	return []


func get_provinces_near_sea(country_name: String) -> Array[int]:
	var provinces = country_to_provinces.get(country_name, [])
	var provinces_near_sea: Array[int] = []

	for pid in provinces:
		var neighbors = adjacency_list.get(pid, [])

		for neighbor_id in neighbors:
			var neighbor_province = province_objects.get(neighbor_id)

			if neighbor_province and neighbor_province.type == 0:  # Assuming 0 is SEA
				provinces_near_sea.append(pid)
				break

	return provinces_near_sea


func get_provincesID_for_country(country: String) -> Array:
	var provinces := []

	for province in province_objects.values():
		if province.country == country:
			provinces.append(province.id)

	return provinces


func get_provincesOBJ_for_country(country: String) -> Array:
	var provinces := []

	for province in province_objects.values():
		if province.country == country:
			provinces.append(province)

	return provinces


## Returns an array of province IDs that are on the border of a different country
func get_border_provinces(country_name: String) -> Array[int]:
	var border_provinces: Array[int] = []

	# Get all provinces owned by this country
	var my_provinces = country_to_provinces.get(country_name, [])

	for prov_id in my_provinces:
		var province_data: Province = province_objects.get(prov_id)

		if not province_data:
			continue

		# Check neighbors of this province
		for neighbor_id in province_data.neighbors:
			var neighbor_owner = province_objects.get(neighbor_id, "unknown")

			# If the neighbor is owned by someone else (and isn't sea/neutral)
			if neighbor_owner.country != country_name:
				border_provinces.append(prov_id)
				break  # Move to next province once we know this one is a border

	return border_provinces


func get_all_releasables(my_country: String) -> Array:
	var releasables = []

	# 1. Get a list of all province IDs I currently own
	var my_provinces = []
	for obj in province_objects.values():
		# Using 'country' as per your Province resource
		if obj.country == my_country:
			my_provinces.append(obj.id)

	# 2. Check every country in the registry
	for potential_country in global_claims_registry.keys():
		if potential_country == my_country:
			continue

		var required_provinces = global_claims_registry[potential_country]
		var has_all_provinces = true

		# 3. Verify I own every province they claim
		for p_id in required_provinces:
			if not p_id in my_provinces:
				has_all_provinces = false
				break

		if has_all_provinces:
			# 4. Only add if they aren't already on the map
			if not _country_exists_on_map(potential_country):
				releasables.append(potential_country)

	return releasables


func _country_exists_on_map(c_name: String) -> bool:
	for obj in province_objects.values():
		if obj.country == c_name:
			return true
	return false


func release_country(country_name: String) -> void:
	# 1. Create/Get the country object
	var new_country = CountryManager.add_country(country_name)
	if new_country == null:
		return

	# 2. Collect provinces first (don't modify while iterating)
	var provinces_to_transfer = []
	for obj in province_objects.values():
		if obj.claims.has(country_name):
			provinces_to_transfer.append(obj)

	# 3. Perform the transfer
	for obj in provinces_to_transfer:
		# Clear existing troops safely
		for troop in obj.troops_here.duplicate():
			if is_instance_valid(troop):
				TroopManager.remove_troop(troop)

		# Transfer ownership
		transfer_ownership(obj.id, country_name)

	
	# Update neighbors affected by the new country
	for obj in provinces_to_transfer:
		CountryManager.update_province_border_status(obj)
		for neighbor in obj.neighbors_obj:
			CountryManager.update_province_border_status(neighbor)

	CountryManager._cleanup_empty_countries()


func get_all_cities() -> Array:
	var cities := []
	for province in province_objects.values():
		if not province.city.is_empty():
			cities.append({"id": province.id, "name": province.city})
	return cities

func get_cities_province_country(country_name) -> Array:
	var provinces = []
	for pid in country_to_provinces[country_name]:
		if len(province_objects[pid].city) > 0:
			provinces.append(pid)
	return provinces


## Returns provinces that specifically border a certain enemy
func get_provinces_bordering_enemy(country_name: String, enemy_name: String) -> Array[int]:
	var specific_borders: Array[int] = []
	var my_provinces = country_to_provinces.get(country_name, [])

	for prov_id in my_provinces:
		var province_data: Province = province_objects.get(prov_id)
		for neighbor_id in province_data.neighbors:
			if province_objects[neighbor_id].country == enemy_name:
				specific_borders.append(prov_id)
				break

	return specific_borders


func annex_country(target_country_name: String) -> void:
	var playerobj = CountryManager.player_country
	var player = playerobj.country_name

	var target_troops = TroopManager.get_troops_for_country(target_country_name).duplicate()
	for troop in target_troops:
		TroopManager.remove_troop(troop)

	var provinces_to_transfer = country_to_provinces.get(target_country_name, []).duplicate()

	if provinces_to_transfer.is_empty():
		print("MapManager: No provinces found for ", target_country_name)
		return

	for pid in provinces_to_transfer:
		transfer_ownership(pid, player)

	#playerobj.reset_manpower()
	print("ANNEXATION COMPLETE: ", player, " has taken all of ", target_country_name)


func get_province(pid: int) -> Province:
	return province_objects.get(pid, null)


func _build_global_registry():
	global_claims_registry.clear()
	for obj in province_objects.values():
		for country_name in obj.claims:
			if not global_claims_registry.has(country_name):
				global_claims_registry[country_name] = []
			global_claims_registry[country_name].append(obj.id)


func generate_type_mask() -> ImageTexture:
	if id_map_image == null:
		push_error("MapManager: Cannot generate type mask - id_map_image is null!")
		return null

	var w := id_map_image.get_width()
	var h := id_map_image.get_height()

	var type_img := Image.create_empty(w, h, false, Image.FORMAT_L8)
	var uncertain_pixels: Array[Vector2i] = []

	# --- PASS 1: Direct Mapping ---
	for y in range(h):
		for x in range(w):
			var pid = _get_pid_fast(x, y)
			var province = province_objects.get(pid)

			if province:
				# 0 is usually Sea, anything else is Land
				var color = Color.WHITE if province.type != 0 else Color.BLACK
				type_img.set_pixel(x, y, color)
			else:
				# This pixel is a border (ID 1) or unassigned.
				uncertain_pixels.append(Vector2i(x, y))

	# --- PASS 2: Neighbor Check for Borders ---
	for pos in uncertain_pixels:
		var touches_land := false

		# 8-way check (includes diagonals)
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				if dx == 0 and dy == 0:
					continue

				var nx: int = pos.x + dx
				var ny: int = pos.y + dy

				if nx >= 0 and nx < w and ny >= 0 and ny < h:
					var nid = _get_pid_fast(nx, ny)
					if nid > 1:  # Ignore other border pixels
						var n_prov = province_objects.get(nid)
						if n_prov and n_prov.type != 0:
							touches_land = true
							break
			if touches_land:
				break

		var final_color = Color.WHITE if touches_land else Color.BLACK
		type_img.set_pixel(pos.x, pos.y, final_color)

	return ImageTexture.create_from_image(type_img)
