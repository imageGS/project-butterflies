extends Node
class_name AudioSystem

var footstep_sounds: Array = []
var footstep_player: AudioStreamPlayer


func setup(parent_node: Node):
	footstep_player = AudioStreamPlayer.new()
	parent_node.add_child(footstep_player)
	load_footstep_sounds()


func load_footstep_sounds():
	for i in 5:
		var path: String = "res://audio/sfx/footsteps/Tile_Mono_0" + str(i + 1) + ".wav"
		var stream := load(path) as AudioStream
		if stream:
			footstep_sounds.append(stream)


func play_footstep():
	if footstep_sounds.is_empty(): return
	footstep_player.stream = footstep_sounds[randi() % footstep_sounds.size()]
	footstep_player.play()


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
