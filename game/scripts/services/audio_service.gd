class_name NetboundAudioService
extends Node

const BUS_MUSIC := "Music"
const BUS_SFX := "SFX"
const BUS_UI := "UI"

const MAX_SFX_PLAYERS := 10
const MAX_UI_PLAYERS := 4
const DEFAULT_COOLDOWN := 0.035

const MUSIC_MENU := "music_menu_loop"
const MUSIC_GAMEPLAY := "music_gameplay_loop"
const MUSIC_FINAL := "music_final_loop"

const AUDIO_PATHS := {
	"ui_tap": "res://audio/generated/ui_tap.wav",
	"ui_confirm": "res://audio/generated/ui_confirm.wav",
	"ui_back": "res://audio/generated/ui_back.wav",
	"ui_locked": "res://audio/generated/ui_locked.wav",
	"ui_tab": "res://audio/generated/ui_tab.wav",
	"aim_start": "res://audio/generated/aim_start.wav",
	"shot_weak": "res://audio/generated/shot_weak.wav",
	"shot_release": "res://audio/generated/shot_release.wav",
	"shot_strong": "res://audio/generated/shot_strong.wav",
	"impact_ground": "res://audio/generated/impact_ground.wav",
	"impact_obstacle": "res://audio/generated/impact_obstacle.wav",
	"impact_bounce": "res://audio/generated/impact_bounce.wav",
	"impact_post": "res://audio/generated/impact_post.wav",
	"hazard_cue": "res://audio/generated/hazard_cue.wav",
	"near_miss": "res://audio/generated/near_miss.wav",
	"goal_scored": "res://audio/generated/goal_scored.wav",
	"result_success": "res://audio/generated/result_success.wav",
	"result_star": "res://audio/generated/result_star.wav",
	"result_failure": "res://audio/generated/result_failure.wav",
	"cosmetic_unlock": "res://audio/generated/cosmetic_unlock.wav",
	"music_menu_loop": "res://audio/generated/music_menu_loop.wav",
	"music_gameplay_loop": "res://audio/generated/music_gameplay_loop.wav",
	"music_final_loop": "res://audio/generated/music_final_loop.wav",
}

const COOLDOWNS := {
	"impact_ground": 0.09,
	"impact_obstacle": 0.08,
	"impact_bounce": 0.08,
	"impact_post": 0.14,
	"near_miss": 0.35,
	"goal_scored": 0.45,
	"aim_start": 0.3,
}

var _streams: Dictionary = {}
var _sfx_players: Array[AudioStreamPlayer] = []
var _ui_players: Array[AudioStreamPlayer] = []
var _music_player: AudioStreamPlayer
var _current_music_id: String = ""
var _last_play_time: Dictionary = {}
var _master_volume: float = 1.0
var _music_volume: float = 1.0
var _sfx_volume: float = 1.0
var _music_paused_for_lifecycle: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_audio_buses()
	_load_streams()
	_build_players()
	var service := get_node_or_null("/root/SaveService")
	if service:
		apply_settings_from_save(service)


func apply_settings_from_save(save_service: Node) -> void:
	if not save_service:
		return
	_master_volume = clampf(float(save_service.get_setting_value("master_volume", 1.0)), 0.0, 1.0)
	_music_volume = clampf(float(save_service.get_setting_value("music_volume", 1.0)), 0.0, 1.0)
	_sfx_volume = clampf(float(save_service.get_setting_value("sfx_volume", 1.0)), 0.0, 1.0)
	_apply_bus_volume("Master", _master_volume)
	_apply_bus_volume(BUS_MUSIC, _music_volume)
	_apply_bus_volume(BUS_SFX, _sfx_volume)
	_apply_bus_volume(BUS_UI, _sfx_volume)


func play_music(music_id: String) -> bool:
	if music_id == _current_music_id and _music_player and _music_player.playing:
		_music_player.stream_paused = false
		_music_paused_for_lifecycle = false
		return true
	var stream := _streams.get(music_id) as AudioStream
	if not stream or not _music_player:
		return false
	_prepare_loop(stream)
	_music_player.stop()
	_music_player.stream = stream
	_music_player.volume_db = -8.0
	_music_player.stream_paused = false
	_music_player.play()
	_music_paused_for_lifecycle = false
	_current_music_id = music_id
	return true


func stop_music() -> void:
	if _music_player:
		_music_player.stop()
	_current_music_id = ""


func play_ui(sound_id: String = "ui_tap", volume_scale: float = 1.0) -> bool:
	return _play_from_pool(_ui_players, sound_id, BUS_UI, volume_scale, 1.0)


func play_sfx(sound_id: String, volume_scale: float = 1.0, pitch_scale: float = 1.0) -> bool:
	return _play_from_pool(_sfx_players, sound_id, BUS_SFX, volume_scale, pitch_scale)


func play_shot(power_ratio: float) -> bool:
	if power_ratio < 0.34:
		return play_sfx("shot_weak", 0.75, 0.96)
	if power_ratio > 0.76:
		return play_sfx("shot_strong", 1.0, 1.0)
	return play_sfx("shot_release", 0.9, 1.0)


func play_impact(kind: String, strength: float = 1.0) -> bool:
	var sound_id := "impact_obstacle"
	match kind:
		"ground":
			sound_id = "impact_ground"
		"bounce":
			sound_id = "impact_bounce"
		"post":
			sound_id = "impact_post"
		_:
			sound_id = "impact_obstacle"
	return play_sfx(sound_id, clampf(strength, 0.35, 1.0), lerpf(0.92, 1.08, clampf(strength, 0.0, 1.0)))


func cleanup_scene_audio() -> void:
	for player in _sfx_players:
		player.stop()
	for player in _ui_players:
		player.stop()
	_last_play_time.clear()


func handle_app_backgrounded() -> void:
	cleanup_scene_audio()
	if _music_player and _music_player.playing and not _music_player.stream_paused:
		_music_player.stream_paused = true
		_music_paused_for_lifecycle = true


func handle_app_foregrounded() -> void:
	if _music_player and _music_paused_for_lifecycle:
		_music_player.stream_paused = false
		_music_paused_for_lifecycle = false


func validate_assets() -> Dictionary:
	var missing: Array[String] = []
	for sound_id in AUDIO_PATHS.keys():
		if not ResourceLoader.exists(String(AUDIO_PATHS[sound_id])):
			missing.append(String(sound_id))
	return {"ok": missing.is_empty(), "missing": missing}


func get_registered_sound_ids() -> Array[String]:
	var ids: Array[String] = []
	for key in AUDIO_PATHS.keys():
		ids.append(String(key))
	ids.sort()
	return ids


func get_sfx_player_count() -> int:
	return _sfx_players.size()


func get_ui_player_count() -> int:
	return _ui_players.size()


func get_current_music_id() -> String:
	return _current_music_id


func is_music_paused_for_lifecycle() -> bool:
	return _music_paused_for_lifecycle


func get_active_sfx_count() -> int:
	var count := 0
	for player in _sfx_players:
		if player.playing:
			count += 1
	return count


func get_active_ui_count() -> int:
	var count := 0
	for player in _ui_players:
		if player.playing:
			count += 1
	return count


func _ensure_audio_buses() -> void:
	_ensure_bus(BUS_MUSIC, "Master")
	_ensure_bus(BUS_SFX, "Master")
	_ensure_bus(BUS_UI, BUS_SFX)


func _ensure_bus(bus_name: String, send_to: String) -> void:
	if AudioServer.get_bus_index(bus_name) >= 0:
		var existing := AudioServer.get_bus_index(bus_name)
		AudioServer.set_bus_send(existing, send_to)
		return
	AudioServer.add_bus()
	var index := AudioServer.get_bus_count() - 1
	AudioServer.set_bus_name(index, bus_name)
	AudioServer.set_bus_send(index, send_to)


func _load_streams() -> void:
	_streams.clear()
	for sound_id in AUDIO_PATHS.keys():
		var path := String(AUDIO_PATHS[sound_id])
		var stream := load(path) as AudioStream
		if stream:
			_streams[String(sound_id)] = stream


func _build_players() -> void:
	if _music_player:
		return
	_music_player = AudioStreamPlayer.new()
	_music_player.name = "MusicPlayer"
	_music_player.bus = BUS_MUSIC
	add_child(_music_player)

	for i in MAX_SFX_PLAYERS:
		var player := AudioStreamPlayer.new()
		player.name = "SFXPlayer%02d" % i
		player.bus = BUS_SFX
		add_child(player)
		_sfx_players.append(player)

	for i in MAX_UI_PLAYERS:
		var player := AudioStreamPlayer.new()
		player.name = "UIPlayer%02d" % i
		player.bus = BUS_UI
		add_child(player)
		_ui_players.append(player)


func _play_from_pool(
	pool: Array[AudioStreamPlayer],
	sound_id: String,
	bus_name: String,
	volume_scale: float,
	pitch_scale: float
) -> bool:
	var stream := _streams.get(sound_id) as AudioStream
	if not stream:
		return false
	if not _cooldown_ready(sound_id):
		return false
	var player := _first_available_player(pool)
	if not player:
		return false
	player.stop()
	player.stream = stream
	player.bus = bus_name
	player.volume_db = linear_to_db(clampf(volume_scale, 0.0, 1.0))
	player.pitch_scale = clampf(pitch_scale, 0.55, 1.65)
	player.play()
	_last_play_time[sound_id] = Time.get_ticks_msec()
	return true


func _first_available_player(pool: Array[AudioStreamPlayer]) -> AudioStreamPlayer:
	for player in pool:
		if not player.playing:
			return player
	return null


func _cooldown_ready(sound_id: String) -> bool:
	var cooldown := float(COOLDOWNS.get(sound_id, DEFAULT_COOLDOWN))
	var now := Time.get_ticks_msec()
	var last := int(_last_play_time.get(sound_id, -1000000))
	return float(now - last) / 1000.0 >= cooldown


func _apply_bus_volume(bus_name: String, linear: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index < 0:
		return
	AudioServer.set_bus_volume_db(index, -80.0 if linear <= 0.001 else linear_to_db(linear))


func _prepare_loop(stream: AudioStream) -> void:
	if stream is AudioStreamWAV:
		var wav := stream as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
