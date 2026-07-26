extends Node2D
class_name MapContainer

@onready var map_sprite: Sprite2D = $CultureSprite as Sprite2D
@onready var camera: Camera2D = $"../Camera2D"

@export var map_shader: Shader
@export var clock: GameClock

var water_offset: Vector2 = Vector2.ZERO


var _cached_map_width: int = 0
var _ocean_shader_timer: float = 0.0

func _process(_delta: float) -> void:
	if _cached_map_width <= 0 and is_instance_valid(MapManager) and MapManager.id_map_image:
		_cached_map_width = MapManager.id_map_image.get_width()

	if _cached_map_width > 0 and camera:
		if camera.position.x > map_sprite.position.x + _cached_map_width:
			camera.position.x -= _cached_map_width
		elif camera.position.x < map_sprite.position.x - _cached_map_width:
			camera.position.x += _cached_map_width

	if map_sprite and map_sprite.material and is_instance_valid(clock) and !clock.paused:
		_ocean_shader_timer += _delta
		if _ocean_shader_timer >= 0.066: # ~15 FPS shader uniform update
			water_offset.x += clock.time_scale * 0.001 * _ocean_shader_timer
			_ocean_shader_timer = 0.0
			map_sprite.material.set_shader_parameter("ocean_offset", water_offset)


func _enter_tree() -> void:
	GameState.current_map = self


func _ready() -> void:
	clock = GameState.main.clock
	var map_width := MapManager.id_map_image.get_width()
	var map_height := MapManager.id_map_image.get_height()

	var mat := ShaderMaterial.new()
	mat.shader = map_shader
	var id_tex := ImageTexture.create_from_image(MapManager.id_map_image)
	mat.set_shader_parameter("region_id_map", id_tex)
	mat.set_shader_parameter("state_colors", MapManager.state_color_texture)

	var type_tex = MapManager.generate_type_mask()
	mat.set_shader_parameter("type_map", type_tex)

	var noise = FastNoiseLite.new()
	noise.seed = randi()

	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH

	noise.frequency = 0.005

	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 3
	noise.fractal_gain = 0.5

	var noise_tex = NoiseTexture2D.new()
	noise_tex.seamless = true
	noise_tex.width = 512
	noise_tex.height = 512
	noise_tex.noise = noise

	await noise_tex.changed
	mat.set_shader_parameter("ocean_noise", noise_tex)

	mat.set_shader_parameter("original_texture", map_sprite.texture)
	mat.set_shader_parameter("sea_speed", 0.00)  # Changed by MainClock
	mat.set_shader_parameter("tex_size", Vector2(map_width, MapManager.id_map_image.get_height()))
	mat.set_shader_parameter("country_border_color", Color.BLACK)

	map_sprite.material = mat

	for i in [-2, -1, 1, 2]:
		_create_ghost_map(Vector2(i * map_width, 0), mat)


func _create_ghost_map(offset: Vector2, p_material: ShaderMaterial) -> void:
	var ghost := Sprite2D.new()
	ghost.texture = map_sprite.texture
	ghost.centered = map_sprite.centered
	ghost.material = p_material
	ghost.position = map_sprite.position + offset
	add_child(ghost)
