class_name EquipmentSlots
extends Control

const MARGIN: int = 0
const GAP: int = 2
const LABEL_H: int = 10

enum SlotType { HEAD, BODY, WEAPON }

var slots: Dictionary = {}
var _slot_rects: Dictionary = {}
var _container_rects: Dictionary = {}

var inventory_panel: Control

var _dragging: bool = false
var _drag_item: Item
var _drag_slot: int = -1
var _drag_follower: ColorRect

signal equipped(slot_type: int, item: Item)
signal unequipped(slot_type: int, item: Item)

func _ready():
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_slots()

func _build_slots():
	var p := get_parent()
	var aw: float = (p.size.x if p and p.size.x > 0 else 64) - MARGIN * 2
	var slot_w: float = min(aw, 55)
	var slot_h: float = 14
	var container_h: float = slot_h + 4 + LABEL_H
	var names := ["Голова", "Тело", "Оружие"]
	var types := [SlotType.HEAD, SlotType.BODY, SlotType.WEAPON]
	var total_h: float = MARGIN * 2 + container_h * 3 + GAP * 2
	size = Vector2(aw + MARGIN * 2, total_h)
	for i in types.size():
		var t: int = types[i]
		var container := ColorRect.new()
		container.name = "Slot_%s" % names[i]
		container.size = Vector2(slot_w, container_h)
		container.position = Vector2(MARGIN, MARGIN + i * (container_h + GAP))
		container.color = Color(0.1, 0.1, 0.12, 1)
		container.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(container)
		var inner := ColorRect.new()
		inner.name = "Inner"
		inner.size = Vector2(slot_h, slot_h)
		inner.position = Vector2(2, 2)
		inner.color = Color(0.2, 0.2, 0.22, 1)
		inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		container.add_child(inner)
		var label := Label.new()
		label.text = names[i]
		label.position = Vector2(slot_h + 6, 2)
		label.size = Vector2(slot_w - slot_h - 8, LABEL_H)
		label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.6, 1))
		label.add_theme_font_size_override("font_size", 8)
		container.add_child(label)
		_slot_rects[t] = inner
		_container_rects[t] = container
		slots[t] = null

func get_equipped(slot_type: int) -> Item:
	return slots.get(slot_type)

func hit_test(pos: Vector2) -> int:
	for t in _container_rects:
		var rect: ColorRect = _container_rects[t]
		if rect.get_rect().has_point(pos):
			return t
	return -1

func try_equip(item: Item, slot_type: int) -> bool:
	if slot_type < 0 or slot_type >= SlotType.size(): return false
	if item.category != Item.Category.EQUIPMENT: return false
	if item.equip_slot != slot_type: return false
	var old: Item = slots.get(slot_type)
	slots[slot_type] = item
	_update_slot_visual(slot_type)
	if old:
		unequipped.emit(slot_type, old)
	equipped.emit(slot_type, item)
	return true

func try_unequip(slot_type: int) -> Item:
	if slot_type < 0: return null
	var item: Item = slots.get(slot_type)
	if not item: return null
	slots[slot_type] = null
	_update_slot_visual(slot_type)
	unequipped.emit(slot_type, item)
	return item

func _input(event: InputEvent):
	if not (event is InputEventMouseButton or event is InputEventMouseMotion): return
	var local_event := make_input_local(event)
	var local_pos: Vector2 = (local_event as InputEventMouse).position

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed and not _dragging:
			var t := hit_test(local_pos)
			if t >= 0 and slots.get(t):
				try_unequip(t)
				get_viewport().set_input_as_handled()
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed and not _dragging:
				var t := hit_test(local_pos)
				if t >= 0 and slots.get(t):
					_start_drag(t)
					get_viewport().set_input_as_handled()
			elif not mb.pressed and _dragging:
				_end_drag()
				get_viewport().set_input_as_handled()

	if event is InputEventMouseMotion and _dragging:
		_drag_follower.position = local_pos - _drag_follower.size / 2

func _start_drag(slot_type: int):
	_drag_slot = slot_type
	_drag_item = slots.get(slot_type)
	if not _drag_item: return
	var old_follower := _drag_follower
	if old_follower:
		remove_child(old_follower)
		old_follower.free()
	slots[slot_type] = null
	_update_slot_visual(slot_type)
	_dragging = true
	_drag_follower = ColorRect.new()
	_drag_follower.size = Vector2(_drag_item.grid_size.x * 14, _drag_item.grid_size.y * 14)
	_drag_follower.color = _drag_item.icon_color
	_drag_follower.z_index = 100
	_drag_follower.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_drag_follower)

func _end_drag():
	if not _drag_item:
		_cleanup_drag()
		return

	var global_mouse := get_global_mouse_position()

	if inventory_panel and inventory_panel.visible:
		var inv_local := inventory_panel.get_global_transform().affine_inverse() * global_mouse
		if Rect2(Vector2(), inventory_panel.size).has_point(inv_local):
			if PlayerStats.inventory and PlayerStats.inventory.try_add(_drag_item):
				_cleanup_drag()
				return

	var equip_local := get_global_transform().affine_inverse() * global_mouse
	var target_slot := hit_test(equip_local)
	if target_slot >= 0 and target_slot != _drag_slot:
		if try_equip(_drag_item, target_slot):
			_cleanup_drag()
			return

	if slots.get(_drag_slot) == null:
		slots[_drag_slot] = _drag_item
		_update_slot_visual(_drag_slot)

	_cleanup_drag()

func _cleanup_drag():
	if _drag_follower:
		remove_child(_drag_follower)
		_drag_follower.free()
		_drag_follower = null
	_dragging = false
	_drag_item = null
	_drag_slot = -1

func _update_slot_visual(slot_type: int):
	var rect: ColorRect = _slot_rects.get(slot_type)
	if not rect: return
	var item: Item = slots.get(slot_type)
	if item:
		rect.color = item.icon_color
	else:
		rect.color = Color(0.2, 0.2, 0.22, 1)
