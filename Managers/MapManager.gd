extends Node
var DEBUG_MODE = false

signal province_hovered(province_id: int, country_name: String)
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

var color_to_pop_map: Dictionary = {}
var color_to_city_map: Dictionary = {}
var color_to_ethnic_map: Dictionary = {}
var color_to_claim_map: Dictionary = {}
var ethnic_name_to_color: Dictionary = {}
var gdp_map: Dictionary = {}

var province_to_country: Dictionary = {}
var country_to_provinces: Dictionary = {}
var province_objects: Dictionary[int, Province] = {}

var adjacency_list: Dictionary = {} # Stores {ID: [Neighbor_ID_1, Neighbor_ID_2, ...]}
var current_hovered_pid: int = -1
var last_hovered_pid: int = -1
var original_hover_color: Color
var province_centers: Dictionary = {} # Stores {ID: Vector2(x, y)}

# This will look like: {"french_empire": [101, 102, 103], "canada": [1, 2, 5]}
var global_claims_registry: Dictionary = {}


var all_cities = []

const MAP_DATA_PATH = "res://map_data/MapData.tres"
const CACHE_FOLDER = "res://map_data/"

@export var region_texture: Texture2D
@export var culture_texture: Texture2D
@export var population_texture: Texture2D
@export var city_texture: Texture2D
@export var gdp_texture: Texture2D
@export var ethnicity_texture: Texture2D
@export var claims_texture: Texture2D


func load_country_data() -> void:
	# NOTE Z21 this can all be done in 1 function like load_json("countries.json", color_to_country_map)
	_load_country_colors()
	_load_population_json()
	_load_city_json()
	_load_gdp_json()
	_load_ethnic_json()
	_load_claims_json()
	var dir = DirAccess.open("res://")
	if dir and not dir.dir_exists(CACHE_FOLDER):
		dir.make_dir_recursive(CACHE_FOLDER)

	if !DEBUG_MODE:
		if _try_load_cached_data():
			print("MapManager: Loaded cached data with Province Objects.")
			return

	var region = region_texture if region_texture else preload("res://maps/regions.png")
	var culture = culture_texture if culture_texture else preload("res://maps/cultures.png")
	var population = (
		population_texture if population_texture else preload("res://maps/population_color_map.png")
	)
	var city = city_texture if city_texture else preload("res://maps/city_colors.png")
	var gdp_data = gdp_texture if gdp_texture else preload("res://maps/gdp_data.png")
	var ethnicity = (
		ethnicity_texture if ethnicity_texture else preload("res://maps/ethnicities.png")
	)
	var claims = claims_texture if claims_texture else preload("res://maps/claims.png")

	_generate_and_save(region, culture, population, city, gdp_data, ethnicity, claims)


func _generate_and_save(
	region: Texture2D,
	culture: Texture2D,
	population: Texture2D,
	city: Texture2D,
	gdp_data: Texture2D,
	ethnicity: Texture2D,
	claims: Texture2D
) -> void:
	initialize_map(region, culture, population, city, gdp_data, ethnicity, claims)

	var map_data := MapData.new()
	map_data.province_centers = province_centers.duplicate()
	map_data.adjacency_list = adjacency_list.duplicate(true)
	map_data.province_to_country = province_to_country.duplicate()
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
	province_to_country = loaded.province_to_country
	country_to_provinces = loaded.country_to_provinces
	max_province_id = loaded.max_province_id
	id_map_image = loaded.id_map_image
	province_objects.assign(loaded.province_objects)

	_build_lookup_texture()
	return true


func initialize_map(
	region_tex: Texture2D,
	culture_tex: Texture2D,
	population_tex: Texture2D,
	city_tex: Texture2D,
	gdp_tex,
	ethnicity_tex,
	claims_tex
) -> void:
	var r_img = region_tex.get_image()
	var c_img = culture_tex.get_image()
	var p_img = population_tex.get_image()
	var city_img = city_tex.get_image()
	var gdp_img = gdp_tex.get_image()
	var ethnicity_img = ethnicity_tex.get_image()
	var claims_img = claims_tex.get_image()

	var w = r_img.get_width()
	var h = r_img.get_height()

	# Safety check for the crash you saw
	var pw = p_img.get_width()
	var ph = p_img.get_height()

	id_map_image = Image.create(w, h, false, Image.FORMAT_RGB8)
	var unique_regions = {}
	var next_id = 2

	for y in range(h):
		for x in range(w):
			var c_color = c_img.get_pixel(x, y)
			var r_color = r_img.get_pixel(x, y)
			var is_sea_pixel = _is_sea(c_color)

			# var is_sea_grid = _is_sea_grid(c_color)

			# FIX: Generate a key based on the actual color in the region map (r_color)
			# We add a prefix so that a land province and sea province with the
			# same hex color won't accidentally merge.
			var hex = r_color.to_html(false)
			var key = ("S_" if is_sea_pixel else "L_") + hex

			# Check for Borders/Grid (ID 1)
			if r_color == Color.BLACK:
				_write_id(x, y, 1)
				continue

			# If this is a new region (Unique Sea Zone or Land Province)
			if not unique_regions.has(key):
				unique_regions[key] = next_id

				var province = Province.new()
				province.id = next_id

				if is_sea_pixel:
					# SEA LOGIC: Unique ID, but 0 stats
					province.type = province.SEA
					province.country = "sea"
					province.population = 0
					province.gdp = 0
					province.city = ""
				else:
					# LAND LOGIC
					province.type = province.LAND
					province.country = _identify_country(c_color)

					var p_color = p_img.get_pixel(min(x, pw - 1), min(y, ph - 1))
					var city_color = city_img.get_pixel(min(x, pw - 1), min(y, ph - 1))
					var gdp_color = gdp_img.get_pixel(min(x, pw - 1), min(y, ph - 1))
					var ethnicity_color = ethnicity_img.get_pixel(min(x, pw - 1), min(y, ph - 1))
					var claims_color = claims_img.get_pixel(min(x, pw - 1), min(y, ph - 1))
					province.population = _get_pop_from_color(p_color)
					province.city = _get_city_from_color(city_color)
					province.ethnicity = _get_name_from_color(ethnicity_color, color_to_ethnic_map)
					province.claims = _get_claims_from_color(claims_color, color_to_claim_map)
					if len(province.city) > 0: # Cities by default have factories
						province.factory = Province.FACTORY_BUILT
					province.gdp = _get_gdp_from_color(gdp_color)

				province_objects[next_id] = province
				province_to_country[next_id] = province.country
				next_id += 1

			# Write the unique ID to your id_map_image
			_write_id(x, y, unique_regions[key])
	max_province_id = next_id - 1
	_calculate_province_centroids()
	_build_country_to_provinces()
	_build_adjacency_list()
	_build_lookup_texture()


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


func _build_country_to_provinces():
	var result: Dictionary = {}

	for pid in province_to_country.keys():
		var country: String = province_to_country[pid]

		if not result.has(country):
			result[country] = []

		result[country].append(pid)

	country_to_provinces = result
	return


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

		if province == null or province.type == 0: # 0 is province.SEA
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
	update_lookup(pid, new_color)

	if pid == last_hovered_pid:
		original_hover_color = new_color
		update_lookup(pid, new_color + Color(0.15, 0.15, 0.15, 0))


func set_country_color(country_name: String, custom_color: Color = Color.TRANSPARENT) -> void:
	var new_color = custom_color
	if new_color == Color.TRANSPARENT:
		new_color = country_colors.get(country_name, Color.GRAY)

	var provinces = country_to_provinces.get(country_name, [])

	if provinces.is_empty():
		print("Warning: No provinces found for country: ", country_name)
		return

	for pid in provinces:
		update_lookup(pid, new_color)

		if pid == last_hovered_pid:
			original_hover_color = new_color
			update_lookup(pid, new_color + Color(0.15, 0.15, 0.15, 0))


func get_province_at_pos(pos: Vector2, map_sprite: Sprite2D = null) -> int:
	if not id_map_image:
		return 0

	var x: int
	var y: int
	var size = id_map_image.get_size()

	if map_sprite:
		var local = map_sprite.to_local(pos)
		var sprite_size = map_sprite.texture.get_size()

		# If sprite is centered, offset the local position to be top-left based
		if map_sprite.centered:
			local += sprite_size / 2.0

		# --- INFINITE SCROLL MATH ---
		x = int(local.x) % int(sprite_size.x)
		if x < 0:
			x += int(sprite_size.x)
		y = int(local.y)

	else:
		x = int(pos.x)
		y = int(pos.y)

	# Y is not infinite, so we strictly check bounds
	if y < 0 or y >= size.y or x < 0 or x >= size.x:
		return 0

	var c = id_map_image.get_pixel(x, y)
	var r = int(round(c.r * 255.0))
	var g = int(round(c.g * 255.0))
	return r + (g * 256)


func handle_hover(global_pos: Vector2, map_sprite: Sprite2D) -> void:
	if _is_mouse_over_ui() or GameState.in_peace_process:
		_reset_last_hover()
		return

	var pid = get_province_at_pos(global_pos, map_sprite)
	current_hovered_pid = pid

	var highlight_color = _get_contextual_highlight(pid)

	if pid != last_hovered_pid:
		_reset_last_hover() # Clean up the old one

		if pid > 1 and highlight_color != Color.TRANSPARENT:
			original_hover_color = state_color_image.get_pixel(pid, 0)
			update_lookup(pid, highlight_color)

			last_hovered_pid = pid
			Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)
			province_hovered.emit(pid, CountryManager.player_country.country_name)
		else:
			Input.set_default_cursor_shape(Input.CURSOR_ARROW)
			province_hovered.emit(-1, "")


func _reset_last_hover() -> void:
	if last_hovered_pid > 1:
		update_lookup(last_hovered_pid, original_hover_color)
	last_hovered_pid = -1


func _get_contextual_highlight(pid: int) -> Color:
	if pid <= 1:
		return Color.TRANSPARENT

	var player_name = CountryManager.player_country.country_name
	var is_player_owned = province_to_country.get(pid) == player_name

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
		return Color.TRANSPARENT # Don't highlight non-city provinces during deploy

	elif GameState.industry_building != GameState.IndustryType.DEFAULT:
		return state_color_image.get_pixel(pid, 0).lightened(0.2).blend(Color.GREEN_YELLOW)

	return Color.TRANSPARENT


func handle_click_down(global_pos: Vector2, map_sprite: Sprite2D) -> void:
	if _is_mouse_over_ui() or Console.is_visible():
		return

	TroopManager.troop_selection.deselect_all()


func handle_click(global_pos: Vector2, map_sprite: Sprite2D) -> void:
	if _is_mouse_over_ui() or Console.is_visible() or GameState.in_peace_process:
		return

	var pid = get_province_with_radius(global_pos, map_sprite, 5)
	# 1. Handle Clicks on Water or Invalid Areas
	if pid <= 1 or province_objects[pid].type == 0: # 0 is SEA
		if GameState.industry_building != GameState.IndustryType.DEFAULT:
			GameState.reset_industry_building()
			show_countries_map()
		else:
			close_sidemenu.emit()
		return

	var player_country_name = CountryManager.player_country.country_name
	var is_player_owned = province_to_country.get(pid) == player_country_name
	var is_puppet_owned = province_to_country.get(pid) in CountryManager.player_country.puppets

	if GameState.choosing_deploy_city:
		if is_player_owned:
			_execute_deployment(pid, player_country_name)
		else:
			print("Action Failed: Province not owned by player.")

	elif GameState.industry_building != GameState.IndustryType.DEFAULT:
		if is_player_owned:
			_province_build_industry(pid, player_country_name)
		elif is_puppet_owned:
			_province_build_industry(pid, province_to_country.get(pid))
		else:
			print("Action Failed: Cannot build in foreign territory.")
			GameState.reset_industry_building()
			show_countries_map()

	if TroopManager.troop_selection.selected_troops.is_empty(): # Prevent menu from spawning when selecting troops (annoying)
		country_clicked.emit(province_to_country.get(pid, ""))


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
			
		EconomyManager.start_construction(pid, "factory", 10, 150.0, country)
		
		_cleanup_interaction_state()
		show_industry_country(player_name)

	elif type == GameState.IndustryType.PORT:
		if province.port != province.NO_PORT:
			print("Cannot build: Port slot is busy or full.")
			return
			
		# 3. Sea check for Ports
		if pid in get_provinces_near_sea(player_name):
			EconomyManager.start_construction(pid, "port", 10, 150.0, country)
			
			_cleanup_interaction_state()
			show_industry_country(player_name)
		else:
			print("Action Failed: Port must be on a coast!")
			return

	country_clicked.emit(player_name)


func _cleanup_interaction_state() -> void:
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	if last_hovered_pid > 1:
		update_lookup(last_hovered_pid, original_hover_color)
		last_hovered_pid = -1


# To probe around and still register a click if we hit province/coutnry border
func get_province_with_radius(center: Vector2, map_sprite: Sprite2D, radius: int) -> int:
	var offsets = [
		Vector2(0, 0),
		Vector2(radius, 0),
		Vector2(-radius, 0),
		Vector2(0, radius),
		Vector2(0, -radius),
		Vector2(radius, radius),
		Vector2(radius, -radius),
		Vector2(-radius, radius),
		Vector2(-radius, -radius),
	]

	for off in offsets:
		var pid = get_province_at_pos(center + off, map_sprite)
		if pid > 1:
			return pid

	return -1


func update_lookup(pid: int, color: Color) -> void:
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
			var pid = get_province_at_pos(Vector2(x, y), null) # Use direct coordinates, sprite is null

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

	# Prepare dictionary for unique tracking
	var unique_neighbors := {}

	for y in range(h):
		for x in range(w):
			var pid = _get_pid_fast(x, y)
			if pid <= 1:
				continue

			if not unique_neighbors.has(pid):
				unique_neighbors[pid] = {}

			# 4-directional neighbors
			var dirs = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

			for d in dirs:
				var nx = x + d.x
				var ny = y + d.y
				if nx < 0 or ny < 0 or nx >= w or ny >= h:
					continue

				var neighbor = _get_pid_fast(nx, ny)

				# Normal adjacency (Land-to-Land)
				if neighbor > 1 and neighbor != pid:
					unique_neighbors[pid][neighbor] = true
					continue

				# Border pixel scan (ID=1)
				if neighbor == 1:
					var across = _scan_across_border(nx, ny, pid)
					if across > 1 and across != pid:
						unique_neighbors[pid][across] = true

	# --- THE FIX: Convert to Typed Arrays and Populate Objects ---
	for pid in unique_neighbors:
		var neighbors_keys = unique_neighbors[pid].keys()

		# Create a typed array for the Province resource
		var typed_list: Array[int] = []
		for n_id in neighbors_keys:
			typed_list.append(int(n_id))

		# Store in the global dictionary (can remain untyped for pathfinding)
		adjacency_list[pid] = typed_list

		# Sync to the Province object
		if province_objects.has(pid):
			province_objects[pid].neighbors = typed_list

	print("MapManager: Adjacency list built and synced to Province objects.")


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

const HEURISTIC_SCALE: float = 1.0 # / 50.0


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
					continue # BLOCKED: No port to launch ships

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


func force_bidirectional_connections() -> void:
	var fix_count = 0

	# 1. Iterate through every province object
	for pid_a in province_objects.keys():
		var prov_a: Province = province_objects[pid_a]

		var neighbors_of_a = prov_a.neighbors

		for pid_b in neighbors_of_a:
			# Safety check: Does the neighbor ID even exist in our world?
			if not province_objects.has(pid_b):
				push_warning(
					(
						"Graph Repair: Province %d lists neighbor %d, but %d doesn't exist!"
						% [pid_a, pid_b, pid_b]
					)
				)
				continue

			var prov_b: Province = province_objects[pid_b]

			# Check if B points back to A
			if not pid_a in prov_b.neighbors:
				prov_b.neighbors.append(pid_a)

				if adjacency_list.has(pid_b):
					if not pid_a in adjacency_list[pid_b]:
						adjacency_list[pid_b].append(pid_a)
				else:
					adjacency_list[pid_b] = [pid_a]

				fix_count += 1

	print("Graph Repair Complete: Fixed %d one-way connections in Province Resources." % fix_count)


func _is_mouse_over_ui() -> bool:
	var hovered = get_viewport().gui_get_hovered_control()
	return hovered != null


func _get_heatmap_color(pop: int, max_pop: float) -> Color:
	# If population is 0, return a neutral "empty" color (dark slate/gray)
	if pop <= 0:
		return Color(0.1, 0.1, 0.15, 1.0)

	# Calculate intensity based on the REAL maximum in your current data
	var intensity = clamp(float(pop) / max_pop, 0.0, 1.0)

	# We create a multi-stop gradient:
	# Low: Cyan/Green -> Mid: Yellow -> High: Red
	var col: Color
	if intensity < 0.5:
		# Blend from a "Low Density" Teal to Yellow
		col = Color.DARK_CYAN.lerp(Color.YELLOW, intensity * 2.0)
	else:
		# Blend from Yellow to a "High Density" Deep Red
		col = Color.YELLOW.lerp(Color.RED, (intensity - 0.5) * 2.0)

	return col

# soilad aneurysm time
func show_faction_map() -> void:
	var faction_color = Color.GRAY
	if province_objects.is_empty():
		return

	var current_max_gdp: float = 1.0
	for province in province_objects.values():
		if province.gdp > current_max_gdp:
			current_max_gdp = float(province.gdp)

	for pid in province_objects.keys():
		var province = province_objects[pid]

		if pid <= 1:
			continue

		var total: int = 0
		for faction in FactionManager.factions:
			if province.country in FactionManager.factions[faction]:
				total += 1
				var faction_leader = FactionManager.factions[faction][0]
				faction_color = country_colors.get(faction_leader, Color.GRAY)
			else:
				faction_color = Color.GRAY
			state_color_image.set_pixel(pid, 0, faction_color / total)

	state_color_texture.update(state_color_image)
	KeyboardManager.current_view = KeyboardManager.MapView.FACTION
	print("MapManager: Faction View Updated")

func show_population_map() -> void:
	if province_objects.is_empty():
		return
	var current_max_pop: float = 1.0
	for province in province_objects.values():
		if province.population > current_max_pop:
			current_max_pop = float(province.population)

	for pid in province_objects.keys():
		var province = province_objects[pid]
		if pid <= 1:
			continue
		var pop_color = _get_heatmap_color(province.population, current_max_pop)
		state_color_image.set_pixel(pid, 0, pop_color)

	state_color_texture.update(state_color_image)
	print("MapManager: Population View Updated. Max Pop found: ", current_max_pop)


func show_ethnic_map() -> void:
	if province_objects.is_empty():
		return

	for pid in province_objects.keys():
		# Skip index 0/1 (usually sea or null)
		if pid <= 1:
			continue

		var province = province_objects[pid]
		var eth_name = province.ethnicity # Assuming this is the String name (e.g., "Igbo")

		# Default to black or transparent if ethnicity not found
		var display_color = Color.BLACK

		if ethnic_name_to_color.has(eth_name):
			display_color = ethnic_name_to_color[eth_name]

		# Update the lookup texture
		state_color_image.set_pixel(pid, 0, display_color)

	state_color_texture.update(state_color_image)
	print("MapManager: Ethnic View Updated.")


func _get_gdp_heatmap_color(gdp: int, max_gdp: float) -> Color:
	if gdp <= 0:
		return Color(0.1, 0.1, 0.1) # Dark gray for no data

	# Using Square Root scale to make lower GDP differences more visible
	# Otherwise, the richest city makes everything else look the same color.
	var intensity = clamp(sqrt(float(gdp)) / sqrt(max_gdp), 0.0, 1.0)

	var col: Color
	if intensity < 0.5:
		# Low GDP: Dark Red/Purple -> Neutral White/Blue
		col = Color(0.6, 0.1, 0.1).lerp(Color.ALICE_BLUE, intensity * 2.0)
	else:
		# High GDP: White/Blue -> Deep Electric Blue
		col = Color.ALICE_BLUE.lerp(Color(0.0, 0.4, 1.0), (intensity - 0.5) * 2.0)

	return col


func show_gdp_map() -> void:
	if province_objects.is_empty():
		return

	var current_max_gdp: float = 1.0
	for province in province_objects.values():
		if province.gdp > current_max_gdp:
			current_max_gdp = float(province.gdp)

	for pid in province_objects.keys():
		var province = province_objects[pid]

		if pid <= 1:
			continue

		var gdp_color = _get_gdp_heatmap_color(province.gdp, current_max_gdp)
		state_color_image.set_pixel(pid, 0, gdp_color)

	state_color_texture.update(state_color_image)
	KeyboardManager.current_view = KeyboardManager.MapView.GDP
	print("MapManager: GDP View Updated. Max GDP: ", current_max_gdp)


func show_countries_map() -> void:
	state_color_image.set_pixel(0, 0, SEA_MAIN) # ID 0: Sea
	state_color_image.set_pixel(1, 0, Color.BLACK) # ID 1: Borders/Grid

	for pid in province_objects.keys():
		if pid <= 1:
			continue

		var province = province_objects[pid]
		var country_name = province.country
		var country_color = country_colors.get(country_name, Color.GRAY)
		var country_data = CountryManager.get_country(country_name)
		if country_data and country_data.owner:
			var owner_color = country_colors.get(country_data.owner, Color.GRAY)
			country_color = (country_color + 3 * owner_color) / 4

		state_color_image.set_pixel(pid, 0, country_color)

	state_color_texture.update(state_color_image)
	KeyboardManager.current_view = KeyboardManager.MapView.COUNTRIES


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
		var color = Color.WHITE # Default color

		if province.city.length() > 0:
			color = Color.YELLOW
		
		elif province.factory == province.FACTORY_BUILT:
			color = Color.GREEN
		elif province.factory == province.FACTORY_BUILDING:
			color = Color.ORANGE # Show progress
			
		elif province.port == province.PORT_BUILT:
			color = Color.BLUE
		elif province.port == province.PORT_BUILDING:
			color = Color.CYAN # Show progress
			
		elif pid in provinces_near_sea:
			color = Color.LIGHT_SKY_BLUE
		
		state_color_image.set_pixel(pid, 0, color)

	state_color_texture.update(state_color_image)


func transfer_ownership(pid: int, new_owner_name: String) -> void:
	var old_owner_name = province_to_country.get(pid, "")

	if old_owner_name == new_owner_name:
		return

	if province_objects.has(pid):
		province_objects[pid].country = new_owner_name
	else:
		push_error("MapManager: Attempted to transfer ownership of non-existent PID: ", pid)
		return

	if country_to_provinces.has(old_owner_name):
		country_to_provinces[old_owner_name].erase(pid)

	if not country_to_provinces.has(new_owner_name):
		country_to_provinces[new_owner_name] = []

	if not pid in country_to_provinces[new_owner_name]:
		country_to_provinces[new_owner_name].append(pid)

	province_to_country[pid] = new_owner_name

	var new_color = country_colors.get(new_owner_name, Color.GRAY)
	update_lookup(pid, new_color)


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


func _load_population_json() -> void:
	var path = "res://map_data/population_color_map.json"
	if not FileAccess.file_exists(path):
		push_error("Population JSON missing!")
		return

	var file = FileAccess.open(path, FileAccess.READ)
	var json_data = JSON.parse_string(file.get_as_text())
	if json_data is Dictionary:
		color_to_pop_map = json_data


func _get_pop_from_color(c: Color) -> int:
	var r = int(round(c.r * 255.0))
	var g = int(round(c.g * 255.0))
	var b = int(round(c.b * 255.0))

	var exact_key = "(%d, %d, %d)" % [r, g, b]

	# 1. Try Exact Match
	if color_to_pop_map.has(exact_key):
		return color_to_pop_map[exact_key]

	# 2. Try match without spaces (common JSON difference)
	var tight_key = "(%d,%d,%d)" % [r, g, b]
	if color_to_pop_map.has(tight_key):
		return color_to_pop_map[tight_key]

	# 3. Fuzzy Match (Only if exact fails)
	# We look for the color in our map with the smallest RGB distance
	var best_match = 0
	var min_dist = 999999.0

	for color_str in color_to_pop_map.keys():
		var target_rgb = _parse_color_string(color_str)
		var dist = (Vector3(r, g, b) - target_rgb).length_squared()

		if dist < min_dist:
			min_dist = dist
			best_match = color_to_pop_map[color_str]

	# If the closest color is reasonably similar, use it
	if min_dist < 100: # Threshold for "close enough"
		return best_match

	return 0


func _parse_color_string(s: String) -> Vector3:
	var cleaned = s.replace("(", "").replace(")", "").replace(" ", "")
	var parts = cleaned.split(",")
	return Vector3(float(parts[0]), float(parts[1]), float(parts[2]))


func _load_city_json() -> void:
	var path = "res://map_data/city_colors.json" # Ensure path is correct
	if not FileAccess.file_exists(path):
		push_error("City JSON missing!")
		return

	var file = FileAccess.open(path, FileAccess.READ)
	var json_data = JSON.parse_string(file.get_as_text())
	if json_data is Dictionary:
		color_to_city_map = json_data


func _load_claims_json() -> void:
	var path = "res://map_data/claims.json" # Ensure path is correct
	if not FileAccess.file_exists(path):
		push_error("City JSON missing!")
		return

	var file = FileAccess.open(path, FileAccess.READ)
	var json_data = JSON.parse_string(file.get_as_text())
	if json_data is Dictionary:
		color_to_claim_map = json_data


func _get_city_from_color(c: Color) -> String:
	var r = int(round(c.r * 255.0))
	var g = int(round(c.g * 255.0))
	var b = int(round(c.b * 255.0))

	var exact_key = "(%d, %d, %d)" % [r, g, b]

	# 1. Try Exact Match
	if color_to_city_map.has(exact_key):
		return color_to_city_map[exact_key]

	# 2. Try match without spaces
	var tight_key = "(%d,%d,%d)" % [r, g, b]
	if color_to_city_map.has(tight_key):
		return color_to_city_map[tight_key]

	# 3. Fuzzy Match
	var best_match = "Unknown"
	var min_dist = 999999.0

	for color_str in color_to_city_map.keys():
		var target_rgb = _parse_color_string(color_str)
		var dist = (Vector3(r, g, b) - target_rgb).length_squared()

		if dist < min_dist:
			min_dist = dist
			best_match = color_to_city_map[color_str]

	# Threshold check: 100 distance squared is very close
	if min_dist < 100:
		return best_match

	return ""


func _load_gdp_json() -> void:
	var path = "res://map_data/gdp_data.json"
	if not FileAccess.file_exists(path):
		push_error("GDP JSON missing!")
		return

	var file = FileAccess.open(path, FileAccess.READ)
	var json_data = JSON.parse_string(file.get_as_text())
	if json_data is Dictionary:
		gdp_map = json_data


func _load_ethnic_json() -> void:
	var path = "res://map_data/ethnicities.json"

	if not FileAccess.file_exists(path):
		push_error("Ethnic JSON missing at: " + path)
		return

	var file = FileAccess.open(path, FileAccess.READ)
	var json_data = JSON.parse_string(file.get_as_text())

	if json_data is Dictionary:
		color_to_ethnic_map = json_data

		# --- BUILD THE REVERSE LOOKUP ---
		# We do this once here so show_ethnic_map() is super fast
		ethnic_name_to_color.clear()
		for color_key in color_to_ethnic_map.keys():
			var ethnicity_name = color_to_ethnic_map[color_key]

			# Use your existing _parse_color_string to get a Vector3(R, G, B)
			var rgb_vec = _parse_color_string(color_key)

			# Convert to Godot Color (0.0 to 1.0 range)
			var final_color = Color(rgb_vec.x / 255.0, rgb_vec.y / 255.0, rgb_vec.z / 255.0)

			# Map the NAME to the COLOR
			ethnic_name_to_color[ethnicity_name] = final_color

		print("Successfully loaded ", color_to_ethnic_map.size(), " ethnicities.")
	else:
		push_error("Ethnic JSON format is invalid (Expected Dictionary)")


func _get_name_from_color(c: Color, data_map: Dictionary) -> String:
	var r = int(round(c.r * 255.0))
	var g = int(round(c.g * 255.0))
	var b = int(round(c.b * 255.0))

	var exact_key = "(%d, %d, %d)" % [r, g, b]

	# 1. Try Exact Match
	if data_map.has(exact_key):
		return data_map[exact_key]

	# 2. Try match without spaces (tight format)
	var tight_key = "(%d,%d,%d)" % [r, g, b]
	if data_map.has(tight_key):
		return data_map[tight_key]

	# 3. Fuzzy Match
	var best_match = ""
	var min_dist = 999999.0

	for color_str in data_map.keys():
		var target_rgb = _parse_color_string(color_str)
		var dist = (Vector3(r, g, b) - target_rgb).length_squared()

		if dist < min_dist:
			min_dist = dist
			best_match = data_map[color_str]

	# Threshold check
	if min_dist < 100:
		return best_match

	return "Unknown"


func _get_claims_from_color(c: Color, data_map: Dictionary) -> Array:
	var r = int(round(c.r * 255.0))
	var g = int(round(c.g * 255.0))
	var b = int(round(c.b * 255.0))

	# Define possible key formats (Standard, Tight, and No-Bracket)
	var formats = ["(%d, %d, %d)" % [r, g, b], "(%d,%d,%d)" % [r, g, b], "%d,%d,%d" % [r, g, b]]

	# 1. Try Exact Matches
	for key in formats:
		if data_map.has(key):
			return _force_array(data_map[key])

	# 2. Fuzzy Match
	var best_data = null
	var min_dist = 999999.0
	var current_vec = Vector3(r, g, b)

	for color_str in data_map.keys():
		var target_rgb = _parse_color_string(color_str)
		var dist = (current_vec - target_rgb).length_squared()

		if dist < min_dist:
			min_dist = dist
			best_data = data_map[color_str]

	# Threshold check (10 units distance)
	if min_dist < 100 and best_data != null:
		return _force_array(best_data)

	return [] # Return empty array if no claim found


# Helper to ensure we never return a single String when an Array is expected
func _force_array(data) -> Array:
	if data is Array:
		return data
	elif data is String:
		return [data] # Wrap the single country in a list
	return []


func _get_gdp_from_color(c: Color) -> int:
	var r = int(round(c.r * 255.0))
	var g = int(round(c.g * 255.0))
	var b = int(round(c.b * 255.0))

	var exact_key = "(%d, %d, %d)" % [r, g, b]

	if gdp_map.has(exact_key):
		return int(gdp_map[exact_key])

	var tight_key = "(%d,%d,%d)" % [r, g, b]
	if gdp_map.has(tight_key):
		return int(gdp_map[tight_key])

	var best_gdp = 0
	var min_dist = 999999.0

	for color_str in gdp_map.keys():
		var target_rgb = _parse_color_string(color_str)
		# Using Euclidean distance squared to find the closest color
		var dist = (Vector3(r, g, b) - target_rgb).length_squared()

		if dist < min_dist:
			min_dist = dist
			best_gdp = int(gdp_map[color_str])

	if min_dist < 200:
		return best_gdp

	return 0


func get_provinces_near_sea(country_name: String) -> Array[int]:
	var provinces = country_to_provinces.get(country_name, [])
	var provinces_near_sea: Array[int] = []

	for pid in provinces:
		var neighbors = adjacency_list.get(pid, [])

		for neighbor_id in neighbors:
			var neighbor_province = province_objects.get(neighbor_id)

			if neighbor_province and neighbor_province.type == 0: # Assuming 0 is SEA
				provinces_near_sea.append(pid)
				break

	return provinces_near_sea


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
			var neighbor_owner = province_to_country.get(neighbor_id, "unknown")

			# If the neighbor is owned by someone else (and isn't sea/neutral)
			if neighbor_owner != country_name:
				border_provinces.append(prov_id)
				break # Move to next province once we know this one is a border

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
	for obj in province_objects.values():
		if obj.claims.has(country_name):
			var troops = TroopManager.troops_by_province.get(obj.id, [])
			for troop in troops.duplicate():
				if is_instance_valid(troop):
					TroopManager.remove_troop(troop)

			transfer_ownership(obj.id, country_name)
	CountryManager.add_country(country_name)
	CountryManager.cleanup_empty_countries()


func get_all_cities() -> Array:
	var pids = []
	for obj in province_objects.values():
		if len(obj.city) > 0:
			pids.append([obj.id, obj.city])
	return pids


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
			if province_to_country.get(neighbor_id) == enemy_name:
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


func _build_global_registry():
	global_claims_registry.clear()
	for obj in province_objects.values():
		for country_name in obj.claims:
			if not global_claims_registry.has(country_name):
				global_claims_registry[country_name] = []
			global_claims_registry[country_name].append(obj.id)
