extends Node
class_name AudioSystem

var footstep_sounds: Array = []
var footstep_player: AudioStreamPlayer
var flashlight_player: AudioStreamPlayer
var breath_player: AudioStreamPlayer
var flashlight_sfx: AudioStream
var breath_sfx: AudioStream


func setup(parent_node: Node):
	footstep_player = AudioStreamPlayer.new()
	parent_node.add_child(footstep_player)
	load_footstep_sounds()
	flashlight_player = AudioStreamPlayer.new()
	flashlight_player.volume_db = -6.0
	parent_node.add_child(flashlight_player)
	flashlight_sfx = load("res://audio/sfx/flashlight.mp3") as AudioStream
	breath_player = AudioStreamPlayer.new()
	breath_player.volume_db = -12.0
	parent_node.add_child(breath_player)
	breath_sfx = load("res://audio/sfx/breath/breath_01.ogg") as AudioStream


func load_footstep_sounds():
	for i in 5:
		var path: String = "res://audio/sfx/footsteps/Tile_Mono_0" + str(i + 1) + ".wav"
		var stream := load(path) as AudioStream
		if stream:
			footstep_sounds.append(stream)


func play_footstep():
	if footstep_sounds.is_empty(): return
	footstep_player.stream = footstep_sounds[randi() % footstep_sounds.size()]
	footstep_player.pitch_scale = 1.0
	footstep_player.play()


func play_bump():
	if footstep_sounds.is_empty(): return
	footstep_player.stream = footstep_sounds[randi() % footstep_sounds.size()]
	footstep_player.pitch_scale = 0.55
	footstep_player.play()


func play_flashlight_toggle(on: bool):
	if not flashlight_sfx: return
	flashlight_player.stream = flashlight_sfx
	flashlight_player.pitch_scale = 1.0 if on else 0.85
	flashlight_player.play()


func start_breathing():
	if breath_player.playing or not breath_sfx: return
	breath_player.stream = breath_sfx
	breath_player.play()


func stop_breathing():
	breath_player.stop()


func play_enemy_step(ent: Dictionary, player_x: float, player_y: float):
	if footstep_sounds.is_empty(): return
	var player: AudioStreamPlayer = ent.get("audio_player")
	if not player or player.playing: return
	var dx: float = float(ent.grid_x) - player_x
	var dy: float = float(ent.grid_y) - player_y
	var dist: float = sqrt(dx * dx + dy * dy)
	var hear_radius: float = 6.0
	if dist >= hear_radius: return
	var vol: float = linear_to_db(clamp(1.0 - dist / hear_radius, 0.0, 1.0))
	vol = max(vol, -30.0)
	player.volume_db = vol
	player.stream = footstep_sounds[randi() % footstep_sounds.size()]
	player.pitch_scale = 0.9 + randf() * 0.2
	player.play()
