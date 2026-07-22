class_name PlayerLight
extends Node2D

const LIGHT_GROUP := "tdl_light"

@export var radius: float = 300.0
@export var intensity: float = 1.2
@export var color: Color = Color(1.0, 0.95, 0.8)
@export_range(0.0, 1.0) var flicker: float = 0.03
@export var enabled: bool = true

func _enter_tree() -> void:
	add_to_group(LIGHT_GROUP)

func _exit_tree() -> void:
	remove_from_group(LIGHT_GROUP)

func _ready():
	radius = 300.0
	intensity = 1.2
	color = Color(1.0, 0.95, 0.8)

func _process(_delta):
	var vp := get_viewport()
	if vp:
		position = vp.get_visible_rect().size * 0.5
