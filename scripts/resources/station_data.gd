class_name StationData
extends Resource

@export var station_name: String = ""
@export var spawn: Vector2i = Vector2i(10, 3)
@export var spawn_dir: int = 2
@export var ascii_rows: Array[String] = []
@export var outer_ring: bool = true
@export var fog_distance: float = 7.0
@export var shelter_mode: bool = false
