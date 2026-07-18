class_name StationData
extends Resource

@export var station_name: String = ""
@export var map_file: String = ""
@export var spawn: Vector2i = Vector2i(10, 3)
@export var spawn_dir: int = 2
@export var outer_ring: bool = true
@export var fog_distance: float = 7.0
@export var exits: Array[ExitData] = []

func get_exit_at(pos: Vector2i) -> ExitData:
	for e: ExitData in exits:
		if e.position == pos:
			return e
	return null
