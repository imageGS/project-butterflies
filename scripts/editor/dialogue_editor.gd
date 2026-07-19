extends VBoxContainer

var _char_ids: Array[String] = []
var _char_dropdown: OptionButton
var _name_edit: LineEdit
var _dialogue_data: Dictionary = {}
var _dialogue_name: String = ""
var _icon_map: Array[String] = []

var _graph_edit: GraphEdit
var _graph_nodes: Dictionary = {}  # id → GraphNode
var _inspector_scroll: ScrollContainer
var _no_selection: Label

var _edit_id: LineEdit
var _edit_name: LineEdit
var _text_pages: VBoxContainer
var _icon_dropdown: OptionButton
var _choices_container: VBoxContainer
var _actions_container: VBoxContainer
var _status_lbl: Label

var _selected_id: String = ""

static var _current_char: String = "kitsu"

const SLOT_COLOR_NEXT: Color = Color(0.3, 0.8, 0.3)
const SLOT_COLOR_CHOICE: Color = Color(0.3, 0.5, 1.0)
const SLOT_COLOR_INPUT: Color = Color(0.8, 0.8, 0.3)

func _init():
	print("=== DialogueEditor._init() ===")

func _ready():
	print("=== DialogueEditor._ready() ===")
	_scan_characters()
	_scan_icons()
	_setup_ui()
	_update_status()
	_load_current()

func _char_file_path() -> String:
	return "res://dialogues/%s/main.json" % _current_char

func _scan_characters():
	_char_ids.clear()
	_char_ids.append("kitsu")
	var dd := DirAccess.open("res://dialogues")
	if dd:
		dd.list_dir_begin()
		var f: String = dd.get_next()
		while f != "":
			if f != "." and f != ".." and dd.current_is_dir() and f not in _char_ids:
				_char_ids.append(f)
			f = dd.get_next()
		dd.list_dir_end()
	_char_ids.sort()
	if "kitsu" in _char_ids:
		_char_ids.erase("kitsu")
		_char_ids.insert(0, "kitsu")

func _populate_char_dropdown():
	_char_dropdown.clear()
	var sel: int = 0
	for i in _char_ids.size():
		_char_dropdown.add_item(_char_ids[i])
		if _char_ids[i] == _current_char: sel = i
	if _char_dropdown.item_count == 0 or sel >= _char_dropdown.item_count:
		_char_dropdown.add_item(_current_char); sel = _char_dropdown.item_count - 1
	_char_dropdown.selected = sel

func _on_char_selected(idx: int):
	if idx < 0 or idx >= _char_dropdown.item_count: return
	_save_current()
	_current_char = _char_dropdown.get_item_text(idx)
	_clear_all()
	_load_current()
	_populate_char_dropdown()

func _save_current():
	if _dialogue_data.is_empty(): return
	_save()

func _load_current():
	print("=== _load_current: %s ===" % _current_char)
	_populate_char_dropdown()
	var path: String = _char_file_path()
	var raw: String = FileAccess.get_file_as_string(path)
	if raw.is_empty():
		print("  no file yet at %s" % path)
		_dialogue_name = _current_char.capitalize()
		_name_edit.text = _dialogue_name
		return
	var data: Dictionary = JSON.parse_string(raw)
	if data == null or data.is_empty():
		print("  invalid JSON at %s" % path)
		_dialogue_name = _current_char.capitalize()
		_name_edit.text = _dialogue_name
		return
	_dialogue_name = data.get("name", _current_char.capitalize())
	_name_edit.text = _dialogue_name
	for key: String in data:
		if key == "name": continue
		var nd: Variant = data[key]
		if typeof(nd) != TYPE_DICTIONARY: continue
		if not nd.has("text") or nd["text"] is String: nd["text"] = [nd.get("text", "")]
		if not nd.has("choices"): nd["choices"] = []
		if not nd.has("icon"): nd["icon"] = ""
		if not nd.has("action"): nd["action"] = []
		_dialogue_data[key] = nd
		_add_graph_node(key)
	print("  loaded %d nodes from %s" % [_dialogue_data.size(), path])
	_reconnect_all()
	_update_status()

func _scan_icons():
	_icon_map.clear()
	var nd := DirAccess.open("res://sprites/npc")
	if not nd: return
	nd.list_dir_begin()
	var f: String = nd.get_next()
	while f != "":
		if f != "." and f != ".." and nd.current_is_dir():
			var dd := DirAccess.open("res://sprites/npc/%s/dialogue" % f)
			if dd:
				dd.list_dir_begin()
				var p: String = dd.get_next()
				while p != "":
					if not dd.current_is_dir() and p.ends_with(".png"):
						_icon_map.append("%s/dialogue/%s" % [f, p.get_basename()])
					p = dd.get_next()
				dd.list_dir_end()
		f = nd.get_next()
	nd.list_dir_end()
	_icon_map.sort()

func _mk_btn(text: String, cb: Callable) -> Button:
	var b := Button.new(); b.text = text
	b.custom_minimum_size = Vector2(0, 22); b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.add_theme_font_size_override("font_size", 11)
	b.pressed.connect(cb)
	return b

func _setup_ui():
	self.size_flags_vertical = Control.SIZE_EXPAND_FILL
	self.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 2)
	add_theme_font_size_override("font_size", 12)

	var tb := HBoxContainer.new()
	tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tb.add_theme_constant_override("separation", 2)

	tb.add_child(_mk_btn("+", _add_node))
	tb.add_child(_mk_btn("-", _del_selected))
	tb.add_child(VSeparator.new())
	var l_char := Label.new(); l_char.text = "Char:"; tb.add_child(l_char)
	_char_dropdown = OptionButton.new()
	_char_dropdown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_char_dropdown.custom_minimum_size.y = 22
	_char_dropdown.item_selected.connect(_on_char_selected)
	tb.add_child(_char_dropdown)
	tb.add_child(VSeparator.new())
	var ln := Label.new(); ln.text = "Name:"; tb.add_child(ln)
	_name_edit = LineEdit.new(); _name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_edit.custom_minimum_size.y = 22
	_name_edit.placeholder_text = "NPC Name"
	_name_edit.text_changed.connect(func(t): _dialogue_name = t)
	tb.add_child(_name_edit)
	add_child(tb)

	var hsplit := HSplitContainer.new()
	hsplit.size_flags_vertical = Control.SIZE_EXPAND_FILL; add_child(hsplit)

	_graph_edit = GraphEdit.new()
	_graph_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL; _graph_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_graph_edit.show_menu = true; _graph_edit.minimap_enabled = true
	_graph_edit.connection_to_empty.connect(_on_connection_to_empty)
	_graph_edit.connection_request.connect(_on_connection)
	_graph_edit.disconnection_request.connect(_on_disconnection)
	_graph_edit.node_selected.connect(_on_node_selected)
	hsplit.add_child(_graph_edit)

	_inspector_scroll = ScrollContainer.new()
	_inspector_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL; _inspector_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_inspector_scroll.custom_minimum_size.x = 280
	hsplit.add_child(_inspector_scroll)

	var c := VBoxContainer.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL; _inspector_scroll.add_child(c)

	_no_selection = Label.new()
	_no_selection.text = "Select a node"
	_no_selection.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_no_selection.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_no_selection.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(_no_selection)

	_edit_id = _add_field(c, "ID:", LineEdit.new())
	_edit_name = _add_field(c, "Name:", LineEdit.new()); _edit_name.placeholder_text = "(default)"

	c.add_child(HSeparator.new())
	var ph := HBoxContainer.new()
	var lp := Label.new(); lp.text = "Text:"; ph.add_child(lp)
	ph.add_spacer(true)
	ph.add_child(_mk_btn("+", _add_text_page))
	c.add_child(ph)
	_text_pages = VBoxContainer.new(); c.add_child(_text_pages)

	_icon_dropdown = _add_field(c, "Icon:", OptionButton.new())

	c.add_child(HSeparator.new())
	var ch := HBoxContainer.new()
	var lc := Label.new(); lc.text = "Choices:"; ch.add_child(lc)
	ch.add_spacer(true)
	ch.add_child(_mk_btn("+", _add_choice))
	c.add_child(ch)
	_choices_container = VBoxContainer.new(); c.add_child(_choices_container)

	c.add_child(HSeparator.new())
	var ah := HBoxContainer.new()
	var la := Label.new(); la.text = "Actions:"; ah.add_child(la)
	ah.add_spacer(true)
	ah.add_child(_mk_btn("+", _add_action_row))
	c.add_child(ah)
	_actions_container = VBoxContainer.new(); c.add_child(_actions_container)

	c.add_child(HSeparator.new())
	c.add_child(_mk_btn("Apply", _apply))

	_hide_inspector()

	var bb := HBoxContainer.new()
	bb.add_theme_constant_override("separation", 2)
	bb.add_child(_mk_btn("Save", _save))
	bb.add_child(_mk_btn("Load", _load))
	bb.add_child(_mk_btn("Back", _back))
	_status_lbl = Label.new()
	_status_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_lbl.text = "ready"
	bb.add_child(_status_lbl)
	add_child(bb)

func _mk_small(w: Control) -> Control:
	if w is LineEdit: w.custom_minimum_size.y = 22
	if w is OptionButton: w.custom_minimum_size.y = 22
	if w is TextEdit: w.custom_minimum_size.y = 36
	return w

func _add_field(parent: VBoxContainer, label: String, widget: Control) -> Control:
	var h := HBoxContainer.new(); h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var l := Label.new(); l.text = label; h.add_child(l)
	widget.size_flags_horizontal = Control.SIZE_EXPAND_FILL; _mk_small(widget); h.add_child(widget)
	parent.add_child(h)
	return widget

func _hide_inspector():
	_edit_id.get_parent().visible = false
	_edit_name.get_parent().visible = false
	for c in _inspector_scroll.get_child(0).get_children():
		c.visible = false
	_edit_id.get_parent().visible = false; _edit_name.get_parent().visible = false
	_no_selection.visible = true

func _show_inspector():
	for c in _inspector_scroll.get_child(0).get_children():
		c.visible = true
	_no_selection.visible = false

func _get_gn_id(gn: GraphNode) -> String:
	var n: String = gn.name
	return n.trim_prefix("gn_")

func _setup_slots(gn: GraphNode, nd: Dictionary):
	var ts: int = 1 + nd.get("choices", []).size()
	for i in range(ts):
		gn.set_slot(i, i == 0, 0, SLOT_COLOR_INPUT, true, 0, SLOT_COLOR_NEXT if i == 0 else SLOT_COLOR_CHOICE)
	gn.queue_redraw()

func _add_graph_node(id: String):
	if id in _graph_nodes: return
	var nd: Dictionary = _dialogue_data[id]
	var gn := GraphNode.new()
	gn.title = nd.get("name", id)
	gn.name = "gn_" + id
	gn.custom_minimum_size = Vector2(180, 60)

	var preview := Label.new()
	preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview.autowrap_mode = TextServer.AUTOWRAP_WORD
	preview.custom_minimum_size.y = 40
	var texts: Array = nd.get("text", [""])
	if texts.is_empty() or (texts.size() == 1 and (texts[0] as String).is_empty()):
		preview.text = "(empty)"
		preview.modulate = Color(0.5, 0.5, 0.5)
	else:
		preview.text = (texts[0] as String).substr(0, 60).replace("\n", " ")
		if (texts[0] as String).length() > 60: preview.text += "..."

	var hc := HBoxContainer.new()
	if nd.get("icon", "") != "":
		var ic := TextureRect.new()
		ic.custom_minimum_size = Vector2(24, 24); ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var icon_path := "res://sprites/npc/%s.png" % nd["icon"]
		var tex := load(icon_path) as Texture2D
		if tex: ic.texture = tex
		hc.add_child(ic)
	hc.add_child(preview)
	gn.add_child(hc)

	_graph_nodes[id] = gn
	_graph_edit.add_child(gn)
	_setup_slots(gn, nd)
	var px: float = nd.get("_pos_x", -1.0)
	var py: float = nd.get("_pos_y", -1.0)
	var pos: Vector2
	if px < 0:
		pos = Vector2(randi_range(100, 700), randi_range(100, 500))
	else:
		pos = Vector2(px, py)
	gn.position_offset = pos

func _update_graph_node(id: String):
	if id not in _graph_nodes: return
	var gn: GraphNode = _graph_nodes[id]
	var nd: Dictionary = _dialogue_data[id]
	gn.title = nd.get("name", id)

	var texts: Array = nd.get("text", [""])
	var preview := gn.get_child(0).get_child(1) if gn.get_child_count() > 0 and gn.get_child(0) is HBoxContainer else null
	if preview and preview is Label:
		if texts.is_empty() or (texts.size() == 1 and (texts[0] as String).is_empty()):
			preview.text = "(empty)"
			preview.modulate = Color(0.5, 0.5, 0.5)
		else:
			preview.text = (texts[0] as String).substr(0, 60).replace("\n", " ")
			if (texts[0] as String).length() > 60: preview.text += "..."
			preview.modulate = Color(1, 1, 1)

	_setup_slots(gn, nd)
	gn.queue_redraw()
	for i in range(gn.get_child_count()):
		gn.get_child(i).queue_redraw()

func _add_node():
	print("=== _add_node() ===")
	var nid := _unique_id()
	var nd: Dictionary = {}
	nd["text"] = [""]; nd["choices"] = []; nd["icon"] = ""
	_dialogue_data[nid] = nd
	_add_graph_node(nid)
	_update_status()

func _unique_id() -> String:
	var n := 0
	while "node_%d" % n in _dialogue_data: n += 1
	return "node_%d" % n

func _del_selected():
	if _selected_id == "" or _selected_id not in _dialogue_data: return
	print("=== _del_selected: %s ===" % _selected_id)
	if _selected_id in _graph_nodes:
		var gn: GraphNode = _graph_nodes[_selected_id]
		_graph_nodes.erase(_selected_id)
		_graph_edit.remove_child(gn); gn.queue_free()
	# remove connections referencing this node
	var to_remove: Array[Dictionary] = []
	for conn in _graph_edit.get_connection_list():
		if conn["from_node"] == "gn_" + _selected_id or conn["to_node"] == "gn_" + _selected_id:
			to_remove.append(conn)
	for conn in to_remove:
		_graph_edit.disconnect_node(conn["from_node"], conn["from_port"], conn["to_node"], conn["to_port"])
	# fix stored references
	for id: String in _dialogue_data:
		var nd: Dictionary = _dialogue_data[id]
		if nd.get("next", "") == _selected_id: nd.erase("next")
		for c in nd.get("choices", []):
			if c.get("next", "") == _selected_id: c.erase("next")
			if c.get("next_pass", "") == _selected_id: c.erase("next_pass")
			if c.get("next_fail", "") == _selected_id: c.erase("next_fail")
	_dialogue_data.erase(_selected_id)
	_selected_id = ""
	_hide_inspector()
	_update_status()

func _on_node_selected(node: Node):
	var gn := node as GraphNode
	if not gn: return
	if _selected_id != "": _collect_inspector()
	_selected_id = _get_gn_id(gn)
	_fill_inspector()

func _on_connection_to_empty(from_node: StringName, from_port: int, _to_pos: Vector2):
	print("connection to empty: %s port %d" % [from_node, from_port])
	var nid := _unique_id()
	var nd: Dictionary = {}
	nd["text"] = [""]; nd["choices"] = []; nd["icon"] = ""
	_dialogue_data[nid] = nd
	_add_graph_node(nid)
	if _graph_nodes[nid]:
		var pos: Vector2 = _graph_edit.scroll_offset + Vector2(200, 200) + Vector2(randi_range(-50, 50), randi_range(-50, 50))
		_graph_nodes[nid].position_offset = pos
		_graph_edit.connect_node(from_node, from_port, "gn_" + nid, 0)
		_save_connection(from_node, from_port, "gn_" + nid, 0)
	_update_status()

func _on_connection(from_node: StringName, from_port: int, to_node: StringName, to_port: int):
	print("connection: %s[%d] → %s[%d]" % [from_node, from_port, to_node, to_port])
	_graph_edit.connect_node(from_node, from_port, to_node, to_port)
	_save_connection(from_node, from_port, to_node, to_port)

func _on_disconnection(from_node: StringName, from_port: int, to_node: StringName, to_port: int):
	print("disconnection: %s[%d] → %s[%d]" % [from_node, from_port, to_node, to_port])
	_graph_edit.disconnect_node(from_node, from_port, to_node, to_port)
	_remove_connection(from_node, from_port, to_node, to_port)

func _save_connection(from_node: StringName, from_port: int, to_node: StringName, _to_port: int):
	var fid: String = (from_node as String).trim_prefix("gn_")
	var tid: String = (to_node as String).trim_prefix("gn_")
	if fid not in _dialogue_data or tid not in _dialogue_data: return
	var nd: Dictionary = _dialogue_data[fid]
	if from_port == 0:
		nd["next"] = tid
	elif from_port > 0:
		var ci: int = from_port - 1
		var choices: Array = nd.get("choices", [])
		if ci < choices.size():
			choices[ci]["next"] = tid

func _remove_connection(from_node: StringName, from_port: int, to_node: StringName, _to_port: int):
	var fid: String = (from_node as String).trim_prefix("gn_")
	var _tid: String = (to_node as String).trim_prefix("gn_")
	if fid not in _dialogue_data: return
	var nd: Dictionary = _dialogue_data[fid]
	if from_port == 0:
		nd.erase("next")
	elif from_port > 0:
		var ci: int = from_port - 1
		var choices: Array = nd.get("choices", [])
		if ci < choices.size():
			choices[ci].erase("next")

func _reconnect_all():
	for conn in _graph_edit.get_connection_list():
		_graph_edit.disconnect_node(conn["from_node"], conn["from_port"], conn["to_node"], conn["to_port"])
	for id: String in _dialogue_data:
		var nd: Dictionary = _dialogue_data[id]
		var fn: StringName = StringName("gn_" + id)
		# reconnect main next
		if nd.has("next"):
			var tn: String = nd["next"]
			if tn in _dialogue_data and tn in _graph_nodes:
				_graph_edit.connect_node(fn, 0, StringName("gn_" + tn), 0)
		# reconnect choice nexts
		var choices: Array = nd.get("choices", [])
		for ci in choices.size():
			var ch: Dictionary = choices[ci]
			if ch.has("next"):
				var tn: String = ch["next"]
				if tn in _dialogue_data and tn in _graph_nodes:
					_graph_edit.connect_node(fn, ci + 1, StringName("gn_" + tn), 0)

func _update_status():
	var msg: String = "Nodes: %d | Selected: %s" % [_dialogue_data.size(), _selected_id if _selected_id else "(none)"]
	_status_lbl.text = msg

func _fill_inspector():
	if _selected_id == "" or _selected_id not in _dialogue_data:
		_hide_inspector(); return
	_show_inspector()
	var nd: Dictionary = _dialogue_data[_selected_id]
	_edit_id.text = _selected_id
	_edit_name.text = nd.get("name", "")
	_fill_texts(nd.get("text", [""]))
	_fill_icon(nd.get("icon", ""))
	_fill_choices(nd.get("choices", []))
	_fill_actions(nd.get("action", []))

func _collect_inspector():
	if _selected_id == "" or _selected_id not in _dialogue_data: return
	var nd: Dictionary = _dialogue_data[_selected_id]
	var new_id: String = _edit_id.text.strip_edges()
	if new_id != _selected_id and new_id != "" and new_id not in _dialogue_data:
		# rename
		_dialogue_data[new_id] = nd
		_dialogue_data.erase(_selected_id)
		_graph_nodes[new_id] = _graph_nodes[_selected_id]
		_graph_nodes.erase(_selected_id)
		_graph_nodes[new_id].name = "gn_" + new_id
		_selected_id = new_id
	nd["text"] = _collect_texts()
	nd["icon"] = _icon_value()
	nd["name"] = _edit_name.text.strip_edges()
	nd["choices"] = _collect_choices()
	nd["action"] = _collect_actions()

func _apply():
	if _selected_id == "" or _selected_id not in _dialogue_data: return
	_collect_inspector()
	_update_graph_node(_selected_id)
	_fill_inspector()
	_save_all_positions()
	_reconnect_all()
	_update_status()

func _save_all_positions():
	for id: String in _graph_nodes:
		var p: Vector2 = _graph_nodes[id].position_offset
		_dialogue_data[id]["_pos_x"] = p.x
		_dialogue_data[id]["_pos_y"] = p.y

func _fill_texts(texts: Array):
	for c in _text_pages.get_children(): _text_pages.remove_child(c); c.queue_free()
	for i in texts.size():
		var h := HBoxContainer.new(); h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(_mk_btn("x", _del_text_page.bind(i)))
		var te := TextEdit.new(); te.custom_minimum_size.y = 36
		te.size_flags_horizontal = Control.SIZE_EXPAND_FILL; te.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
		te.text = texts[i]; h.add_child(te)
		_text_pages.add_child(h)

func _del_text_page(idx: int):
	var t: Array = _collect_texts()
	if idx < t.size(): t.remove_at(idx); _fill_texts(t)

func _add_text_page():
	var t: Array = _collect_texts(); t.append(""); _fill_texts(t)

func _collect_texts() -> Array:
	var out: Array = []
	for c in _text_pages.get_children():
		for ch in c.get_children():
			var te := ch as TextEdit
			if te: out.append(te.text); break
	return out if out else [""]

func _fill_icon(current: String):
	if _icon_dropdown.item_selected.is_connected(_on_icon_sel):
		_icon_dropdown.item_selected.disconnect(_on_icon_sel)
	_icon_dropdown.clear(); _icon_dropdown.add_item("(None)")
	var found: int = 0
	for ic: String in _icon_map:
		var idx: int = _icon_dropdown.item_count; _icon_dropdown.add_item(ic)
		if ic == current: found = idx
	_icon_dropdown.add_item("Custom...")
	if current != "" and found <= 0:
		_icon_dropdown.set_item_text(_icon_dropdown.item_count - 1, current); found = _icon_dropdown.item_count - 1
	_icon_dropdown.selected = found
	_icon_dropdown.item_selected.connect(_on_icon_sel)

func _icon_value() -> String:
	var idx: int = _icon_dropdown.selected
	if idx <= 0: return ""
	var t: String = _icon_dropdown.get_item_text(idx)
	if t in _icon_map: return t
	if idx == _icon_dropdown.item_count - 1: return t
	return ""

func _on_icon_sel(idx: int):
	if idx == _icon_dropdown.item_count - 1:
		var fd := FileDialog.new()
		fd.file_mode = FileDialog.FILE_MODE_OPEN_FILE; fd.access = FileDialog.ACCESS_RESOURCES
		fd.add_filter("*.png", "Icon PNG")
		fd.file_selected.connect(func(p: String):
			var s: String = p.trim_prefix("res://sprites/npc/").trim_suffix(".png")
			_fill_icon(s))
		fd.title = "Select Icon"; add_child(fd); fd.popup_centered(Vector2i(600, 400))

func _fill_choices(choices: Array):
	for c in _choices_container.get_children(): _choices_container.remove_child(c); c.queue_free()
	for i in choices.size():
		var opt: Dictionary = choices[i]
		var frame := VBoxContainer.new(); frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var h0 := HBoxContainer.new()
		h0.add_child(_mk_btn("x", _del_choice.bind(i)))
		var te := LineEdit.new(); te.placeholder_text = "Choice text..."; te.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_mk_small(te); te.text = opt.get("text", ""); h0.add_child(te); frame.add_child(h0)
		frame.add_child(_labeled_dropdown("next:", opt.get("next", "")))
		var hc := HBoxContainer.new()
		var lc := Label.new(); lc.text = "check:"; hc.add_child(lc)
		var ce := LineEdit.new(); ce.placeholder_text = "skill dc"; ce.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ce.text = opt.get("check", ""); hc.add_child(ce); frame.add_child(hc)
		var hs := HBoxContainer.new()
		var ls := Label.new(); ls.text = "show:"; hs.add_child(ls)
		var se := LineEdit.new(); se.placeholder_text = "check/flag condition"; se.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		se.text = opt.get("show_only_if", ""); hs.add_child(se); frame.add_child(hs)
		var hp := HBoxContainer.new()
		var lp := Label.new(); lp.text = "pass:"; hp.add_child(lp)
		var pe := _node_dropdown(opt.get("next_pass", "")); hp.add_child(pe)
		var lf := Label.new(); lf.text = "fail:"; hp.add_child(lf)
		var fe := _node_dropdown(opt.get("next_fail", "")); hp.add_child(fe); frame.add_child(hp)
		frame.set_meta("te", te); frame.set_meta("ne", frame.get_child(1).get_child(1))
		frame.set_meta("ce", ce); frame.set_meta("se", se)
		frame.set_meta("pe", pe); frame.set_meta("fe", fe)
		_choices_container.add_child(frame)

func _labeled_dropdown(label: String, current: String) -> HBoxContainer:
	var h := HBoxContainer.new()
	var l := Label.new(); l.text = label; h.add_child(l)
	h.add_child(_node_dropdown(current))
	return h

func _node_dropdown(current: String) -> OptionButton:
	var dd := OptionButton.new(); dd.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dd.add_item("(none)")
	var found: int = 0
	for id: String in _dialogue_data:
		var idx: int = dd.item_count; dd.add_item(id)
		if id == current: found = idx
	dd.selected = found
	return dd

func _del_choice(idx: int):
	var ch: Array = _collect_choices()
	if idx < ch.size(): ch.remove_at(idx); _fill_choices(ch)

func _add_choice():
	var ch: Array = _collect_choices()
	var c: Dictionary = {}; c["text"] = ""; ch.append(c)
	_fill_choices(ch)

func _meta_val(frame: Control, key: StringName):
	return frame.get_meta(key) if frame.has_meta(key) else null

func _collect_choices() -> Array:
	var out: Array = []
	for frame in _choices_container.get_children():
		var te: LineEdit = _meta_val(frame, &"te")
		var ne: OptionButton = _meta_val(frame, &"ne")
		var ce: LineEdit = _meta_val(frame, &"ce")
		var se: LineEdit = _meta_val(frame, &"se")
		var pe: OptionButton = _meta_val(frame, &"pe")
		var fe: OptionButton = _meta_val(frame, &"fe")
		var c: Dictionary = {}
		if te and te.text != "": c["text"] = te.text
		if ne: var t: String = ne.get_item_text(ne.selected); if t != "(none)": c["next"] = t
		if ce and ce.text != "": c["check"] = ce.text
		if se and se.text != "": c["show_only_if"] = se.text
		if pe: var pt: String = pe.get_item_text(pe.selected); if pt != "(none)": c["next_pass"] = pt
		if fe: var ft: String = fe.get_item_text(fe.selected); if ft != "(none)": c["next_fail"] = ft
		out.append(c)
	return out

func _fill_actions(actions: Array):
	for c in _actions_container.get_children(): _actions_container.remove_child(c); c.queue_free()
	for i in actions.size():
		var h := HBoxContainer.new(); h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(_mk_btn("x", _del_action.bind(i)))
		var te := LineEdit.new(); te.placeholder_text = "flag key, give item..."; te.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_mk_small(te); te.text = actions[i]; h.add_child(te)
		_actions_container.add_child(h)

func _del_action(idx: int):
	var a: Array = _collect_actions()
	if idx < a.size(): a.remove_at(idx); _fill_actions(a)

func _add_action_row():
	var a: Array = _collect_actions(); a.append(""); _fill_actions(a)

func _collect_actions() -> Array:
	var out: Array = []
	for c in _actions_container.get_children():
		for ch in c.get_children():
			var te := ch as LineEdit
			if te: out.append(te.text); break
	return out

func _load():
	var fd := FileDialog.new()
	fd.file_mode = FileDialog.FILE_MODE_OPEN_FILE; fd.access = FileDialog.ACCESS_RESOURCES
	fd.add_filter("*.json", "Dialogue JSON")
	fd.title = "Load Dialogue"
	fd.file_selected.connect(_load_file)
	add_child(fd); fd.popup_centered(Vector2i(700, 500))

func _load_file(path: String):
	print("=== _load_file: %s ===" % path)
	var raw: String = FileAccess.get_file_as_string(path)
	if raw.is_empty(): print("  empty file"); return
	var data: Dictionary = JSON.parse_string(raw)
	if data == null or data.is_empty(): print("  invalid JSON"); return
	_clear_all()
	_dialogue_name = data.get("name", "")
	_name_edit.text = _dialogue_name
	var count: int = 0
	for key: String in data:
		if key == "name": continue
		var nd: Variant = data[key]
		if typeof(nd) != TYPE_DICTIONARY: continue
		if not nd.has("text") or nd["text"] is String: nd["text"] = [nd.get("text", "")]
		if not nd.has("choices"): nd["choices"] = []
		if not nd.has("icon"): nd["icon"] = ""
		if not nd.has("action"): nd["action"] = []
		_dialogue_data[key] = nd
		_add_graph_node(key)
		count += 1
	print("  loaded %d nodes from %s" % [count, path])
	_reconnect_all()
	_update_status()
	_status_lbl.text = "Loaded %d nodes: %s" % [count, path.get_file()]

static func _clean_node(nd: Dictionary):
	for c in nd.get("choices", []):
		if c.get("text", "").is_empty(): c.erase("text")
		if c.get("check", "").is_empty(): c.erase("check")
		if c.get("show_only_if", "").is_empty(): c.erase("show_only_if")
		if c.get("next", "") == "": c.erase("next")
		if c.get("next_pass", "") == "": c.erase("next_pass")
		if c.get("next_fail", "") == "": c.erase("next_fail")
	var acts: Array = nd.get("action", [])
	acts = acts.filter(func(s): return s is String and not s.is_empty())
	if acts.is_empty(): nd.erase("action")
	else: nd["action"] = acts
	var texts: Array = nd.get("text", [""])
	texts = texts.filter(func(s): return s is String)
	if texts.is_empty(): nd["text"] = [""]
	else: nd["text"] = texts
	if nd.get("icon", "").is_empty(): nd.erase("icon")
	if nd.get("name", "").is_empty(): nd.erase("name")

func _save():
	print("=== _save() ===")
	if _selected_id != "": _collect_inspector()
	_save_all_positions()
	var path: String = _char_file_path()
	var out: Dictionary = {"name": _dialogue_name}
	for id: String in _dialogue_data:
		var nd: Dictionary = _dialogue_data[id].duplicate(true)
		_clean_node(nd)
		out[id] = nd
	var json: String = JSON.stringify(out, "\t")
	# ensure directory exists
	var dir_path: String = path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.make_dir_recursive_absolute(dir_path)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(json); file.close()
		_status_lbl.text = "Saved %d nodes to %s" % [_dialogue_data.size(), path]
		print("  saved %d nodes" % [_dialogue_data.size()])
	else:
		_status_lbl.text = "ERROR: failed to open file for writing"

func _back():
	_save()
	TransitionManager.change_scene("res://scenes/editor/station_editor.tscn")

func _clear_all():
	print("=== _clear_all() ===")
	_selected_id = ""; _hide_inspector()
	_dialogue_data.clear(); _dialogue_name = ""; _name_edit.text = ""
	for id: String in _graph_nodes:
		var gn: GraphNode = _graph_nodes[id]
		_graph_edit.remove_child(gn); gn.queue_free()
	_graph_nodes.clear()
	_update_status()
