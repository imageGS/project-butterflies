class_name InventoryPanel
extends Control

const CELL_SIZE: int = 30
const GAP: int = 1

const DROP_COLOR := Color(0.3, 0.6, 0.3, 1)
const BG_COLOR := Color(0.18, 0.18, 0.2, 1)

var grid_w: int = 6
var grid_h: int = 5
var _cell_colors: Array[Color] = []
var _item_textures: Array[Dictionary] = []
var _highlight_data: Dictionary = {}
var _dragging: bool = false
var _drag_item: Item
var _drag_from: Vector2i
var _drag_follower: TextureRect
var _hovered_origin: Vector2i = Vector2i(-1, -1)
var _hovered_item: Item
var _tooltip: Control
var _popup: Control
var _ctx_items: Array[Dictionary] = []
var _ctx_menu_rect: Rect2
var _ctx_hover_idx: int = -1

signal examine_requested(item_name: String, description: String)
signal throw_requested(item: Item)

var equip_slots: EquipmentSlots
var use_item_callback: Callable
var inventory: InventoryGrid:
	set(value):
		if inventory:
			inventory.changed.disconnect(_rebuild)
		inventory = value
		if inventory:
			inventory.changed.connect(_rebuild)

func _ready():
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_grid()
	_setup_tooltip()
	if inventory:
		_rebuild_items()

func _setup_tooltip():
	_tooltip = Panel.new()
	_tooltip.name = "ItemTooltip"
	_tooltip.visible = false
	_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip.size = Vector2(120, 44)
	_tooltip.position = Vector2(-999, -999)
	add_child(_tooltip)

	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.1, 0.1, 0.12, 0.95)
	bg.border_width_left = 1
	bg.border_width_right = 1
	bg.border_width_top = 1
	bg.border_width_bottom = 1
	bg.border_color = Color(0.3, 0.3, 0.35, 1)
	bg.set_corner_radius_all(2)
	_tooltip.add_theme_stylebox_override("panel", bg)

	var vb := VBoxContainer.new()
	vb.name = "VBox"
	vb.position = Vector2(3, 2)
	vb.size = Vector2(114, 44)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_theme_constant_override("separation", 0)
	_tooltip.add_child(vb)

	var name_label := Label.new()
	name_label.name = "Name"
	name_label.size = Vector2(114, 14)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.add_theme_color_override("font_color", Color(1, 1, 1))
	name_label.add_theme_font_size_override("font_size", 9)
	vb.add_child(name_label)

	var desc_label := Label.new()
	desc_label.name = "Desc"
	desc_label.size = Vector2(114, 12)
	desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	desc_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	desc_label.add_theme_font_size_override("font_size", 7)
	vb.add_child(desc_label)

	var info_label := Label.new()
	info_label.name = "Info"
	info_label.size = Vector2(114, 12)
	info_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_label.add_theme_color_override("font_color", Color(0.5, 0.7, 0.5))
	info_label.add_theme_font_size_override("font_size", 7)
	vb.add_child(info_label)

	var cat_label := Label.new()
	cat_label.name = "Category"
	cat_label.size = Vector2(114, 11)
	cat_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cat_label.add_theme_font_size_override("font_size", 7)
	vb.add_child(cat_label)

func _build_grid():
	var total_w: int = grid_w * CELL_SIZE + (grid_w - 1) * GAP
	var total_h: int = grid_h * CELL_SIZE + (grid_h - 1) * GAP
	size = Vector2(total_w, total_h)
	_cell_colors.resize(grid_w * grid_h)
	_cell_colors.fill(BG_COLOR)
	for child in get_children():
		if child != _tooltip and child != _popup and child != _drag_follower:
			remove_child(child)
			child.free()

func _rebuild():
	_close_context_menu()
	_rebuild_items()

func _rebuild_items():
	_item_textures.clear()
	if _cell_colors.is_empty(): return
	_cell_colors.fill(BG_COLOR)
	_highlight_data = {}
	if inventory:
		var seen: Dictionary = {}
		for s in inventory.slots:
			var key: String = "%d_%d" % [s.x, s.y]
			if seen.has(key): continue
			seen[key] = true
			var it: Item = s.item
			if not it: continue
			var px: float = s.x * (CELL_SIZE + GAP)
			var py: float = s.y * (CELL_SIZE + GAP)
			var pw: float = it.grid_size.x * CELL_SIZE + (it.grid_size.x - 1) * GAP
			var ph: float = it.grid_size.y * CELL_SIZE + (it.grid_size.y - 1) * GAP
			_item_textures.append({
				"rect": Rect2(px, py, pw, ph),
				"texture": it.get_texture(),
				"color": it.icon_color,
				"rotated": it.texture_rotated,
			})
	_clear_hover()

func _get_cell_at_pos(pos: Vector2) -> Vector2i:
	var step := CELL_SIZE + GAP
	var gx := int(pos.x / step)
	var gy := int(pos.y / step)
	if gx >= 0 and gx < grid_w and gy >= 0 and gy < grid_h:
		return Vector2i(gx, gy)
	return Vector2i(-1, -1)

func _highlight_rect(coords: Vector2i, item: Item, color: Color):
	_highlight_data = {"coords": coords, "item": item, "color": color}
	queue_redraw()

func _find_item(coords: Vector2i) -> Dictionary:
	if not inventory or coords.x < 0: return {}
	return inventory.get_item_at(coords.x, coords.y)

func _hit_test(pos: Vector2) -> Dictionary:
	if pos.x < 0 or pos.y < 0 or pos.x > size.x or pos.y > size.y:
		return {}
	if not inventory: return {}
	for i in inventory.slots.size():
		var s: Dictionary = inventory.slots[i]
		var item: Item = s.item
		var ox: float = s.x * (CELL_SIZE + GAP)
		var oy: float = s.y * (CELL_SIZE + GAP)
		var ow: float = item.grid_size.x * CELL_SIZE + (item.grid_size.x - 1) * GAP
		var oh: float = item.grid_size.y * CELL_SIZE + (item.grid_size.y - 1) * GAP
		if Rect2(ox, oy, ow, oh).has_point(pos):
			return {"idx": i, "item": item, "origin": Vector2i(s.x, s.y)}
	return {}

func _clear_hover():
	_hovered_origin = Vector2i(-1, -1)
	_hovered_item = null
	_highlight_data = {}
	_hide_tooltip()
	queue_redraw()

func _show_tooltip(item: Item, local_pos: Vector2):
	var name_lbl: Label = _tooltip.get_node("VBox/Name")
	var desc_lbl: Label = _tooltip.get_node("VBox/Desc")
	var info_lbl: Label = _tooltip.get_node("VBox/Info")
	var cat_lbl: Label = _tooltip.get_node("VBox/Category")

	name_lbl.text = item.name
	desc_lbl.text = item.description

	var info := ""
	if item.heal_amount > 0:
		info += "+%d HP" % item.heal_amount
	info += "  [%d×%d]" % [item.grid_size.x, item.grid_size.y]
	if item.stack_max > 1:
		info += "  x%d" % item.stack_count
	info_lbl.text = info

	match item.category:
		Item.Category.CONSUMABLE:
			cat_lbl.text = "РАСХОДНИК"
			cat_lbl.add_theme_color_override("font_color", Color(0.3, 0.9, 0.3))
		Item.Category.EQUIPMENT:
			cat_lbl.text = "СНАРЯЖЕНИЕ"
			cat_lbl.add_theme_color_override("font_color", Color(0.3, 0.6, 0.9))
		Item.Category.QUEST:
			cat_lbl.text = "КВЕСТОВЫЙ"
			cat_lbl.add_theme_color_override("font_color", Color(0.9, 0.7, 0.2))
		Item.Category.JUNK:
			cat_lbl.text = "ХЛАМ"
			cat_lbl.add_theme_color_override("font_color", Color(0.6, 0.5, 0.4))

	var labels: Array[Label] = [name_lbl, desc_lbl, info_lbl, cat_lbl]
	var max_w := 0
	var total_h := 0
	for l in labels:
		var ms: Vector2 = l.get_minimum_size()
		if ms.x > max_w:
			max_w = ms.x
		total_h += ms.y
	max_w = maxi(max_w, 114)
	total_h = maxi(total_h, 44)
	_tooltip.size = Vector2(max_w + 6, total_h + 4)
	var vb: VBoxContainer = _tooltip.get_node("VBox")
	vb.size = Vector2(max_w, total_h)

	_update_tooltip_position(local_pos)
	_tooltip.visible = true

func _update_tooltip_position(local_pos: Vector2):
	_tooltip.position = local_pos + Vector2(12, 0)
	if _tooltip.position.x + _tooltip.size.x > size.x:
		_tooltip.position.x = local_pos.x - _tooltip.size.x - 12
	if _tooltip.position.y + _tooltip.size.y > size.y:
		_tooltip.position.y = size.y - _tooltip.size.y - 4
	if _tooltip.position.y < 0:
		_tooltip.position.y = 4

func _hide_tooltip():
	if _tooltip:
		_tooltip.visible = false

func _draw():
	for ci in _cell_colors.size():
		var gx: int = ci % grid_w
		var gy: int = ci / grid_w
		var px: float = gx * (CELL_SIZE + GAP)
		var py: float = gy * (CELL_SIZE + GAP)
		draw_rect(Rect2(px, py, CELL_SIZE, CELL_SIZE), _cell_colors[ci])

	for t in _item_textures:
		draw_rect(t.rect, BG_COLOR)
		var tex: Texture2D = t.texture
		if not tex: continue
		var r: Rect2 = t.rect
		var ts: Vector2 = tex.get_size()
		if ts.x > 0 and ts.y > 0:
			var use_ts: Vector2 = Vector2(ts.y, ts.x) if t.rotated else ts
			var scale: float = min(r.size.x / use_ts.x, r.size.y / use_ts.y)
			var dw: float = use_ts.x * scale
			var dh: float = use_ts.y * scale
			var dx: float = r.position.x + (r.size.x - dw) / 2
			var dy: float = r.position.y + (r.size.y - dh) / 2
			var rot: float = PI / 2 if t.rotated else 0
			var cx: float = dx + dw / 2
			var cy: float = dy + dh / 2
			draw_set_transform(Vector2(cx, cy), rot, Vector2(scale, scale))
			draw_texture(tex, -ts / 2)
			draw_set_transform(Vector2(), 0, Vector2(1, 1))

	if not _highlight_data.is_empty():
		var hd: Dictionary = _highlight_data
		var h_coords: Vector2i = hd.coords
		var h_item: Item = hd.item
		var h_col: Color = hd.color
		for dx in h_item.grid_size.x:
			for dy in h_item.grid_size.y:
				var cx: int = h_coords.x + dx
				var cy: int = h_coords.y + dy
				if cx < 0 or cx >= grid_w or cy < 0 or cy >= grid_h: continue
				var x: float = cx * (CELL_SIZE + GAP)
				var y: float = cy * (CELL_SIZE + GAP)
				draw_rect(Rect2(x, y, CELL_SIZE, CELL_SIZE), h_col)

	if _hovered_item and _hovered_origin.x >= 0:
		var ox: int = _hovered_origin.x
		var oy: int = _hovered_origin.y
		var gw: int = _hovered_item.grid_size.x
		var gh: int = _hovered_item.grid_size.y
		var px: float = ox * (CELL_SIZE + GAP)
		var py: float = oy * (CELL_SIZE + GAP)
		var pw: float = gw * CELL_SIZE + (gw - 1) * GAP
		var ph: float = gh * CELL_SIZE + (gh - 1) * GAP
		var c := Color(1, 1, 1, 0.7)
		draw_line(Vector2(px, py), Vector2(px + pw, py), c, 1.0)
		draw_line(Vector2(px + pw, py), Vector2(px + pw, py + ph), c, 1.0)
		draw_line(Vector2(px + pw, py + ph), Vector2(px, py + ph), c, 1.0)
		draw_line(Vector2(px, py + ph), Vector2(px, py), c, 1.0)

	if not _ctx_items.is_empty():
		var mr: Rect2 = _ctx_menu_rect
		draw_rect(mr, Color(0.12, 0.12, 0.14, 1))
		draw_rect(mr, Color(0.3, 0.3, 0.35), false, 1.0)
		for i in _ctx_items.size():
			var it: Dictionary = _ctx_items[i]
			var ir: Rect2 = it.rect
			ir.position = mr.position + ir.position
			if i == _ctx_hover_idx:
				draw_rect(ir, Color(0.2, 0.2, 0.25, 0.8))
			draw_string(
				ThemeDB.fallback_font,
				Vector2(ir.position.x + 3, ir.position.y + 12),
				it.text,
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				8,
				Color(1, 1, 1) if i != _ctx_hover_idx else Color(1, 1, 0.6)
			)

func _update_hover(local_pos: Vector2):
	var hit := _hit_test(local_pos)
	if hit.is_empty():
		_clear_hover()
		CursorManager.set_cursor("pointer")
		return
	if hit.origin != _hovered_origin:
		_clear_hover()
		_hovered_origin = hit.origin
		_hovered_item = hit.item
		queue_redraw()
		_show_tooltip(hit.item, local_pos)
		CursorManager.set_cursor("hand")
	else:
		_update_tooltip_position(local_pos)

func is_dragging() -> bool:
	return _dragging

func _over_equipment(mp: Vector2) -> bool:
	if not equip_slots or not equip_slots.is_visible_in_tree(): return false
	var p := equip_slots.get_global_transform().affine_inverse() * mp
	return Rect2(Vector2(), equip_slots.size).has_point(p)

func _input(event: InputEvent):
	if not inventory or not is_visible_in_tree(): return

	if event is InputEventKey:
		return

	if not (event is InputEventMouseButton or event is InputEventMouseMotion): return

	if equip_slots and equip_slots.is_dragging():
		return

	var local_event := make_input_local(event)
	var local_pos: Vector2 = Vector2(0, 0)
	if event is InputEventMouse:
		local_pos = (local_event as InputEventMouse).position

	if event is InputEventMouseMotion and not _dragging:
		if local_pos.x < 0 or local_pos.y < 0 or local_pos.x > size.x or local_pos.y > size.y:
			_clear_hover()
			if not _over_equipment((event as InputEventMouse).position):
				CursorManager.set_cursor("pointer")
			return
		if _ctx_items.is_empty():
			_update_hover(local_pos)
			return
		var new_hover: int = -1
		if _ctx_menu_rect.has_point(local_pos):
			for i in _ctx_items.size():
				var ir: Rect2 = _ctx_items[i].rect
				ir.position += _ctx_menu_rect.position
				if ir.has_point(local_pos):
					new_hover = i
					break
		if new_hover != _ctx_hover_idx:
			_ctx_hover_idx = new_hover
			queue_redraw()
		return

	if event is InputEventMouseMotion and _dragging and _drag_follower:
		_hide_tooltip()
		var mm := event as InputEventMouseMotion
		var local_mm := make_input_local(mm)
		var mm_pos := (local_mm as InputEventMouseMotion).position
		_drag_follower.position = mm_pos - _drag_follower.size / 2
		var coords := _get_cell_at_pos(mm_pos)
		_rebuild_items()
		if coords.x >= 0 and inventory.can_place(_drag_item, coords.x, coords.y):
			_highlight_rect(coords, _drag_item, DROP_COLOR)
		return

	if local_pos.x < 0 or local_pos.y < 0 or local_pos.x > size.x or local_pos.y > size.y:
		if not _dragging:
			_clear_hover()
			return

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and not _ctx_items.is_empty():
			if _ctx_menu_rect.has_point(local_pos):
				if mb.button_index == MOUSE_BUTTON_LEFT:
					for i in _ctx_items.size():
						var ir: Rect2 = _ctx_items[i].rect
						ir.position += _ctx_menu_rect.position
						if ir.has_point(local_pos):
							_ctx_items[i].cb.call()
							break
				_close_context_menu()
				return
			else:
				_close_context_menu()
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed and not _dragging:
				_hide_tooltip()
				var hit := _hit_test(local_pos)
				if hit.is_empty(): return
				_dragging = true
				_drag_item = hit.item
				_drag_from = hit.origin
				CursorManager.set_cursor("pinch")
				inventory.remove(hit.idx)
				_drag_follower = TextureRect.new()
				var fw: int = CELL_SIZE * _drag_item.grid_size.x + GAP * (_drag_item.grid_size.x - 1)
				var fh: int = CELL_SIZE * _drag_item.grid_size.y + GAP * (_drag_item.grid_size.y - 1)
				_drag_follower.size = Vector2(fw, fh)
				_drag_follower.texture = _drag_item.get_rotated_texture() if _drag_item.texture_rotated else _drag_item.get_texture()
				_drag_follower.modulate = _drag_item.icon_color
				_drag_follower.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				_drag_follower.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				_drag_follower.z_index = 100
				_drag_follower.mouse_filter = Control.MOUSE_FILTER_IGNORE
				add_child(_drag_follower)
				_drag_follower.position = local_pos - _drag_follower.size / 2
			elif not mb.pressed and _dragging:
				_hide_tooltip()
				_drop_item(local_pos)
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed and not _dragging:
			_show_context_menu(local_pos)
			_clear_hover()

func _show_context_menu(local_pos: Vector2):
	var hit := _hit_test(local_pos)
	if hit.is_empty(): return
	_close_context_menu()

	var item: Item = hit.item
	var can_use: bool = item.category == Item.Category.CONSUMABLE or item.heal_amount > 0

	_ctx_hover_idx = -1
	_ctx_items.clear()
	var mw: int = 80
	var yc: float = 2

	var items_list: Array[Dictionary] = []
	if can_use:
		items_list.append({"text": "Использовать", "cb": func(): _use_item(item, hit.idx)})
	items_list.append({"text": "Бросить", "cb": func():
		throw_requested.emit(item)
		_close_context_menu()
	})
	items_list.append({"text": "Осмотреть", "cb": func(): _examine_item(item)})

	for it in items_list:
		_ctx_items.append({"text": it.text, "rect": Rect2(2, yc, mw - 4, 16), "cb": it.cb})
		yc += 16

	_ctx_menu_rect = Rect2(
		clamp(local_pos.x, 0, size.x - mw),
		clamp(local_pos.y, 0, size.y - yc),
		mw, yc
	)

	queue_redraw()

func _close_context_menu():
	if _ctx_items.is_empty(): return
	_ctx_items.clear()
	_ctx_hover_idx = -1
	queue_redraw()

func _use_item(item: Item, idx: int):
	var apply_effect: Callable = func():
		if item.heal_amount > 0:
			PlayerStats.heal(item.heal_amount)
		elif item.id == "battery":
			PlayerStats.change_flashlight_energy(25.0)
		var s: Dictionary = inventory.slots[idx]
		s.item.stack_count -= 1
		if s.item.stack_count <= 0:
			inventory.slots.remove_at(idx)
		inventory.changed.emit()
	if use_item_callback.is_valid():
		var anim_name: String = "heal" if item.heal_amount > 0 else "use"
		use_item_callback.call(anim_name, apply_effect)
	else:
		apply_effect.call()

func _drop_from_grid(item: Item, idx: int):
	inventory.remove(idx)
	inventory.changed.emit()
	_rebuild_items()
	_close_context_menu()

func _examine_item(item: Item):
	examine_requested.emit(item.name, item.examine_text if not item.examine_text.is_empty() else item.description)

func _drop_item(local_pos: Vector2):
	if equip_slots and _drag_item.category == Item.Category.EQUIPMENT:
		var global_mouse := get_global_mouse_position()
		var equip_local := equip_slots.get_global_transform().affine_inverse() * global_mouse
		var slot_type := equip_slots.hit_test(equip_local)
		if slot_type >= 0 and equip_slots.try_equip(_drag_item, slot_type):
			_cleanup_drag()
			return
	var coords := _get_cell_at_pos(local_pos)
	if coords.x >= 0 and inventory.can_place(_drag_item, coords.x, coords.y):
		inventory.slots.append({"item": _drag_item, "x": coords.x, "y": coords.y})
		inventory.changed.emit()
	elif inventory.can_place(_drag_item, _drag_from.x, _drag_from.y):
		inventory.slots.append({"item": _drag_item, "x": _drag_from.x, "y": _drag_from.y})
		inventory.changed.emit()
	else:
		inventory.try_add(_drag_item)
	_cleanup_drag()

func _cleanup_drag():
	if _drag_follower:
		remove_child(_drag_follower)
		_drag_follower.free()
		_drag_follower = null
	_dragging = false
	_drag_item = null
	_rebuild_items()
	CursorManager.set_cursor("pointer")

func rotate_focused_item() -> void:
	if not inventory or not is_visible_in_tree():
		return
	if _dragging:
		_drag_item.texture_rotated = not _drag_item.texture_rotated
		var tmp := _drag_item.grid_size.x
		_drag_item.grid_size.x = _drag_item.grid_size.y
		_drag_item.grid_size.y = tmp
		var fw: int = CELL_SIZE * _drag_item.grid_size.x + GAP * (_drag_item.grid_size.x - 1)
		var fh: int = CELL_SIZE * _drag_item.grid_size.y + GAP * (_drag_item.grid_size.y - 1)
		_drag_follower.size = Vector2(fw, fh)
		_drag_follower.texture = _drag_item.get_rotated_texture() if _drag_item.texture_rotated else _drag_item.get_texture()
		_rebuild_items()
		return
	if not _hovered_item or _hovered_origin.x < 0:
		return
	var it: Item = _hovered_item
	var old_x := it.grid_size.x
	var old_y := it.grid_size.y
	it.texture_rotated = not it.texture_rotated
	it.grid_size.x = old_y
	it.grid_size.y = old_x
	var found := inventory.get_item_at(_hovered_origin.x, _hovered_origin.y)
	var idx: int = found.get("idx", -1)
	if inventory.can_place(it, _hovered_origin.x, _hovered_origin.y, idx):
		_rebuild_items()
	else:
		it.grid_size.x = old_x
		it.grid_size.y = old_y
		it.texture_rotated = not it.texture_rotated
