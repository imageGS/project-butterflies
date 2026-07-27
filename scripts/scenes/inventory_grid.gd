class_name InventoryGrid
extends RefCounted

signal changed

var grid_w: int = 6
var grid_h: int = 5
var slots: Array[Dictionary] = []

func can_place(item: Item, x: int, y: int, exclude_idx: int = -1) -> bool:
	for dx in item.grid_size.x:
		for dy in item.grid_size.y:
			var cx: int = x + dx
			var cy: int = y + dy
			if cx < 0 or cx >= grid_w or cy < 0 or cy >= grid_h:
				return false
			for i in slots.size():
				if i == exclude_idx: continue
				var s: Dictionary = slots[i]
				var sx: int = s.get("x", 0)
				var sy: int = s.get("y", 0)
				var si: Item = s.get("item")
				if not si: continue
				for sdx in si.grid_size.x:
					for sdy in si.grid_size.y:
						if sx + sdx == cx and sy + sdy == cy:
							return false
	return true

func try_add(item: Item, x: int = -1, y: int = -1) -> bool:
	# Try to stack first
	for i in slots.size():
		var s: Dictionary = slots[i]
		var si: Item = s.get("item")
		if si and si.name == item.name and si.stack_count < si.stack_max:
			var space: int = si.stack_max - si.stack_count
			var add: int = min(space, item.stack_count)
			si.stack_count += add
			item.stack_count -= add
			changed.emit()
			if item.stack_count <= 0:
				return true

	if item.stack_count <= 0:
		return true

	if x < 0 or y < 0:
		for cy in range(grid_h):
			for cx in range(grid_w):
				if can_place(item, cx, cy):
					slots.append({"item": item, "x": cx, "y": cy})
					changed.emit()
					return true
		return false

	if can_place(item, x, y):
		slots.append({"item": item, "x": x, "y": y})
		changed.emit()
		return true
	return false

func remove(idx: int) -> Item:
	if idx < 0 or idx >= slots.size(): return null
	var s: Dictionary = slots.pop_at(idx)
	changed.emit()
	return s.get("item")

func get_item(idx: int) -> Item:
	if idx < 0 or idx >= slots.size(): return null
	return slots[idx].get("item")

func has_item(name: String) -> bool:
	for s in slots:
		if s.item.name == name: return true
	return false

func get_item_at(x: int, y: int) -> Dictionary:
	for i in slots.size():
		var s: Dictionary = slots[i]
		var si: Item = s.get("item")
		if not si: continue
		for dx in si.grid_size.x:
			for dy in si.grid_size.y:
				if s.x + dx == x and s.y + dy == y:
					return {"idx": i, "item": si}
	return {}

func remove_at(x: int, y: int) -> Item:
	var found := get_item_at(x, y)
	if found.is_empty(): return null
	var idx: int = found.idx
	return remove(idx)

func move_item(from_x: int, from_y: int, to_x: int, to_y: int) -> bool:
	var found := get_item_at(from_x, from_y)
	if found.is_empty(): return false
	var item: Item = found.item
	var old_idx: int = found.idx
	if can_place(item, to_x, to_y, old_idx):
		slots[old_idx].x = to_x
		slots[old_idx].y = to_y
		changed.emit()
		return true
	return false

func find_slot(item: Item) -> Vector2i:
	for cy in range(grid_h):
		for cx in range(grid_w):
			if can_place(item, cx, cy):
				return Vector2i(cx, cy)
	return Vector2i(-1, -1)

func size() -> int:
	return slots.size()
