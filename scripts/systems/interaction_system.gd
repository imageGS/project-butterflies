extends Node
class_name InteractionSystem

const DIR_VECTORS: Dictionary = {
	0: Vector2i(0, -1),
	1: Vector2i(1, 0),
	2: Vector2i(0, 1),
	3: Vector2i(-1, 0),
}

var renderer: Control
var entities: Array
var dialogue_system: DialogueSystem
var log_system: LogBox
var map_manager: MapManager
var station_data
var hovered_entity: Dictionary = {}
var hovered_wall: Vector2i = Vector2i(-1, -1)
var was_clicking: bool = false
var tooltip_label: Label

var _get_player_x: Callable
var _get_player_y: Callable
var _get_player_dir: Callable
var _refresh_stats: Callable
var _mono_font: Font

signal entity_interacted(ent: Dictionary)

func setup(
	renderer_node: Control,
	ds: DialogueSystem,
	ls: LogBox,
	mm: MapManager,
	player_x_callable: Callable,
	player_y_callable: Callable,
	player_dir_callable: Callable,
	mono_font: Font,
	refresh_stats: Callable,
	station_data_ref = null
):
	renderer = renderer_node
	dialogue_system = ds
	log_system = ls
	map_manager = mm
	_get_player_x = player_x_callable
	_get_player_y = player_y_callable
	_get_player_dir = player_dir_callable
	_mono_font = mono_font
	_refresh_stats = refresh_stats
	station_data = station_data_ref
	_setup_tooltip()

func _setup_tooltip():
	tooltip_label = Label.new()
	tooltip_label.add_theme_color_override("font_color", Color(1, 0.95, 0.4, 1))
	tooltip_label.add_theme_font_size_override("font_size", 25)
	tooltip_label.add_theme_font_override("font", _mono_font)
	tooltip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tooltip_label.visible = false
	tooltip_label.z_index = 100
	tooltip_label.set_anchors_preset(Control.PRESET_CENTER)
	tooltip_label.position = Vector2(-100, 120)
	tooltip_label.size = Vector2(200, 30)
	renderer.get_parent().get_parent().add_child(tooltip_label)

func _is_adjacent(ent: Dictionary) -> bool:
	var px: int = roundi(_get_player_x.call())
	var py: int = roundi(_get_player_y.call())
	var ex: int = ent.get("grid_x", -999)
	var ey: int = ent.get("grid_y", -999)
	return abs(px - ex) + abs(py - ey) == 1

func update_mouse_hover(mp_win: Vector2):
	if not renderer: return
	hovered_entity = {}

	var crt_root = renderer.get_parent().get_parent().get_parent().get_parent()
	var crt = crt_root.get_node("CRT_Display") as ColorRect
	var mp: Vector2 = mp_win - renderer.global_position
	if crt:
		var off_x: float = -crt.offset_left
		var off_y: float = -crt.offset_top
		var svp = crt_root.get_node("GameViewport") as SubViewport
		var sx: float = float(svp.size.x) / crt.size.x
		var sy: float = float(svp.size.y) / crt.size.y
		mp = Vector2((mp_win.x + off_x) * sx, (mp_win.y + off_y) * sy) - renderer.global_position
	var vis: Array = renderer.get_visible_entities()
	for ve: Dictionary in vis:
		var ex1: float = ve.get("dx1", 0.0)
		var ex2: float = ve.get("dx2", 0.0)
		if mp.x >= ex1 and mp.x <= ex2 and mp.y >= ve.get("spy", 0.0) and mp.y <= (ve.get("spy", 0.0) + ve.get("sph", 0.0)):
			var ent: Dictionary = ve.get("ent", {})
			if ent.get("object_type", "") in ["floor_decal"]: continue
			if not _is_adjacent(ent): continue
			hovered_entity = {"ent": ent}
			return
	return

func update_tooltip():
	if not tooltip_label: return
	if hovered_entity.is_empty():
		tooltip_label.visible = false
		if renderer: renderer.hovered_grid = Vector2i(-1, -1)
		return
	var ent: Dictionary = hovered_entity.get("ent", {})
	var data: Dictionary = ent.get("data", {})
	tooltip_label.text = "[Click] " + data.get("name", "???")
	tooltip_label.visible = true
	if renderer: renderer.hovered_grid = Vector2i(ent.grid_x, ent.grid_y)

func check_click_interact():
	var clicking: bool = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	if clicking and not was_clicking and not hovered_entity.is_empty():
		var ent: Dictionary = hovered_entity.get("ent", {})
		if ent.get("type", "") == "object":
			interact_object(ent)
			hovered_entity = {}
		elif ent.get("type", "") == "npc" and ent.has("dialogue"):
			dialogue_system.start(ent.dialogue as Array, ent.get("name", "Незнакомец"))
		elif ent.get("type", "") == "enemy":
			TransitionManager.change_scene("res://scenes/battle/node.tscn")
	was_clicking = clicking

	if Input.is_action_just_pressed("ui_accept"):
		var vec: Vector2i = DIR_VECTORS[_get_player_dir.call()]
		var fx: int = roundi(_get_player_x.call()) + vec.x
		var fy: int = roundi(_get_player_y.call()) + vec.y
		for ent: Dictionary in entities:
			if ent.grid_x == fx and ent.grid_y == fy:
				if ent.get("type", "") == "object":
					interact_object(ent)
					return
				elif ent.get("type", "") == "npc" and ent.has("dialogue"):
					dialogue_system.start(ent.dialogue as Array, ent.get("name", "Незнакомец"))
					return
				elif ent.get("type", "") == "enemy":
					TransitionManager.change_scene("res://scenes/battle/node.tscn")
					return

func try_interact():
	var vec: Vector2i = DIR_VECTORS[_get_player_dir.call()]
	var fx: int = roundi(_get_player_x.call()) + vec.x
	var fy: int = roundi(_get_player_y.call()) + vec.y
	for ent: Dictionary in entities:
		if ent.grid_x == fx and ent.grid_y == fy:
			if ent.type == "enemy":
				TransitionManager.change_scene("res://scenes/battle/node.tscn")
				return
			if ent.type == "npc" and ent.has("dialogue"):
				dialogue_system.start(ent.dialogue as Array, ent.get("name", "Незнакомец"))
				return
			if ent.type == "object":
				interact_object(ent)
				return

func interact_object(obj: Dictionary):
	var ot: String = obj.get("object_type", "lore")
	var data: Dictionary = obj.get("data", {})
	var obj_name: String = data.get("name", "Объект")
	match ot:
		"lore":
			var text: String = data.get("description", "Ничего особенного.")
			show_tip(obj_name + ": " + text)
		"container":
			var loot: Array = data.get("loot", [])
			if loot.is_empty():
				show_tip(obj_name + " — пусто.")
			else:
				var item_name: String = loot[0] if loot.size() == 1 else loot[randi() % loot.size()]
				PlayerStats.inventory.try_add(Item.new(item_name, "Найден в " + obj_name, 2, Vector2i(1,1), 3))
				show_tip(item_name + " добавлен в инвентарь.")
				data.loot = loot.duplicate()
				data.loot.erase(item_name)
		"rest":
			PlayerStats.restore_sanity(2)
			PlayerStats.heal(2)
			PlayerStats._limb_snapshot.clear()
			if _refresh_stats: _refresh_stats.call()
			show_tip("Вы отдыхаете у " + obj_name + ". +2 Здоровье, +2 Рассудок.")
		"hazard":
			PlayerStats.take_damage(data.get("damage", 2))
			if _refresh_stats: _refresh_stats.call()
			show_tip(data.get("description", "Ловушка!") + " -" + str(data.get("damage", 2)) + " HP.")

func check_entity():
	var rx: int = roundi(_get_player_x.call())
	var ry: int = roundi(_get_player_y.call())
	for ent: Dictionary in entities:
		if ent.grid_x == rx and ent.grid_y == ry:
			if ent.type == "enemy":
				entity_interacted.emit(ent)
				return
	var tile_val: int = map_manager.map_data[ry][rx] if ry < map_manager.map_data.size() and rx < map_manager.map_data[0].size() else 1
	if tile_val == 7 and not dialogue_system.active:
		entity_interacted.emit({"type": "exit", "grid_x": rx, "grid_y": ry})

func try_interact_wall(tx: int, ty: int):
	if not renderer: return
	var wd: Dictionary = renderer.wall_decors
	var key := "%d,%d" % [tx, ty]
	if wd.has(key):
		var cell: Dictionary = wd[key]
		var tid: String = cell.get("texture", "")
		var msg := "Стена"
		if not tid.is_empty(): msg += ": " + tid
		var decals: Array = cell.get("decals", [])
		if not decals.is_empty(): msg += ", декалей: %d" % decals.size()
		show_tip(msg)
	else:
		show_tip("Глухая стена.")

func show_tip(msg: String):
	if not dialogue_system.active:
		log_system.add_message(msg)
