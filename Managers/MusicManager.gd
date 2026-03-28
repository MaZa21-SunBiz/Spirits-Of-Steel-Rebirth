extends Node

var current_track_type: int = -1

var music_player: AudioStreamPlayer:
	get:
		return get_node_or_null("/root/Main/Audio/Music")

var _interactive_stream: AudioStream = null
const USE_INTERACTIVE = false # Fallback to manual shuffle if interactive fails

var sfx_players: Array[AudioStreamPlayer]:
	get:
		var players: Array[AudioStreamPlayer] = []
		var sfx_node = get_node_or_null("/root/Main/Audio/SFX")
		if sfx_node is AudioStreamPlayer:
			players.append(sfx_node)
		if sfx_node:
			for child in sfx_node.get_children():
				if child is AudioStreamPlayer:
					players.append(child)
		return players

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

enum MUSIC {MAIN_THEME, BATTLE_THEME}

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



var music_map = {MUSIC.MAIN_THEME: {}, MUSIC.BATTLE_THEME: {}}

var radios = ["default"]

var music_volume_map = {MUSIC.MAIN_THEME: 1.0, MUSIC.BATTLE_THEME: 1.0}


func _ready():
	var default_dir = DirAccess.open(default_music_path)
	if default_dir:
		for radio in default_dir.get_directories():
			if radio != "superevents":
				music_map[MUSIC.MAIN_THEME][radio] = []
				music_map[MUSIC.BATTLE_THEME][radio] = []
				_load_music_folder(default_music_path, radio, MUSIC.MAIN_THEME)
				_load_music_folder(default_music_path, radio, MUSIC.BATTLE_THEME)
				if radio not in radios:
					radios.append(radio)

	var custom_dir = DirAccess.open(custom_music_path)
	if custom_dir:
		for radio in custom_dir.get_directories():
			if radio != "superevents":
				music_map[MUSIC.MAIN_THEME][radio] = []
				music_map[MUSIC.BATTLE_THEME][radio] = []
				_load_music_folder(custom_music_path, radio, MUSIC.MAIN_THEME)
				_load_music_folder(custom_music_path, radio, MUSIC.BATTLE_THEME)
				if radio not in radios:
					radios.append(radio)
		
	# Note: We don't setup audio here because the scene tree isn't ready for autoloads.
	# Audio.gd will call setup_audio() when it's ready.

func setup_audio():
	if music_player:
		print("MusicManager: Setting up audio system...")
		if not music_player.finished.is_connected(_on_music_finished):
			music_player.finished.connect(_on_music_finished)
		if not _interactive_stream:
			_interactive_stream = music_player.stream
			print("MusicManager: Captured interactive stream: ", _interactive_stream)
		update_interactive_playlists()
		if current_track_type == -1:
			play_music(MUSIC.MAIN_THEME)
		else:
			play_music(current_track_type)
		
		# Diagnostic check
		debug_audio_status()
	else:
		printerr("MusicManager: setup_audio called but music_player is still null!")

func debug_audio_status():
	print("--- AUDIO DIAGNOSTIC ---")
	print("Master Bus Volume: ", AudioServer.get_bus_volume_db(0), " Muted: ", AudioServer.is_bus_mute(0))
	var music_bus_idx = AudioServer.get_bus_index("Music")
	if music_bus_idx != -1:
		print("Music Bus Volume: ", AudioServer.get_bus_volume_db(music_bus_idx), " Muted: ", AudioServer.is_bus_mute(music_bus_idx))
	else:
		print("Music Bus NOT FOUND!")
	
	var m_player = music_player
	if m_player:
		print("Music Player Node: ", m_player.get_path())
		print("Music Player Stream: ", m_player.stream)
		print("Music Player Playing: ", m_player.playing)
		print("Music Player Volume DB: ", m_player.volume_db)
		print("Music Player Bus: ", m_player.bus)
	else:
		print("Music Player Node NOT FOUND at path '/root/Main/Audio/Music'")
	print("-----------------------")

func debug_play_direct():
	print("MusicManager: Attempting direct playback test...")
	var m_player = music_player
	if m_player:
		var test_path = "res://assets/music/default/gameMusic/Miyasan_Miyasan.mp3"
		var stream = load(test_path)
		if stream:
			print("MusicManager: Loaded test stream: ", test_path)
			m_player.stream = stream
			m_player.volume_db = 0 # Full volume
			m_player.play()
			print("MusicManager: Called play() on test stream.")
		else:
			print("MusicManager: FAILED to load test stream: ", test_path)


func update_interactive_playlists():
	var m_player = music_player
	if not m_player:
		return
		
	var interactive: AudioStreamInteractive = null
	if m_player.stream is AudioStreamInteractive:
		interactive = m_player.stream
	elif _interactive_stream is AudioStreamInteractive:
		interactive = _interactive_stream
		
	if not interactive:
		print("MusicManager: No AudioStreamInteractive found to update!")
		return
		
	print("MusicManager: Updating interactive playlists for radios: ", radios)
	for clip_idx in range(interactive.clip_count):
		var clip_name = interactive.get_clip_name(clip_idx)
		var playlist = interactive.get_clip_stream(clip_idx) as AudioStreamPlaylist
		if not playlist:
			continue
			
		var target_track = -1
		if clip_name == &"Main":
			target_track = MUSIC.MAIN_THEME
		elif clip_name == &"War":
			target_track = MUSIC.BATTLE_THEME
			
		if target_track != -1:
			var songs = []
			for radio in radios:
				if music_map.has(target_track) and music_map[target_track].has(radio):
					songs.append_array(music_map[target_track][radio])
					
			if not songs.is_empty():
				var new_playlist = AudioStreamPlaylist.new()
				new_playlist.stream_count = songs.size()
				new_playlist.loop = true
				new_playlist.shuffle = true
				for i in range(songs.size()):
					new_playlist.set_list_stream(i, songs[i])
				
				interactive.set_clip_stream(clip_idx, new_playlist)
				print("MusicManager: Assigned fresh playlist to '", clip_name, "' with ", songs.size(), " songs.")
			else:
				print("MusicManager: No songs found for radio group '", target_track, "'")
	
	# Force refresh the playback by re-assigning the stream
	if m_player.stream == interactive or m_player.stream == _interactive_stream:
		m_player.stream = null # Temporarily clear to force rebuild
		m_player.stream = interactive
		if current_track_type != -1:
			play_music(current_track_type)
		print("MusicManager: Forced stream refresh for AudioStreamInteractive.")


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
		if track in [MUSIC.MAIN_THEME, MUSIC.BATTLE_THEME]:
			last_track_type = track
		return

	if not music_map.has(track) or music_map[track].is_empty():
		return

	var m_player = music_player
	if not m_player:
		return

	if not _interactive_stream and m_player.stream is AudioStreamInteractive:
		_interactive_stream = m_player.stream
		update_interactive_playlists()


	# Store as last track if it's a valid standard track
	if track in [MUSIC.MAIN_THEME, MUSIC.BATTLE_THEME]:
		last_track_type = track

	if current_track_type == track and m_player.playing:
		return


	current_track_type = track

	if USE_INTERACTIVE:
		if not m_player.playing:
			m_player.play()
			print("MusicManager: Started m_player playback.")

		if GameState.game_ui:
			GameState.game_ui.now_playing.text = m_player.stream.resource_path.get_file()

		var playback = m_player.get_stream_playback() as AudioStreamPlaybackInteractive
		if playback:
			if track == MUSIC.MAIN_THEME:
				playback.switch_to_clip_by_name(&"Main")
			elif track == MUSIC.BATTLE_THEME:
				playback.switch_to_clip_by_name(&"War")
	else:
		# Manual Fallback Logic
		var songs = []
		for radio in radios:
			if music_map.has(track) and music_map[track].has(radio):
				songs.append_array(music_map[track][radio])
		
		if not songs.is_empty():
			var song = songs.pick_random()
			print("MusicManager: Manual Fallback - Playing song: ", song.resource_path.get_file())
			if GameState.game_ui and GameState.game_ui.now_playing:
				GameState.game_ui.now_playing.text = song.resource_path.get_file()
			m_player.stream = song
			m_player.play()
		else:
			print("MusicManager: Manual Fallback - No songs found!")

	var vol = music_volume_map.get(track, 1.0) * SettingsManager.settings["music_volume"]
	m_player.volume_db = linear_to_db(vol)
	print("MusicManager: Playing track ", track, " at volume linear: ", vol, " (db: ", m_player.volume_db, ")")


func play_custom_file(full_path: String):
	if not FileAccess.file_exists(full_path) and not ResourceLoader.exists(full_path):
		push_warning("MusicManager: Custom file not found: " + full_path)
		return

	# Stop standard shuffle
	current_track_type = -1
	
	var stream = load(full_path)
	if stream:
		var m_player = music_player
		if m_player:
			locking_custom_track = true
			if not _interactive_stream:
				_interactive_stream = m_player.stream
			print("MusicManager: Playing custom file: ", full_path, ". Locking interactive music.")
			m_player.stream = stream
			m_player.volume_db = linear_to_db(1.0) # Default volume for events
			m_player.play()


func resume_last_track():
	locking_custom_track = false # Ensure lock is released
	var m_player = music_player
	if _interactive_stream and m_player:
		m_player.stream = _interactive_stream
	if last_track_type != -1:
		play_music(last_track_type)
	else:
		play_music(MUSIC.MAIN_THEME)


func skip_track():
	if locking_custom_track:
		resume_last_track()
		return
	var m_player = music_player
	if m_player:
		m_player.stop()
		if current_track_type != -1:
			play_music(current_track_type)
		else:
			play_music(MUSIC.MAIN_THEME)


func _on_music_finished():
	if locking_custom_track:
		resume_last_track()
		return
		
	if not USE_INTERACTIVE:
		# In manual mode, we need to pick the next song
		print("MusicManager: Manual Fallback - Song finished, picking next...")
		if current_track_type != -1:
			play_music(current_track_type)
		else:
			play_music(MUSIC.MAIN_THEME)
	# In interactive mode, AudioStreamPlaylist handles it natively.


func play_sfx(sfx: int):
	if sfx not in sfx_map:
		return
	var players = sfx_players
	if players.is_empty():
		return
	var player = players.filter(func(p): return not p.playing).front()
	if not player:
		player = players[0]

	player.stream = sfx_map[sfx]
	player.volume_db = linear_to_db(1.0 * SettingsManager.settings["sfx_volume"])
	player.play()


func stop_all_sfx():
	for p in sfx_players:
		p.stop()


func set_music_volume(volume_linear: float):
	if music_player:
		music_player.volume_db = linear_to_db(music_volume_map.get(current_track_type, 0.5) * volume_linear)


func set_sfx_volume(_volume_linear: float):
	pass

		
func _toggle_pause() -> void:
	if music_player:
		music_player.playing = !music_player.playing
