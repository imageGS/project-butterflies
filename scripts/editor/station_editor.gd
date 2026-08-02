class_name StationEditor
extends Control

const CELL_SIZE: int = 24
const MAX_UNDO: int = 128

enum Mode { TILES, ENTITIES, STATION }
enum Tool { FLOOR, WALL, COLUMN, DOOR, LOCKED, EXIT, ERASE, FILL, PLACE, CURSOR }

const TILE_TOOLS: Array = [Tool.FLOOR, Tool.WALL, Tool.COLUMN, Tool.DOOR, Tool.LOCKED, Tool.EXIT]
const TOOL_NAMES: Dictionary = {
	Tool.FLOOR: "Floor", Tool.WALL: "Wall", Tool.COLUMN: "Column", Tool.DOOR: "Door",
	Tool.LOCKED: "Locked", Tool.EXIT: "Exit", Tool.ERASE: "Eraser", Tool.FILL: "Fill",
	Tool.PLACE: "Place", Tool.CURSOR: "Select",
}
const TOOL_KEYS: Array[String] = [".", "#", "O", "D", "L", "E"]
const TOOL_COLORS: Dictionary = {
	".": Color(0.18, 0.18, 0.18), "#": Color(0.45, 0.45, 0.5),
	"O": Color(0.45, 0.35, 0.45), "D": Color(0.55, 0.37, 0.18),
	"L": Color(0.75, 0.18, 0.18), "E": Color(0.95, 0.75, 0.05),
}
const TYPE_COLORS: Dictionary = {
	EntitySpawn.Type.ENEMY: Color(0.9, 0.1, 0.1, 0.5),
	EntitySpawn.Type.NPC: Color(0.1, 0.6, 0.9, 0.5),
	EntitySpawn.Type.ITEM: Color(0.1, 0.9, 0.1, 0.5),
	EntitySpawn.Type.OBJECT: Color(0.7, 0.5, 0.1, 0.5),
}
const TYPE_NAMES: Array[String] = ["Enemy", "NPC", "Item", "Object"]

var _station_data: StationData = null
var _map_grid: Array[Array] = []
var _map_meta: MapMeta = MapMeta.new()
var _grid_width: int = 32
var _grid_height: int = 24
var _mode: int = Mode.TILES
var _tool: int = Tool.FLOOR
var _camera_offset: Vector2 = Vector2.ZERO
var _zoom_level: float = 1.0
var _show_grid: bool = true
var _last_tile: Vector2i = Vector2i(-1, -1)
var _selected_tile: Vector2i = Vector2i(-1, -1)
var _selected_entity_index: int = -1
var _selected_exit_index: int = -1
var _palette_template: EntityTemplate = null

var _undo_stack: Array = []
var _redo_stack: Array = []
var _panning: bool = false
var _pan_start: Vector2 = Vector2.ZERO
var _pan_off_start: Vector2 = Vector2.ZERO
var _is_dragging: bool = false

const CACHE_CELL: int = 48
var _grid_cache_tex: ImageTexture
var _cache_hash: int = 0
var _tex_thumb_cache: Dictionary = {}
var _entity_visual_cache: Dictionary = {}
var _visual_options: Array[String] = []
var _visual_options_built: bool = false
var _cached_textures: Array[String] = []
var _textures_built: bool = false

# --- UI refs ---
var _grid_control: Control
var _status_label: Label
var _left_scroll: ScrollContainer
var _left_panel: VBoxContainer
var _mode_buttons: Dictionary = {}
var _tool_grid: GridContainer
var _tool_buttons: Dictionary = {}
var _brush_spin: SpinBox
var _palette_cats: OptionButton
var _palette_list: ItemList
var _insp_scroll: ScrollContainer
var _insp_panel: VBoxContainer

# --- station meta refs ---
var _name_edit: LineEdit
var _map_file_edit: LineEdit
var _fog_edit: SpinBox
var _outer_ring_check: CheckBox
var _is_safe_check: CheckBox
var _time_of_day_spin: SpinBox
var _ceiling_check: CheckBox
var _ceiling_tex_edit: LineEdit
var _spawn_x: SpinBox
var _spawn_y: SpinBox
var _spawn_dir: OptionButton

# --- tileset / floor / recent ---
var _tileset_select: OptionButton
var _tileset_dict: Dictionary = {}
var _floor_tex_select: OptionButton
var _recent_select: OptionButton

# --- tile inspector refs ---
var _insp_coords: Label
var _insp_tile: Label
var _wall_tex_edit: LineEdit
var _wall_rot: OptionButton

# --- exit inspector refs ---
var _exit_target_select: OptionButton
var _exit_target_x: SpinBox
var _exit_target_y: SpinBox
var _exit_target_dir: OptionButton

# --- entity inspector refs ---
var _ent_banner: Label
var _ent_type: OptionButton
var _ent_subtype: OptionButton
var _ent_name: LineEdit
var _ent_desc: LineEdit
var _ent_loot: LineEdit
var _ent_tex_edit: LineEdit
var _ent_tex_pick: OptionButton
var _ent_size: SpinBox
var _ent_ceiling_lift: SpinBox
var _ent_offset_x: SpinBox
var _ent_facing: OptionButton
var _ent_light_on: CheckBox
var _ent_light_radius: SpinBox
var _ent_light_intensity: SpinBox
var _ent_light_color: ColorPickerButton
var _ent_light_height: SpinBox
var _ent_light_world_radius: SpinBox
var _ent_light_flicker: SpinBox
var _ent_light_style: OptionButton
var _ent_extra: LineEdit
var _over_count_label: Label
var _insp_applying: bool = false

func _ready():
	_setup_ui()
	_new_station()
	call_deferred("_fit_to_window")
	get_viewport().size_changed.connect(_fit_to_window)

func _fit_to_window():
	_grid_control.offset_left = 190
	_grid_control.offset_right = -300

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

func _add_labeled_spin(parent: Control, label_text: String, spin: SpinBox):
	var hbox := HBoxContainer.new()
	parent.add_child(hbox)
	var lbl := Label.new()
	lbl.text = label_text
	hbox.add_child(lbl)
	spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(spin)

# ============================= UI BUILD =============================

func _setup_ui():
	_build_top_bar()
	_build_left_panel()
	_build_inspector()
	_build_grid_control()

func _build_top_bar():
	var bar := HBoxContainer.new()
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.offset_bottom = 40
	add_child(bar)

	var new_btn := Button.new(); new_btn.text = "New"; new_btn.pressed.connect(_new_station); bar.add_child(new_btn)
	var load_btn := Button.new(); load_btn.text = "Load"; load_btn.pressed.connect(_load_station_dialog); bar.add_child(load_btn)
	var save_btn := Button.new(); save_btn.text = "Save"; save_btn.pressed.connect(_save_station); bar.add_child(save_btn)
	var play_btn := Button.new(); play_btn.text = "Play"; play_btn.pressed.connect(_play_station); bar.add_child(play_btn)

	bar.add_spacer(false)
	_recent_select = OptionButton.new()
	_recent_select.add_item("Recent:", 0)
	_recent_select.set_item_disabled(0, true)
	_recent_select.item_selected.connect(_on_recent_selected)
	bar.add_child(_recent_select)
	_refresh_recent_dropdown()

	bar.add_spacer(false)
	var resize_x := SpinBox.new(); resize_x.min_value = 4; resize_x.max_value = 128; resize_x.value = _grid_width
	resize_x.value_changed.connect(func(v: float): _grid_width = int(v)); bar.add_child(resize_x)
	var resize_y := SpinBox.new(); resize_y.min_value = 4; resize_y.max_value = 128; resize_y.value = _grid_height
	resize_y.value_changed.connect(func(v: float): _grid_height = int(v)); bar.add_child(resize_y)
	var resize_btn := Button.new(); resize_btn.text = "Resize"; resize_btn.pressed.connect(_resize_grid); bar.add_child(resize_btn)

	bar.add_spacer(false)
	var grid_check := CheckBox.new(); grid_check.text = "Grid"
	grid_check.button_pressed = true
	grid_check.toggled.connect(func(v: bool): _show_grid = v; _grid_control.queue_redraw())
	bar.add_child(grid_check)

	var help := Label.new()
	help.text = "Wheel=zoom  MM drag=pan  Alt=pick  R-click=menu"
	help.add_theme_font_size_override("font_size", 11)
	help.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	bar.add_child(help)

func _build_left_panel():
	_left_scroll = ScrollContainer.new()
	_left_scroll.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	_left_scroll.offset_top = 45
	_left_scroll.offset_right = 185
	_left_scroll.offset_bottom = -10
	add_child(_left_scroll)

	_left_panel = VBoxContainer.new()
	_left_panel.custom_minimum_size = Vector2(170, 0)
	_left_scroll.add_child(_left_panel)

	var mode_row := HBoxContainer.new()
	_left_panel.add_child(mode_row)
	for m in [Mode.TILES, Mode.ENTITIES, Mode.STATION]:
		var btn := Button.new()
		btn.text = ["Tiles", "Entities", "Station"][m]
		btn.toggle_mode = true
		btn.pressed.connect(_set_mode.bind(m))
		mode_row.add_child(btn)
		_mode_buttons[m] = btn
	_set_mode(Mode.TILES)

func _set_mode(m: int):
	if _mode == Mode.STATION and m != Mode.STATION:
		_update_station_from_ui()
	_mode = m
	for k in _mode_buttons:
		_mode_buttons[k].button_pressed = (k == m)
	_rebuild_left_content()
	_rebuild_inspector()
	if _grid_control:
		_grid_control.queue_redraw()

func _rebuild_left_content():
	_tool_buttons.clear()
	for c in _left_panel.get_children():
		c.queue_free()
	var mode_row := HBoxContainer.new()
	_left_panel.add_child(mode_row)
	for m in [Mode.TILES, Mode.ENTITIES, Mode.STATION]:
		var btn := Button.new()
		btn.text = ["Tiles", "Entities", "Station"][m]
		btn.toggle_mode = true
		btn.button_pressed = (_mode == m)
		btn.pressed.connect(_set_mode.bind(m))
		mode_row.add_child(btn)
		_mode_buttons[m] = btn

	match _mode:
		Mode.TILES:
			_build_tiles_left()
		Mode.ENTITIES:
			_build_entities_left()
		Mode.STATION:
			_build_station_left()

func _build_tiles_left():
	var tool_label := Label.new()
	tool_label.text = "Tiles"
	tool_label.add_theme_font_size_override("font_size", 16)
	_left_panel.add_child(tool_label)

	_tool_grid = GridContainer.new()
	_tool_grid.columns = 2
	_left_panel.add_child(_tool_grid)
	_tool_buttons.clear()
	var order: Array = TILE_TOOLS + [Tool.ERASE, Tool.FILL]
	for t: int in order:
		var btn := Button.new()
		btn.text = TOOL_NAMES[t]
		btn.toggle_mode = true
		btn.custom_minimum_size = Vector2(78, 34)
		btn.pressed.connect(_select_tool.bind(t))
		_tool_grid.add_child(btn)
		_tool_buttons[t] = btn
	_select_tool(_tool)

	var brush_label := Label.new(); brush_label.text = "Brush:"; _left_panel.add_child(brush_label)
	_brush_spin = SpinBox.new()
	_brush_spin.min_value = 1; _brush_spin.max_value = 5; _brush_spin.value = 1
	_left_panel.add_child(_brush_spin)

	var walls_btn := Button.new()
	walls_btn.text = "Auto Walls"
	walls_btn.pressed.connect(_auto_walls)
	_left_panel.add_child(walls_btn)

	_tileset_select = OptionButton.new()
	_tileset_select.item_selected.connect(_on_tileset_selected)
	_left_panel.add_child(_tileset_select)
	_refresh_tileset_dropdown()

	_floor_tex_select = OptionButton.new()
	_floor_tex_select.item_selected.connect(_on_floor_tex_selected)
	_left_panel.add_child(_floor_tex_select)
	_refresh_floor_textures()

func _build_entities_left():
	var label := Label.new()
	label.text = "Object Templates"
	label.add_theme_font_size_override("font_size", 16)
	_left_panel.add_child(label)

	var hint := Label.new()
	hint.text = "Выбери объект и кликай по карте.\nПКМ — удалить."
	hint.autowrap_mode = 3
	hint.add_theme_font_size_override("font_size", 10)
	_left_panel.add_child(hint)

	_palette_cats = OptionButton.new()
	_palette_cats.add_item("(all)")
	_palette_cats.item_selected.connect(func(_i): _refresh_palette())
	_left_panel.add_child(_palette_cats)

	_palette_list = ItemList.new()
	_palette_list.custom_minimum_size = Vector2(0, 260)
	_palette_list.item_selected.connect(_on_palette_selected)
	_left_panel.add_child(_palette_list)

	var row := HBoxContainer.new()
	_left_panel.add_child(row)
	var new_btn := Button.new(); new_btn.text = "New"
	new_btn.tooltip_text = "Create a new reusable object"
	new_btn.pressed.connect(_new_template_dialog)
	row.add_child(new_btn)
	var reload_btn := Button.new(); reload_btn.text = "Reload"
	reload_btn.pressed.connect(func(): TemplateLibrary.reload(); _refresh_palette())
	row.add_child(reload_btn)

	_refresh_palette_categories()

func _build_station_left():
	var label := Label.new()
	label.text = "Station Info"
	label.add_theme_font_size_override("font_size", 16)
	_left_panel.add_child(label)

	var info := Label.new()
	info.text = "Параметры станции — в правой панели."
	info.autowrap_mode = 3
	_left_panel.add_child(info)

func _build_inspector():
	_insp_scroll = ScrollContainer.new()
	_insp_scroll.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	_insp_scroll.offset_top = 45
	_insp_scroll.offset_left = -300
	_insp_scroll.offset_right = 0
	_insp_scroll.offset_bottom = 0
	add_child(_insp_scroll)

	_insp_panel = VBoxContainer.new()
	_insp_panel.custom_minimum_size = Vector2(280, 0)
	_insp_scroll.add_child(_insp_panel)

func _build_grid_control():
	_grid_control = Control.new()
	_grid_control.set_anchors_preset(Control.PRESET_FULL_RECT)
	_grid_control.offset_left = 190
	_grid_control.offset_top = 45
	_grid_control.offset_right = -300
	_grid_control.offset_bottom = 0
	_grid_control.mouse_filter = Control.MOUSE_FILTER_PASS
	_grid_control.clip_contents = true
	add_child(_grid_control)
	move_child(_grid_control, 0)
	_grid_control.draw.connect(_draw_grid)
	_grid_control.gui_input.connect(_on_grid_input)

# ============================= INSPECTOR =============================

func _rebuild_inspector():
	if not _insp_panel:
		return
	for c in _insp_panel.get_children():
		c.queue_free()
	_status_label = Label.new()
	match _mode:
		Mode.TILES:
			_build_tile_inspector()
		Mode.ENTITIES:
			_build_entity_inspector()
		Mode.STATION:
			_build_station_inspector()
	# status label at bottom
	var status := Label.new()
	status.text = "Ready"
	status.add_theme_font_size_override("font_size", 11)
	status.autowrap_mode = 3
	_insp_panel.add_child(status)
	_status_label = status

func _build_station_inspector():
	var label := Label.new(); label.text = "Station"; label.add_theme_font_size_override("font_size", 18); _insp_panel.add_child(label)
	_name_edit = LineEdit.new(); _name_edit.placeholder_text = "Station Name"; _insp_panel.add_child(_name_edit)
	var map_h := HBoxContainer.new(); _insp_panel.add_child(map_h)
	_map_file_edit = LineEdit.new(); _map_file_edit.placeholder_text = "res://resources/stations/maps/x.txt"; _map_file_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_h.add_child(_map_file_edit)
	_fog_edit = SpinBox.new(); _fog_edit.min_value = 1; _fog_edit.max_value = 50; _fog_edit.step = 0.5; _fog_edit.value = 7.0
	_add_labeled_spin(_insp_panel, "Fog", _fog_edit)
	_outer_ring_check = CheckBox.new(); _outer_ring_check.text = "Outer Ring"; _insp_panel.add_child(_outer_ring_check)
	_is_safe_check = CheckBox.new(); _is_safe_check.text = "Safe Station"; _insp_panel.add_child(_is_safe_check)
	_time_of_day_spin = SpinBox.new(); _time_of_day_spin.min_value = 0; _time_of_day_spin.max_value = 24; _time_of_day_spin.step = 0.5; _time_of_day_spin.value = 12.0
	_add_labeled_spin(_insp_panel, "Time of Day", _time_of_day_spin)
	_ceiling_check = CheckBox.new(); _ceiling_check.text = "Ceiling"; _insp_panel.add_child(_ceiling_check)
	_ceiling_tex_edit = LineEdit.new(); _ceiling_tex_edit.placeholder_text = "ceiling texture id"; _insp_panel.add_child(_ceiling_tex_edit)
	_spawn_x = SpinBox.new(); _spawn_x.min_value = 0; _spawn_x.max_value = 127; _spawn_x.value = 1
	_add_labeled_spin(_insp_panel, "Spawn X", _spawn_x)
	_spawn_y = SpinBox.new(); _spawn_y.min_value = 0; _spawn_y.max_value = 127; _spawn_y.value = 1
	_add_labeled_spin(_insp_panel, "Spawn Y", _spawn_y)
	_spawn_dir = OptionButton.new()
	for d: String in ["North", "East", "South", "West"]: _spawn_dir.add_item(d)
	_spawn_dir.selected = 2
	_insp_panel.add_child(_spawn_dir)
	_refresh_ui()

func _build_tile_inspector():
	var label := Label.new(); label.text = "Selected Tile"; label.add_theme_font_size_override("font_size", 18); _insp_panel.add_child(label)
	_insp_coords = Label.new(); _insp_panel.add_child(_insp_coords)
	_insp_tile = Label.new(); _insp_panel.add_child(_insp_tile)

	var tex_h := HBoxContainer.new(); _insp_panel.add_child(tex_h)
	_wall_tex_edit = LineEdit.new(); _wall_tex_edit.placeholder_text = "texture id"; _wall_tex_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tex_h.add_child(_wall_tex_edit)
	_wall_rot = OptionButton.new()
	for d in [0, 90, 180, 270]: _wall_rot.add_item(str(d))
	tex_h.add_child(_wall_rot)

	var btns := HBoxContainer.new(); _insp_panel.add_child(btns)
	var apply := Button.new(); apply.text = "Tex"; apply.pressed.connect(_apply_wall_texture); btns.add_child(apply)
	var clear_tex := Button.new(); clear_tex.text = "Clear"; clear_tex.pressed.connect(_clear_wall_texture); btns.add_child(clear_tex)
	var set_spawn := Button.new(); set_spawn.text = "Spawn"; set_spawn.pressed.connect(func(): _set_spawn_at_tile(_selected_tile)); btns.add_child(set_spawn)
	var clear_tile := Button.new(); clear_tile.text = "Clear Tile"; clear_tile.pressed.connect(func(): _clear_tile(_selected_tile)); btns.add_child(clear_tile)

	_build_exit_section()
	_refresh_selected_tile_info()

func _build_exit_section():
	var exit_label := Label.new(); exit_label.text = "Exit"; exit_label.add_theme_font_size_override("font_size", 16); _insp_panel.add_child(exit_label)
	var hint := Label.new(); hint.text = "Кликни " + TOOL_NAMES[Tool.EXIT] + ", чтобы добавить выход."
	hint.add_theme_font_size_override("font_size", 10); _insp_panel.add_child(hint)
	var target_label := Label.new(); target_label.text = "Target Station:"; _insp_panel.add_child(target_label)
	_exit_target_select = OptionButton.new()
	_exit_target_select.item_selected.connect(_on_exit_target_selected)
	_insp_panel.add_child(_exit_target_select)
	_refresh_station_dropdown()
	_exit_target_x = SpinBox.new(); _exit_target_x.min_value = -1; _exit_target_x.max_value = 127; _exit_target_x.value = -1
	_add_labeled_spin(_insp_panel, "Spawn X", _exit_target_x)
	_exit_target_y = SpinBox.new(); _exit_target_y.min_value = -1; _exit_target_y.max_value = 127; _exit_target_y.value = -1
	_add_labeled_spin(_insp_panel, "Spawn Y", _exit_target_y)
	_exit_target_dir = OptionButton.new()
	for d: String in ["North", "East", "South", "West", "Default"]: _exit_target_dir.add_item(d)
	_exit_target_dir.selected = 4
	_insp_panel.add_child(_exit_target_dir)
	var apply_exit := Button.new(); apply_exit.text = "Apply Exit"; apply_exit.pressed.connect(_apply_exit); _insp_panel.add_child(apply_exit)
	var remove_exit := Button.new(); remove_exit.text = "Remove Exit"; remove_exit.pressed.connect(_remove_selected_exit); _insp_panel.add_child(remove_exit)

func _build_entity_inspector():
	var label := Label.new(); label.text = "Entities"; label.add_theme_font_size_override("font_size", 18); _insp_panel.add_child(label)

	if _selected_entity_index < 0 or _selected_entity_index >= _station_data.entity_spawns.size():
		var hint := Label.new()
		hint.text = "Выбери объект в палитре слева и кликай по карте.\nИли кликни по уже размещённому объекту."
		hint.autowrap_mode = 3
		_insp_panel.add_child(hint)
		return

	_insp_applying = true

	var s: EntitySpawn = _station_data.entity_spawns[_selected_entity_index]
	var resolved: EntitySpawn = TemplateLibrary.resolve_spawn(s)

	if not s.template_id.is_empty():
		var t: EntityTemplate = TemplateLibrary.get_template(s.template_id)
		var banner := Label.new()
		banner.text = "Linked: %s\n(id: %s)" % [t.display_name if t else s.template_id, s.template_id]
		banner.autowrap_mode = 3
		banner.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))
		_insp_panel.add_child(banner)
		var brow := HBoxContainer.new(); _insp_panel.add_child(brow)
		var edit_btn := Button.new(); edit_btn.text = "Edit template"; edit_btn.pressed.connect(_edit_template_dialog); brow.add_child(edit_btn)
		var detach_btn := Button.new(); detach_btn.text = "Detach"; detach_btn.pressed.connect(_detach_entity); brow.add_child(detach_btn)
		var reset_btn := Button.new(); reset_btn.text = "Reset"; reset_btn.pressed.connect(_reset_overrides); brow.add_child(reset_btn)
		var over_count: int = s.overrides.size()
		_over_count_label = Label.new()
		_over_count_label.text = "Overrides: %d" % over_count
		_insp_panel.add_child(_over_count_label)
	else:
		var banner := Label.new(); banner.text = "Standalone (no template)"; banner.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7)); _insp_panel.add_child(banner)
		var brow := HBoxContainer.new(); _insp_panel.add_child(brow)
		var save_btn := Button.new(); save_btn.text = "Save as template"; save_btn.pressed.connect(_save_as_template_dialog); brow.add_child(save_btn)

	var pos_label := Label.new()
	pos_label.text = "Pos: (%d, %d)" % [s.position.x, s.position.y]
	_insp_panel.add_child(pos_label)

	_ent_type = OptionButton.new()
	for t: String in TYPE_NAMES: _ent_type.add_item(t)
	_ent_type.selected = resolved.type
	_ent_type.item_selected.connect(_on_ent_type_changed)
	_insp_panel.add_child(_ent_type)

	_ent_subtype = OptionButton.new()
	_refresh_subtype_options(resolved.type)
	var sf: bool = false
	for i in _ent_subtype.item_count:
		if _ent_subtype.get_item_text(i) == resolved.subtype:
			_ent_subtype.selected = i
			sf = true
	if not sf:
		_ent_subtype.selected = -1
	_ent_subtype.item_selected.connect(_apply_entity.bind(false))
	_insp_panel.add_child(_ent_subtype)

	_ent_extra = LineEdit.new(); _ent_extra.placeholder_text = "Extra JSON (optional)"; _insp_panel.add_child(_ent_extra)
	_ent_extra.text_changed.connect(_on_extra_changed)
	_ent_extra.focus_exited.connect(_apply_entity.bind(false))
	_ent_name = LineEdit.new(); _ent_name.placeholder_text = "Name"; _insp_panel.add_child(_ent_name)
	_ent_name.text_changed.connect(_apply_entity.bind(false))
	_ent_desc = LineEdit.new(); _ent_desc.placeholder_text = "Description"; _insp_panel.add_child(_ent_desc)
	_ent_desc.text_changed.connect(_apply_entity.bind(false))
	_ent_loot = LineEdit.new(); _ent_loot.placeholder_text = "Loot ids (comma-separated)"; _insp_panel.add_child(_ent_loot)
	_ent_loot.text_changed.connect(_apply_entity.bind(false))

	var tex_h := HBoxContainer.new(); _insp_panel.add_child(tex_h)
	_ent_tex_edit = LineEdit.new(); _ent_tex_edit.placeholder_text = "sprites/entity/tv"; _ent_tex_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ent_tex_edit.text_changed.connect(_apply_entity.bind(false))
	tex_h.add_child(_ent_tex_edit)
	_ent_tex_pick = OptionButton.new(); _ent_tex_pick.add_item("(pick)", 0); _ent_tex_pick.set_item_disabled(0, true)
	_ent_tex_pick.item_selected.connect(_on_ent_tex_picked)
	tex_h.add_child(_ent_tex_pick)
	_build_visual_options()

	var siz_h := HBoxContainer.new(); _insp_panel.add_child(siz_h)
	_ent_size = SpinBox.new(); _ent_size.min_value = 0.05; _ent_size.max_value = 2.0; _ent_size.step = 0.05; _ent_size.value = 0.3
	_ent_size.value_changed.connect(_apply_entity.bind(false))
	siz_h.add_child(_ent_size)
	_ent_ceiling_lift = SpinBox.new(); _ent_ceiling_lift.min_value = 0.0; _ent_ceiling_lift.max_value = 2.0; _ent_ceiling_lift.step = 0.05; _ent_ceiling_lift.value = 0.0
	_ent_ceiling_lift.value_changed.connect(_apply_entity.bind(false))
	siz_h.add_child(_ent_ceiling_lift)
	_ent_offset_x = SpinBox.new(); _ent_offset_x.min_value = -1.0; _ent_offset_x.max_value = 1.0; _ent_offset_x.step = 0.1; _ent_offset_x.value = 0.0
	_ent_offset_x.value_changed.connect(_apply_entity.bind(false))
	siz_h.add_child(_ent_offset_x)
	_ent_facing = OptionButton.new()
	for d: String in ["F:N", "F:E", "F:S", "F:W"]: _ent_facing.add_item(d)
	_ent_facing.selected = clamp(resolved.facing, 0, 3)
	_ent_facing.item_selected.connect(_apply_entity.bind(false))
	_insp_panel.add_child(_ent_facing)

	_ent_light_on = CheckBox.new(); _ent_light_on.text = "Light Source"; _insp_panel.add_child(_ent_light_on)
	_ent_light_on.toggled.connect(_apply_entity.bind(false))
	_ent_light_radius = SpinBox.new(); _ent_light_radius.min_value = 0; _ent_light_radius.max_value = 2000; _ent_light_radius.step = 10; _ent_light_radius.value = 150
	_ent_light_radius.value_changed.connect(_apply_entity.bind(false))
	_add_labeled_spin(_insp_panel, "Radius", _ent_light_radius)
	_ent_light_intensity = SpinBox.new(); _ent_light_intensity.min_value = 0.0; _ent_light_intensity.max_value = 2.0; _ent_light_intensity.step = 0.05; _ent_light_intensity.value = 0.6
	_ent_light_intensity.value_changed.connect(_apply_entity.bind(false))
	_add_labeled_spin(_insp_panel, "Intensity", _ent_light_intensity)
	var lcol_h := HBoxContainer.new(); _insp_panel.add_child(lcol_h)
	_ent_light_color = ColorPickerButton.new(); _ent_light_color.color = Color(1.0, 0.6, 0.3); lcol_h.add_child(_ent_light_color)
	_ent_light_color.color_changed.connect(_apply_entity.bind(false))
	_ent_light_height = SpinBox.new(); _ent_light_height.min_value = 0.0; _ent_light_height.max_value = 2.0; _ent_light_height.step = 0.05; _ent_light_height.value = 0.2
	_ent_light_height.value_changed.connect(_apply_entity.bind(false))
	lcol_h.add_child(_ent_light_height)
	_ent_light_world_radius = SpinBox.new(); _ent_light_world_radius.min_value = 0.5; _ent_light_world_radius.max_value = 20.0; _ent_light_world_radius.step = 0.5; _ent_light_world_radius.value = 2.0
	_ent_light_world_radius.value_changed.connect(_apply_entity.bind(false))
	_add_labeled_spin(_insp_panel, "World Radius", _ent_light_world_radius)
	_ent_light_flicker = SpinBox.new(); _ent_light_flicker.min_value = 0.0; _ent_light_flicker.max_value = 0.5; _ent_light_flicker.step = 0.01; _ent_light_flicker.value = 0.0
	_ent_light_flicker.value_changed.connect(_apply_entity.bind(false))
	_add_labeled_spin(_insp_panel, "Flicker", _ent_light_flicker)
	_ent_light_style = OptionButton.new()
	for s_name: String in ["", "fluorescent", "candle", "alarm"]: _ent_light_style.add_item(s_name)
	_ent_light_style.item_selected.connect(_apply_entity.bind(false))
	_insp_panel.add_child(_ent_light_style)

	var remove := Button.new(); remove.text = "Remove"; remove.pressed.connect(_remove_selected_entity); _insp_panel.add_child(remove)
	var hint_auto := Label.new()
	hint_auto.text = "Изменения сохраняются автоматически"
	hint_auto.add_theme_font_size_override("font_size", 10)
	hint_auto.add_theme_color_override("font_color", Color(0.5, 0.6, 0.5))
	_insp_panel.add_child(hint_auto)

	# Load resolved values into fields
	_ent_extra.text = JSON.stringify(resolved.extra)
	_ent_name.text = resolved.extra.get("name", "")
	_ent_desc.text = resolved.extra.get("description", "")
	var loot_arr: Array = resolved.extra.get("loot", [])
	var loot_str := ""
	for li in loot_arr:
		loot_str += (", " if not loot_str.is_empty() else "") + str(li)
	_ent_loot.text = loot_str
	_ent_tex_edit.text = resolved.texture
	_ent_size.value = resolved.size
	_ent_ceiling_lift.value = resolved.ceiling_lift
	_ent_offset_x.value = resolved.visual_offset_x
	var lc: Dictionary = resolved.light_source
	_ent_light_on.button_pressed = not lc.is_empty()
	if lc.has("radius"): _ent_light_radius.value = lc["radius"]
	if lc.has("intensity"): _ent_light_intensity.value = lc["intensity"]
	if lc.has("color"): _ent_light_color.color = lc["color"]
	if lc.has("height"): _ent_light_height.value = lc["height"]
	if lc.has("world_radius"): _ent_light_world_radius.value = lc["world_radius"]
	if lc.has("flicker"): _ent_light_flicker.value = lc["flicker"]
	_ent_light_style.selected = _light_style_index(lc.get("style", ""))

	_insp_applying = false

# ============================= STATION / SAVE =============================

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
		var row: Array[String] = []
		for x in _grid_width: row.append(".")
		_map_grid.append(row)
	_selected_entity_index = -1
	_selected_exit_index = -1
	_palette_template = null
	_refresh_ui()
	_rebuild_inspector()
	_grid_control.queue_redraw()

func _load_station_dialog():
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
	_selected_entity_index = -1
	_selected_exit_index = -1
	_palette_template = null
	_refresh_ui()
	_rebuild_inspector()
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
		var row: Array[String] = []
		for x in line.length(): row.append(line[x])
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
	var base: String = _station_data.map_file.get_basename().get_file()
	return "res://resources/stations/" + base + ".tres"

func _write_map_file(path: String):
	var file := FileAccess.open(path, FileAccess.WRITE)
	if not file:
		_status_label.text = "Failed to write map file"
		return
	for y in _grid_height:
		var line := ""
		for x in _grid_width:
			line += _map_grid[y][x]
		file.store_line(line)
	file.close()

func _play_station():
	_save_station()
	PlayerStats.current_station = _station_data
	TransitionManager.change_scene("res://scenes/dungeon/dungeon_gameplay.tscn")

func _update_station_from_ui():
	if not _station_data:
		return
	_station_data.station_name = _name_edit.text if _name_edit else _station_data.station_name
	_station_data.map_file = _map_file_edit.text if _map_file_edit else _station_data.map_file
	_station_data.fog_distance = _fog_edit.value if _fog_edit else _station_data.fog_distance
	_station_data.outer_ring = _outer_ring_check.button_pressed if _outer_ring_check else _station_data.outer_ring
	_station_data.is_safe = _is_safe_check.button_pressed if _is_safe_check else _station_data.is_safe
	_station_data.time_of_day = _time_of_day_spin.value if _time_of_day_spin else _station_data.time_of_day
	_station_data.ceiling_enabled = _ceiling_check.button_pressed if _ceiling_check else _station_data.ceiling_enabled
	_station_data.ceiling_texture = _ceiling_tex_edit.text.strip_edges() if _ceiling_tex_edit else _station_data.ceiling_texture
	_station_data.spawn = Vector2i(int(_spawn_x.value), int(_spawn_y.value)) if _spawn_x else _station_data.spawn
	_station_data.spawn_dir = _spawn_dir.selected if _spawn_dir else _station_data.spawn_dir

func _refresh_ui():
	if _name_edit:
		_name_edit.text = _station_data.station_name
		_map_file_edit.text = _station_data.map_file
		_fog_edit.value = _station_data.fog_distance
		_outer_ring_check.button_pressed = _station_data.outer_ring
		_is_safe_check.button_pressed = _station_data.is_safe
		_time_of_day_spin.value = _station_data.time_of_day
		_ceiling_check.button_pressed = _station_data.ceiling_enabled
		_ceiling_tex_edit.text = _station_data.ceiling_texture
		_spawn_x.value = _station_data.spawn.x
		_spawn_y.value = _station_data.spawn.y
		_spawn_dir.selected = _station_data.spawn_dir

func _on_recent_selected(index: int):
	var text: String = _recent_select.get_item_text(index)
	if text.is_empty() or text == "Recent:":
		return
	_load_station(text)

func _refresh_recent_dropdown():
	if not _recent_select: return
	for s in _scan_resources("res://resources/stations", ".tres"):
		_recent_select.add_item(s)

func _on_tileset_selected(idx: int):
	if idx <= 0:
		_tileset_dict.clear()
		return
	var name := _tileset_select.get_item_text(idx)
	var path := "res://resources/stations/tilesets/" + name
	if ResourceLoader.exists(path):
		var res = load(path)
		_tileset_dict = res if res is Dictionary else {"wall_tex": res}
		_status_label.text = "Tileset: " + name

func _refresh_tileset_dropdown():
	if not _tileset_select: return
	_tileset_select.clear()
	_tileset_select.add_item("(no tileset)")
	var dir := DirAccess.open("res://resources/stations/tilesets")
	if dir:
		dir.list_dir_begin()
		var file := dir.get_next()
		while file != "":
			if file.ends_with(".tres"):
				_tileset_select.add_item(file)
			file = dir.get_next()
		dir.list_dir_end()

func _refresh_floor_textures():
	if not _floor_tex_select: return
	_floor_tex_select.clear()
	_floor_tex_select.add_item("Floor: (default)")
	var dir := DirAccess.open("res://assets/textures/floor")
	if not dir: return
	dir.list_dir_begin()
	var f := dir.get_next()
	while f != "":
		if f.ends_with(".png") and not f.ends_with(".import"):
			_floor_tex_select.add_item("Floor: " + f)
		f = dir.get_next()
	dir.list_dir_end()

func _on_floor_tex_selected(idx: int):
	if not _floor_tex_select or idx < 0: return
	var item: String = _floor_tex_select.get_item_text(idx)
	var name: String = item.trim_prefix("Floor: ")
	if name.is_empty() or name == "(default)":
		_map_meta.cells.erase("_floor_")
		_status_label.text = "Floor: default"
		return
	_map_meta.cells["_floor_"] = {"texture": "floor/" + name}
	_status_label.text = "Floor: " + name
	_grid_control.queue_redraw()

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

func _auto_walls():
	_push_undo()
	for x in _grid_width:
		_map_grid[0][x] = "#"
		_map_grid[_grid_height - 1][x] = "#"
	for y in _grid_height:
		_map_grid[y][0] = "#"
		_map_grid[y][_grid_width - 1] = "#"
	_grid_control.queue_redraw()

# ============================= TOOLS =============================

func _select_tool(t: int):
	_tool = t
	if _tool_buttons.is_empty():
		return
	for k in _tool_buttons:
		if is_instance_valid(_tool_buttons[k]):
			_tool_buttons[k].button_pressed = (k == t)

func _on_palette_selected(index: int):
	if index < 0 or index >= _palette_list.item_count:
		return
	var id: String = _palette_list.get_item_metadata(index)
	_palette_template = TemplateLibrary.get_template(id)
	_select_tool(Tool.PLACE)
	_status_label.text = "Object: " + (_palette_template.display_name if _palette_template else "none")

func _refresh_palette_categories():
	if not _palette_cats: return
	_palette_cats.clear()
	_palette_cats.add_item("(all)")
	for cat in TemplateLibrary.get_categories():
		_palette_cats.add_item(cat)
	_palette_cats.selected = 0
	_refresh_palette()

func _refresh_palette():
	if not _palette_list: return
	_palette_list.clear()
	var cat: String = ""
	if _palette_cats and _palette_cats.selected >= 0:
		cat = _palette_cats.get_item_text(_palette_cats.selected)
	var list: Array = TemplateLibrary.get_by_category(cat) if not cat.is_empty() and cat != "(all)" else TemplateLibrary.get_all()
	for t: EntityTemplate in list:
		var idx := _palette_list.add_item(t.display_name)
		var thumb: Texture2D = _template_thumbnail(t)
		if thumb:
			var img: Image = thumb.get_image()
			if img:
				img.resize(48, 48, Image.INTERPOLATE_NEAREST)
				_palette_list.set_item_icon(idx, ImageTexture.create_from_image(img))
		_palette_list.set_item_metadata(idx, t.id)
	if _palette_template:
		var pid: String = _palette_template.id
		for i in _palette_list.item_count:
			if _palette_list.get_item_metadata(i) == pid:
				_palette_list.select(i)
				break

func _template_thumbnail(t: EntityTemplate) -> Texture2D:
	var tid: String = t.get_state_texture()
	if tid.is_empty():
		return null
	return _load_visual_tex(tid)

func _load_visual_tex(tid: String) -> Texture2D:
	if _entity_visual_cache.has(tid):
		return _entity_visual_cache[tid]
	var tex: Texture2D = null
	if tid.ends_with(".png"):
		tex = load("res://" + tid) as Texture2D
	else:
		var base := ("res://" + tid).trim_suffix("/")
		var dir := DirAccess.open(base)
		if dir:
			var fallback: Texture2D = null
			dir.list_dir_begin()
			var f := dir.get_next()
			while f != "":
				if not dir.current_is_dir() and f.ends_with(".png"):
					var t := load(base + "/" + f) as Texture2D
					if not fallback: fallback = t
					if f.contains("front") and not f.contains("side"):
						tex = t
						break
				f = dir.get_next()
			dir.list_dir_end()
			if not tex:
				tex = fallback
	_entity_visual_cache[tid] = tex
	return tex

# ============================= GRID / DRAW =============================

func _draw_grid():
	var cs: int = int(CELL_SIZE * _zoom_level)
	if cs < 6: cs = 6
	var offset: Vector2 = _grid_control.size * 0.5 - Vector2(_grid_width * cs, _grid_height * cs) * 0.5 + _camera_offset

	if _grid_cache_tex == null or _cache_hash != _current_map_hash():
		_render_grid_cache()
	if _grid_cache_tex:
		_grid_control.draw_texture_rect(_grid_cache_tex, Rect2(offset, Vector2(_grid_width * cs, _grid_height * cs)), false)

	if _show_grid:
		var gcol := Color(0.3, 0.3, 0.3)
		var grid_w: float = _grid_width * cs
		var grid_h: float = _grid_height * cs
		for x in range(_grid_width + 1):
			var px: float = offset.x + x * cs
			_grid_control.draw_line(Vector2(px, offset.y), Vector2(px, offset.y + grid_h), gcol)
		for y in range(_grid_height + 1):
			var py: float = offset.y + y * cs
			_grid_control.draw_line(Vector2(offset.x, py), Vector2(offset.x + grid_w, py), gcol)

	var visible_cols: int = int(_grid_control.size.x / cs) + 2
	var visible_rows: int = int(_grid_control.size.y / cs) + 2
	var start_x: int = max(0, int((-offset.x) / cs) - 1)
	var start_y: int = max(0, int((-offset.y) / cs) - 1)
	var end_x: int = min(_grid_width, start_x + visible_cols)
	var end_y: int = min(_grid_height, start_y + visible_rows)

	for y in range(start_y, end_y):
		for x in range(start_x, end_x):
			var tile: String = _map_grid[y][x]
			var rect := Rect2(offset.x + x * cs, offset.y + y * cs, cs, cs)
			if tile != ".":
				var font := _grid_control.get_theme_default_font()
				if font and cs >= 12:
					var font_size: int = max(8, cs - 4)
					_grid_control.draw_string(font, rect.position + Vector2(3, font_size + 3), tile, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color.BLACK)
					_grid_control.draw_string(font, rect.position + Vector2(2, font_size + 2), tile, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color.WHITE)
			if _map_meta.has_any(x, y):
				_grid_control.draw_rect(Rect2(rect.position.x, rect.position.y, 4, 4), Color(0.3, 0.8, 1.0))

	# Entities
	if _station_data:
		for i in _station_data.entity_spawns.size():
			var s: EntitySpawn = _station_data.entity_spawns[i]
			var sr := Rect2(offset.x + s.position.x * cs, offset.y + s.position.y * cs, cs, cs)
			var sc: Color = TYPE_COLORS.get(s.type, Color(0.5, 0.5, 0.5, 0.5))
			var resolved: EntitySpawn = TemplateLibrary.resolve_spawn(s)
			if not resolved.light_source.is_empty():
				var wr: float = resolved.light_source.get("world_radius", resolved.light_source.get("radius", 150.0) * 0.01)
				var center := sr.get_center()
				var rpx: float = wr * cs
				_grid_control.draw_circle(center, rpx, Color(1, 1, 0.4, 0.06))
				_grid_control.draw_arc(center, rpx, 0, TAU, 48, Color(1, 1, 0.4, 0.55), 1.5, true)
			var etex: Texture2D = _load_visual_tex(resolved.texture) if not resolved.texture.is_empty() else null
			if etex:
				var aspect: float = etex.get_width() / float(max(etex.get_height(), 1))
				var dw: float = cs * 0.9
				var dh: float = dw / aspect
				var drect := Rect2(sr.position.x + (cs - dw) * 0.5, sr.position.y + (cs - dh) * 0.5, dw, dh)
				_grid_control.draw_texture_rect(etex, drect, false)
			else:
				_grid_control.draw_rect(sr, sc)
			if i == _selected_entity_index:
				_grid_control.draw_rect(sr, Color(1, 1, 0, 1), false, 2.0)
			else:
				_grid_control.draw_rect(sr, Color.WHITE, false)

	# Exits
	if _station_data:
		for e: ExitData in _station_data.exits:
			var er := Rect2(offset.x + e.position.x * cs, offset.y + e.position.y * cs, cs, cs)
			_grid_control.draw_rect(er, Color(1, 0, 1, 0.4))
			_grid_control.draw_rect(er, Color(1, 0, 1), false)

	# Spawn
	if _station_data:
		var spawn_rect := Rect2(offset.x + _station_data.spawn.x * cs, offset.y + _station_data.spawn.y * cs, cs, cs)
		_grid_control.draw_rect(spawn_rect, Color(0, 1, 0, 0.4))
		_grid_control.draw_rect(spawn_rect, Color(0, 1, 0), false)

	# Hover / selection
	if _last_tile.x >= 0 and _last_tile.y >= 0:
		var hr := Rect2(offset.x + _last_tile.x * cs, offset.y + _last_tile.y * cs, cs, cs)
		_grid_control.draw_rect(hr, Color(1, 1, 1, 0.2))
	if _selected_tile.x >= 0 and _selected_tile.y >= 0:
		var st := Rect2(offset.x + _selected_tile.x * cs, offset.y + _selected_tile.y * cs, cs, cs)
		_grid_control.draw_rect(st, Color(1, 1, 1, 0.35))
		_grid_control.draw_rect(st, Color(1, 1, 1), false, 2.0)

func _current_map_hash() -> int:
	return _map_grid.hash() * 31 + _map_meta.cells.hash()

func _get_thumb(tid: String, rot: int, darken: bool) -> Image:
	var key := ("d|" if darken else "") + "%s|%d" % [tid, rot]
	if _tex_thumb_cache.has(key): return _tex_thumb_cache[key]
	var tex := load("res://assets/textures/" + tid) as Texture2D
	if not tex and not tid.ends_with(".png"):
		tex = load("res://assets/textures/" + tid + ".png") as Texture2D
	if not tex:
		_tex_thumb_cache[key] = null
		return null
	var src: Image = tex.get_image()
	if not src:
		_tex_thumb_cache[key] = null
		return null
	src.convert(Image.FORMAT_RGBA8)
	src.resize(CACHE_CELL, CACHE_CELL, Image.INTERPOLATE_NEAREST)
	if rot != 0:
		src = _rotate_img(src, rot)
	var img := Image.create(CACHE_CELL, CACHE_CELL, false, Image.FORMAT_RGBA8)
	img.blit_rect(src, Rect2i(0, 0, CACHE_CELL, CACHE_CELL), Vector2i.ZERO)
	if darken:
		for y in CACHE_CELL:
			for x in CACHE_CELL:
				var p := img.get_pixel(x, y)
				img.set_pixel(x, y, Color(p.r * 0.6, p.g * 0.6, p.b * 0.6, p.a))
	_tex_thumb_cache[key] = img
	return img

func _rotate_img(img: Image, quarter_turns: int) -> Image:
	quarter_turns = posmod(quarter_turns, 4)
	if quarter_turns == 0: return img
	var w: int = img.get_width()
	var h: int = img.get_height()
	var out := Image.create(w, h, false, img.get_format())
	for y in range(h):
		for x in range(w):
			var src := img.get_pixel(x, y)
			match quarter_turns:
				1: out.set_pixel(h - 1 - y, x, src)
				2: out.set_pixel(w - 1 - x, h - 1 - y, src)
				3: out.set_pixel(y, w - 1 - x, src)
	return out

func _render_grid_cache():
	_cache_hash = _current_map_hash()
	if _map_grid.is_empty() or _grid_width <= 0 or _grid_height <= 0: return
	var w: int = _grid_width * CACHE_CELL
	var h: int = _grid_height * CACHE_CELL
	if w <= 0 or h <= 0: return
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in _grid_height:
		for x in _grid_width:
			var tile: String = _map_grid[y][x]
			var rect := Rect2i(x * CACHE_CELL, y * CACHE_CELL, CACHE_CELL, CACHE_CELL)
			var tid: String = _map_meta.get_texture(x, y)
			if tid.is_empty():
				match tile:
					"#", "O": tid = "wall/default.png"
					"D", "L": tid = "door/default.png"
					"R", "S": tid = "floor/rails.png"
					".": tid = "floor/default.png"
			if not tid.is_empty():
				var thumb := _get_thumb(tid, _map_meta.get_rotation(x, y), tile != ".")
				if thumb:
					img.blit_rect(thumb, Rect2i(0, 0, CACHE_CELL, CACHE_CELL), rect.position)
				else:
					img.fill_rect(rect, TOOL_COLORS.get(tile, Color.MAGENTA))
			else:
				img.fill_rect(rect, TOOL_COLORS.get(tile, Color.MAGENTA))
	_grid_cache_tex = ImageTexture.create_from_image(img)

# ============================= INPUT =============================

func _on_grid_input(event: InputEvent):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_level = min(_zoom_level * 1.15, 4.0); _grid_control.queue_redraw()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_level = max(_zoom_level / 1.15, 0.25); _grid_control.queue_redraw()
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			if event.pressed:
				_panning = true; _pan_start = event.position; _pan_off_start = _camera_offset
			else:
				_panning = false
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if Input.is_key_pressed(KEY_ALT):
					_pick_at_mouse(event.position)
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
			_camera_offset = _pan_off_start + (event.position - _pan_start)
			_grid_control.queue_redraw()
		elif _is_dragging:
			_paint_at_mouse(event.position)

func _update_last_tile(pos: Vector2):
	var cs: int = int(CELL_SIZE * _zoom_level); if cs < 6: cs = 6
	var offset: Vector2 = _grid_control.size * 0.5 - Vector2(_grid_width * cs, _grid_height * cs) * 0.5 + _camera_offset
	var gx: int = int((pos.x - offset.x) / cs)
	var gy: int = int((pos.y - offset.y) / cs)
	if gx < 0 or gy < 0 or gy >= _grid_height or gx >= _grid_width:
		_last_tile = Vector2i(-1, -1)
		return
	_last_tile = Vector2i(gx, gy)
	_grid_control.queue_redraw()

func _cell_at(pos: Vector2) -> Vector2i:
	var cs: int = int(CELL_SIZE * _zoom_level); if cs < 6: cs = 6
	var offset: Vector2 = _grid_control.size * 0.5 - Vector2(_grid_width * cs, _grid_height * cs) * 0.5 + _camera_offset
	var gx: int = int((pos.x - offset.x) / cs)
	var gy: int = int((pos.y - offset.y) / cs)
	if gx < 0 or gy < 0 or gy >= _grid_height or gx >= _grid_width:
		return Vector2i(-1, -1)
	return Vector2i(gx, gy)

func _paint_at_mouse(pos: Vector2):
	_update_last_tile(pos)
	var gx: int = _last_tile.x
	var gy: int = _last_tile.y
	if gx < 0 or gy < 0: return
	match _mode:
		Mode.TILES:
			_paint_tile(gx, gy)
		Mode.ENTITIES:
			match _tool:
				Tool.PLACE:
					if _palette_template:
						_paint_template_entity(gx, gy)
				Tool.ERASE:
					_remove_entity_at_tile(Vector2i(gx, gy))
				Tool.CURSOR:
					_select_entity_at_tile(gx, gy)
		Mode.STATION:
			pass

func _paint_tile(gx: int, gy: int):
	var brush: int = int(_brush_spin.value) if _brush_spin else 1
	match _tool:
		Tool.FILL:
			_flood_fill(gx, gy, _map_grid[gy][gx], ".")
		Tool.ERASE:
			for dy in range(brush):
				for dx in range(brush):
					var x: int = gx + dx; var y: int = gy + dy
					if x < 0 or y < 0 or y >= _grid_height or x >= _grid_width: continue
					_map_grid[y][x] = "."
					_remove_entity_at_tile(Vector2i(x, y))
					_remove_exit_at_tile(Vector2i(x, y))
					_map_meta.clear_cell(x, y)
		Tool.EXIT:
			_add_exit_at_tile(gx, gy)
		_:
			var ch: String = TOOL_KEYS[_tool]
			for dy in range(brush):
				for dx in range(brush):
					var x: int = gx + dx; var y: int = gy + dy
					if x < 0 or y < 0 or y >= _grid_height or x >= _grid_width: continue
					_map_grid[y][x] = ch
	_grid_control.queue_redraw()

func _flood_fill(x: int, y: int, old_ch: String, new_ch: String):
	if x < 0 or y < 0 or y >= _grid_height or x >= _grid_width: return
	if _map_grid[y][x] != old_ch: return
	if old_ch == new_ch: return
	_map_grid[y][x] = new_ch
	_flood_fill(x + 1, y, old_ch, new_ch)
	_flood_fill(x - 1, y, old_ch, new_ch)
	_flood_fill(x, y + 1, old_ch, new_ch)
	_flood_fill(x, y - 1, old_ch, new_ch)

func _paint_template_entity(gx: int, gy: int):
	if not _palette_template: return
	var pos := Vector2i(gx, gy)
	_remove_entity_at_tile(pos)
	var s := EntitySpawn.new()
	s.position = pos
	s.template_id = _palette_template.id
	_station_data.entity_spawns.append(s)
	_selected_entity_index = _station_data.entity_spawns.size() - 1
	_selected_tile = pos
	_rebuild_inspector()
	_grid_control.queue_redraw()

func _pick_at_mouse(pos: Vector2):
	_update_last_tile(pos)
	var gx: int = _last_tile.x; var gy: int = _last_tile.y
	if gx < 0 or gy < 0: return
	if _mode == Mode.ENTITIES:
		_select_entity_at_tile(gx, gy)
		return
	_current_tool_hack(gx, gy)

func _current_tool_hack(gx: int, gy: int):
	var ch: String = _map_grid[gy][gx]
	var t := TOOL_KEYS.find(ch)
	if t >= 0 and t < TILE_TOOLS.size():
		_select_tool(TILE_TOOLS[t])
	_status_label.text = "Picked tile '%s'" % ch

func _select_tile_at_mouse(pos: Vector2):
	_update_last_tile(pos)
	var gx: int = _last_tile.x; var gy: int = _last_tile.y
	if gx < 0 or gy < 0: return
	_selected_tile = Vector2i(gx, gy)
	if _mode == Mode.ENTITIES:
		_select_entity_at_tile(gx, gy)
	else:
		var ex: ExitData = _station_data.get_exit_at(_selected_tile)
		_selected_exit_index = _station_data.exits.find(ex) if ex else -1
		_rebuild_inspector()
	_grid_control.queue_redraw()

func _select_entity_at_tile(gx: int, gy: int):
	var found: int = -1
	for i in _station_data.entity_spawns.size():
		if _station_data.entity_spawns[i].position == Vector2i(gx, gy):
			found = i
			break
	_selected_entity_index = found
	_rebuild_inspector()
	_grid_control.queue_redraw()

# ============================= ENTITY OPS =============================

func _refresh_subtype_options(type_index: int):
	if not _ent_subtype: return
	var options: Array = []
	match type_index:
		EntitySpawn.Type.ENEMY:
			options = ["bunny", "scav"]
		EntitySpawn.Type.NPC:
			options = _scan_dialogue_subtypes()
			if options.is_empty(): options = ["kitsu"]
		EntitySpawn.Type.ITEM:
			options = ItemCatalog.get_item_ids()
			if options.is_empty(): options = ["medkit", "bandage", "pistol"]
		EntitySpawn.Type.OBJECT:
			options = ["rest", "lore", "container", "tv", "lamp", "hazard"]
	_ent_subtype.clear()
	for o in options:
		_ent_subtype.add_item(o)

func _scan_dialogue_subtypes() -> Array[String]:
	var result: Array[String] = []
	var dir := DirAccess.open("res://dialogues")
	if not dir: return result
	dir.list_dir_begin()
	var f := dir.get_next()
	while f != "":
		if f == "." or f == "..":
			f = dir.get_next(); continue
		if dir.current_is_dir():
			result.append(f)
		elif f.ends_with(".json"):
			result.append(f.get_basename())
		f = dir.get_next()
	dir.list_dir_end()
	result.sort()
	return result

func _build_visual_options():
	if _visual_options_built:
		for opt in _visual_options:
			_ent_tex_pick.add_item(opt)
		return
	_visual_options_built = true
	for root in ["res://sprites/entity", "res://sprites/npc", "res://sprites/enemy"]:
		var dir := DirAccess.open(root)
		if not dir: continue
		dir.list_dir_begin()
		var f := dir.get_next()
		while f != "":
			if f == "." or f == "..":
				f = dir.get_next(); continue
			if dir.current_is_dir():
				_visual_options.append((root + "/" + f).trim_prefix("res://"))
			elif f.ends_with(".png") and not f.ends_with(".import"):
				_visual_options.append((root + "/" + f).trim_prefix("res://"))
			f = dir.get_next()
		dir.list_dir_end()
	_visual_options.sort()
	for opt in _visual_options:
		_ent_tex_pick.add_item(opt)

func _on_ent_tex_picked(index: int):
	if index <= 0: return
	_ent_tex_edit.text = _visual_options[index - 1]

func _on_ent_type_changed(index: int):
	_apply_entity(null, true)

func _on_extra_changed(new_text: String):
	var t := new_text.strip_edges()
	if not t.is_empty() and not (JSON.parse_string(t) is Dictionary):
		return
	_apply_entity(null, false)

func _apply_entity(_ignored: Variant = null, rebuild: bool = true):
	if _insp_applying:
		return
	if _selected_entity_index < 0 or _selected_entity_index >= _station_data.entity_spawns.size():
		return
	var s: EntitySpawn = _station_data.entity_spawns[_selected_entity_index]
	TemplateLibrary.update_override(s, "type", _ent_type.selected as EntitySpawn.Type)
	if _ent_subtype.selected >= 0:
		TemplateLibrary.update_override(s, "subtype", _ent_subtype.get_item_text(_ent_subtype.selected))
	TemplateLibrary.update_override(s, "facing", clamp(_ent_facing.selected, 0, 3))
	TemplateLibrary.update_override(s, "size", _ent_size.value)
	TemplateLibrary.update_override(s, "ceiling_lift", _ent_ceiling_lift.value)
	TemplateLibrary.update_override(s, "visual_offset_x", _ent_offset_x.value)
	TemplateLibrary.update_override(s, "texture", _ent_tex_edit.text.strip_edges())

	var data: Dictionary = {}
	var extra_text: String = _ent_extra.text.strip_edges()
	var extra_valid: bool = true
	if not extra_text.is_empty():
		var parsed: Variant = JSON.parse_string(extra_text)
		if parsed is Dictionary:
			data = parsed
		else:
			extra_valid = false
	if not _ent_name.text.strip_edges().is_empty():
		data["name"] = _ent_name.text.strip_edges()
	if not _ent_desc.text.strip_edges().is_empty():
		data["description"] = _ent_desc.text.strip_edges()
	var loot := _parse_loot(_ent_loot.text)
	if not loot.is_empty():
		data["loot"] = loot
	if _ent_light_on.button_pressed:
		data["color"] = [_ent_light_color.color.r, _ent_light_color.color.g, _ent_light_color.color.b]
		TemplateLibrary.set_light_override(s, {
			"radius": int(_ent_light_radius.value),
			"intensity": _ent_light_intensity.value,
			"color": _ent_light_color.color,
			"flicker": _ent_light_flicker.value,
			"style": _light_style_name(_ent_light_style.selected),
			"height": _ent_light_height.value,
			"world_radius": _ent_light_world_radius.value,
		})
	else:
		TemplateLibrary.set_light_override(s, {})
		data.erase("color")
	if extra_valid:
		TemplateLibrary.update_override(s, "extra", data)

	_grid_control.queue_redraw()
	if _over_count_label:
		_over_count_label.text = "Overrides: %d" % s.overrides.size()
	if rebuild:
		_rebuild_inspector()
	if _status_label:
		_status_label.text = "Applied overrides to %s" % s.display_name()

func _reset_overrides():
	if _selected_entity_index < 0 or _selected_entity_index >= _station_data.entity_spawns.size():
		return
	var s: EntitySpawn = _station_data.entity_spawns[_selected_entity_index]
	TemplateLibrary.clear_all_overrides(s)
	_rebuild_inspector()
	_grid_control.queue_redraw()
	_status_label.text = "Overrides reset"

func _detach_entity():
	if _selected_entity_index < 0 or _selected_entity_index >= _station_data.entity_spawns.size():
		return
	var s: EntitySpawn = _station_data.entity_spawns[_selected_entity_index]
	var r: EntitySpawn = TemplateLibrary.resolve_spawn(s)
	s.type = r.type
	s.subtype = r.subtype
	s.facing = r.facing
	s.size = r.size
	s.ceiling_lift = r.ceiling_lift
	s.visual_offset_x = r.visual_offset_x
	s.texture = r.texture
	s.extra = r.extra.duplicate()
	s.light_source = r.light_source.duplicate()
	s.template_id = ""
	s.overrides = {}
	_rebuild_inspector()
	_grid_control.queue_redraw()
	_status_label.text = "Entity detached from template"

func _remove_selected_entity():
	_remove_entity_at_tile(_station_data.entity_spawns[_selected_entity_index].position)

func _remove_entity_at_tile(pos: Vector2i):
	for i in range(_station_data.entity_spawns.size() - 1, -1, -1):
		if _station_data.entity_spawns[i].position == pos:
			_station_data.entity_spawns.remove_at(i)
			if _selected_entity_index >= i:
				_selected_entity_index -= 1
			break
	if _selected_entity_index < 0:
		_rebuild_inspector()
	_grid_control.queue_redraw()

func _remove_exit_at_tile(pos: Vector2i):
	for i in range(_station_data.exits.size() - 1, -1, -1):
		if _station_data.exits[i].position == pos:
			_station_data.exits.remove_at(i)
			if _selected_exit_index >= i:
				_selected_exit_index -= 1
			break
	_grid_control.queue_redraw()

func _clear_tile(pos: Vector2i):
	if pos.y >= 0 and pos.y < _grid_height and pos.x >= 0 and pos.x < _grid_width:
		_map_grid[pos.y][pos.x] = "."
	_map_meta.clear_cell(pos.x, pos.y)
	_remove_entity_at_tile(pos)
	_remove_exit_at_tile(pos)
	_grid_control.queue_redraw()

func _parse_loot(text: String) -> Array:
	var result: Array = []
	for part in text.split(",", false):
		var p: String = part.strip_edges()
		if not p.is_empty():
			result.append(p)
	return result

func _light_style_name(index: int) -> String:
	return ["", "fluorescent", "candle", "alarm"][clamp(index, 0, 3)]

func _light_style_index(name: String) -> int:
	for i in 4:
		if name == ["", "fluorescent", "candle", "alarm"][i]:
			return i
	return 0

# ============================= EXIT OPS =============================

func _add_exit_at_tile(gx: int, gy: int):
	if gx < 0 or gy < 0 or gy >= _grid_height or gx >= _grid_width:
		return
	var pos := Vector2i(gx, gy)
	_map_grid[gy][gx] = "E"
	for i in range(_station_data.exits.size() - 1, -1, -1):
		if _station_data.exits[i].position == pos:
			_station_data.exits.remove_at(i)
	var e := ExitData.new()
	e.position = pos
	e.target_station_path = ""
	_station_data.exits.append(e)
	_selected_tile = pos
	_selected_exit_index = _station_data.exits.size() - 1
	_rebuild_inspector()
	_grid_control.queue_redraw()
	_status_label.text = "Exit added at (%d, %d)" % [pos.x, pos.y]

func _on_exit_target_selected(_index: int):
	pass

func _refresh_station_dropdown():
	if not _exit_target_select: return
	var current: String = ""
	if _selected_exit_index >= 0 and _selected_exit_index < _station_data.exits.size():
		current = _station_data.exits[_selected_exit_index].target_station_path
	_exit_target_select.clear()
	var stations: Array[String] = _scan_resources("res://resources/stations", ".tres")
	var selected_idx: int = -1
	for i in stations.size():
		_exit_target_select.add_item(stations[i])
		if stations[i] == current:
			selected_idx = i
	if selected_idx >= 0:
		_exit_target_select.selected = selected_idx
	else:
		_exit_target_select.set_meta("target_path", current)

func _get_exit_target_path() -> String:
	if not _exit_target_select: return ""
	var idx: int = _exit_target_select.selected
	if idx < 0:
		return _exit_target_select.get_meta("target_path", "") as String
	return _exit_target_select.get_item_text(idx)

func _apply_exit():
	if _selected_exit_index < 0 or _selected_exit_index >= _station_data.exits.size():
		# create/find exit at selected tile
		if _selected_tile.x < 0: return
		var e2: ExitData = _station_data.get_exit_at(_selected_tile)
		if not e2:
			e2 = ExitData.new()
			e2.position = _selected_tile
			_station_data.exits.append(e2)
		_selected_exit_index = _station_data.exits.find(e2)
	var e: ExitData = _station_data.exits[_selected_exit_index]
	e.target_station_path = _get_exit_target_path()
	e.target_spawn = Vector2i(int(_exit_target_x.value), int(_exit_target_y.value))
	e.target_dir = -1 if _exit_target_dir.selected == 4 else _exit_target_dir.selected
	_grid_control.queue_redraw()
	_status_label.text = "Exit applied"

func _remove_selected_exit():
	if _selected_exit_index < 0 or _selected_exit_index >= _station_data.exits.size():
		return
	_station_data.exits.remove_at(_selected_exit_index)
	_selected_exit_index = -1
	_rebuild_inspector()
	_grid_control.queue_redraw()

func _set_spawn_at_tile(pos: Vector2i):
	_station_data.spawn = pos
	_grid_control.queue_redraw()
	_status_label.text = "Spawn set at (%d, %d)" % [pos.x, pos.y]

# ============================= TILE INSPECTOR =============================

func _refresh_selected_tile_info():
	if not _insp_coords or not _station_data: return
	if _selected_tile.x < 0 or _selected_tile.y < 0:
		_insp_coords.text = "Selected: none"
		_insp_tile.text = ""
		return
	_insp_coords.text = "Selected: (%d, %d)" % [_selected_tile.x, _selected_tile.y]
	var ch: String = _map_grid[_selected_tile.y][_selected_tile.x]
	_insp_tile.text = "Tile: '%s'" % ch
	_wall_tex_edit.text = _map_meta.get_texture(_selected_tile.x, _selected_tile.y)
	_wall_rot.selected = _map_meta.get_rotation(_selected_tile.x, _selected_tile.y) / 90
	var e: ExitData = _station_data.get_exit_at(_selected_tile)
	_selected_exit_index = _station_data.exits.find(e) if e else -1
	if e:
		_exit_target_x.value = e.target_spawn.x
		_exit_target_y.value = e.target_spawn.y
		_exit_target_dir.selected = 4 if e.target_dir < 0 else e.target_dir
	_refresh_station_dropdown()

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

# ============================= TEMPLATE DIALOGS =============================

func _new_template_dialog():
	_edit_template_dialog_with(null)

func _edit_template_dialog():
	var s: EntitySpawn = _station_data.entity_spawns[_selected_entity_index]
	var t: EntityTemplate = TemplateLibrary.get_template(s.template_id)
	if not t:
		return
	_edit_template_dialog_with(t)

func _edit_template_dialog_with(t: EntityTemplate):
	var dlg := AcceptDialog.new()
	dlg.title = "Edit Object" if t else "New Object"
	dlg.ok_button_text = "Save Object"
	dlg.size = Vector2(460, 560)
	var sc := ScrollContainer.new()
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(420, 0)
	sc.add_child(box)
	dlg.add_child(sc)

	var is_new: bool = t == null
	if is_new:
		var selected: EntitySpawn = _station_data.entity_spawns[_selected_entity_index] if (_selected_entity_index >= 0 and _selected_entity_index < _station_data.entity_spawns.size()) else null
		t = EntityTemplate.new()
		if selected:
			t = TemplateLibrary.create_from_spawn(selected, "", "", "container")

	var id_edit := LineEdit.new()
	id_edit.placeholder_text = "id (letters, no spaces)"
	id_edit.text = t.id
	id_edit.editable = is_new
	box.add_child(_labelled("id", id_edit))
	var name_edit := LineEdit.new()
	name_edit.text = t.display_name
	box.add_child(_labelled("Display name", name_edit))
	var cat_edit := LineEdit.new()
	cat_edit.text = t.category
	box.add_child(_labelled("Category", cat_edit))
	var type_opt := OptionButton.new()
	for tn: String in TYPE_NAMES: type_opt.add_item(tn)
	type_opt.selected = t.type
	box.add_child(_labelled("Type", type_opt))
	var subtype_edit := LineEdit.new()
	subtype_edit.text = t.subtype
	box.add_child(_labelled("Subtype", subtype_edit))
	var size_spin := SpinBox.new(); size_spin.min_value = 0.05; size_spin.max_value = 2.0; size_spin.step = 0.05; size_spin.value = t.size
	box.add_child(_labelled("Size", size_spin))
	var lift_spin := SpinBox.new(); lift_spin.min_value = 0.0; lift_spin.max_value = 2.0; lift_spin.step = 0.05; lift_spin.value = t.ceiling_lift
	box.add_child(_labelled("Ceiling lift", lift_spin))
	var off_spin := SpinBox.new(); off_spin.min_value = -1.0; off_spin.max_value = 1.0; off_spin.step = 0.1; off_spin.value = t.visual_offset_x
	box.add_child(_labelled("Offset X", off_spin))
	var facing_opt := OptionButton.new()
	for d: String in ["F:N", "F:E", "F:S", "F:W"]: facing_opt.add_item(d)
	facing_opt.selected = clamp(t.facing, 0, 3)
	box.add_child(_labelled("Facing", facing_opt))
	var tex_edit := LineEdit.new()
	tex_edit.text = t.get_state_texture()
	tex_edit.placeholder_text = "sprites/entity/locker"
	box.add_child(_labelled("Texture (state 'front')", tex_edit))
	var name_edit2 := LineEdit.new()
	name_edit2.text = t.extra.get("name", "")
	box.add_child(_labelled("Object name", name_edit2))
	var desc_edit := LineEdit.new()
	desc_edit.text = t.extra.get("description", "")
	box.add_child(_labelled("Description", desc_edit))
	var loot_edit := LineEdit.new()
	var loot_str := ""
	for li in t.extra.get("loot", []):
		loot_str += (", " if not loot_str.is_empty() else "") + str(li)
	loot_edit.text = loot_str
	box.add_child(_labelled("Loot", loot_edit))

	dlg.confirmed.connect(func():
		var tid: String = id_edit.text.strip_edges()
		if is_new and tid.is_empty():
			tid = "object_" + str(Time.get_ticks_msec())
		t.id = tid
		t.display_name = name_edit.text.strip_edges()
		t.category = cat_edit.text.strip_edges()
		t.type = type_opt.selected as EntitySpawn.Type
		t.subtype = subtype_edit.text.strip_edges()
		t.size = size_spin.value
		t.ceiling_lift = lift_spin.value
		t.visual_offset_x = off_spin.value
		t.facing = clamp(facing_opt.selected, 0, 3)
		var tex_path: String = tex_edit.text.strip_edges()
		if not tex_path.is_empty():
			t.sprites = { "front": tex_path }
			t.default_state = "front"
		var ex: Dictionary = t.extra.duplicate()
		if not name_edit2.text.strip_edges().is_empty():
			ex["name"] = name_edit2.text.strip_edges()
		else:
			ex.erase("name")
		if not desc_edit.text.strip_edges().is_empty():
			ex["description"] = desc_edit.text.strip_edges()
		else:
			ex.erase("description")
		var loot_arr := _parse_loot(loot_edit.text)
		if not loot_arr.is_empty():
			ex["loot"] = loot_arr
		else:
			ex.erase("loot")
		t.extra = ex
		var err := TemplateLibrary.save_template(t)
		_status_label.text = "Object saved: %s (%s)" % [t.display_name, str(err)]
		TemplateLibrary.reload()
		_refresh_palette_categories()
		_rebuild_inspector()
	)
	add_child(dlg)
	dlg.popup_centered()

func _labelled(label_text: String, ctrl: Control) -> VBoxContainer:
	var v := VBoxContainer.new()
	var l := Label.new()
	l.text = label_text
	l.add_theme_font_size_override("font_size", 11)
	v.add_child(l)
	ctrl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(ctrl)
	return v

func _save_as_template_dialog():
	if _selected_entity_index < 0 or _selected_entity_index >= _station_data.entity_spawns.size():
		return
	var s: EntitySpawn = _station_data.entity_spawns[_selected_entity_index]
	_edit_template_dialog_with(TemplateLibrary.create_from_spawn(TemplateLibrary.resolve_spawn(s), "", s.display_name(), "container"))

# ============================= CONTEXT MENU =============================

func _open_context_menu(pos: Vector2):
	if _selected_tile.x < 0: return
	var menu := PopupMenu.new()
	menu.add_item("Set Spawn", 0)
	if _mode == Mode.ENTITIES:
		if _station_data.get_entity_spawn_at(_selected_tile):
			menu.add_item("Remove Entity", 1)
		if _palette_template:
			menu.add_item("Place '" + _palette_template.display_name + "'", 2)
	else:
		if _station_data.get_exit_at(_selected_tile):
			menu.add_item("Remove Exit", 3)
		menu.add_item("Clear Tile", 4)
	menu.id_pressed.connect(func(id):
		match id:
			0: _set_spawn_at_tile(_selected_tile)
			1: _remove_entity_at_tile(_selected_tile)
			2:
				_paint_template_entity(_selected_tile.x, _selected_tile.y)
			3: _remove_exit_at_tile(_selected_tile)
			4: _clear_tile(_selected_tile)
	)
	add_child(menu)
	menu.position = _grid_control.global_position + pos
	menu.popup()

# ============================= INPUT / UNDO =============================

func _push_undo():
	var snap: Array = []
	for row: Array in _map_grid:
		snap.append(row.duplicate())
	_undo_stack.append(snap)
	if _undo_stack.size() > MAX_UNDO:
		_undo_stack.pop_front()
	_redo_stack.clear()

func _undo():
	if _undo_stack.size() <= 1: return
	_redo_stack.append(_undo_stack.pop_back())
	var snap: Array = _undo_stack.back()
	_map_grid = [] as Array[Array]
	for row: Array in snap:
		_map_grid.append(row)
	_grid_control.queue_redraw()

func _redo():
	if _redo_stack.is_empty(): return
	var snap: Array = _redo_stack.pop_back()
	_undo_stack.append(snap)
	_map_grid = [] as Array[Array]
	for row: Array in snap:
		_map_grid.append(row)
	_grid_control.queue_redraw()

func _input(event: InputEvent):
	if event is InputEventKey and event.pressed and not event.echo:
		var focus_owner := get_viewport().gui_get_focus_owner()
		if focus_owner is LineEdit or focus_owner is SpinBox or focus_owner is TextEdit or focus_owner is OptionButton:
			return
		match event.keycode:
			KEY_1: _set_mode(Mode.TILES)
			KEY_2: _set_mode(Mode.ENTITIES)
			KEY_3: _set_mode(Mode.STATION)
			KEY_Z:
				if event.ctrl_pressed or event.meta_pressed: _undo()
			KEY_Y:
				if event.ctrl_pressed or event.meta_pressed: _redo()
			KEY_S:
				if event.ctrl_pressed: _save_station()

func _process(delta: float):
	if Input.is_key_pressed(KEY_SHIFT):
		if Input.is_key_pressed(KEY_LEFT): _camera_offset.x -= 200 * delta
		if Input.is_key_pressed(KEY_RIGHT): _camera_offset.x += 200 * delta
		if Input.is_key_pressed(KEY_UP): _camera_offset.y -= 200 * delta
		if Input.is_key_pressed(KEY_DOWN): _camera_offset.y += 200 * delta
		_grid_control.queue_redraw()
