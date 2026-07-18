class_name ExitData
extends Resource

@export var position: Vector2i = Vector2i(-1, -1)
@export var target_station: StationData
@export var target_spawn: Vector2i = Vector2i(-1, -1)
@export var target_dir: int = -1

func resolve_target_station() -> StationData:
	return target_station

func resolve_spawn(default_spawn: Vector2i) -> Vector2i:
	if target_spawn.x < 0 or target_spawn.y < 0:
		return default_spawn
	return target_spawn

func resolve_dir(default_dir: int) -> int:
	if target_dir < 0 or target_dir > 3:
		return default_dir
	return target_dir
