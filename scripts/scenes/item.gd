class_name Item
extends RefCounted

var name: String
var description: String
var heal_amount: int
var grid_size: Vector2i = Vector2i(1, 1)
var stack_max: int = 1
var stack_count: int = 1
var icon_color: Color = Color(1, 1, 1)

func _init(_name: String, _desc: String, _heal: int, _size: Vector2i = Vector2i(1,1), _stack: int = 1):
	name = _name
	description = _desc
	heal_amount = _heal
	grid_size = _size
	stack_max = max(_stack, 1)
	stack_count = 1
