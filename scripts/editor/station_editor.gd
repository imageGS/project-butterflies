class_name StationEditor
extends Control

const CELL_SIZE: int = 24
const MAX_UNDO: int = 128

const TOOLS: Array[String] = ["cursor", ".", "#", "O", "D", "L", "E", "I", "@", "N"]
const TOOL_NAMES: Dictionary = {
	"cursor": "Select", ".": "Floor", "#": "Wall", "O": "Window", "D": "Door", "L": "Locked",
	"E": "Exit", "I": "Item", "@": "Enemy", "N": "NPC",
}
const TOOL_COLORS: Dictionary = {
	".": Color(0.18,0.18,0.18), "#": Color(0.45,0.45,0.5), "O": Color(0.3,0.5,0.7),
	"D": Color(0.55,0.37,0.18), "L": Color(0.75,0.18,0.18), "E": Color(0.95,0.75,0.05),
	"I": Color(0.1,0.7,0.1), "@": Color(0.75,0.05,0.05), "N": Color(0.05,0.55,0.75),
}

var _station_data: StationData = null
var _map_grid: Array[Array] = []
var _map_meta: MapMeta = MapMeta.new()
var _grid_width: int = 32
var _grid_height: int = 24
var _current_tool: String = "cursor"
var _draw_exit_marker: bool = true
var _camera_offset: Vector2 = Vector2.ZERO
var _is_dragging: bool = false
var _last_tile_pos: Vector2i = Vector2i(-1, -1)
var _selected_tile: Vector2i = Vector2i(-1, -1)
var _show_grid: bool = true
var _zoom_level: float = 1.0

var _undo_stack: Array = []
var _redo_stack: Array = []
var _fill_start: Vector2i = Vector2i(-1, -1)
var _line_start: Vector2i = Vector2i(-1, -1)
var _rect_start: Vector2i = Vector2i(-1, -1)
var _panning: bool = false
var _pan_start: Vector2 = Vector2.ZERO
var _pan_offset_start: Vector2 = Vector2.ZERO

var _grid_control: Control
var _tool_buttons: Dictionary = {}

func _ready():
	_setup_ui()
	_new_station()
	call_deferred("_fit_to_window")
	get_viewport().size_changed.connect(_fit_to_window)

func _fit_to_window():
	var vs := get_viewport().get_visible_rect().size
	# Adjust minimum sizes based on viewport
	if vs.x < 1000:
		# Compact mode: right panel narrower
		pass
	# Grid fills the area between left and right panels
	_grid_control.offset_left = 125
	_grid_control.offset_right = -280

func _scan_resources(folder: String, extension: String) -> Array[String]:
	var result: Array[String] = []
	var dir := DirAccess.open(folder)
	if not dir:
		return result
	dir.list_dir_begin()
	var file: String = dir.get_next()
	while file != "":
		if not dir.current_is_dir() and file.ends_with(extension):
			result.append(folder.path_join(file))
		file = dir.get_next()
	dir.list_dir_end()
	result.sort()
	return result

func _refresh_station_dropdown():
	if not _exit_target_select:
		return
	var current: String = ""
	if _exit_target_select.selected >= 0:
		current = _exit_target_select.get_item_text(_exit_target_select.selected)
	_exit_target_select.clear()
	var stations: Array[String] = _scan_resources("res://resources/stations", ".tres")
	var selected_idx: int = -1
	for i in stations.size():
		_exit_target_select.add_item(stations[i])
		if stations[i] == current:
			selected_idx = i
	if selected_idx >= 0:
		_exit_target_select.selected = selected_idx

func _on_exit_target_selected(index: int):
	if index < 0:
		return
	var path: String = _exit_target_select.get_item_text(index)
	_exit_target_select.set_meta("target_path", path)

func _get_exit_target_path() -> String:
	if not _exit_target_select:
		return ""
	var idx: int = _exit_target_select.selected
	if idx < 0:
		return _exit_target_select.get_meta("target_path", "") as String
	return _exit_target_select.get_item_text(idx)

func _on_entity_type_changed(index: int):
	_refresh_entity_subtype_dropdown(index)

func _refresh_entity_subtype_dropdown(type_index: int = -1):
	if type_index < 0:
		type_index = _entity_type.selected
	var current: String = ""
	if _entity_subtype.selected >= 0:
		current = _entity_subtype.get_item_text(_entity_subtype.selected)
	_entity_subtype.clear()
	var options: Array[String] = []
	match type_index:
		EntitySpawn.Type.ENEMY:
			options = _scan_resources("res://resources/enemies", ".tres")
			if options.is_empty():
				options = ["bunny", "scav"]
		EntitySpawn.Type.NPC:
			options = _scan_resources("res://dialogues", ".json")
			if options.is_empty():
				options = ["wanderer"]
		EntitySpawn.Type.ITEM:
			options = _scan_resources("res://resources/items", ".tres")
			if options.is_empty():
				options = ["medkit", "canned_food", "bandage"]
		EntitySpawn.Type.OBJECT:
			options = ["rest", "lore", "container"]
	var selected_idx: int = -1
	for i in options.size():
		_entity_subtype.add_item(options[i])
		if options[i] == current:
			selected_idx = i
	if selected_idx >= 0:
		_entity_subtype.selected = selected_idx

func _setup_ui():
	# Top toolbar
	var toolbar := HBoxContainer.new()
	toolbar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	toolbar.offset_bottom = 40
	add_child(toolbar)

	var new_btn := Button.new(); new_btn.text = "New"; new_btn.pressed.connect(_new_station); toolbar.add_child(new_btn)
	var load_btn := Button.new(); load_btn.text = "Load"; load_btn.pressed.connect(_load_station_dialog); toolbar.add_child(load_btn)
	var save_btn := Button.new(); save_btn.text = "Save"; save_btn.pressed.connect(_save_station); toolbar.add_child(save_btn)
	var play_btn := Button.new(); play_btn.text = "Play"; play_btn.pressed.connect(_play_station); toolbar.add_child(play_btn)

	toolbar.add_spacer(false)
	var resize_x := SpinBox.new(); resize_x.min_value = 4; resize_x.max_value = 128; resize_x.value = _grid_width; resize_x.value_changed.connect(_on_resize_x); toolbar.add_child(resize_x)
	var resize_y := SpinBox.new(); resize_y.min_value = 4; resize_y.max_value = 128; resize_y.value = _grid_height; resize_y.value_changed.connect(_on_resize_y); toolbar.add_child(resize_y)
	var resize_btn := Button.new(); resize_btn.text = "Resize"; resize_btn.pressed.connect(_resize_grid); toolbar.add_child(resize_btn)

	# Left tool palette
	var left_panel := VBoxContainer.new()
	left_panel.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	left_panel.offset_top = 45
	left_panel.offset_right = 110
	left_panel.offset_bottom = -10
	add_child(left_panel)

	var tools_label := Label.new(); tools_label.text = "Tools"; left_panel.add_child(tools_label)
	var tools_grid := GridContainer.new()
	tools_grid.columns = 2
	left_panel.add_child(tools_grid)
	for tool: String in TOOLS:
		var btn := Button.new()
		btn.text = tool; btn.tooltip_text = TOOL_NAMES[tool]
		btn.custom_minimum_size = Vector2(36, 26)
		btn.pressed.connect(_select_tool.bind(tool))
		tools_grid.add_child(btn)
		_tool_buttons[tool] = btn
	_highlight_tool()

	var help := Label.new(); help.text = "Alt=pick G=grid Z/Y=undo"
	help.autowrap_mode = 3; help.add_theme_font_size_override("font_size", 10)
	left_panel.add_child(help)
	
	var shape_label := Label.new(); shape_label.text = "Shapes:"; left_panel.add_child(shape_label)
	var shapes := HBoxContainer.new(); left_panel.add_child(shapes)
	var f_btn := Button.new(); f_btn.text = "F"; f_btn.tooltip_text = "Flood Fill"; f_btn.pressed.connect(func(): _current_tool = "FILL"); shapes.add_child(f_btn)
	var l_btn := Button.new(); l_btn.text = "L"; l_btn.tooltip_text = "Line"; l_btn.pressed.connect(func(): _current_tool = "LINE"); shapes.add_child(l_btn)
	var r_btn := Button.new(); r_btn.text = "R"; r_btn.tooltip_text = "Rect"; r_btn.pressed.connect(func(): _current_tool = "RECT"); shapes.add_child(r_btn)

	# Right metadata panel (scrollable)
	var right_scroll := ScrollContainer.new()
	right_scroll.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	right_scroll.offset_top = 45
	right_scroll.offset_left = -280
	right_scroll.offset_right = 0
	right_scroll.offset_bottom = 0
	add_child(right_scroll)

	var right_panel := VBoxContainer.new()
	right_panel.custom_minimum_size = Vector2(260, 0)
	right_scroll.add_child(right_panel)

	var meta_label := Label.new(); meta_label.text = "Station Metadata"; meta_label.add_theme_font_size_override("font_size", 18); right_panel.add_child(meta_label)

	_name_edit = LineEdit.new(); _name_edit.placeholder_text = "Station Name"; right_panel.add_child(_name_edit)

	var map_file_hbox := HBoxContainer.new(); right_panel.add_child(map_file_hbox)
	var map_file_label := Label.new(); map_file_label.text = "Map File:"; map_file_hbox.add_child(map_file_label)
	_map_file_edit = LineEdit.new()
	_map_file_edit.placeholder_text = "res://resources/stations/maps/name.txt"
	_map_file_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_file_hbox.add_child(_map_file_edit)

	_fog_edit = SpinBox.new(); _fog_edit.min_value = 1; _fog_edit.max_value = 50; _fog_edit.step = 0.5; _fog_edit.value = 7.0
	_add_labeled_spin(right_panel, "Fog Distance", _fog_edit)

	_outer_ring_check = CheckBox.new(); _outer_ring_check.text = "Outer Ring"
	right_panel.add_child(_outer_ring_check)

	var tset_label := Label.new(); tset_label.text = "Tileset:"; right_panel.add_child(tset_label)
	_tileset_select = OptionButton.new()
	_tileset_select.item_selected.connect(_on_tileset_selected)
	right_panel.add_child(_tileset_select)
	_refresh_tileset_dropdown()

	_spawn_x = SpinBox.new(); _spawn_x.min_value = 0; _spawn_x.max_value = 127; _spawn_x.value = 1
	_spawn_y = SpinBox.new(); _spawn_y.min_value = 0; _spawn_y.max_value = 127; _spawn_y.value = 1
	_add_labeled_spin(right_panel, "Spawn X", _spawn_x)
	_add_labeled_spin(right_panel, "Spawn Y", _spawn_y)

	_spawn_dir = OptionButton.new()
	for d: String in ["North", "East", "South", "West"]:
		_spawn_dir.add_item(d)
	_spawn_dir.selected = 2
	right_panel.add_child(_spawn_dir)

	# Exit inspector
	var exit_label := Label.new(); exit_label.text = "Exits"; exit_label.add_theme_font_size_override("font_size", 18); right_panel.add_child(exit_label)

	_exit_list = ItemList.new()
	_exit_list.custom_minimum_size = Vector2(0, 120)
	_exit_list.item_selected.connect(_on_exit_selected)
	right_panel.add_child(_exit_list)

	_exit_pos_x = SpinBox.new(); _exit_pos_x.min_value = 0; _exit_pos_x.max_value = 127; _exit_pos_x.value = 0
	_exit_pos_y = SpinBox.new(); _exit_pos_y.min_value = 0; _exit_pos_y.max_value = 127; _exit_pos_y.value = 0
	_add_labeled_spin(right_panel, "Exit X", _exit_pos_x)
	_add_labeled_spin(right_panel, "Exit Y", _exit_pos_y)

	var target_label := Label.new(); target_label.text = "Target Station:"; right_panel.add_child(target_label)
	_exit_target_select = OptionButton.new()
	_exit_target_select.item_selected.connect(_on_exit_target_selected)
	right_panel.add_child(_exit_target_select)
	_refresh_station_dropdown()

	_exit_target_x = SpinBox.new(); _exit_target_x.min_value = -1; _exit_target_x.max_value = 127; _exit_target_x.value = -1
	_exit_target_y = SpinBox.new(); _exit_target_y.min_value = -1; _exit_target_y.max_value = 127; _exit_target_y.value = -1
	_add_labeled_spin(right_panel, "Target Spawn X", _exit_target_x)
	_add_labeled_spin(right_panel, "Target Spawn Y", _exit_target_y)

	_exit_target_dir = OptionButton.new()
	for d: String in ["North", "East", "South", "West", "Default"]:
		_exit_target_dir.add_item(d)
	_exit_target_dir.selected = 4
	right_panel.add_child(_exit_target_dir)

	var exit_apply := Button.new(); exit_apply.text = "Apply Exit"; exit_apply.pressed.connect(_apply_exit); right_panel.add_child(exit_apply)

	# Entity spawns inspector
	var entity_label := Label.new(); entity_label.text = "Entity Spawns"; entity_label.add_theme_font_size_override("font_size", 18); right_panel.add_child(entity_label)

	_entity_list = ItemList.new()
	_entity_list.custom_minimum_size = Vector2(0, 100)
	_entity_list.item_selected.connect(_on_entity_selected)
	right_panel.add_child(_entity_list)

	_entity_type = OptionButton.new()
	for t: String in ["Enemy", "NPC", "Item", "Object"]:
		_entity_type.add_item(t)
	_entity_type.selected = 0
	_entity_type.item_selected.connect(_on_entity_type_changed)
	right_panel.add_child(_entity_type)

	var subtype_label := Label.new(); subtype_label.text = "Subtype:"; right_panel.add_child(subtype_label)
	_entity_subtype = OptionButton.new()
	right_panel.add_child(_entity_subtype)
	_refresh_entity_subtype_dropdown()

	_entity_extra = LineEdit.new(); _entity_extra.placeholder_text = "Extra JSON (optional)"; right_panel.add_child(_entity_extra)

	var entity_apply := Button.new(); entity_apply.text = "Apply Entity"; entity_apply.pressed.connect(_apply_entity); right_panel.add_child(entity_apply)

	# Wall texture override
	var tex_label := Label.new(); tex_label.text = "Wall Override"; tex_label.add_theme_font_size_override("font_size", 16); right_panel.add_child(tex_label)
	_wall_tex_edit = LineEdit.new(); _wall_tex_edit.placeholder_text = "texture_id (e.g. wall_metal)"; right_panel.add_child(_wall_tex_edit)
	var tex_hbox := HBoxContainer.new(); right_panel.add_child(tex_hbox)
	_wall_rot = OptionButton.new()
	for r: String in ["0°", "90°", "180°", "270°"]: _wall_rot.add_item(r)
	tex_hbox.add_child(_wall_rot)
	var tex_apply := Button.new(); tex_apply.text = "Set Texture"; tex_apply.pressed.connect(_apply_wall_texture); tex_hbox.add_child(tex_apply)
	var tex_clear := Button.new(); tex_clear.text = "Clear"; tex_clear.pressed.connect(_clear_wall_texture); tex_hbox.add_child(tex_clear)

	# Decal list
	var dec_label := Label.new(); dec_label.text = "Decals"; dec_label.add_theme_font_size_override("font_size", 16); right_panel.add_child(dec_label)
	_decal_list = ItemList.new(); _decal_list.custom_minimum_size = Vector2(0, 80); right_panel.add_child(_decal_list)
	var dec_hbox := HBoxContainer.new(); right_panel.add_child(dec_hbox)
	_decal_id_edit = LineEdit.new(); _decal_id_edit.placeholder_text = "decal_id"; dec_hbox.add_child(_decal_id_edit)
	_decal_side = OptionButton.new()
	for s: String in ["N", "E", "S", "W"]: _decal_side.add_item(s)
	dec_hbox.add_child(_decal_side)
	_decal_offset = SpinBox.new(); _decal_offset.min_value = 0; _decal_offset.max_value = 1; _decal_offset.step = 0.05; _decal_offset.value = 0.5; dec_hbox.add_child(_decal_offset)
	var dec_add := Button.new(); dec_add.text = "+"; dec_add.pressed.connect(_add_decal); dec_hbox.add_child(dec_add)
	var dec_rem := Button.new(); dec_rem.text = "-"; dec_rem.pressed.connect(_remove_decal); dec_hbox.add_child(dec_rem)

	_status_label = Label.new(); _status_label.text = "Ready"; right_panel.add_child(_status_label)

	# Context menu
	_context_menu = PopupMenu.new()
	_context_menu.add_item("Set Spawn", 0)
	_context_menu.add_item("Add Exit", 1)
	_context_menu.add_item("Add Entity", 2)
	_context_menu.add_item("Remove Exit", 3)
	_context_menu.add_item("Remove Entity", 4)
	_context_menu.add_item("Clear Tile", 5)
	_context_menu.id_pressed.connect(_on_context_menu)
	add_child(_context_menu)

	# Grid control
	_grid_control = Control.new()
	_grid_control.set_anchors_preset(Control.PRESET_FULL_RECT)
	_grid_control.offset_left = 125
	_grid_control.offset_top = 45
	_grid_control.offset_right = -280
	_grid_control.offset_bottom = 0
	_grid_control.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_grid_control)
	_grid_control.draw.connect(_draw_grid)
	_grid_control.gui_input.connect(_on_grid_input)

var _name_edit: LineEdit
var _map_file_edit: LineEdit
var _fog_edit: SpinBox
var _outer_ring_check: CheckBox
var _spawn_x: SpinBox
var _spawn_y: SpinBox
var _spawn_dir: OptionButton

var _exit_list: ItemList
var _exit_pos_x: SpinBox
var _exit_pos_y: SpinBox
var _exit_target_select: OptionButton
var _exit_target_x: SpinBox
var _exit_target_y: SpinBox
var _exit_target_dir: OptionButton
var _selected_exit_index: int = -1

var _entity_list: ItemList
var _entity_type: OptionButton
var _entity_subtype: OptionButton
var _entity_extra: LineEdit
var _selected_entity_index: int = -1

var _status_label: Label
var _context_menu: PopupMenu
var _tileset_select: OptionButton
var _wall_tex_edit: LineEdit
var _wall_rot: OptionButton
var _decal_list: ItemList
var _decal_id_edit: LineEdit
var _decal_side: OptionButton
var _decal_offset: SpinBox

func _add_labeled_spin(parent: Control, label_text: String, spin: SpinBox):
	var hbox := HBoxContainer.new(); parent.add_child(hbox)
	var lbl := Label.new(); lbl.text = label_text; hbox.add_child(lbl)
	spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL; hbox.add_child(spin)

func _new_station():
	_station_data = StationData.new()
	_station_data.station_name = "New Station"
	_station_data.map_file = "res://resources/stations/maps/new_station.txt"
	_station_data.spawn = Vector2i(1, 1)
	_station_data.spawn_dir = 2
	_station_data.fog_distance = 7.0
	_station_data.outer_ring = false
	_grid_width = 32
	_grid_height = 24
	_map_grid = []
	for y in _grid_height:
		var row: Array[String] = []; for x in _grid_width: row.append(".")
		_map_grid.append(row)
	_refresh_ui()
	_grid_control.queue_redraw()

func _load_station_dialog():
	# Dev-only: use FileDialog via code
	var dlg := FileDialog.new()
	dlg.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dlg.access = FileDialog.ACCESS_RESOURCES
	dlg.filters = ["*.tres"]
	dlg.file_selected.connect(_load_station)
	add_child(dlg)
	dlg.popup_centered(Vector2(800, 600))

func _load_station(path: String):
	var res := load(path)
	if not res is StationData:
		_status_label.text = "Not a StationData resource"
		return
	_station_data = res
	_parse_map_file(_station_data.map_file)
	_refresh_ui()
	_grid_control.queue_redraw()
	_status_label.text = "Loaded: " + path

func _parse_map_file(path: String):
	var text: String = FileAccess.get_file_as_string(path)
	var rows: PackedStringArray = text.split("\n", false)
	_map_grid = []
	_grid_height = rows.size()
	_grid_width = 0
	for y in rows.size():
		var line: String = rows[y]
		_grid_width = max(_grid_width, line.length())
		var row: Array[String] = []; for x in line.length(): row.append(line[x])
		_map_grid.append(row)
	for row in _map_grid:
		while row.size() < _grid_width: row.append(".")
	_map_meta = MapMeta.new()
	_map_meta.load_from_json(path.get_basename() + ".meta.json")

func _save_station():
	if not _station_data: return
	_update_station_from_ui()
	_write_map_file(_station_data.map_file)
	_map_meta.save_to_json(_station_data.map_file.get_basename() + ".meta.json")
	var err := ResourceSaver.save(_station_data, _get_tres_path())
	if err == OK:
		_status_label.text = "Saved: " + _get_tres_path()
	else:
		_status_label.text = "Save failed: " + str(err)

func _get_tres_path() -> String:
	var map_path: String = _station_data.map_file
	var base: String = map_path.get_basename().get_file()
	return "res://resources/stations/" + base + ".tres"

func _write_map_file(path: String):
	var file := FileAccess.open(path, FileAccess.WRITE)
	if not file:
		_status_label.text = "Failed to write map file"
		return
	for y in _grid_height:
		var line: String = ""
		for x in _grid_width:
			line += _map_grid[y][x]
		file.store_line(line)
	file.close()

func _play_station():
	_save_station()
	PlayerStats.current_station = _station_data
	TransitionManager.change_scene("res://scenes/dungeon/test_dungeon_mechanics.tscn")

func _update_station_from_ui():
	_station_data.station_name = _name_edit.text
	_station_data.map_file = _map_file_edit.text
	_station_data.fog_distance = _fog_edit.value
	_station_data.outer_ring = _outer_ring_check.button_pressed
	_station_data.spawn = Vector2i(int(_spawn_x.value), int(_spawn_y.value))
	_station_data.spawn_dir = _spawn_dir.selected

func _refresh_ui():
	_name_edit.text = _station_data.station_name
	_map_file_edit.text = _station_data.map_file
	_fog_edit.value = _station_data.fog_distance
	_outer_ring_check.button_pressed = _station_data.outer_ring
	_spawn_x.value = _station_data.spawn.x
	_spawn_y.value = _station_data.spawn.y
	_spawn_dir.selected = _station_data.spawn_dir
	_refresh_exit_list()
	_refresh_entity_list()
	_refresh_tileset_dropdown()

func _refresh_exit_list():
	_exit_list.clear()
	if not _station_data: return
	for i in _station_data.exits.size():
		var e: ExitData = _station_data.exits[i]
		_exit_list.add_item("%d: (%d,%d) -> %s" % [i, e.position.x, e.position.y, e.target_station_path])

func _select_tool(tool: String):
	_current_tool = tool
	_highlight_tool()

func _highlight_tool():
	for tool: String in _tool_buttons:
		_tool_buttons[tool].modulate = Color(1.3, 1.3, 0.6) if tool == _current_tool else Color.WHITE

func _on_resize_x(v: float): _grid_width = int(v)
func _on_resize_y(v: float): _grid_height = int(v)

func _resize_grid():
	var new_grid: Array[Array] = []
	for y in _grid_height:
		var row: Array[String] = []
		for x in _grid_width:
			if y < _map_grid.size() and x < _map_grid[y].size():
				row.append(_map_grid[y][x])
			else:
				row.append(".")
		new_grid.append(row)
	_map_grid = new_grid
	_grid_control.queue_redraw()

func _draw_grid():
	var cs: int = int(CELL_SIZE * _zoom_level)
	if cs < 6: cs = 6
	var offset: Vector2 = _grid_control.size * 0.5 - Vector2(_grid_width * cs, _grid_height * cs) * 0.5 + _camera_offset
	
	var visible_cols: int = int(_grid_control.size.x / cs) + 2
	var visible_rows: int = int(_grid_control.size.y / cs) + 2
	var start_x: int = max(0, int((-offset.x) / cs) - 1)
	var start_y: int = max(0, int((-offset.y) / cs) - 1)
	var end_x: int = min(_grid_width, start_x + visible_cols)
	var end_y: int = min(_grid_height, start_y + visible_rows)
	
	for y in range(start_y, end_y):
		for x in range(start_x, end_x):
			var tile: String = _map_grid[y][x]
			var color: Color = TOOL_COLORS.get(tile, Color.MAGENTA)
			var rect := Rect2(offset.x + x * cs, offset.y + y * cs, cs, cs)
			_grid_control.draw_rect(rect, color)
			if _show_grid: _grid_control.draw_rect(rect, Color(0.3, 0.3, 0.3), false)
			if tile != ".":
				var font := _grid_control.get_theme_default_font()
				if font and cs >= 12:
					var font_size: int = max(8, cs - 4)
					_grid_control.draw_string(font, rect.position + Vector2(2, font_size + 2), tile, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color.WHITE)
			if _map_meta.has_any(x, y):
				_grid_control.draw_rect(Rect2(rect.position.x, rect.position.y, 4, 4), Color(0.3, 0.8, 1.0))

	# Draw entity spawns
	for s: EntitySpawn in _station_data.entity_spawns:
		var sr := Rect2(offset.x + s.position.x * cs, offset.y + s.position.y * cs, cs, cs)
		var sc: Color
		match s.type:
			EntitySpawn.Type.ENEMY: sc = Color(0.9, 0.1, 0.1, 0.5)
			EntitySpawn.Type.NPC: sc = Color(0.1, 0.6, 0.9, 0.5)
			EntitySpawn.Type.ITEM: sc = Color(0.1, 0.9, 0.1, 0.5)
			EntitySpawn.Type.OBJECT: sc = Color(0.7, 0.5, 0.1, 0.5)
		_grid_control.draw_rect(sr, sc)
		_grid_control.draw_rect(sr, Color.WHITE, false)

	# Draw exits
	for e: ExitData in _station_data.exits:
		var er := Rect2(offset.x + e.position.x * cs, offset.y + e.position.y * cs, cs, cs)
		_grid_control.draw_rect(er, Color(1, 0, 1, 0.4))
		_grid_control.draw_rect(er, Color(1, 0, 1), false)

	# Draw spawn
	var spawn_rect := Rect2(offset.x + _station_data.spawn.x * cs, offset.y + _station_data.spawn.y * cs, cs, cs)
	_grid_control.draw_rect(spawn_rect, Color(0, 1, 0, 0.4))
	_grid_control.draw_rect(spawn_rect, Color(0, 1, 0), false)

	# Hover highlight
	if _last_tile_pos.x >= 0 and _last_tile_pos.y >= 0:
		var hr := Rect2(offset.x + _last_tile_pos.x * cs, offset.y + _last_tile_pos.y * cs, cs, cs)
		_grid_control.draw_rect(hr, Color(1, 1, 1, 0.2))

	# Selected tile highlight
	if _selected_tile.x >= 0 and _selected_tile.y >= 0:
		var sr := Rect2(offset.x + _selected_tile.x * cs, offset.y + _selected_tile.y * cs, cs, cs)
		_grid_control.draw_rect(sr, Color(1, 1, 1, 0.35))
		_grid_control.draw_rect(sr, Color(1, 1, 1), false, 2.0)

func _on_grid_input(event: InputEvent):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_level = min(_zoom_level * 1.15, 4.0); _grid_control.queue_redraw()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_level = max(_zoom_level / 1.15, 0.25); _grid_control.queue_redraw()
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			if event.pressed:
				_panning = true; _pan_start = event.position; _pan_offset_start = _camera_offset
			else:
				_panning = false
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if Input.is_key_pressed(KEY_ALT):
					_pick_at_mouse(event.position)
				elif _current_tool == "cursor":
					_select_tile_at_mouse(event.position)
				elif _current_tool == "FILL":
					_start_fill(event.position)
				elif _current_tool == "LINE":
					_start_line(event.position)
				elif _current_tool == "RECT":
					_start_rect(event.position)
				else:
					_push_undo()
					_is_dragging = true
					_paint_at_mouse(event.position)
			else:
				_is_dragging = false
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_select_tile_at_mouse(event.position)
			_open_context_menu(event.position)
	elif event is InputEventMouseMotion:
		_update_last_tile(event.position)
		if _panning:
			_camera_offset = _pan_offset_start + (event.position - _pan_start)
			_grid_control.queue_redraw()
		elif _is_dragging:
			_paint_at_mouse(event.position)

func _select_tile_at_mouse(pos: Vector2):
	_update_last_tile(pos)
	var gx: int = _last_tile_pos.x
	var gy: int = _last_tile_pos.y
	if gx < 0 or gy < 0 or gy >= _grid_height or gx >= _grid_width:
		return
	_selected_tile = Vector2i(gx, gy)
	_grid_control.queue_redraw()
	_refresh_selected_tile_info()

func _open_context_menu(pos: Vector2):
	if _selected_tile.x < 0:
		return
	var has_exit: bool = _station_data.get_exit_at(_selected_tile) != null
	var has_entity: bool = _station_data.get_entity_spawn_at(_selected_tile) != null
	_context_menu.set_item_disabled(3, not has_exit)
	_context_menu.set_item_disabled(4, not has_entity)
	_context_menu.position = _grid_control.global_position + pos
	_context_menu.popup()

func _set_spawn_at_mouse(pos: Vector2):
	var cs: int = int(CELL_SIZE * _zoom_level); if cs < 6: cs = 6
	var offset: Vector2 = _grid_control.size * 0.5 - Vector2(_grid_width * cs, _grid_height * cs) * 0.5 + _camera_offset
	var gx: int = int((pos.x - offset.x) / CELL_SIZE)
	var gy: int = int((pos.y - offset.y) / CELL_SIZE)
	if gx < 0 or gy < 0 or gy >= _grid_height or gx >= _grid_width:
		return
	_station_data.spawn = Vector2i(gx, gy)
	_spawn_x.value = gx
	_spawn_y.value = gy
	_grid_control.queue_redraw()

func _update_last_tile(pos: Vector2):
	var cs: int = int(CELL_SIZE * _zoom_level); if cs < 6: cs = 6
	var offset: Vector2 = _grid_control.size * 0.5 - Vector2(_grid_width * cs, _grid_height * cs) * 0.5 + _camera_offset
	var gx: int = int((pos.x - offset.x) / cs)
	var gy: int = int((pos.y - offset.y) / cs)
	if gx < 0 or gy < 0 or gy >= _grid_height or gx >= _grid_width:
		return
	_last_tile_pos = Vector2i(gx, gy)

func _paint_at_mouse(pos: Vector2):
	_update_last_tile(pos)
	var gx: int = _last_tile_pos.x
	var gy: int = _last_tile_pos.y
	if gx < 0 or gy < 0 or gy >= _grid_height or gx >= _grid_width: return
	if _map_grid[gy][gx] != _current_tool:
		_map_grid[gy][gx] = _current_tool
		_grid_control.queue_redraw()

func _pick_at_mouse(pos: Vector2):
	_update_last_tile(pos)
	var gx: int = _last_tile_pos.x; var gy: int = _last_tile_pos.y
	if gx < 0 or gy < 0 or gy >= _grid_height or gx >= _grid_width: return
	_current_tool = _map_grid[gy][gx]
	_highlight_tool()
	_status_label.text = "Picked: '%s'" % _current_tool

func _start_fill(pos: Vector2):
	_update_last_tile(pos)
	_fill_start = Vector2i(_last_tile_pos.x, _last_tile_pos.y)
	_push_undo()
	var old_ch: String = _map_grid[_fill_start.y][_fill_start.x]
	_flood_fill(_fill_start.x, _fill_start.y, old_ch, _current_tool)

func _start_line(pos: Vector2):
	_update_last_tile(pos)
	if _line_start.x < 0:
		_line_start = Vector2i(_last_tile_pos.x, _last_tile_pos.y); _push_undo()
	else:
		_draw_line(_line_start, Vector2i(_last_tile_pos.x, _last_tile_pos.y), _current_tool)
		_line_start = Vector2i(-1, -1)

func _start_rect(pos: Vector2):
	_update_last_tile(pos)
	if _rect_start.x < 0:
		_rect_start = Vector2i(_last_tile_pos.x, _last_tile_pos.y); _push_undo()
	else:
		_draw_rect(_rect_start, Vector2i(_last_tile_pos.x, _last_tile_pos.y), _current_tool)
		_rect_start = Vector2i(-1, -1)

func _flood_fill(x: int, y: int, old_ch: String, new_ch: String):
	if x < 0 or y < 0 or y >= _grid_height or x >= _grid_width: return
	if _map_grid[y][x] != old_ch: return
	_map_grid[y][x] = new_ch
	_flood_fill(x+1, y, old_ch, new_ch); _flood_fill(x-1, y, old_ch, new_ch)
	_flood_fill(x, y+1, old_ch, new_ch); _flood_fill(x, y-1, old_ch, new_ch)
	_grid_control.queue_redraw()

func _draw_line(a: Vector2i, b: Vector2i, ch: String):
	var dx: int = abs(b.x-a.x); var dy: int = -abs(b.y-a.y)
	var sx: int = 1 if a.x < b.x else -1; var sy_v: int = 1 if a.y < b.y else -1
	var err: int = dx+dy; var cx: int = a.x; var cy: int = a.y
	while true:
		_paint_cell(cx, cy, ch)
		if cx == b.x and cy == b.y: break
		var e2: int = err*2
		if e2 >= dy: err += dy; cx += sx
		if e2 <= dx: err += dx; cy += sy_v

func _draw_rect(a: Vector2i, b: Vector2i, ch: String):
	var x1: int = min(a.x,b.x); var x2: int = max(a.x,b.x)
	var y1: int = min(a.y,b.y); var y2: int = max(a.y,b.y)
	for x: int in range(x1, x2+1): _paint_cell(x, y1, ch); _paint_cell(x, y2, ch)
	for y: int in range(y1, y2+1): _paint_cell(x1, y, ch); _paint_cell(x2, y, ch)

func _paint_cell(x: int, y: int, ch: String):
	if x < 0 or y < 0 or y >= _grid_height or x >= _grid_width: return
	_map_grid[y][x] = ch

func _push_undo():
	var snap: Array = []
	for row: Array in _map_grid: snap.append(row.duplicate())
	_undo_stack.append(snap)
	if _undo_stack.size() > MAX_UNDO: _undo_stack.pop_front()
	_redo_stack.clear()

func _undo():
	if _undo_stack.size() <= 1: return
	_redo_stack.append(_undo_stack.pop_back())
	var snap: Array = _undo_stack.back()
	_map_grid = [] as Array[Array]
	for row: Array in snap: _map_grid.append(row)
	_grid_control.queue_redraw()
	_status_label.text = "Undo"

func _redo():
	if _redo_stack.is_empty(): return
	var snap: Array = _redo_stack.pop_back()
	_undo_stack.append(snap)
	_map_grid = [] as Array[Array]
	for row: Array in snap: _map_grid.append(row)
	_grid_control.queue_redraw()
	_status_label.text = "Redo"

func _add_exit_at_selection():
	var pos: Vector2i
	if _selected_tile.x >= 0:
		pos = _selected_tile
	elif _last_tile_pos.x >= 0:
		pos = _last_tile_pos
	else:
		pos = _station_data.spawn
	# Ensure tile at exit position is marked as Exit
	if pos.y >= 0 and pos.y < _grid_height and pos.x >= 0 and pos.x < _grid_width:
		_map_grid[pos.y][pos.x] = "E"
	# Remove any existing exit at same position
	for i in range(_station_data.exits.size() - 1, -1, -1):
		if _station_data.exits[i].position == pos:
			_station_data.exits.remove_at(i)
	var e := ExitData.new()
	e.position = pos
	e.target_station_path = ""
	_station_data.exits.append(e)
	_selected_exit_index = _station_data.exits.size() - 1
	_refresh_exit_list()
	_exit_list.select(_selected_exit_index)
	_on_exit_selected(_selected_exit_index)
	_grid_control.queue_redraw()
	_status_label.text = "Exit added at (%d, %d)" % [pos.x, pos.y]

func _on_exit_selected(index: int):
	_selected_exit_index = index
	if index < 0 or index >= _station_data.exits.size():
		return
	var e: ExitData = _station_data.exits[index]
	_exit_pos_x.value = e.position.x
	_exit_pos_y.value = e.position.y
	_exit_target_x.value = e.target_spawn.x
	_exit_target_y.value = e.target_spawn.y
	_exit_target_dir.selected = 4 if e.target_dir < 0 else e.target_dir
	_refresh_station_dropdown()
	var target_path: String = e.target_station_path
	var found: bool = false
	for i in _exit_target_select.item_count:
		if _exit_target_select.get_item_text(i) == target_path:
			_exit_target_select.selected = i
			found = true
			break
	if not found:
		_exit_target_select.selected = -1
		_exit_target_select.set_meta("target_path", target_path)

func _apply_exit():
	if _selected_exit_index < 0 or _selected_exit_index >= _station_data.exits.size():
		return
	var e: ExitData = _station_data.exits[_selected_exit_index]
	e.position = Vector2i(int(_exit_pos_x.value), int(_exit_pos_y.value))
	e.target_station_path = _get_exit_target_path()
	e.target_spawn = Vector2i(int(_exit_target_x.value), int(_exit_target_y.value))
	e.target_dir = -1 if _exit_target_dir.selected == 4 else _exit_target_dir.selected
	_refresh_exit_list()
	_grid_control.queue_redraw()

func _remove_selected_exit():
	if _selected_exit_index < 0 or _selected_exit_index >= _station_data.exits.size():
		return
	_station_data.exits.remove_at(_selected_exit_index)
	_selected_exit_index = -1
	_refresh_exit_list()
	_grid_control.queue_redraw()

func _refresh_entity_list():
	_entity_list.clear()
	if not _station_data: return
	for i in _station_data.entity_spawns.size():
		var s: EntitySpawn = _station_data.entity_spawns[i]
		_entity_list.add_item("%d: (%d,%d) %s" % [i, s.position.x, s.position.y, s.display_name()])

func _add_entity_at_selection():
	var pos: Vector2i
	if _selected_tile.x >= 0:
		pos = _selected_tile
	elif _last_tile_pos.x >= 0:
		pos = _last_tile_pos
	else:
		pos = _station_data.spawn
	# Remove existing spawn at same position
	for i in range(_station_data.entity_spawns.size() - 1, -1, -1):
		if _station_data.entity_spawns[i].position == pos:
			_station_data.entity_spawns.remove_at(i)
	var s := EntitySpawn.new()
	s.position = pos
	s.type = _entity_type.selected as EntitySpawn.Type
	var subtype_text: String = ""
	if _entity_subtype.selected >= 0:
		subtype_text = _entity_subtype.get_item_text(_entity_subtype.selected)
	s.subtype = subtype_text
	_station_data.entity_spawns.append(s)
	_selected_entity_index = _station_data.entity_spawns.size() - 1
	_refresh_entity_list()
	_entity_list.select(_selected_entity_index)
	_on_entity_selected(_selected_entity_index)
	_grid_control.queue_redraw()
	_status_label.text = "Entity added at (%d, %d)" % [pos.x, pos.y]

func _on_entity_selected(index: int):
	_selected_entity_index = index
	if index < 0 or index >= _station_data.entity_spawns.size():
		return
	var s: EntitySpawn = _station_data.entity_spawns[index]
	_entity_type.selected = s.type
	_refresh_entity_subtype_dropdown(s.type)
	var subtype: String = s.subtype
	var found: bool = false
	for i in _entity_subtype.item_count:
		if _entity_subtype.get_item_text(i) == subtype:
			_entity_subtype.selected = i
			found = true
			break
	if not found:
		_entity_subtype.selected = -1
	_entity_extra.text = JSON.stringify(s.extra)

func _apply_entity():
	if _selected_entity_index < 0 or _selected_entity_index >= _station_data.entity_spawns.size():
		return
	var s: EntitySpawn = _station_data.entity_spawns[_selected_entity_index]
	s.type = _entity_type.selected as EntitySpawn.Type
	var subtype_text: String = ""
	if _entity_subtype.selected >= 0:
		subtype_text = _entity_subtype.get_item_text(_entity_subtype.selected)
	s.subtype = subtype_text
	var extra_text: String = _entity_extra.text.strip_edges()
	if not extra_text.is_empty():
		var parsed: Variant = JSON.parse_string(extra_text)
		if parsed is Dictionary:
			s.extra = parsed
	_refresh_entity_list()
	_grid_control.queue_redraw()

func _remove_selected_entity():
	if _selected_entity_index < 0 or _selected_entity_index >= _station_data.entity_spawns.size():
		return
	_station_data.entity_spawns.remove_at(_selected_entity_index)
	_selected_entity_index = -1
	_refresh_entity_list()
	_grid_control.queue_redraw()

func _refresh_selected_tile_info():
	if not _station_data: return
	var info: String = "Tile (%d,%d): %s" % [_selected_tile.x, _selected_tile.y, _map_grid[_selected_tile.y][_selected_tile.x]]
	_wall_tex_edit.text = _map_meta.get_texture(_selected_tile.x, _selected_tile.y)
	_wall_rot.selected = _map_meta.get_rotation(_selected_tile.x, _selected_tile.y) / 90
	_refresh_decal_list()
	var ent: EntitySpawn = _station_data.get_entity_spawn_at(_selected_tile)
	if ent: info += " | %s" % ent.display_name()
	var ex: ExitData = _station_data.get_exit_at(_selected_tile)
	if ex: info += " | exit"
	_status_label.text = info

func _on_context_menu(id: int):
	match id:
		0: _set_spawn_at_tile(_selected_tile)
		1: _add_exit_at_selection()
		2: _add_entity_at_selection()
		3: _remove_exit_at_tile(_selected_tile)
		4: _remove_entity_at_tile(_selected_tile)
		5: _clear_tile(_selected_tile)

func _set_spawn_at_tile(pos: Vector2i):
	_station_data.spawn = pos
	_spawn_x.value = pos.x
	_spawn_y.value = pos.y
	_grid_control.queue_redraw()

func _remove_exit_at_tile(pos: Vector2i):
	for i in range(_station_data.exits.size() - 1, -1, -1):
		if _station_data.exits[i].position == pos:
			_station_data.exits.remove_at(i)
	_selected_exit_index = -1
	_refresh_exit_list()
	_grid_control.queue_redraw()
	_status_label.text = "Exit removed at (%d, %d)" % [pos.x, pos.y]

func _remove_entity_at_tile(pos: Vector2i):
	for i in range(_station_data.entity_spawns.size() - 1, -1, -1):
		if _station_data.entity_spawns[i].position == pos:
			_station_data.entity_spawns.remove_at(i)
	_selected_entity_index = -1
	_refresh_entity_list()
	_grid_control.queue_redraw()
	_status_label.text = "Entity removed at (%d, %d)" % [pos.x, pos.y]

func _clear_tile(pos: Vector2i):
	if pos.y >= 0 and pos.y < _grid_height and pos.x >= 0 and pos.x < _grid_width:
		_map_grid[pos.y][pos.x] = "."
	_remove_exit_at_tile(pos)
	_remove_entity_at_tile(pos)
	_grid_control.queue_redraw()
	_status_label.text = "Tile cleared at (%d, %d)" % [pos.x, pos.y]

func _apply_wall_texture():
	if _selected_tile.x < 0: return
	var tex: String = _wall_tex_edit.text.strip_edges()
	var rot: int = _wall_rot.selected * 90
	_map_meta.set_texture(_selected_tile.x, _selected_tile.y, tex, rot)
	_grid_control.queue_redraw()
	_status_label.text = "Texture set: %s rot=%d" % [tex, rot]

func _clear_wall_texture():
	if _selected_tile.x < 0: return
	_map_meta.clear_cell(_selected_tile.x, _selected_tile.y)
	_grid_control.queue_redraw()
	_status_label.text = "Override cleared"

func _add_decal():
	if _selected_tile.x < 0: return
	var did: String = _decal_id_edit.text.strip_edges()
	if did.is_empty(): return
	_map_meta.add_decal(_selected_tile.x, _selected_tile.y, _decal_side.selected, did, float(_decal_offset.value))
	_refresh_decal_list()
	_grid_control.queue_redraw()
	_status_label.text = "Decal added: %s" % did

func _remove_decal():
	if _selected_tile.x < 0: return
	var items: PackedInt32Array = _decal_list.get_selected_items()
	if items.is_empty(): return
	_map_meta.remove_decal(_selected_tile.x, _selected_tile.y, items[0])
	_refresh_decal_list()
	_grid_control.queue_redraw()
	_status_label.text = "Decal removed"

func _refresh_decal_list():
	_decal_list.clear()
	if _selected_tile.x < 0: return
	var decals: Array = _map_meta.get_decals(_selected_tile.x, _selected_tile.y)
	for i in decals.size():
		var d: Dictionary = decals[i]
		var side_names: Array = ["N", "E", "S", "W"]
		_decal_list.add_item("%d: %s id=%s off=%.2f" % [i, side_names[d.get("side", 0)], d.get("id", "?"), d.get("offset", 0.5)])

func _refresh_tileset_dropdown():
	_tileset_select.clear()
	_tileset_select.add_item("(none)")
	var dir := DirAccess.open("res://resources/stations/tilesets")
	if dir:
		dir.list_dir_begin()
		var file := dir.get_next()
		while file != "":
			if file.ends_with(".tres"):
				_tileset_select.add_item(file)
			file = dir.get_next()
		dir.list_dir_end()
	if _station_data and _station_data.tileset:
		var path := _station_data.tileset.resource_path
		var fname := path.get_file()
		for i in _tileset_select.item_count:
			if _tileset_select.get_item_text(i) == fname:
				_tileset_select.selected = i
				break

func _on_tileset_selected(idx: int):
	if idx <= 0:
		_station_data.tileset = null
		return
	var name := _tileset_select.get_item_text(idx)
	var path := "res://resources/stations/tilesets/" + name
	if ResourceLoader.exists(path):
		_station_data.tileset = load(path)
		_status_label.text = "Tileset: " + name

func _input(event: InputEvent):
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1: _select_tool("cursor")
			KEY_2: _select_tool(".")
			KEY_3: _select_tool("#")
			KEY_4: _select_tool("O")
			KEY_5: _select_tool("D")
			KEY_6: _select_tool("L")
			KEY_7: _select_tool("E")
			KEY_8: _select_tool("I")
			KEY_9: _select_tool("@")
			KEY_0: _select_tool("N")
			KEY_G: _show_grid = not _show_grid; _grid_control.queue_redraw()
			KEY_Z:
				if event.ctrl_pressed or event.meta_pressed: _undo()
			KEY_Y:
				if event.ctrl_pressed or event.meta_pressed: _redo()
			KEY_S:
				if event.ctrl_pressed:
					_save_station()

func _process(delta: float):
	if Input.is_key_pressed(KEY_SHIFT):
		if Input.is_key_pressed(KEY_LEFT): _camera_offset.x -= 200 * delta
		if Input.is_key_pressed(KEY_RIGHT): _camera_offset.x += 200 * delta
		if Input.is_key_pressed(KEY_UP): _camera_offset.y -= 200 * delta
		if Input.is_key_pressed(KEY_DOWN): _camera_offset.y += 200 * delta
		_grid_control.queue_redraw()
