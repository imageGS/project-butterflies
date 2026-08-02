class_name Item
extends RefCounted

enum Category { QUEST, CONSUMABLE, EQUIPMENT, JUNK }
enum EquipSlot { NONE = -1, HEAD, BODY, WEAPON }

var id: String
var name: String
var description: String
var examine_text: String
var heal_amount: int
var grid_size: Vector2i = Vector2i(1, 1)
var stack_max: int = 1
var stack_count: int = 1
var icon_color: Color = Color(1, 1, 1)
var texture_path: String = ""
var _texture_cache: Texture2D
var _rotated_cache: Texture2D
var category: Category = Category.JUNK
var texture_rotated: bool = false
var equip_slot: int = EquipSlot.NONE

func get_rotated_texture() -> Texture2D:
	if not _rotated_cache:
		var tex := get_texture()
		if tex:
			var img := tex.get_image()
			if img:
				img.rotate_90(CLOCKWISE)
				_rotated_cache = ImageTexture.create_from_image(img)
	return _rotated_cache

func _init(_name: String, _desc: String, _heal: int, _size: Vector2i = Vector2i(1,1), _stack: int = 1, _cat: Category = Category.JUNK, _slot: int = EquipSlot.NONE):
	name = _name
	description = _desc
	heal_amount = _heal
	grid_size = _size
	stack_max = max(_stack, 1)
	stack_count = 1
	category = _cat
	equip_slot = _slot

func get_texture() -> Texture2D:
	if not _texture_cache and not texture_path.is_empty():
		_texture_cache = load(texture_path) as Texture2D
	return _texture_cache
