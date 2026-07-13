class_name Interactable
extends Area2D

@export var interaction_label: String = "Interact"
@export var tooltip: String = ""

func _ready():
	collision_layer = 2
	_ensure_collision_shape()
	queue_redraw()

func _ensure_collision_shape():
	for child in get_children():
		if child is CollisionShape2D:
			return
	var shape := CollisionShape2D.new()
	shape.shape = RectangleShape2D.new()
	shape.shape.size = Vector2(48, 48)
	add_child(shape)

func _draw():
	var c := Color.GREEN if interaction_label == "Interact" else Color.CYAN
	draw_rect(Rect2(-24, -24, 48, 48), c)

func interact():
	print("[%s] Interacted with: %s" % [name, interaction_label])
