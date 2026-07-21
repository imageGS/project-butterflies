class_name StationTileset
extends Resource

## Maps tile types to textures and sounds for a station/zone.

@export var wall_tex: Texture2D
@export var floor_tex: Texture2D
@export var rail_tex: Texture2D
@export var window_tex: Texture2D

@export var floor_sounds: Array[AudioStream] = []
@export var metal_sounds: Array[AudioStream] = []

func get_step_sound(tile_char: String) -> AudioStream:
	var arr: Array[AudioStream] = floor_sounds
	if tile_char in ["R", "S"]:
		arr = metal_sounds
	if arr.is_empty(): return null
	return arr[randi() % arr.size()]
