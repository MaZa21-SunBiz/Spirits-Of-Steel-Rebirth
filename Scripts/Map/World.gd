extends Node2D
class_name World

@onready var map_sprite: Sprite2D = $"../../MapContainer/CultureSprite" as Sprite2D
@onready var camera: Camera2D = $"../../Camera2D" as Camera2D
@onready var troop_renderer: CustomRenderer = $CustomRenderer as CustomRenderer

@export var map_shader: Shader
var clock: GameClock

var water_offset: Vector2 = Vector2.ZERO



func _process(_delta: float) -> void:
	if !map_sprite: return
	var map_width := MapManager.id_map_image.get_width()
	if camera.position.x > map_sprite.position.x + map_width:
		camera.position.x -= map_width
	elif camera.position.x < map_sprite.position.x - map_width:
		camera.position.x += map_width
	if map_sprite.material and clock and !clock.paused:
		var move_amount = clock.time_scale * 0.001 * _delta
		water_offset.x += move_amount
		map_sprite.material.set_shader_parameter("ocean_offset", water_offset)


func _enter_tree() -> void:
	GameState.current_world = self
	clock = $/root/Main/Clock
	KeyboardManager.settings = $ui_game/Settings
	TroopManager.troop_selection = $TroopSelection as TroopSelection
	# TODO(pol): Load CountryManager after map instead of an autoload to avoid this.

func DoSetup(a_progress: Array) -> void:
	var path = "res://map_data/map_data.json" # Ensure path is correct
	if not FileAccess.file_exists(path):
		push_error("Map Data JSON missing!")
		return

	a_progress[0] = 0.01
	var json_data = JSON.parse_string(FileAccess.open(path, FileAccess.READ).get_as_text())
	a_progress[0] = 0.03
	var mapData: Dictionary = json_data if json_data is Dictionary else {}
	a_progress[0] = 0.05

	# NOTE(soi): this is here bcuz sometimes main menu is used and im too lazy to comment this out
	if MapManager.province_objects.is_empty():
		load_map_data(mapData)
	a_progress[0] = 0.2

	print("World: Map is ready -> configuring visuals...")

	MapManager.all_cities = MapManager.get_all_cities()
	a_progress[0] = 0.21

	if !CountryManager.player_country:
		# CountryManager.set_player_country(CountryManager.countries.keys().pick_random())
		GameState.selectingCountry = true
		# NOTE(soi): wait so like when i click on a country this should magically play as it?????. damm
	# For debugging purposes. Create some troops first
	MapManager.force_bidirectional_connections()
	a_progress[0] = 0.30
	MapManager._build_global_registry()
	a_progress[0] = 0.35
	var map_width: int = MapManager.MAP_WIDTH
	var map_height: int = MapManager.MAP_HEIGHT

	var mat := ShaderMaterial.new()
	mat.shader = map_shader
	mat.set_shader_parameter("region_id_map", ImageTexture.create_from_image(MapManager.id_map_image))
	mat.set_shader_parameter("state_colors", MapManager.state_color_texture)

	# @warning_ignore("narrowing_conversion")
	var type_img := Image.create_empty(map_width, map_height, false, Image.FORMAT_L8)
	var uncertain_pixels := []
	var x: int
	var y: int
	var inc: float = 0.45 / (map_width * map_height) # Adjust this based on how long you want the loading to take
	# --- PASS 1: Direct Mapping ---
	for i in range(map_height * map_width):
		x = i % map_width
		@warning_ignore("integer_division")
		y = i / map_width
		var province = MapManager.province_objects.get(MapManager._get_pid_fast(x, y))

		if province:
			a_progress[0] += inc
			if province.type == Province.SEA: # SEA
				type_img.set_pixel(x, y, Color(0, 0, 0))
			else: # LAND
				type_img.set_pixel(x, y, Color(1, 1, 1))
		else:
			# It's a border (PID 1 or null). Mark as uncertain for now.
			uncertain_pixels.append(Vector2i(x, y))

	# --- PASS 2: Intelligent Flood-Check ---
	for pos in uncertain_pixels:
		a_progress[0] += inc
		var touches_land: bool = false
		#var touches_sea = false

		# Check 8-way neighbors (Radius 1 ONLY - very important)
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				if dx == 0 and dy == 0:
					continue

				var nx = pos.x + dx
				var ny = pos.y + dy

				if nx >= 0 && nx < map_width && ny >= 0 && ny < map_height:
					var nid = MapManager._get_pid_fast(nx, ny)
					if nid > 1:
						var n_prov: Province = MapManager.province_objects.get(nid)
						if n_prov:
							if n_prov.type != 0:
								touches_land = true
							#else:
							#	touches_sea = true

		if touches_land:
			type_img.set_pixel(pos.x, pos.y, Color(1, 1, 1))
		else:
			# If it only touches sea (or nothing), it's a Sea Grid/Open Water
			type_img.set_pixel(pos.x, pos.y, Color(0, 0, 0))

	mat.set_shader_parameter("type_map", ImageTexture.create_from_image(type_img))

	var noise = FastNoiseLite.new()
	noise.seed = randi()

	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH

	noise.frequency = 0.005

	noise.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	noise.fractal_octaves = 5
	noise.fractal_lacunarity = 3.0
	noise.fractal_gain = 0.5

	var noise_tex = NoiseTexture2D.new()
	noise_tex.seamless = true
	noise_tex.width = 512
	noise_tex.height = 512
	noise_tex.noise = noise

	await noise_tex.changed
	mat.set_shader_parameter("ocean_noise", noise_tex)

	mat.set_shader_parameter("original_texture", map_sprite.texture)
	mat.set_shader_parameter("sea_speed", 0.00) # Changed by MainClock
	mat.set_shader_parameter("tex_size", Vector2(map_width, map_height))
	mat.set_shader_parameter("country_border_color", Color.BLACK)

	map_sprite.material = mat
	a_progress[0] = 0.9

	for i in [-2, -1, 1, 2]:
		_create_ghost_map(Vector2(i * map_width, 0), mat)
		a_progress[0] += 0.015

	if troop_renderer:
		troop_renderer.map_sprite = map_sprite
		troop_renderer.map_width = map_width
	else:
		push_error("CustomRenderer node not found!")

	SettingsManager.apply_settings()

	a_progress[0] = 1.0
	
	clock.hour_passed.connect(CountryManager._on_hour_passed)
	clock.day_passed.connect(CountryManager._on_day_passed)

func load_map_data(mapData):
	MapManager.LoadBiomes(mapData["biomes"] as Array)
	MapManager.LoadResources(mapData["resources"] as Array)
	IdeologyManager.Initialize(mapData["ideologies"] as Dictionary)
	MapManager.load_country_data(preload("res://maps/regions.png"), mapData["provinces"] as Dictionary, mapData["significant_figures"])
	CountryManager.initialize_countries(mapData["polities"] as Array[Dictionary])
	MapManager.build_lookup_texture()
	FactionManager.Initialize(mapData["factions"])
	
	Console.add_command_autocomplete_list("play_as", CountryManager.countries.keys())

func _create_ghost_map(offset: Vector2, p_material: ShaderMaterial) -> void:
	var ghost := Sprite2D.new()
	ghost.texture = map_sprite.texture
	ghost.centered = map_sprite.centered
	ghost.material = p_material
	ghost.position = map_sprite.position + offset
	$"../../MapContainer".add_child(ghost)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			MapManager.handle_click_down(get_global_mouse_position(), map_sprite)
		else:
			MapManager.handle_click(get_global_mouse_position(), map_sprite)
	if event is InputEventMouseMotion:
		MapManager.handle_hover(get_global_mouse_position(), map_sprite)


func save_game(slot: String):
	var save = SaveGame.new()
	
	# Use duplicate() WITHOUT 'true'. 
	# This copies the list of pointers to your Resources, which is what ResourceSaver needs.
	
	# --- COUNTRY DATA ---
	save.countries = CountryManager.countries.duplicate()
	if CountryManager.player_country:
		save.player_country_name = CountryManager.player_country.country_name
	
	# --- MAP DATA ---
	save.province_objects = MapManager.province_objects.duplicate()
	save.province_to_country = MapManager.province_to_country.duplicate()
	save.country_to_provinces = MapManager.country_to_provinces.duplicate()
	
	# --- TROOP DATA ---
	save.troops = TroopManager.troops.duplicate()
	save.moving_troops = TroopManager.moving_troops.duplicate()
	save.troops_by_province = TroopManager.troops_by_province.duplicate()
	save.troops_by_country = TroopManager.troops_by_country.duplicate()
	
	# Ensure directory exists
	if not DirAccess.dir_exists_absolute("res://saves/"):
		DirAccess.make_dir_absolute("res://saves/")
		
	var path = "res://saves/" + slot + ".tres"
	var error = ResourceSaver.save(save, path)
	
	if error == OK:
		print("Game State saved successfully to: ", path)
	else:
		printerr("Save failed! Error code: ", error)
	
func load_game(save_name: String):
	var path = "res://saves/" + save_name + ".tres"

	# --- 1. File check ---
	if not FileAccess.file_exists(path):
		push_error("Save file not found: " + path)
		return

	# --- 2. Load WITHOUT cache ---
	var save := ResourceLoader.load(
		path,
		"",
		ResourceLoader.CACHE_MODE_IGNORE
	) as SaveGame

	if not save:
		push_error("Failed to load SaveGame resource!")
		return

	# --- 3. Pause systems that react to state ---
	if troop_renderer:
		troop_renderer.set_process(false)

	# =====================================================
	# COUNTRY MANAGER
	# =====================================================
	CountryManager.countries.clear()

	for c_name in save.countries:
		var country = save.countries[c_name]
		if country is CountryData:
			country._is_loading = true
			CountryManager.countries[c_name] = country


	CountryManager.set_player_country(save.player_country_name)

	# =====================================================
	# MAP MANAGER
	# =====================================================
	MapManager.province_objects.clear()
	for p_id in save.province_objects:
		var province = save.province_objects[p_id]
		if province is Province:
			MapManager.province_objects[p_id] = province

	MapManager.province_to_country.clear()
	for p_id in save.province_to_country:
		MapManager.province_to_country[p_id] = save.province_to_country[p_id]

	MapManager.country_to_provinces.clear()
	for c_name in save.country_to_provinces:
		MapManager.country_to_provinces[c_name] = save.country_to_provinces[c_name].duplicate()

	# =====================================================
	# TROOP MANAGER (CRITICAL ORDER)
	# =====================================================
	TroopManager.troops.clear()
	TroopManager.moving_troops.clear()
	TroopManager.troops_by_province.clear()
	TroopManager.troops_by_country.clear()

	# --- 1. Load canonical troop list ---
	for t in save.troops:
		if t is TroopData:
			t.country_obj = CountryManager.get_country(t.country_name)
			TroopManager.troops.append(t)

	# --- 2. Moving troops ---
	for t in save.moving_troops:
		if t is TroopData:
			TroopManager.moving_troops.append(t)

	# --- 3. Rebuild province → troops ---
	for province_id in save.troops_by_province:
		TroopManager.troops_by_province[province_id] = []
		for t in save.troops_by_province[province_id]:
			if t is TroopData:
				TroopManager.troops_by_province[province_id].append(t)

	# --- 4. Rebuild country → troops ---
	for c_name in save.troops_by_country:
		TroopManager.troops_by_country[c_name] = []
		for t in save.troops_by_country[c_name]:
			if t is TroopData:
				TroopManager.troops_by_country[c_name].append(t)

	# =====================================================
	# WORLD REFRESH
	# =====================================================
	MapManager._build_lookup_texture()

	if troop_renderer:
		troop_renderer.set_process(true)

	print("Game loaded successfully:", save_name)
