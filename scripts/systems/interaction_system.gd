extends Node
class_name InteractionSystem

const DIR_VECTORS: Dictionary = {
	0: Vector2i(0, -1),
	1: Vector2i(1, 0),
	2: Vector2i(0, 1),
	3: Vector2i(-1, 0),
}
const REACH: float = 1.5
const CONTEXT_MENU_SCRIPT = preload("res://scripts/ui/context_menu.gd")

var renderer: Control
var entities: Array
var dialogue_system: DialogueSystem
var log_system: LogBox
var map_manager: MapManager
var station_data
const CURSOR_BY_OBJECT_TYPE: Dictionary = {
	"npc": "talk",
	"container": "hand",
	"tv": "gear",
	"switch": "gear",
	"terminal": "gear",
	"lore": "eye",
	"rest": "hand",
	"ground_item": "hand",
}

var hovered_entity: Dictionary = {}
var hovered_wall: Vector2i = Vector2i(-1, -1)
var _hovered_no_action: bool = false
var tooltip_label: Label

var _get_player_x: Callable
var _get_player_y: Callable
var _get_player_dir: Callable
var _get_player_angle: Callable
var _refresh_stats: Callable
var _mono_font: Font

var _noise_cb: Callable
var _refresh_world_cb: Callable
var _power_toggle_cb: Callable
var _play_hand_cb: Callable

var door_states: Dictionary = {}
var hovered_door: Vector2i = Vector2i(-1, -1)
var _context_menu = null
var _context_target: Dictionary = {}
var _was_clicking: bool = false
var _rmb_down: bool = false

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

func set_angle_callable(c: Callable):
	_get_player_angle = c

func set_noise_cb(c: Callable):
	_noise_cb = c

func set_refresh_world_cb(c: Callable):
	_refresh_world_cb = c

func set_power_toggle_cb(c: Callable):
	_power_toggle_cb = c

func set_play_hand_cb(c: Callable):
	_play_hand_cb = c

func set_door_states(states: Dictionary):
	door_states = states

func _process(delta: float):
	if _context_menu and _context_menu.open_now:
		_context_menu.update_menu(delta)

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

func _is_in_reach(ent: Dictionary) -> bool:
	var px: float = _get_player_x.call() + 0.5
	var py: float = _get_player_y.call() + 0.5
	var ex: float = ent.get("anim_x", float(ent.get("grid_x", 0.0))) + 0.5
	var ey: float = ent.get("anim_y", float(ent.get("grid_y", 0.0))) + 0.5
	var d := Vector2(px - ex, py - ey).length()
	return d <= REACH

func update_mouse_hover(mp_win: Vector2):
	if not renderer: return
	hovered_entity = {}
	hovered_door = Vector2i(-1, -1)
	_hovered_no_action = false

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
		if renderer.is_entity_occluded(ve):
			continue
		var ex1: float = ve.get("dx1", 0.0)
		var ex2: float = ve.get("dx2", 0.0)
		var spy: float = ve.get("spy", 0.0)
		var sph: float = ve.get("sph", 0.0)
		if mp.x >= ex1 and mp.x <= ex2 and mp.y >= spy and mp.y <= (spy + sph):
			var ent: Dictionary = ve.get("ent", {})
			if not _is_in_reach(ent): continue
			if ent.get("object_type", "") in ["floor_decal", "lamp", "light"]:
				_hovered_no_action = true
				continue
			hovered_entity = {"ent": ent}
			return

	var tile: Vector2i = renderer.wall_cell_at_local(mp.x, mp.y) if renderer.has_method("wall_cell_at_local") else Vector2i(-1, -1)
	if tile.x >= 0 and _is_door(tile.x, tile.y):
		hovered_door = tile
	return

func _is_door(tx: int, ty: int) -> bool:
	if map_manager and map_manager.has_method("is_door_tile"):
		return map_manager.is_door_tile(tx, ty)
	return false

func update_tooltip():
	if not tooltip_label: return
	if _context_open():
		tooltip_label.visible = false
		if renderer: renderer.hovered_grid = Vector2i(-1, -1)
		return
	if hovered_entity.is_empty() and hovered_door.x < 0:
		tooltip_label.visible = false
		if renderer: renderer.hovered_grid = Vector2i(-1, -1)
		return
	if not hovered_entity.is_empty():
		var ent: Dictionary = hovered_entity.get("ent", {})
		var data: Dictionary = ent.get("data", {})
		tooltip_label.text = "[Click] " + data.get("name", "???")
		tooltip_label.visible = true
		if renderer: renderer.hovered_grid = Vector2i(ent.grid_x, ent.grid_y)
	elif hovered_door.x >= 0:
		var d: Dictionary = door_states.get(_door_key(hovered_door.x, hovered_door.y), {})
		var nm: String = d.get("name", "Запертая дверь")
		tooltip_label.text = "%s — ЛКМ: открыть, ПКМ: способы" % nm
		tooltip_label.visible = true
		if renderer: renderer.hovered_grid = hovered_door

func _door_key(tx: int, ty: int) -> String:
	return "%d,%d" % [tx, ty]

func _door_flag(tx: int, ty: int) -> String:
	return "door_%d_%d_open" % [tx, ty]

func update_cursor():
	var kind: String = "eye"
	if not hovered_entity.is_empty():
		var ent: Dictionary = hovered_entity.get("ent", {})
		if ent.get("data", {}).get("locked", false):
			kind = "locked"
		elif ent.get("type", "") == "npc":
			kind = "talk"
		else:
			kind = CURSOR_BY_OBJECT_TYPE.get(ent.get("object_type", ""), "eye")
	elif hovered_door.x >= 0:
		kind = "hand"
	elif _hovered_no_action:
		kind = "no_action"
	if CursorManager:
		CursorManager.set_cursor(kind)

func _is_open(tx: int, ty: int) -> bool:
	return PlayerStats.has_flag(_door_flag(tx, ty))

func _is_at_door(tx: int, ty: int) -> bool:
	var px: int = roundi(_get_player_x.call() if _get_player_x.is_valid() else 0.0)
	var py: int = roundi(_get_player_y.call() if _get_player_y.is_valid() else 0.0)
	return abs(tx - px) + abs(ty - py) <= 2

func _mouse_in_ui() -> Vector2:
	var parent := _menu_parent()
	if not parent: return Vector2.ZERO
	var vp = get_viewport()
	var mp_win: Vector2 = vp.get_mouse_position() if vp else Vector2.ZERO
	var crt_root = renderer.get_parent().get_parent().get_parent().get_parent()
	var crt = crt_root.get_node("CRT_Display") as ColorRect
	var mp: Vector2 = mp_win - parent.global_position
	if crt:
		var off_x: float = -crt.offset_left
		var off_y: float = -crt.offset_top
		var svp = crt_root.get_node("GameViewport") as SubViewport
		var sx: float = float(svp.size.x) / crt.size.x
		var sy: float = float(svp.size.y) / crt.size.y
		mp = Vector2((mp_win.x + off_x) * sx, (mp_win.y + off_y) * sy) - parent.global_position
	return mp

func _menu_parent() -> Control:
	return renderer.get_parent().get_parent() as Control

func _has_keycard() -> bool:
	var inv = PlayerStats.inventory
	if not inv: return false
	for i in inv.size():
		var it = inv.get_item(i)
		if it and it.id == "card":
			return true
	return false

func _find_keycard():
	if not PlayerStats.inventory: return null
	for i in PlayerStats.inventory.size():
		var it = PlayerStats.inventory.get_item(i)
		if it and it.id == "card":
			return it
	return null

func _emit_noise(tx: int, ty: int, radius: float):
	if _noise_cb and _noise_cb.is_valid():
		_noise_cb.call(tx, ty, radius)

func _try_skill(skill: String, dc: int) -> Dictionary:
	return SkillCheck.check(PlayerStats.get_skill(skill), dc)

func _door_named(tx: int, ty: int) -> String:
	return str(door_states.get(_door_key(tx, ty), {}).get("name", "Запертая дверь"))

func _door_display_name(tx: int, ty: int) -> String:
	return str(door_states.get(_door_key(tx, ty), {}).get("name", "Запертая дверь"))

func _attempt_open_door(tile: Vector2i, action: String):
	if PlayerStats.has_flag(_door_flag(tile.x, tile.y)):
		_play_click(func(): _open_door_success(tile, "«%s» уже была открыта." % _door_display_name(tile.x, tile.y)))
		return
	var d: Dictionary = door_states.get(_door_key(tile.x, tile.y), {})
	var title := _door_display_name(tile.x, tile.y)
	if action == "card":
		if _has_keycard():
			_play_click(func(): _open_door_success(tile, "Вы открыли «%s» ключ-картой." % title))
		else:
			show_tip("Нет подходящей ключ-карты.")
		_close_context_menu()
		return
	if action == "auto":
		if _has_keycard():
			_play_click(func(): _open_door_success(tile, "Вы открыли «%s» ключ-картой." % title))
			_close_context_menu()
			return
		if _try_door_skill("resourcefulness", int(d.get("lock_dc", 11))):
			_play_lockpick(func(): _open_door_success(tile, "Вы взломали замок «%s»." % title))
			_close_context_menu()
			return
		if _try_door_skill("stamina", int(d.get("smash_dc", 13))):
			_play_punch(func():
				_open_door_success(tile, "Вы выбили «%s»." % title)
				_emit_noise(tile.x, tile.y, 5.0)
				show_tip("От удара по двери разнёсся громкий грохот.")
			)
		else:
			_play_punch(func():
				_emit_noise(tile.x, tile.y, 1.5)
				show_tip("Не удалось открыть «%s»." % title)
			)
		_close_context_menu()
		return
	if action == "lock":
		_play_lockpick(func():
			if _try_door_skill("resourcefulness", int(d.get("lock_dc", 12))):
				_open_door_success(tile, "Вы взломали замок «%s»." % title)
			else:
				_emit_noise(tile.x, tile.y, 1.5)
				show_tip("Не удалось взломать «%s»." % title)
		)
		return
	if action == "smash":
		_play_punch(func():
			if _try_door_skill("stamina", int(d.get("smash_dc", 13))):
				_open_door_success(tile, "Вы выбили «%s»." % title)
				_emit_noise(tile.x, tile.y, 5.0)
				show_tip("От удара по двери разнёсся громкий грохот.")
			else:
				_emit_noise(tile.x, tile.y, 1.5)
				show_tip("Вы не смогли выбить «%s»." % title)
		)
		_close_context_menu()

func _try_door_skill(skill: String, dc: int) -> bool:
	var r := SkillCheck.check(PlayerStats.get_skill(skill), dc)
	return r.get("success", false)

func _open_door_success(tile: Vector2i, msg: String):
	show_tip(msg)
	if map_manager and map_manager.has_method("open_door"):
		map_manager.open_door(tile.x, tile.y)
	PlayerStats.set_flag(_door_flag(tile.x, tile.y))
	door_states.erase(_door_key(tile.x, tile.y))
	if renderer: renderer.queue_redraw_walls()
	if _refresh_world_cb and _refresh_world_cb.is_valid():
		_refresh_world_cb.call()
	_close_context_menu()

func _play_click(on_done: Callable):
	if _play_hand_cb.is_valid():
		_play_hand_cb.call("click", on_done)
	else:
		on_done.call()

func _play_punch(on_done: Callable):
	if _play_hand_cb.is_valid():
		_play_hand_cb.call("punch", on_done)
	else:
		on_done.call()

func _play_take(on_done: Callable):
	if _play_hand_cb.is_valid():
		_play_hand_cb.call("take", on_done)
	else:
		on_done.call()

func _play_use(on_done: Callable):
	if _play_hand_cb.is_valid():
		_play_hand_cb.call("use", on_done)
	else:
		on_done.call()

func _play_lockpick(on_done: Callable):
	if _play_hand_cb.is_valid():
		_play_hand_cb.call("lockpick/lockpick_start", func():
			_play_hand_cb.call("lockpick/lockpick_loop", func():
				_play_hand_cb.call("lockpick/lockpick_start", on_done, 12.0, false, 1, true)
			, 12.0, false, 1)
		)
	else:
		on_done.call()

func _close_context_menu():
	if _context_menu:
		_context_menu.close()
	if renderer: renderer.hovered_grid = Vector2i(-1, -1)
	hovered_door = Vector2i(-1, -1)
	_context_target = {}

func _context_open() -> bool:
	return _context_menu != null and _context_menu.open_now

func check_click_interact():
	var rmb: bool = Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	if not rmb and _rmb_down:
		_rmb_down = false
		if _context_open():
			_dispatch_context_action(_context_menu.selected())
			_close_context_menu()
		return
	if rmb and not _rmb_down:
		_rmb_down = true
		_open_context_menu()
		return
	if _context_open():
		return

	var clicking: bool = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	if clicking and not _was_clicking:
		if hovered_door.x >= 0 and _is_at_door(hovered_door.x, hovered_door.y):
			_attempt_open_door(hovered_door, "auto")
			hovered_door = Vector2i(-1, -1)
		elif not hovered_entity.is_empty():
			var ent: Dictionary = hovered_entity.get("ent", {})
			if ent.get("type", "") == "object":
				interact_object(ent)
			elif ent.get("type", "") == "npc" and ent.has("dialogue"):
				dialogue_system.start(ent.dialogue as Array, ent.get("name", "Незнакомец"))
			elif ent.get("type", "") == "enemy":
				TransitionManager.change_scene("res://scenes/battle/node.tscn")
			hovered_entity = {}
		_was_clicking = true
		return
	if not clicking and _was_clicking:
		_was_clicking = false
		return

	if Input.is_action_just_pressed("ui_accept"):
		try_interact()

func _open_context_menu():
	if _context_open():
		return
	var target := _current_target()
	if target.is_empty():
		return
	var items: Array = _build_items(target)
	if items.is_empty():
		return
	if _context_menu == null:
		_context_menu = CONTEXT_MENU_SCRIPT.new()
	_context_menu.open(items, _mouse_in_ui(), _menu_parent(), _mono_font, func(): return _mouse_in_ui())
	_context_target = target

func _current_target() -> Dictionary:
	if hovered_door.x >= 0 and _is_at_door(hovered_door.x, hovered_door.y) and _is_door(hovered_door.x, hovered_door.y):
		return {"kind": "door", "tile": hovered_door}
	if not hovered_entity.is_empty():
		var ent: Dictionary = hovered_entity.get("ent", {})
		return {"kind": ent.get("type", ""), "ent": ent}
	return {}

func _build_items(t: Dictionary) -> Array:
	var kind: String = String(t.get("kind", ""))
	match kind:
		"door":
			return [
				{"id": "key", "title": "Ключ-карта"},
				{"id": "lockpick", "title": "Взлом"},
				{"id": "fist", "title": "Выбить"},
			]
		"object":
			return [
				{"id": "interact", "title": "Взаимодействие"},
				{"id": "fist", "title": "Ударить"},
			]
		"npc":
			return [{"id": "talk", "title": "Разговор"}]
		"enemy":
			return [{"id": "fist", "title": "Атаковать"}]
	return []

func _dispatch_context_action(action_id: String):
	var kind: String = String(_context_target.get("kind", ""))
	if kind == "door":
		var tile: Vector2i = _context_target.get("tile", Vector2i(-1, -1))
		match action_id:
			"key":
				_attempt_open_door(tile, "card")
			"lockpick":
				_attempt_open_door(tile, "lock")
			"fist":
				_attempt_open_door(tile, "smash")
		return
	if kind == "object":
		var ent: Dictionary = _context_target.get("ent", {})
		if action_id == "interact":
			interact_object(ent)
		elif action_id == "fist":
			_punch_object(ent)
		return
	if kind == "npc" and action_id == "talk":
		var ent2: Dictionary = _context_target.get("ent", {})
		if ent2.has("dialogue"):
			dialogue_system.start(ent2.dialogue as Array, ent2.get("name", "Незнакомец"))
		return
	if kind == "enemy" and action_id == "fist":
		TransitionManager.change_scene("res://scenes/battle/node.tscn")

func _punch_object(ent: Dictionary):
	var obj_name: String = String(ent.get("data", {}).get("name", "объект"))
	_play_punch(func():
		if randf() < 0.05:
			show_tip("Вы ударили %s. Что-то скрипнуло..." % obj_name)
			_emit_noise(int(ent.get("grid_x", 0)), int(ent.get("grid_y", 0)), 2.0)
		else:
			show_tip("Вы ударили %s. Ничего не произошло." % obj_name)
	)

func try_interact():
	var px: float = _get_player_x.call() + 0.5
	var py: float = _get_player_y.call() + 0.5
	var ang: float = _get_player_angle.call() if _get_player_angle and _get_player_angle.is_valid() else 0.0
	var fwd := Vector2(cos(ang), sin(ang))
	var best: Dictionary = {}
	var best_cos: float = -2.0
	var best_dist: float = 9999.0
	for ent: Dictionary in entities:
		if not _is_in_reach(ent): continue
		var ex: float = ent.get("anim_x", float(ent.get("grid_x", 0.0))) + 0.5
		var ey: float = ent.get("anim_y", float(ent.get("grid_y", 0.0))) + 0.5
		var to := Vector2(ex - px, ey - py)
		var d: float = to.length()
		if d < 0.01: continue
		var c: float = to.dot(fwd) / d
		if c > best_cos or (c == best_cos and d < best_dist):
			best_cos = c
			best_dist = d
			best = ent
	if best.is_empty(): return
	if best.type == "enemy":
		TransitionManager.change_scene("res://scenes/battle/node.tscn")
		return
	if best.type == "npc" and best.has("dialogue"):
		dialogue_system.start(best.dialogue as Array, best.get("name", "Незнакомец"))
		return
	if best.type == "object":
		interact_object(best)
		return

func _resolve_anim(obj: Dictionary) -> String:
	var data: Dictionary = obj.get("data", {})
	var flag: String = data.get("interact_anim", "")
	if not flag.is_empty():
		return flag
	var ot: String = obj.get("object_type", "lore")
	match ot:
		"container": return "take"
		"ground_item": return "take"
		"tv": return "click"
		_: return "use"

func _play_anim(anim_name: String, on_done: Callable):
	match anim_name:
		"click": _play_click(on_done)
		"take": _play_take(on_done)
		"heal": _play_use(on_done)
		"punch": _play_punch(on_done)
		"lockpick": _play_lockpick(on_done)
		_: _play_use(on_done)

func interact_object(obj: Dictionary):
	var ot: String = obj.get("object_type", "lore")
	var data: Dictionary = obj.get("data", {})
	var obj_name: String = data.get("name", "Объект")
	var anim: String = _resolve_anim(obj)
	match ot:
		"lore":
			_play_use(func():
				var text: String = data.get("description", "Ничего особенного.")
				show_tip(obj_name + ": " + text)
			)
		"container":
			var loot: Array = data.get("loot", [])
			if loot.is_empty():
				show_tip(obj_name + " — пусто.")
			else:
				_play_anim(anim, func():
					var item_id: String = loot[0] if loot.size() == 1 else loot[randi() % loot.size()]
					var item: Item = ItemCatalog.create(item_id)
					if item:
						PlayerStats.inventory.try_add(item)
						show_tip(item.name + " добавлен в инвентарь.")
					else:
						show_tip("Внутри ничего ценного.")
					data.loot = loot.duplicate()
					data.loot.erase(item_id)
				)
		"rest":
			_play_anim(anim, func():
				PlayerStats.restore_sanity(2)
				PlayerStats.heal(2)
				PlayerStats._limb_snapshot.clear()
				if _refresh_stats: _refresh_stats.call()
				show_tip("Вы отдыхаете у " + obj_name + ". +2 Здоровье, +2 Рассудок.")
			)
		"ground_item":
			_play_anim(anim, func():
				var gi := ItemCatalog.create(str(data.get("item_id", "")))
				if gi:
					gi.stack_count = int(data.get("count", 1))
					if PlayerStats.inventory.try_add(gi):
						entities.erase(obj)
						show_tip("%s подобраны в инвентарь." % obj_name)
						if _refresh_world_cb and _refresh_world_cb.is_valid():
							_refresh_world_cb.call()
					else:
						show_tip("Нет места в инвентаре.")
				else:
					show_tip("Что-то лежит, но поднять нельзя.")
			)
		"tv":
			var timer: float = data.get("tv_timer", 0.0)
			if timer > 0.0:
				show_tip("Телевизор разогревается. Подождите.")
			else:
				_play_anim(anim, func():
					data.tv_timer = 10.0
					var on_tex: Texture2D = data.get("tv_front_on", null)
					if on_tex:
						var off_tex: Texture2D = data.get("tv_front_off", null)
						if off_tex:
							data.tv_front_off = obj.textures.get("front", null)
						obj.textures["front"] = on_tex
					show_tip(data.get("description", "Ничего."))
				)
		"hazard":
			PlayerStats.take_damage(data.get("damage", 2))
			if _refresh_stats: _refresh_stats.call()
			show_tip(data.get("description", "Ловушка!") + " -" + str(data.get("damage", 2)) + " HP.")
		"terminal":
			var r2 := SkillCheck.check(PlayerStats.get_skill("resourcefulness"), int(data.get("dc", 12)))
			if r2.success:
				var door_cell: String = str(data.get("door", ""))
				if not door_cell.is_empty():
					var parts: PackedStringArray = door_cell.split(",")
					if parts.size() == 2:
						var door_tile := Vector2i(int(parts[0]), int(parts[1]))
						_play_click(func(): _open_door_success(door_tile, "Терминал открыл дверь: " + _door_display_name(door_tile.x, door_tile.y) + "."))
						return
				var flag: String = str(data.get("flag", ""))
				if not flag.is_empty():
					PlayerStats.set_flag(flag)
				_play_anim(anim, func():
					show_tip("Вы взломали терминал. " + data.get("success", ""))
				)
			else:
				_emit_noise(obj.grid_x, obj.grid_y, 1.0)
				show_tip("Терминал сопротивляется. " + data.get("fail", ""))
		"switch":
			_play_anim(anim, func():
				if _power_toggle_cb and _power_toggle_cb.is_valid():
					_power_toggle_cb.call()
				show_tip(data.get("description", "Вы переключили рубильник."))
			)

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
