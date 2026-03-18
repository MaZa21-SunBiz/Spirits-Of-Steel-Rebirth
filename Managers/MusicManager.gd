extends Node

var music_player: AudioStreamPlayer
var sfx_players: Array[AudioStreamPlayer] = []

var current_track_type: int = -1

# --- Enums ---
enum SFX {
	TROOP_MOVE,
	TROOP_SELECTED,
	BATTLE_START,
	OPEN_MENU,
	DECLARE_WAR,
	HOVERED,
	CLOSE_MENU,
	GAME_OVER,
	POPUP,
	BUILD,
	CLAPPING
}

enum MUSIC { MAIN_THEME, BATTLE_THEME }

const default_music_path = "res://assets/music/"
const custom_music_path = "res://radios/"

var sfx_map = {
	SFX.TROOP_MOVE: preload("res://assets/snd/moveDivSound.mp3"),
	SFX.TROOP_SELECTED: preload("res://assets/snd/selectDivSound.mp3"),
	SFX.OPEN_MENU: preload("res://assets/snd/openMenuSound.mp3"),
	SFX.CLOSE_MENU: preload("res://assets/snd/closeMenuSound.mp3"),
	SFX.DECLARE_WAR: preload("res://assets/snd/declareWarSound.mp3"),
	SFX.HOVERED: preload("res://assets/snd/hoveredSound.mp3"),
	SFX.GAME_OVER: preload("res://assets/snd/endGameSound.mp3"),
	SFX.POPUP: preload("res://assets/snd/popupSound.mp3"),
	SFX.BUILD: preload("res://assets/snd/buildSound.mp3"),
	SFX.CLAPPING: preload("res://assets/snd/clappingSound.mp3")
}

var sfx_volume_map = {
	SFX.TROOP_MOVE: 0.1,
	SFX.TROOP_SELECTED: 1.6,
	SFX.BATTLE_START: 0.8,
	SFX.OPEN_MENU: 0.5,
	SFX.CLOSE_MENU: 0.5,
	SFX.DECLARE_WAR: 0.9,
	SFX.HOVERED: 0.3,
	SFX.GAME_OVER: 0.5,
	SFX.POPUP: 0.5,
}

var music_map = {MUSIC.MAIN_THEME: {}, MUSIC.BATTLE_THEME: {}}

var radios = ["default"]

var music_volume_map = {MUSIC.MAIN_THEME: 0.4, MUSIC.BATTLE_THEME: 0.5}


func _ready():
	for radio in DirAccess.open(default_music_path).get_directories():
		if radio != "superevents":
			music_map[MUSIC.MAIN_THEME][radio] = []
			music_map[MUSIC.BATTLE_THEME][radio] = []
			_load_music_folder(default_music_path, radio, MUSIC.MAIN_THEME)
			_load_music_folder(default_music_path, radio, MUSIC.BATTLE_THEME)

	for radio in DirAccess.open(custom_music_path).get_directories():
		if radio != "superevents":
			music_map[MUSIC.MAIN_THEME][radio] = []
			music_map[MUSIC.BATTLE_THEME][radio] = []
			_load_music_folder(custom_music_path, radio, MUSIC.MAIN_THEME)
			_load_music_folder(custom_music_path, radio, MUSIC.BATTLE_THEME)

	music_player = AudioStreamPlayer.new()
	music_player.bus = "Music"
	music_player.finished.connect(_on_music_finished)
	add_child(music_player)

	for i in 8:
		var p = AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		sfx_players.append(p)

	play_music(MUSIC.MAIN_THEME)

func _load_music_folder(path: String, radio: String, track_enum: int):
	path += radio
	match track_enum:
		MUSIC.MAIN_THEME:
			path += "/gameMusic"
		MUSIC.BATTLE_THEME:
			path += "/warMusic"
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and not file_name.ends_with(".import"):
				var stream = load(path + "/" + file_name)
				if stream:
					music_map[track_enum][radio].append(stream)
			file_name = dir.get_next()


var last_track_type: int = MUSIC.MAIN_THEME
var locking_custom_track: bool = false

func play_music(track: int):
	# If a custom track is playing and locked, ignore normal music requests
	if locking_custom_track:
		# Optionally, we could store the requested track as the "next" track to resume to
		if track in [MUSIC.MAIN_THEME, MUSIC.BATTLE_THEME]:
			last_track_type = track
		return

	if not music_map.has(track) or music_map[track].is_empty():
		return

	if current_track_type == track and music_player.playing:
		return

	# Store as last track if it's a valid standard track
	if track in [MUSIC.MAIN_THEME, MUSIC.BATTLE_THEME]:
		last_track_type = track

	current_track_type = track

	var songs = []
	for radio in radios:
		songs.append_array(music_map[track][radio])
	
	if songs.is_empty():
		return
		
	# print(radios)
	# print(songs)
	var song = songs.pick_random()
	if GameState.game_ui and GameState.game_ui.now_playing:
		GameState.game_ui.now_playing.text = song.resource_path.get_file()
	music_player.stream = song
	music_player.volume_db = linear_to_db(music_volume_map.get(track, 1.0))
	music_player.play()


func play_custom_file(full_path: String):
	if not FileAccess.file_exists(full_path) and not ResourceLoader.exists(full_path):
		push_warning("MusicManager: Custom file not found: " + full_path)
		return

	# Stop standard shuffle
	current_track_type = -1
	
	var stream = load(full_path)
	if stream:
		locking_custom_track = true
		music_player.stream = stream
		music_player.volume_db = linear_to_db(1.0) # Default volume for events
		music_player.play()


func resume_last_track():
	locking_custom_track = false # Ensure lock is released
	if last_track_type != -1:
		play_music(last_track_type)
	else:
		play_music(MUSIC.MAIN_THEME)


func _on_music_finished():
	if locking_custom_track:
		resume_last_track()
		return
		
	var temp_type = current_track_type
	current_track_type = -1
	play_music(temp_type)


func fade_out_music(duration: float = 1.0):
	var tween = create_tween()
	tween.tween_property(music_player, "volume_db", -80.0, duration)
	await tween.finished
	music_player.stop()
	current_track_type = -1


func play_sfx(sfx: int):
	if sfx not in sfx_map:
		return
	var player = sfx_players.filter(func(p): return not p.playing).front()
	if not player:
		player = sfx_players[0]

	player.stream = sfx_map[sfx]
	player.volume_db = linear_to_db(sfx_volume_map.get(sfx, 1.0))
	player.play()


func stop_all_sfx():
	for p in sfx_players:
		p.stop()


func set_music_volume(volume_linear: float):
	music_player.volume_db = linear_to_db(volume_linear)


func set_sfx_volume(volume_linear: float):
	for p in sfx_players:
		p.volume_db = linear_to_db(volume_linear)
		
func _toggle_pause() -> void:
	music_player.playing = !music_player.playing
