class_name LightComponent
extends Node2D

## Attach to the player. Stays at screen center to act as flashlight.

@export var radius: float = 140.0
@export var color: Color = Color(1.0, 0.95, 0.8)
@export var intensity: float = 1.4
@export_range(0.0, 1.0) var flicker: float = 0.03
@export var enabled: bool = true

func _enter_tree() -> void:
	add_to_group("tdl_light")

func _exit_tree() -> void:
	remove_from_group("tdl_light")
