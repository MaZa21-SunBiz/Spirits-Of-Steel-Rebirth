extends Node
var DEBUG_MODE: bool = false

signal province_hovered(province_id: int, country_name: String)
signal country_clicked(country_name: String)

# Emitted when a click couldn't be processed (so likely sea or border)
signal close_sidemenu

# The exact colors you provided
const SEA_MAIN: Color = Color("#7e8e9e")
const SEA_RASTER: Color = Color("#697684")

var hoveredCountry: String = "Sea"

# --- DATA ---
var id_map_image: Image
var state_color_image: Image
var state_color_texture: ImageTexture
var max_province_id: int = 0

var ethnic_name_to_color: Dictionary = {}
var gdp_map: Dictionary = {}

var province_to_country: Dictionary[int, String] = {}
var country_to_provinces: Dictionary = {}
var country_to_owned_provinces: Dictionary = {}
var country_to_occupied_provinces: Dictionary = {}
var province_objects: Dictionary[int, Province] = {}

var biomes: Dictionary[String, BiomeData] = {}
var resources: Dictionary[String, ResourceData] = {}

var adjacency_list: Dictionary = {} # Stores {ID: [Neighbor_ID_1, Neighbor_ID_2, ...]}
var current_hovered_pid: int = -1
var last_hovered_pid: int = -1
var original_hover_color: Color
var province_centers: Dictionary = {} # Stores {ID: Vector2(x, y)}
var unique_regions: Dictionary = {} # NOTE(soi): eh

# This will look like: {"french_empire": [101, 102, 103], "canada": [1, 2, 5]}
var global_claims_registry: Dictionary = {}
var world_tension: float = 0.1 # Global tension level (0.1 to 1.0)

var all_cities: Array[Array] = []

const MAP_DATA_PATH = "res://map_data/MapData.tres"

@onready var significantFigures: Dictionary[String, ImportantFigure] ={}

var gay: Label = Label.new()
# soiladin time
var allowed_pids: Dictionary = {}

func increase_world_tension(amount: float) -> void:
	world_tension = clamp(world_tension + amount, 0.1, 1.0)
const CACHE_FOLDER = "res://map_data/"

@export var region_texture: Texture2D
@export var culture_texture: Texture2D
@export var population_texture: Texture2D
@export var city_texture: Texture2D
@export var gdp_texture: Texture2D
@export var ethnicity_texture: Texture2D
@export var claims_texture: Texture2D

@export var MAP_WIDTH: int = 0
@export var MAP_HEIGHT: int = 625

var icon_cache: Dictionary = {}

func LoadBiomes(a_biomeData: Array) -> void:
	biomes.clear()
	for biome: Dictionary in a_biomeData:
		biomes[biome["name"]] = BiomeData.FromDict(biome)

func LoadResources(a_resourceData: Array) -> void:
	resources.clear()
	for resource: Dictionary in a_resourceData:
		resources[resource["name"]] = ResourceData.FromDict(resource)

# Helper to check both custom and default locations
func FindResourceResource(sub_path: String):
	var full_default = "res://assets/icons/Resources/" + sub_path
	if ResourceLoader.exists(full_default):
		return full_default
	return ""
		
func GetResourceIcon(a_resourceType: String):
	var cache_key: String = a_resourceType

	# If already cached → return it
	if icon_cache.has(cache_key):
		return icon_cache[cache_key]

	# Cache key needs to include ideology if provided
	if !a_resourceType in resources:
		var tex := load(FindResourceResource("Droplet.svg"))
		icon_cache[cache_key] = tex
		return tex
	
	# 0. Check Redirects
	var path = ""
	
	# 4. Fallback to old flat structure (just in case): {path}/country_flag.png
	path = FindResourceResource("%s.svg" % resources[a_resourceType].icon)
	
	if path == "":
		path = FindResourceResource("Droplet.svg")
	
	if path != "":
		var tex := load(path)
		icon_cache[cache_key] = tex
		return tex

	return null

func Initialize(a_map: Texture2D, a_provinceData: Dictionary, a_progress: Array = [0]) -> void:
	MAP_WIDTH = a_map.get_width()
	MAP_HEIGHT = a_map.get_height()

	id_map_image = Image.create(MAP_WIDTH, MAP_HEIGHT, false, Image.FORMAT_RGB8)
	var next_id: int = 2

	var mapImage = a_map.get_image()
	($"../Main/MapContainer/CultureSprite" as Sprite2D).texture = a_map

	var inc: float = 0.2 / (MAP_WIDTH * MAP_HEIGHT)

	for i in range(MAP_WIDTH * MAP_HEIGHT):
		a_progress[0] += inc
		var x: int = i % MAP_WIDTH
		@warning_ignore("integer_division")
		var y: int = i / MAP_WIDTH
		var r_color = mapImage.get_pixel(x, y)

		var index: String = "%d" % (r_color.to_rgba32() >> 8) # I hate alpha.


		# Check for Borders/Grid (ID 1)
		if r_color == Color.BLACK:
			id_map_image.set_pixel(x, y, 1)
			continue

		# If this is a new region (Unique Sea Zone or Land Province)
		if !unique_regions.has(index):
			unique_regions[index] = next_id

			var province: Province = Province.FromDict(a_provinceData.get(index, {}))
			# print("(%d, %d, %d) = " % [r_color.r * 255, r_color.g * 255, r_color.b * 255] + index + " -> Assigned ID: %d For Country: %s" % [next_id, province.country])
			province.id = next_id

			province_objects[next_id] = province
			next_id += 1

		# Write the unique ID to your id_map_image
		id_map_image.set_pixel(x, y, Color.hex((unique_regions[index] << 8) | 0x000000FF))
		
	max_province_id = next_id - 1
	_calculate_province_centroids()
	a_progress[0] += 0.025
	_build_country_to_provinces()
	a_progress[0] += 0.025
	_build_adjacency_list()
	a_progress[0] += 0.025
	_build_global_registry()
	a_progress[0] += 0.025

func load_country_data(
	region_map: CompressedTexture2D,
	a_provinceData: Dictionary,
	a_progress: Array = [0]
) -> void:
	#var dir = DirAccess.open("res://")
	#if dir and not dir.dir_exists(CACHE_FOLDER):
	#	dir.make_dir_recursive(CACHE_FOLDER)
	#
	#if !DEBUG_MODE:
	#	if _try_load_cached_data():
	#		print("MapManager: Loaded cached data with Province Objects.")
	#		return
	Initialize(region_map, a_provinceData, a_progress)

	var map_data := MapData.new()
	map_data.province_centers = province_centers.duplicate()
	map_data.adjacency_list = adjacency_list.duplicate(true)
	map_data.country_to_provinces = country_to_provinces.duplicate()
	map_data.max_province_id = max_province_id
	map_data.id_map_image = id_map_image.duplicate()
	map_data.province_objects = province_objects.duplicate()

	ResourceSaver.save(map_data, MAP_DATA_PATH)

func save_country_data() -> Dictionary:
	var provinces: Dictionary = {}
	for index in unique_regions:
		var next_id = unique_regions[index]
		var province = province_objects[next_id]
		provinces[index] = province.ToDict()
	return provinces

func SaveResourcesData() -> Dictionary:
	var returnResources: Dictionary = {}
	for resource: ResourceData in resources.values():
		returnResources[resource.name] = resource.ToDict()
	return returnResources
	
func SaveBiomeData() -> Dictionary:
	var returnBiomes: Dictionary = {}
	for biome: BiomeData in biomes.values():
		returnBiomes[biome.name] = biome.ToDict()
	return returnBiomes

func export_scenario_data(path: String) -> void:
	var export = {
		"resources": SaveResourcesData(),
		"biomes": SaveBiomeData(),
		"provinces": save_country_data(),
		"polities": CountryManager.save_countries(),
		"ideologies": IdeologyManager.ideologies,
		"factions": FactionManager.save_factions()
	}

	var file = FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(export, "\t"))
		file.close()
		print("Scenario exported to: ", path)
	else:
		push_error("Failed to export scenario to: ", path)

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

	build_lookup_texture()
	return true

func draw_province_centroids(image: Image, color: Color = Color(0, 1, 0, 1)) -> void:
	if not image:
		push_warning("No Image provided for drawing centroids!")
		return

	for pid: int in province_centers.keys():
		var center: Vector2 = province_centers[pid]
		var x: int = int(round(center.x))
		var y: int = int(round(center.y))

		# stay inside bounds
		if x >= 0 and x < image.get_width() and y >= 0 and y < image.get_height():
			image.set_pixel(x, y, color)

func _build_country_to_provinces():
	var result: Dictionary = {}
	var owned: Dictionary = {}

	for pid in province_objects.keys():
		var country: String = province_objects[pid].country

		if !result.has(country):
			result[country] = []
			owned[country] = []

		result[country].append(pid)
		owned[country].append(pid)

	country_to_provinces = result
	allowed_pids = result.duplicate()
	country_to_owned_provinces = owned
	return

func build_lookup_texture() -> void:
	state_color_image = Image.create(max_province_id + 1, 2, false, Image.FORMAT_RGBA8)

	for pid in range(max_province_id + 1):
		if pid <= 1:
			state_color_image.set_pixel(pid, 0, Color.BLACK)
			state_color_image.set_pixel(pid, 1, Color.BLACK)
			continue
		var province = province_objects.get(pid)

		if province == null or province.type == 0: # 0 is province.SEA
			state_color_image.set_pixel(pid, 0, Color.BLACK)
			state_color_image.set_pixel(pid, 1, Color.BLACK)
			continue
			
		state_color_image.set_pixel(pid, 0, CountryManager.GetCountryColor(province.country, Color.GRAY))
		state_color_image.set_pixel(pid, 1, CountryManager.GetCountryColor(province.GetFunctionalOwner(), Color.GRAY))

	state_color_texture = ImageTexture.create_from_image(state_color_image)

func _is_sea(c: Color) -> bool:
	return _dist_sq(c, SEA_RASTER) < 0.001 or _dist_sq(c, SEA_MAIN) < 0.001

func _dist_sq(c1: Color, c2: Color) -> float:
	return (c1.r - c2.r) ** 2 + (c1.g - c2.g) ** 2 + (c1.b - c2.b) ** 2

func update_province_color(pid: int, country_name: String) -> void:
	if pid <= 1 or pid > max_province_id:
		return

	var new_color = CountryManager.GetCountryColor(country_name, Color.GRAY)
	update_lookup(pid, new_color, new_color)

	if pid == last_hovered_pid:
		original_hover_color = new_color
		update_lookup(pid, new_color + Color(0.15, 0.15, 0.15, 0), new_color + Color(0.15, 0.15, 0.15, 0))

func SetProvinceColor(pid: int, primaryColor: Color) -> void:
	if pid <= 1 or pid > max_province_id:
		return
		
	update_lookup(pid, primaryColor, CountryManager.GetCountryColor(province_objects[pid].country, Color.GRAY))

func SetProvinceColors(a_pid: int, a_primaryColor: Color, a_secondaryColor: Color) -> void:
	if a_pid <= 1 or a_pid > max_province_id:
		return
		
	update_lookup(a_pid, a_primaryColor, a_secondaryColor)

func ResetProvinceColor(pid: int) -> void:
	if pid <= 1 or pid > max_province_id:
		return
		
	update_lookup(pid, CountryManager.GetCountryColor(province_objects[pid].GetFunctionalOwner(), Color.GRAY), CountryManager.GetCountryColor(province_objects[pid].country, Color.GRAY))

func set_country_color(country_name: String, custom_color: Color = Color.TRANSPARENT) -> void:
	var new_color = custom_color
	if new_color == Color.TRANSPARENT:
		new_color = CountryManager.GetCountryColor(country_name, Color.GRAY)

	var provinces = country_to_provinces.get(country_name, [])

	if provinces.is_empty():
		print("Warning: No provinces found for country: ", country_name)
		return

	for pid in provinces:
		update_lookup(pid, new_color, new_color)

		if pid == last_hovered_pid:
			original_hover_color = new_color
			update_lookup(pid, new_color + Color(0.15, 0.15, 0.15, 0), new_color + Color(0.15, 0.15, 0.15, 0))

func get_province_at_pos(pos: Vector2, map_sprite: Sprite2D = null) -> int:
	if not id_map_image:
		return 0

	var x: int
	var y: int

	if map_sprite:
		var local: Vector2 = map_sprite.to_local(pos)
		var sprite_size: Vector2 = map_sprite.texture.get_size()

		# If sprite is centered, offset the local position to be top-left based
		if map_sprite.centered:
			local += sprite_size * 0.5

		# --- INFINITE SCROLL MATH ---
		x = int(local.x) % int(sprite_size.x)
		if x < 0:
			x += int(sprite_size.x)
		y = int(local.y)

	else:
		x = int(pos.x)
		y = int(pos.y)

	# Y is not infinite, so we strictly check bounds
	if y < 0 || y >= MAP_HEIGHT || x < 0 || x >= MAP_WIDTH:
		return 0

	return id_map_image.get_pixel(x, y).to_rgba32() >> 8

func handle_hover(global_pos: Vector2, map_sprite: Sprite2D) -> void:
	if _is_mouse_over_ui() or GameState.in_peace_process:
		GameState.tooltip.SwitchTooltip(-1)
		_reset_last_hover()
		return

	var pid = get_province_at_pos(global_pos, map_sprite)
	current_hovered_pid = pid

	var highlight_color = _get_contextual_highlight(pid)

	if pid != last_hovered_pid:
		if GameState.selectingCountry:
			if (last_hovered_pid in province_objects
				&& pid in province_objects
				&& province_objects[last_hovered_pid].country == province_objects[pid].country):
				pass
			else:
				last_hovered_pid = -1
				if pid > 1 and highlight_color != Color.TRANSPARENT:
					if hoveredCountry != province_objects[pid].country:
						if hoveredCountry != "Sea" && country_to_provinces.has(hoveredCountry):
							for province in country_to_provinces[hoveredCountry]:
								update_lookup(province, original_hover_color, original_hover_color)
						if pid in province_objects:
							if province_objects[pid].country != "Sea" && highlight_color != Color.TRANSPARENT:
								original_hover_color = state_color_image.get_pixel(pid, 0)
								for province in country_to_provinces[province_objects[pid].country]:
									update_lookup(province, highlight_color, highlight_color)
								last_hovered_pid = pid
								Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)
								province_hovered.emit(pid, CountryManager.player_country.country_name if !GameState.selectingCountry else "")
							hoveredCountry = province_objects[pid].country
		else:
			_reset_last_hover() # Clean up the old one

			if pid > 1:
				match KeyboardManager.current_view:
					KeyboardManager.MapView.COUNTRIES:
						GameState.tooltip.SwitchTooltip(1)
					KeyboardManager.MapView.RESOURCES:
						GameState.tooltip.SwitchTooltip(0)
					_:
						GameState.tooltip.SwitchTooltip(-1)
				
				if (highlight_color != Color.TRANSPARENT):
					original_hover_color = state_color_image.get_pixel(pid, 0)
					update_lookup(pid, highlight_color, highlight_color)
					last_hovered_pid = pid
					Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)
					province_hovered.emit(pid, CountryManager.player_country.country_name if !GameState.selectingCountry else "")
			else:
				Input.set_default_cursor_shape(Input.CURSOR_ARROW)
				province_hovered.emit(-1, "")
				GameState.tooltip.SwitchTooltip(-1)

func _reset_last_hover() -> void:
	if last_hovered_pid > 1:
		update_lookup(last_hovered_pid, original_hover_color, original_hover_color)
	last_hovered_pid = -1

func _get_contextual_highlight(pid: int) -> Color:
	if pid <= 1:
		return Color.TRANSPARENT
	
	if GameState.selectingCountry:
		return Color.ANTIQUE_WHITE

	var player_name = CountryManager.player_country.country_name
	var is_player_owned = MapManager.province_objects[pid].GetFunctionalOwner() == player_name

	if not is_player_owned:
		return Color.TRANSPARENT

	if GameState.industry_building == GameState.IndustryType.PORT:
		var coastal_provinces = get_provinces_near_sea(player_name)
		if pid in coastal_provinces && province_objects[pid].buildings.find_custom(func(a_building): return a_building.type == "Port") != -1:
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

func handle_click_down(_global_pos: Vector2, _map_sprite: Sprite2D) -> void:
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

	if GameState.selectingCountry:
		for stat in GameState.game_ui.select_player_stat.get_children(): stat.queue_free()

		var selected_country: CountryData = CountryManager.countries[MapManager.province_objects[pid].country]
		GameState.game_ui.selected_country = selected_country
		for stat: String in [
			"is_puppet",
			"money",
			"gdp",
			"income",
			"political_power",
			"stability",
			"ideology_name",
			"manpower",
			"puppets",
			"is_at_war",
		]:
			var stat_label: Label = Label.new()
			stat_label.text = "%s: %s" % [stat.capitalize(), str(selected_country[stat]).capitalize()]
			GameState.game_ui.select_player_stat.add_child(stat_label)

		GameState.game_ui.nation_flag.texture = TroopManager.get_flag(
			selected_country.country_name,
			selected_country.ideology_name
		)
		GameState.game_ui.sidemenu_country_label.text = "%s %s" % [
			selected_country.ideology_name.capitalize(),
			selected_country.country_name.capitalize()
		]

		GameState.game_ui.sidemenu_pointer.position.x = remap(
			selected_country.ideology[0],
			-100,
			100,
			3,
			97
		)
		GameState.game_ui.sidemenu_pointer.position.y = remap(
			selected_country.ideology[1],
			-100,
			100,
			3,
			97
		)

		var play_btn: Button = Button.new()
		play_btn.text = "Play as %s" % selected_country.country_name.capitalize()
		play_btn.pressed.connect(
			func():
			CountryManager.set_player_country(MapManager.province_objects[pid].country)
			GameState.selectingCountry = false
			GameState.game_ui._on_province_clicked(CountryManager.player_country.country_name)
		)
		play_btn.use_parent_material = true
		GameState.game_ui.select_player_stat.add_child(play_btn)


		show_countries_map()
	else:
		var player_country_name = CountryManager.player_country.country_name
		var is_player_owned = MapManager.province_objects[pid].GetFunctionalOwner() == player_country_name
		var is_puppet_owned = MapManager.province_objects[pid].GetFunctionalOwner() in CountryManager.player_country.puppets

		if GameState.choosing_deploy_city:
			if is_player_owned and province_objects[pid].city != "":
				_execute_deployment(pid, player_country_name)
			else:
				print("Action Failed: Province not owned by player or not a city.")

		elif GameState.industry_building != GameState.IndustryType.DEFAULT:
			if EconomyManager.is_province_building(pid):
				print("Action Failed: Already building there.")
			else:
				if is_player_owned:
					if _province_build_industry(pid, player_country_name, GameState.industry_building):
						_cleanup_interaction_state()
						show_industry_country(player_country_name)
						country_clicked.emit(player_country_name)
				elif is_puppet_owned:
					if _province_build_industry(pid, province_objects[pid].GetFunctionalOwner(), GameState.industry_building):
						_cleanup_interaction_state()
						show_industry_country(province_objects[pid].GetFunctionalOwner())
						country_clicked.emit(province_objects[pid].GetFunctionalOwner())
				else:
					print("Action Failed: Cannot build in foreign territory.")
					GameState.reset_industry_building()
					show_countries_map()

		if TroopManager.troop_selection.selected_troops.is_empty(): # Prevent menu from spawning when selecting troops (annoying)
			print("Prae Emit Click")
			country_clicked.emit(province_objects[pid].GetFunctionalOwner())
			print("Post Emit Click")

func _execute_deployment(pid: int, player_name: String) -> void:
	country_clicked.emit(player_name)
	CountryManager.player_country.deploy_pid = pid
	GameState.choosing_deploy_city = false
	_cleanup_interaction_state()

func _province_build_industry(pid: int, player_name: String, type: GameState.IndustryType) -> bool:
	var province = province_objects[pid]

	# 1. Safety Check: Is there already something there or currently building?
	# Using your Enums: 0 = NO, 1 = BUILDING, 2 = BUILT
	if type == GameState.IndustryType.FACTORY:
		if province.buildings.size() >= 4:
			#print("Cannot build: Factory slot is busy or full.")
			return false
			
		EconomyManager.start_construction(pid, "Factory", 10, 150.0, CountryManager.get_country(player_name))
	elif type == GameState.IndustryType.PORT:
		if province.buildings.size() >= 4 && province.buildings.find_custom(func(a_building: BuildingData): return a_building.type != "Port") == -1:
			#print("Cannot build: Port slot is busy or full.")
			return false
			
		# 3. Sea check for Ports
		if pid in get_provinces_near_sea(player_name):
			EconomyManager.start_construction(pid, "Port", 10, 150.0, CountryManager.get_country(player_name))
		else:
			print("Action Failed: Port must be on a coast!")
			return false
	elif type == GameState.IndustryType.INFRASTRUCTURE:
		if province.infrastructure >= province.maxInfrastructure:
			#print("Cannot build: Infrastructure is already maxeda.")
			return false
			
		EconomyManager.StartInfrastructureConstruction(pid, 10, 150.0, CountryManager.get_country(player_name))
		
	return true


func _cleanup_interaction_state() -> void:
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	if last_hovered_pid > 1:
		update_lookup(last_hovered_pid, original_hover_color, original_hover_color)
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
		var pid: int = get_province_at_pos(center + off, map_sprite)
		if pid > 1:
			return pid

	return -1

func update_lookup(pid: int, colorMain: Color, colorSecondary: Color) -> void:
	state_color_image.set_pixel(pid, 0, colorMain)
	state_color_image.set_pixel(pid, 1, colorSecondary)
	state_color_texture.update(state_color_image)

func _calculate_province_centroids() -> void:
	# Use a dictionary to accumulate data: {ID: [total_x, total_y, pixel_count]}
	var accumulators: Dictionary = {}

	# Initialize accumulators for all valid province IDs (IDs > 1)
	for i in range(2, max_province_id + 1):
		accumulators[i] = [0.0, 0.0, 0]

	# --- Pass 1: Accumulate Coordinates ---
	for i in range(MAP_WIDTH * MAP_HEIGHT):
		var x: int = i % MAP_WIDTH
		@warning_ignore("integer_division")
		var y: int = i / MAP_WIDTH
		var pid: int = get_province_at_pos(Vector2(x, y), null) # Use direct coordinates, sprite is null

		if pid > 1 && accumulators.has(pid):
			accumulators[pid][0] += x
			accumulators[pid][1] += y
			accumulators[pid][2] += 1

	# --- Pass 2: Calculate Average (Centroid) ---
	for pid: int in accumulators:
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
	adjacency_list.clear()

	# Prepare dictionary for unique tracking
	var unique_neighbors := {}

	for i in range(MAP_WIDTH * MAP_HEIGHT):
		var x: int = i % MAP_WIDTH
		@warning_ignore("integer_division")
		var y: int = i / MAP_WIDTH
		var pid = _get_pid_fast(x, y)
		if pid <= 1:
			continue

		if not unique_neighbors.has(pid):
			#print("Unique Neighbor: %d" % pid)
			unique_neighbors[pid] = {}

		# 4-directional neighbors

		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nx = x + d.x
			var ny = y + d.y
			if nx < 0 || ny < 0 || nx >= MAP_WIDTH || ny >= MAP_HEIGHT:
				#print("Skipping: (%d, %d)" % [nx, ny])
				continue

			var neighbor = _get_pid_fast(nx, ny)
			#print("Checking Neighbor: %d %d" % [pid, neighbor])

			# Normal adjacency (Land-to-Land)
			if neighbor > 0 && neighbor != pid:
				#print("Neighborship: %d = %d" % [pid, neighbor])
				unique_neighbors[pid][neighbor] = true
				continue

			# Border pixel scan (ID=1)
			if neighbor == 0:
				#print("Across: %d" % pid)
				var across = _scan_across_border(nx, ny, pid)
				if across > 0 and across != pid:
					#print("Across Neighborship: %d = %d" % [pid, across])
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
	# Check right
	if x + 1 < MAP_WIDTH:
		var n: int = _get_pid_fast(x + 1, y)
		if n > 0 and n != pid:
			return n

	# Check down
	if y + 1 < MAP_HEIGHT:
		var n: int = _get_pid_fast(x, y + 1)
		if n > 0 and n != pid:
			return n

	return -1

# Faster direct pid fetch
func _get_pid_fast(x: int, y: int) -> int:
	return id_map_image.get_pixel(x, y).to_rgba32() >> 8

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

	if use_cache && path_cache.has(cache_key):
		return path_cache[cache_key].duplicate()

	var path = _find_path_astar(start_pid, end_pid, allowed_countries)

	if use_cache && !path.is_empty():
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
	var closest_pid_so_far: int = start_pid
	var closest_dist_so_far: float = f_score[start_pid]

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
		var dist_to_target: float = heuristic(current, end_pid)
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
				if current_prov.buildings.find_custom(func(building): return building.type == "Port") == -1:
					continue # BLOCKED: No port to launch ships

			# --- RULE 2: POLITICAL RESTRICTIONS ---
			if restricted_mode:
				# Sea is always free
				if neighbor_prov.type == Province.LAND:
					# Strictly check if the country is in the allowed list
					# If it's not there, we can't enter it—even if it's the end_pid
					if not allowed_dict.has(neighbor_prov.GetFunctionalOwner()):
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
	return province_centers[a].distance_to(province_centers[b]) * HEURISTIC_SCALE

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
	for pid_a: int in province_objects.keys():
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
	return get_viewport().gui_get_hovered_control() != null

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
			current_max_gdp = province.gdp

	for pid in province_objects.keys():
		if pid <= 1:
			continue

		var total: int = 0
		faction_color = Color.GRAY
		for faction in FactionManager.factions:
			if FactionManager.factions[faction].members.find_custom(func(a_factionMember: FactionMember): return a_factionMember.polity == province_objects[pid].country) != -1:
				total += 1
				faction_color = FactionManager.factions[faction].color
		state_color_image.set_pixel(pid, 0, faction_color / total)
		state_color_image.set_pixel(pid, 1, faction_color / total)

	state_color_texture.update(state_color_image)
	KeyboardManager.current_view = KeyboardManager.MapView.FACTION
	print("MapManager: Faction View Updated")

func show_population_map() -> void:
	if province_objects.is_empty():
		return
	var current_max_pop: float = 1.0
	for province in province_objects.values():
		if province.GetPopulation() > current_max_pop:
			current_max_pop = province.GetPopulation()

	for pid in province_objects.keys():
		if pid <= 1:
			continue
		var color: Color = _get_heatmap_color(province_objects[pid].GetPopulation(), current_max_pop)
		state_color_image.set_pixel(pid, 0, color)
		state_color_image.set_pixel(pid, 1, color)

	state_color_texture.update(state_color_image)
	print("MapManager: Population View Updated. Max Pop found: ", current_max_pop)

func ShowInfrastructureMap() -> void:
	if province_objects.is_empty():
		return

	for pid in province_objects.keys():
		if pid <= 1 || province_objects[pid].country == "Sea":
			continue
		if !GameState.selectingCountry and CountryManager.player_country.country_name != province_objects[pid].country and !CountryManager.player_country.allowedCountries.has(province_objects[pid].country):
			state_color_image.set_pixel(pid, 0, CountryManager.GetCountryColor(province_objects[pid].country))
		else:
			var infra = province_objects[pid].infrastructure
			if infra == 0:
				state_color_image.set_pixel(pid, 0, CountryManager.countries[province_objects[pid].country].country_color * 0.5 + Color.WHITE * 0.5)
			elif infra == province_objects[pid].maxInfrastructure:
				state_color_image.set_pixel(pid, 0, CountryManager.countries[province_objects[pid].country].country_color * 0.5 + Color.BLUE * 0.5)
			else:
				state_color_image.set_pixel(pid, 0, CountryManager.countries[province_objects[pid].country].country_color * 0.5 + Color.YELLOW * 0.5 * (float(infra) / province_objects[pid].maxInfrastructure))

	state_color_texture.update(state_color_image)
	print("MapManager: Infrastructure View Updated.")

func show_ethnic_map() -> void:
	if province_objects.is_empty():
		return

	for pid in province_objects.keys():
		# Skip index 0/1 (usually sea or null)
		if pid <= 1:
			continue

		var province: Province = province_objects[pid]
		if (province.populations.size() <= 0):
			continue
		var eth_name = province.populations[0].ethnicity # Assuming this is the String name (e.g., "Igbo")

		# Default to black or transparent if ethnicity not found
		var display_color = Color.BLACK

		if ethnic_name_to_color.has(eth_name):
			display_color = ethnic_name_to_color[eth_name]

		# Update the lookup texture
		state_color_image.set_pixel(pid, 0, display_color)
		state_color_image.set_pixel(pid, 1, display_color)

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
			current_max_gdp = province.gdp

	for pid in province_objects.keys():
		if pid <= 1:
			continue

		var color: Color = _get_gdp_heatmap_color(province_objects[pid].gdp, current_max_gdp)
		state_color_image.set_pixel(pid, 0, color)
		state_color_image.set_pixel(pid, 1, color)

	state_color_texture.update(state_color_image)
	KeyboardManager.current_view = KeyboardManager.MapView.GDP
	print("MapManager: GDP View Updated. Max GDP: ", current_max_gdp)

func GetCountryDisplayColor(a_countryName: String) -> Color:
	var country_data: CountryData = CountryManager.countries.get(a_countryName)
	if !country_data:
		return Color.GRAY
	var owner_data: CountryData = CountryManager.countries.get(country_data.owner)
	if !owner_data:
		return country_data.country_color
	return (country_data.country_color + 3 * owner_data.country_color) * 0.25

func show_countries_map() -> void:
	state_color_image.set_pixel(0, 0, SEA_MAIN) # ID 0: Sea
	state_color_image.set_pixel(1, 0, Color.BLACK) # ID 1: Borders/Grid

	for pid in province_objects.keys():
		if pid <= 1:
			continue

		state_color_image.set_pixel(pid, 0, GetCountryDisplayColor(province_objects[pid].country))
		state_color_image.set_pixel(pid, 1, GetCountryDisplayColor(province_objects[pid].GetFunctionalOwner()))

	state_color_texture.update(state_color_image)
	KeyboardManager.current_view = KeyboardManager.MapView.COUNTRIES

func ShowResourcesMap() -> void:
	state_color_image.set_pixel(0, 0, SEA_MAIN) # ID 0: Sea
	state_color_image.set_pixel(1, 0, Color.BLACK) # ID 1: Borders/Grid

	for pid in province_objects.keys():
		if pid <= 1:
			continue

		state_color_image.set_pixel(pid, 0, GetCountryDisplayColor(province_objects[pid].country))
		state_color_image.set_pixel(pid, 1, GetCountryDisplayColor(province_objects[pid].GetFunctionalOwner()))

	state_color_texture.update(state_color_image)
	KeyboardManager.current_view = KeyboardManager.MapView.RESOURCES

func show_biomes_map() -> void:
	state_color_image.set_pixel(0, 0, SEA_MAIN) # ID 0: Sea
	state_color_image.set_pixel(1, 0, Color.BLACK) # ID 1: Borders/Grid

	for pid in province_objects.keys():
		if pid <= 1:
			continue
		
		var biomeColor: Color = MapManager.biomes[province_objects[pid].biome].color if province_objects[pid].biome in MapManager.biomes else Color.ANTIQUE_WHITE

		state_color_image.set_pixel(pid, 0, biomeColor)
		state_color_image.set_pixel(pid, 1, biomeColor)

	state_color_texture.update(state_color_image)
	KeyboardManager.current_view = KeyboardManager.MapView.BIOMES

func province_updated():
	if GameState.industry_building:
		show_industry_country(CountryManager.player_country.country_name)

func show_industry_country(country_name: String) -> void:
	if not country_to_provinces.has(country_name):
		push_warning("MapManager: Country " + country_name + " not found.")
		return

	var provinces_near_sea := get_provinces_near_sea(country_name)

	for pid in country_to_provinces.get(country_name):
		var province = province_objects[pid]
		var color = Color.WHITE # Default color

		# TODO(sockmit2007): This whole section has to be reworked.
		if province.city.length() > 0:
			color = Color.YELLOW
		
		#elif province.factory == province.FACTORY_BUILT:
		#	color = Color.GREEN
		elif EconomyManager.is_province_building(pid):
			color = Color.ORANGE # Show progress
		#elif province.port == province.PORT_BUILT:
		#	color = Color.BLUE
		#elif province.port == province.PORT_BUILDING:
		#	color = Color.CYAN # Show progress
			
		elif pid in provinces_near_sea:
			color = Color.LIGHT_SKY_BLUE
		
		state_color_image.set_pixel(pid, 0, color)
		state_color_image.set_pixel(pid, 1, color)

	state_color_texture.update(state_color_image)

func transfer_ownership(pid: int, new_owner_name: String) -> void:
	var old_owner_name = MapManager.province_objects[pid].country
	var oldControllerName = MapManager.province_objects[pid].GetFunctionalOwner()

	if province_objects.has(pid):
		province_objects[pid].country = new_owner_name
	else:
		push_error("MapManager: Attempted to transfer ownership of non-existent PID: ", pid)
		return

	if country_to_occupied_provinces.has(MapManager.province_objects[pid].occupier):
		country_to_occupied_provinces[MapManager.province_objects[pid].occupier].erase(pid)
	
	if country_to_owned_provinces.has(old_owner_name):
		country_to_owned_provinces[old_owner_name].erase(pid)
	
	if country_to_provinces.has(oldControllerName):
		country_to_provinces[oldControllerName].erase(pid)

	if not country_to_provinces.has(new_owner_name):
		country_to_provinces[new_owner_name] = []
		
	if not country_to_owned_provinces.has(new_owner_name):
		country_to_owned_provinces[new_owner_name] = []

	if not pid in country_to_provinces[new_owner_name]:
		country_to_provinces[new_owner_name].append(pid)
		
	if not pid in country_to_owned_provinces[new_owner_name]:
		country_to_owned_provinces[new_owner_name].append(pid)
	
	province_objects[pid].occupier = ""

	update_lookup(pid, CountryManager.GetCountryColor(new_owner_name, Color.GRAY), CountryManager.GetCountryColor(new_owner_name, Color.GRAY))

func OccupyProvince(pid: int, new_owner_name: String) -> void:
	var old_owner_name = MapManager.province_objects[pid].country
	var oldControllerName = MapManager.province_objects[pid].GetFunctionalOwner()

	if province_objects.has(pid):
		province_objects[pid].occupier = new_owner_name
	else:
		push_error("MapManager: Attempted to transfer ownership of non-existent PID: ", pid)
		return
		
	if country_to_provinces.has(oldControllerName):
		country_to_provinces[oldControllerName].erase(pid)
		
	if country_to_occupied_provinces.has(oldControllerName):
		country_to_occupied_provinces[oldControllerName].erase(pid)

	if not country_to_provinces.has(new_owner_name):
		country_to_provinces[new_owner_name] = []

	if not pid in country_to_provinces[new_owner_name]:
		country_to_provinces[new_owner_name].append(pid)

	if province_objects[pid].occupier == old_owner_name:
		province_objects[pid].occupier = ""
	else:
		if not country_to_occupied_provinces.has(new_owner_name):
			country_to_occupied_provinces[new_owner_name] = []

		if not pid in country_to_occupied_provinces[new_owner_name]:
			country_to_occupied_provinces[new_owner_name].append(pid)
	#else:
	#	occupied_provinces[new_owner_name] = occupied_provinces.get(new_owner_name, [])
	#	occupied_provinces[new_owner_name].append(pid)

	update_lookup(pid, CountryManager.GetCountryColor(province_objects[pid].country, Color.GRAY), CountryManager.GetCountryColor(province_objects[pid].GetFunctionalOwner(), Color.GRAY))

func DeoccupyProvince(pid: int) -> void:
	if province_objects[pid].occupier != "":
		if country_to_provinces.has(province_objects[pid].occupier):
			country_to_provinces[province_objects[pid].occupier].erase(pid)
			
		if country_to_occupied_provinces.has(province_objects[pid].occupier):
			country_to_occupied_provinces[province_objects[pid].occupier].erase(pid)
		
		if not country_to_provinces.has(province_objects[pid].country):
			country_to_provinces[province_objects[pid].country] = []

		if not pid in country_to_provinces[province_objects[pid].country]:
			country_to_provinces[province_objects[pid].country].append(pid)
			
	province_objects[pid].occupier = ""

	update_lookup(pid, CountryManager.GetCountryColor(province_objects[pid].country, Color.GRAY), CountryManager.GetCountryColor(province_objects[pid].GetFunctionalOwner(), Color.GRAY))

func _parse_color_string(s: String) -> Vector3:
	var parts = s.replace("(", "").replace(")", "").replace(" ", "").split(",")
	return Vector3(float(parts[0]), float(parts[1]), float(parts[2]))

# Helper to ensure we never return a single String when an Array is expected
func _force_array(data) -> Array:
	if data is Array:
		return data
	elif data is String:
		return [data] # Wrap the single country in a list
	return []

func get_provinces_near_sea(country_name: String) -> PackedInt32Array:
	var provinces_near_sea: PackedInt32Array = []

	for pid: int in country_to_provinces.get(country_name, []):
		for neighbor_id: int in adjacency_list.get(pid, []):
			var neighbor_province: Province = province_objects.get(neighbor_id)

			if neighbor_province && neighbor_province.type == 0: # Assuming 0 is SEA
				provinces_near_sea.append(pid)
				break

	return provinces_near_sea

## Returns an array of province IDs that are on the border of a different country
func get_border_provinces(country_name: String) -> PackedInt32Array:
	var border_provinces: PackedInt32Array = []

	# Get all provinces owned by this country

	for prov_id: int in country_to_provinces.get(country_name, []):
		var province_data: Province = province_objects.get(prov_id)

		if !province_data:
			continue

		# Check neighbors of this province
		for neighbor_id: int in province_data.neighbors:
			# If the neighbor is owned by someone else (and isn't sea/neutral)
			if MapManager.province_objects[neighbor_id].GetFunctionalOwner() != country_name:
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

func ReleaseCountry(a_countryName: String) -> void:
	for obj in province_objects.values():
		if obj.claims.has(a_countryName):
			for troop in TroopManager.troops_by_province.get(obj.id, []):
				if is_instance_valid(troop):
					TroopManager.remove_troop(troop)

			transfer_ownership(obj.id, a_countryName)
	CountryManager.add_country({"name": a_countryName})
	CountryManager.cleanup_empty_countries()

func InstantiateCountryFromClaims(a_countryData: Dictionary) -> void:
	CountryManager.add_country(a_countryData)
	
	for obj: Province in province_objects.values():
		if obj.claims.has(a_countryData["name"]):
			for troop in TroopManager.troops_by_province.get(obj.id, []):
				if is_instance_valid(troop):
					TroopManager.remove_troop(troop)

			transfer_ownership(obj.id, a_countryData["name"])
	CountryManager.cleanup_empty_countries()

func InstantiateCountryFromProvinces(a_countryData: Dictionary, a_claims: PackedInt32Array) -> void:
	CountryManager.add_country(a_countryData)
	for pid: int in a_claims:
		for troop in TroopManager.troops_by_province.get(pid, []):
			if is_instance_valid(troop):
				TroopManager.remove_troop(troop)

		transfer_ownership(pid, a_countryData["name"])
	CountryManager.cleanup_empty_countries()

func get_all_cities() -> Array[Array]:
	var pids: Array[Array] = []
	for obj: Province in province_objects.values():
		if len(obj.city) > 0:
			pids.append([obj.id, obj.city])
	return pids

func get_cities_province_country(country_name) -> Array:
	var provinces = []
	for pid in country_to_provinces.get(country_name, []):
		if province_objects[pid].GetFunctionalOwner() == country_name and len(province_objects[pid].city) > 0:
			provinces.append(pid)
	return provinces

## Returns provinces that specifically border a certain enemy
func get_provinces_bordering_enemies(country_name: String, enemies: Array[String]) -> PackedInt32Array:
	var specific_borders: PackedInt32Array = []

	for prov_id: int in allowed_pids.get(country_name, []):
		# NOTE(soi): make this better  in c# or smthn T_T
		for neighbor_id: int in province_objects.get(prov_id).neighbors:
			if MapManager.province_objects[neighbor_id].GetFunctionalOwner() in enemies:
				specific_borders.append(prov_id)
				break

	return specific_borders

func annex_country(annexer: String, annexee: String) -> void:
	#var playerobj = CountryManager.player_country
	for troop: TroopData in TroopManager.get_troops_for_country(annexee):
		TroopManager.remove_troop(troop)
		
	for pid: int in country_to_occupied_provinces.get(annexee, []):
		DeoccupyProvince(pid)

	var provinces_to_transfer = country_to_owned_provinces.get(annexee, [])

	if provinces_to_transfer.is_empty():
		print("MapManager: No provinces found for ", annexee)
		return

	for pid in provinces_to_transfer.duplicate():
		transfer_ownership(pid, annexer)

	#playerobj.reset_manpower()
	print("ANNEXATION COMPLETE: ", annexer, " has taken all of ", annexee)

func _build_global_registry():
	global_claims_registry.clear()
	for obj in province_objects.values():
		for country_name in obj.claims:
			if not global_claims_registry.has(country_name):
				global_claims_registry[country_name] = []
			global_claims_registry[country_name].append(obj.id)


func allow_pids(accesser: CountryData, accessee: CountryData):
	if !allowed_pids.has(accesser.country_name):
		allowed_pids[accesser.country_name] = []
	for province in country_to_provinces[accessee.country_name]:
		allowed_pids[accesser.country_name].append(province)


func unallow_pids(unaccesser: CountryData, unaccessee: CountryData):
	for province in country_to_provinces[unaccessee.country_name]:
		allowed_pids[unaccesser.country_name].erase(province)
