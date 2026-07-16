class_name ItemData
extends Resource

@export var item_name: String = ""
@export var description: String = ""
@export var heal_amount: int = 0
@export var grid_size: Vector2i = Vector2i(1, 1)
@export var stack_max: int = 1
@export var icon_color: Color = Color(0.5, 0.5, 0.5)

func to_item() -> Item:
	return Item.new(item_name, description, heal_amount, grid_size, stack_max)
