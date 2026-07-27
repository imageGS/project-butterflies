extends Node

signal dialogue_started(npc_name: String)
signal dialogue_ended
signal player_moved(from_x: float, from_y: float, to_x: float, to_y: float)
signal player_turned(from_dir: int, to_dir: int)
signal flashlight_toggled(on: bool)
signal inventory_toggled(open: bool)
