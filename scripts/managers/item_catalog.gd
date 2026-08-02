class_name ItemCatalog
extends RefCounted

const CAT_MAP: Dictionary = {
	"consumable": Item.Category.CONSUMABLE,
	"equipment": Item.Category.EQUIPMENT,
	"quest": Item.Category.QUEST,
	"junk": Item.Category.JUNK,
}

const SLOT_MAP: Dictionary = {
	"head": Item.EquipSlot.HEAD,
	"body": Item.EquipSlot.BODY,
	"weapon": Item.EquipSlot.WEAPON,
}

static var _data: Dictionary = {}
static var _loaded: bool = false

static func ensure_loaded():
	if _loaded: return
	_loaded = true
	var file := FileAccess.open("res://resources/items/items.json", FileAccess.READ)
	if not file:
		push_error("ItemCatalog: cannot open items.json")
		return
	var json: Variant = JSON.parse_string(file.get_as_text())
	if json is Dictionary:
		_data = json
	else:
		push_error("ItemCatalog: invalid JSON")

static func create_all() -> Array[Item]:
	ensure_loaded()
	var result: Array[Item] = []
	for id in _data:
		var item := create(id)
		if item:
			result.append(item)
	return result

static func create(id: String) -> Item:
	ensure_loaded()
	var entry: Dictionary = _data.get(id, {})
	if entry.is_empty():
		return null

	var cat: int = CAT_MAP.get(entry.get("category", "junk"), Item.Category.JUNK)
	var slot: int = SLOT_MAP.get(entry.get("equip_slot", ""), Item.EquipSlot.NONE)
	var sz: Array = entry.get("size", [1, 1])
	var size := Vector2i(sz[0], sz[1])

	var item := Item.new(
		entry.get("name", ""),
		entry.get("description", ""),
		entry.get("heal", 0),
		size,
		entry.get("stack", 1),
		cat,
		slot,
	)

	item.id = id
	item.texture_path = entry.get("texture", "")
	item.examine_text = entry.get("flavor", "")
	var col: Array = entry.get("color", [1, 1, 1])
	if col.size() >= 3:
		item.icon_color = Color(col[0], col[1], col[2])

	return item

static func get_description(id: String) -> String:
	ensure_loaded()
	var entry: Dictionary = _data.get(id, {})
	return entry.get("description", "")

static func get_item_ids() -> Array[String]:
	ensure_loaded()
	return _data.keys()
