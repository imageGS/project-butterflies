extends Node

enum Dir { NORTH, EAST, SOUTH, WEST }
const DIR_ANGLES: Dictionary = { Dir.NORTH: -PI / 2.0, Dir.EAST: 0.0, Dir.SOUTH: PI / 2.0, Dir.WEST: PI }
const DIR_NAMES: Dictionary = { Dir.NORTH: "N ↑", Dir.EAST: "E →", Dir.SOUTH: "S ↓", Dir.WEST: "W ←" }
const DIR_VECTORS: Dictionary = {
	Dir.NORTH: Vector2i(0, -1),
	Dir.EAST:  Vector2i(1, 0),
	Dir.SOUTH: Vector2i(0, 1),
	Dir.WEST:  Vector2i(-1, 0),
}

const TILE_FLOOR := 0
const TILE_WALL := 1
const TILE_DOOR := 2
const TILE_LOCKED := 3
const TILE_STAIRS := 4
const TILE_SPECIAL := 5
const TILE_BLOCKED := 6
const TILE_EXIT := 7
const TILE_ITEM := 8

@export var move_duration: float = 0.25
@export var turn_duration: float = 0.2

var _player_x: float = 1.0
var _player_y: float = 1.0
var _player_dir: int = Dir.SOUTH
var _current_angle: float = PI / 2.0
var _map_data: Array = []
var _entities: Array = []

var _is_animating := false
var _anim_timer := 0.0
var _anim_from_x := 1.0
var _anim_to_x := 1.0
var _anim_from_y := 1.0
var _anim_to_y := 1.0
var _anim_from_angle := 0.0
var _anim_to_angle := 0.0

var _footstep_sounds: Array = []
var _footstep_player: AudioStreamPlayer
var _audio_listener: AudioListener2D

var _awareness_timer: float = 0.0
var _awareness_interval: float = 8.0
var _awareness_pool: Array[String] = [
	"Вы замечаете странные царапины на стенах.",
	"Откуда-то доносится запах сырости и металла.",
	"Краем глаза вы замечаете движение в темноте.",
	"Пол под ногами слегка вибрирует.",
	"Где-то капает вода. Звук эхом разносится по тоннелю.",
	"Тишина слишком плотная. Словно метро затаило дыхание.",
	"На стене следы когтей. Свежие.",
	"Воздух становится тяжелее. Вы чувствуете давление в висках.",
	"Лампы мигают. На мгновение тьма становится абсолютной.",
	"По полу пробегает крыса. Обычная, не падальщик.",
]

var _dialogue_overlay: CanvasLayer
var _dialogue_root: ColorRect
var _dialogue_portrait_bg: ColorRect
var _dialogue_portrait_sprite: TextureRect
var _npc_portrait_texture: Texture2D
var _dialogue_name: Label
var _dialogue_text: Label
var _dialogue_prompt: Label
var _dialogue_responses: Array[Label] = []
var _dialogue_nodes: Array = []
var _dialogue_index: int = 0
var _dialogue_active: bool = false
var _dialogue_busy: bool = false
var _passive_cache: Dictionary = {}

var _inv_open: bool = false
var _inv_overlay: CanvasLayer
var _inv_cells: Array[ColorRect] = []
var _inv_item_labels: Array[Label] = []
const INV_CELL_SIZE := 44
const INV_GAP := 2

var _minimap: Control

@onready var _renderer: Control = $CRT_Root/GameViewport/UI/CentralViewport/DungeonView
@onready var _label: Label = $CRT_Root/GameViewport/UI/CentralViewport/DungeonView/InfoLabel
@onready var _awareness_label: Label = $CRT_Root/GameViewport/UI/CentralViewport/DungeonView/AwarenessLabel

func _ready():
	_build_test_level()
	_setup_entities()
	_current_angle = DIR_ANGLES[_player_dir]
	_setup_dialogue_ui()
	_setup_inventory_ui()
	_setup_audio()
	_refresh()
	_awareness_timer = _awareness_interval
	PlayerStats.inventory.try_add(Item.new("Аптечка", "Восстанавливает здоровье", 3, Vector2i(1,2), 1))
	PlayerStats.inventory.try_add(Item.new("Монета", "Старая, потёртая", 0, Vector2i(1,1), 5))
	PlayerStats.inventory.try_add(Item.new("Консервы", "Еда с истёкшим сроком", 1, Vector2i(1,1), 2))
	_setup_minimap()

func _build_test_level():
	var ascii_rows: Array[String] = [
		"################################################",
		"#E....#.........#.......#.....#........#........#",
		"#.###.#.#######.#.#####.#.###.#.######.#.######.#",
		"#.#.#...#.....#...#...#...#.#...#....#...#....#..#",
		"#.#.#####.###.#####.#.#####.#####.#.#####.##.#.#.#",
		"#.#.......#.#.....#.#.....#.....#.#.....#..#.#.#.#",
		"#.#######.#.#####.#.#####.#####.#.#####.#.##.#.#.#",
		"#.......#.#.....#.#.....#.....#.#.....#.#..#.#.#.#",
		"#.#####.#.#####.#.#####.#####.#.#####.#.##.#.#.#.#",
		"#.#...#.#.#...#.#.....#.....#.#.....#.#..#.#...#.#",
		"#.#.#.#.#.#.#.#.#####.#####.#.#####.#.##.#.#####.#",
		"#.#.#.#...#.#.#.....#.....#.#.....#.#..#.#.....#.#",
		"#.#.#.#####.#.#####.#####.#.#####.#.##.#.#####.#.#",
		"#.#.#.....#.#.....#.....#.#.....#.#..#...#...#.#.#",
		"#.#.#####.#.#####.#####.#.#####.#.##.#####.#.#.#.#",
		"#...#...#.#.....#.....#.#.....#.#..#.....#.#.#...#",
		"#####.#.#.#####.#####.#.#####.#.##.#####.#.#.###.#",
		"#...#.#.#.....#.....#.#.....#.#..#.....#.#.#.#...#",
		"#.#.#.#.#####.#####.#.#####.#.##.#####.#.#.#.#.###",
		"#.#.#.#.....#.....#.#.....#.#..#.....#.#.#.#.#...#",
		"#.#.#.#####.#####.#.#####.#.##.#####.#.#.#.#.###.#",
		"#.#.#.....#.....#.#.....#.#..#.....#...#.#.#...#.#",
		"#.#.#####.#####.#.#####.#.##.#####L#####.#.###.#.#",
		"#.#.....#.....#.#.....#.#..#.....#.....#.#...#.#.#",
		"#.#####.#####.#.#####.#.##.#####.#####.#.###.#.#.#",
		"#.....#.....#.#.....#.#..#.....#.....#.#...#.#.#.#",
		"#.###.#####.#.#####.#.##.#####.#####.#.###.#.#.#.#",
		"#.#.#.....#.#.....#.#..#.....#.....#.#...#...#.#.#",
		"#.#.#####.#.#####.#.##.#####.#####.#.###.#####.#.#",
		"#.#.....#...#...#.#..#.....#.....#...#...#.....#.#",
		"#.#####.#####.#.#.#.#####.#####.#####.#.#.#####.#",
		"#.....#.....#.#.#.#.....#.....#.....#.#.#.....#.#",
		"#.###.#####.#.#.#.#####.#####.#####.#.#.#####.#.#",
		"#.#.#.....#.#...#.....#.....#.....#.#...#...#...#",
		"#.#.#####.#.#########.#####.#####.#.#####.#.#####",
		"#.#.#.....#...........#.....#.....#...#...#.#.....#",
		"#.#####.###########.#####.#####.###.#.#.#.#####.#",
		"#.....#...........#.....#.....#...#.#.#.#.....#.#",
		"#####.###########.#####.#####.#.#.#.#.#.#####.#.#",
		"#...#...........#.....#.....#.#.#.#.#.#.....#.#.#",
		"#.#.###########.#####.#####.#.#.#.#.#.#####.#.#.#",
		"#.#...........#.....#.....#.#...#.#.#.....#.#.#.#",
		"#.###########.#####.#####.#.#####.#.#####.#.#.#.#",
		"#...........#.....#.....#...#...#.#.....#.#.#...#",
		"###########.#####.#####.#####.#.#.#####.#.#.###.#",
		"#.........#.....#.....#.....#.#.#.....#.#.#...#.#",
		"#.#######.#####.#####.#####.#.#.#####.#.#.###.#X#",
		"################################################",
	]

	_map_data = []
	for y in ascii_rows.size():
		var row: Array = []
		var line: String = ascii_rows[y]
		for x in line.length():
			var ch: String = line[x]
			match ch:
				"#": row.append(TILE_WALL)
				".": row.append(TILE_FLOOR)
				"+": row.append(TILE_FLOOR)
				"T": row.append(TILE_FLOOR)
				"O": row.append(TILE_FLOOR)
				"D": row.append(TILE_DOOR)
				"L": row.append(TILE_LOCKED)
				"K": row.append(TILE_FLOOR)
				"S": row.append(TILE_STAIRS)
				" ": row.append(TILE_WALL)
				"▓": row.append(TILE_FLOOR)
				"E": row.append(TILE_EXIT)
				"X": row.append(TILE_FLOOR)
				"I": row.append(TILE_ITEM)
				"@": row.append(TILE_FLOOR)
				_: row.append(TILE_WALL)
		_map_data.append(row)

	# ─── ИНЪЕКЦИИ ПОВЕРХ СКЕЛЕТА ───
	# 1. Магистральное кольцо (ширина 2)
	_carve(2, 1, 45, 2)      # верх
	_carve(2, 44, 45, 45)    # низ
	_carve(1, 3, 2, 43)      # лево
	_carve(45, 3, 46, 43)    # право

	# 2. Диагональные срезы
	_carve_diag(6, 6, 18, 18)   # срез A
	_carve_diag(40, 8, 28, 20)  # срез B
	_carve_diag(10, 40, 24, 28) # срез C

	# 3. Сокровищница за L
	_carve(35, 22, 37, 24)     # комната
	_set_tile(36, 23, TILE_ITEM)
	_set_tile(34, 22, TILE_DOOR)  # вход с L

	# 4. Ключ в тупике
	_set_tile(2, 46, TILE_ITEM)

	# 5. Центральная спираль → выход X
	var spiral: Array[Vector2i] = [
		Vector2i(24, 20), Vector2i(24, 19), Vector2i(23, 19), Vector2i(22, 19),
		Vector2i(22, 20), Vector2i(22, 21), Vector2i(23, 21), Vector2i(24, 21),
		Vector2i(24, 22), Vector2i(25, 22), Vector2i(25, 21), Vector2i(25, 20),
		Vector2i(25, 19), Vector2i(25, 18), Vector2i(24, 18), Vector2i(23, 18),
		Vector2i(22, 18), Vector2i(22, 17), Vector2i(23, 17), Vector2i(24, 17),
		Vector2i(25, 17), Vector2i(25, 16), Vector2i(24, 16), Vector2i(23, 16),
		Vector2i(22, 16), Vector2i(22, 15), Vector2i(23, 15), Vector2i(24, 15),
		Vector2i(25, 15), Vector2i(25, 14), Vector2i(24, 14), Vector2i(23, 14),
		Vector2i(23, 13), Vector2i(24, 13), Vector2i(25, 13), Vector2i(25, 12),
		Vector2i(24, 12), Vector2i(23, 12), Vector2i(23, 11), Vector2i(24, 11),
		Vector2i(25, 11), Vector2i(25, 10), Vector2i(24, 10), Vector2i(23, 10),
	]
	for pt in spiral:
		_set_tile(pt.x, pt.y, TILE_FLOOR)
	_set_tile(24, 24, TILE_FLOOR)  # центр спирали = X
	_set_tile(46, 46, TILE_FLOOR)  # выход снизу

	# 6. Пролом-секрет ▓
	_set_tile(19, 22, TILE_FLOOR)
	_carve(19, 20, 20, 21)      # секретная камера
	_set_tile(19, 20, TILE_ITEM)

	# 7. Тупики с лутом
	_set_tile(3, 5, TILE_ITEM)
	_set_tile(45, 9, TILE_ITEM)
	_set_tile(7, 33, TILE_ITEM)
	_set_tile(41, 37, TILE_ITEM)
	_set_tile(15, 43, TILE_ITEM)

	# Убедиться что (1,1) вход
	_set_tile(1, 1, TILE_EXIT)

	# 8. Спавны врагов — добавляем как entity

func _carve_diag(x1: int, y1: int, x2: int, y2: int):
	var steps: int = max(abs(x2 - x1), abs(y2 - y1))
	for i in steps + 1:
		var t: float = float(i) / float(steps) if steps > 0 else 0.0
		var px: int = int(round(lerp(float(x1), float(x2), t)))
		var py: int = int(round(lerp(float(y1), float(y2), t)))
		_set_tile(px, py, TILE_FLOOR)

func _carve(x1: int, y1: int, x2: int, y2: int, tile: int = TILE_FLOOR):
	for y in range(y1, y2 + 1):
		for x in range(x1, x2 + 1):
			if y >= 0 and y < _map_data.size() and x >= 0 and x < _map_data[0].size():
				_map_data[y][x] = tile

func _set_tile(x: int, y: int, tile: int):
	if y >= 0 and y < _map_data.size() and x >= 0 and x < _map_data[0].size():
		_map_data[y][x] = tile

func _setup_entities():
	_entities = []
	# Враги на @ позициях
	var tex_f := load("res://sprites/enemy/bunny/bunny_enemy.png")
	var tex_b := load("res://sprites/enemy/bunny/bunny_enemy_back.png")
	var tex_l := load("res://sprites/enemy/bunny/bunny_enemy_left.png")
	var tex_r := load("res://sprites/enemy/bunny/bunny_enemy_right.png")
	# Каждый враг: pos, соседние точки для патруля (маршрут)
	var spawns: Array[Dictionary] = [
		{ "pos": Vector2i(2, 10), "dir": Dir.SOUTH },
		{ "pos": Vector2i(46, 10), "dir": Dir.SOUTH },
		{ "pos": Vector2i(25, 2), "dir": Dir.EAST },
	]
	for s in spawns:
		var audio := AudioStreamPlayer.new()
		audio.volume_db = -4.0
		add_child(audio)
		_entities.append({
			"grid_x": s.pos.x, "grid_y": s.pos.y,
			"anim_x": float(s.pos.x), "anim_y": float(s.pos.y),
			"color": Color(0.8, 0.2, 0.2),
			"type": "enemy",
			"facing": s.dir,
			"textures": { "front": tex_f, "back": tex_b, "left": tex_l, "right": tex_r, "chase": load("res://sprites/enemy/bunny/bunny_enemy_chase.png") },
			"move_progress": 1.0,
			"move_timer": randf_range(0.5, 1.0),
			"chase_active": false,
			"audio_player": audio,
		})

	# Интерактивные объекты
	var objects: Array[Dictionary] = [
		{ "grid_x": 1, "grid_y": 9, "type": "object", "object_type": "container", "data": { "name": "Рюкзак", "description": "Чей-то брошенный рюкзак.", "loot": ["Консервы", "Бинт"] }},
		{ "grid_x": 16, "grid_y": 13, "type": "object", "object_type": "lore", "data": { "name": "Стена", "description": "Кто-то выцарапал: «NEW DAWN — ЭТО АД». Буквы дрожат." }},
		{ "grid_x": 28, "grid_y": 15, "type": "object", "object_type": "rest", "data": { "name": "скамья", "description": "Обшарпанная деревянная скамья." }},
		{ "grid_x": 28, "grid_y": 22, "type": "object", "object_type": "container", "data": { "name": "Ящик", "description": "Деревянный ящик с инструментами.", "loot": ["Аптечка"] }},
		{ "grid_x": 19, "grid_y": 20, "type": "object", "object_type": "lore", "data": { "name": "Труп", "description": "Тело в форме охранника. В кармане пусто. Нашивка: NEW DAWN." }},
		{ "grid_x": 36, "grid_y": 23, "type": "object", "object_type": "container", "data": { "name": "Сейф", "description": "Небольшой сейф. Код сбит, но дверца открыта.", "loot": ["Патроны", "Золотая монета"] }},
		{ "grid_x": 1, "grid_y": 22, "type": "object", "object_type": "lore", "data": { "name": "Газета", "description": "Скомканная газета. Заголовок: «ПРОПАЖА ЛЮДЕЙ В МЕТРО — ПОЛИЦИЯ БЕССИЛЬНА». Дата — полгода назад." }},
		{ "grid_x": 24, "grid_y": 24, "type": "object", "object_type": "lore", "data": { "name": "Алтарь", "description": "Странная конструкция в центре лабиринта. Свечи, символы. Кто-то проводил здесь ритуал." }},
	]
	for o in objects:
		_entities.append(o)

	# NPC-странник
	var file := FileAccess.get_file_as_string("res://dialogues/wanderer.json")
	if file:
		var data: Dictionary = JSON.parse_string(file)
		if data and data.has("nodes"):
			_entities.append({
				"grid_x": 35, "grid_y": 23,
				"color": Color(0.2, 0.6, 0.2),
				"type": "npc",
				"name": data.get("name", "Незнакомец"),
				"texture": load("res://sprites/npc/17_sprite.png"),
				"dialogue": data.nodes,
			})

func _setup_dialogue_ui():
	_dialogue_overlay = CanvasLayer.new()
	_dialogue_overlay.layer = 100
	_dialogue_overlay.visible = false

	_dialogue_root = ColorRect.new()
	_dialogue_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_dialogue_root.color = Color(0.0, 0.0, 0.0, 0.75)
	_dialogue_overlay.add_child(_dialogue_root)

	_dialogue_portrait_bg = ColorRect.new()
	_dialogue_portrait_bg.color = Color(0.08, 0.08, 0.1)
	_dialogue_overlay.add_child(_dialogue_portrait_bg)

	_dialogue_portrait_sprite = TextureRect.new()
	_dialogue_portrait_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_dialogue_portrait_sprite.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	_dialogue_portrait_sprite.modulate = Color(1, 1, 1, 0.9)
	_dialogue_overlay.add_child(_dialogue_portrait_sprite)

	_npc_portrait_texture = load("res://sprites/npc/17_sprite.png")
	_dialogue_portrait_sprite.texture = _npc_portrait_texture

	_dialogue_name = Label.new()
	_dialogue_name.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	_dialogue_name.add_theme_font_size_override("font_size", 28)
	_dialogue_overlay.add_child(_dialogue_name)

	_dialogue_text = Label.new()
	_dialogue_text.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
	_dialogue_text.add_theme_font_size_override("font_size", 20)
	_dialogue_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dialogue_text.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_dialogue_overlay.add_child(_dialogue_text)

	for i in 6:
		var resp: Label = Label.new()
		resp.add_theme_color_override("font_color", Color(0.85, 0.8, 0.65))
		resp.add_theme_font_size_override("font_size", 18)
		resp.text = ""
		resp.visible = false
		resp.mouse_filter = Control.MOUSE_FILTER_STOP
		resp.gui_input.connect(_on_resp_gui_input.bind(resp))
		resp.mouse_entered.connect(_on_resp_mouse_entered.bind(resp))
		resp.mouse_exited.connect(_on_resp_mouse_exited.bind(resp))
		_dialogue_overlay.add_child(resp)
		_dialogue_responses.append(resp)

	_dialogue_prompt = Label.new()
	_dialogue_prompt.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	_dialogue_prompt.add_theme_font_size_override("font_size", 18)
	_dialogue_prompt.text = ""
	_dialogue_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_dialogue_overlay.add_child(_dialogue_prompt)

	add_child(_dialogue_overlay)
	get_viewport().connect("size_changed", _update_dialogue_layout)

func _setup_inventory_ui():
	_inv_overlay = CanvasLayer.new()
	_inv_overlay.layer = 110
	_inv_overlay.visible = false
	add_child(_inv_overlay)
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.85)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_inv_overlay.add_child(bg)
	var gr := Control.new()
	gr.name = "InvGrid"
	_inv_overlay.add_child(gr)
	PlayerStats.inventory.changed.connect(_draw_inventory)
	_draw_inventory()

func _draw_inventory():
	# Clear previous item labels
	for lbl in _inv_item_labels:
		if is_instance_valid(lbl): lbl.text = ""

	var vs := get_viewport().get_visible_rect().size
	var g: InventoryGrid = PlayerStats.inventory
	var gw: int = g.grid_w * (INV_CELL_SIZE + INV_GAP) - INV_GAP
	var gh: int = g.grid_h * (INV_CELL_SIZE + INV_GAP) - INV_GAP
	var ox: float = (vs.x - gw) * 0.5
	var oy: float = (vs.y - gh) * 0.5

	for child in _inv_overlay.get_children():
		if child is ColorRect and child.color.a > 0.1:
			child.set_size(vs)
			child.position = Vector2.ZERO

	var gr := _inv_overlay.get_node_or_null("InvGrid") as Control
	if not gr: return
	gr.position = Vector2(ox, oy)

	var nc: int = g.grid_w * g.grid_h
	if _inv_cells.size() < nc:
		for i in range(nc - _inv_cells.size()):
			var c := ColorRect.new()
			c.mouse_filter = Control.MOUSE_FILTER_IGNORE
			gr.add_child(c)
			_inv_cells.append(c)
			var l := Label.new()
			l.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
			l.add_theme_font_size_override("font_size", 11)
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			l.mouse_filter = Control.MOUSE_FILTER_IGNORE
			gr.add_child(l)
			_inv_item_labels.append(l)

	for y in g.grid_h:
		for x in g.grid_w:
			var idx: int = y * g.grid_w + x
			if idx >= _inv_cells.size(): continue
			_inv_cells[idx].set_size(Vector2(INV_CELL_SIZE, INV_CELL_SIZE))
			_inv_cells[idx].position = Vector2(x * (INV_CELL_SIZE + INV_GAP), y * (INV_CELL_SIZE + INV_GAP))
			_inv_cells[idx].color = Color(0.12, 0.12, 0.12, 0.6)

	for i in g.slots.size():
		var s: Dictionary = g.slots[i]
		var it: Item = s.item
		var ix: int = s.x
		var iy: int = s.y
		for dy in it.grid_size.y:
			for dx in it.grid_size.x:
				var ci: int = (iy + dy) * g.grid_w + (ix + dx)
				if ci < _inv_cells.size():
					_inv_cells[ci].color = it.icon_color
		var li: int = iy * g.grid_w + ix
		if li < _inv_item_labels.size():
			var txt: String = it.name
			if it.stack_count > 1: txt += " x" + str(it.stack_count)
			_inv_item_labels[li].text = txt

func _play_enemy_step(ent: Dictionary):
	if _footstep_sounds.is_empty(): return
	var player: AudioStreamPlayer = ent.get("audio_player")
	if not player or player.playing: return
	var dx: float = float(ent.grid_x) - _player_x
	var dy: float = float(ent.grid_y) - _player_y
	var dist: float = sqrt(dx * dx + dy * dy)
	var hear_radius: float = 6.0
	if dist >= hear_radius: return
	var vol: float = linear_to_db(clamp(1.0 - dist / hear_radius, 0.0, 1.0))
	vol = max(vol, -30.0)
	player.volume_db = vol
	player.stream = _footstep_sounds[randi() % _footstep_sounds.size()]
	player.pitch_scale = 0.9 + randf() * 0.2
	player.play()

func _setup_audio():
	_footstep_player = AudioStreamPlayer.new()
	add_child(_footstep_player)

	for i in 5:
		var path: String = "res://audio/sfx/footsteps/Tile_Mono_0" + str(i + 1) + ".wav"
		var stream := load(path) as AudioStream
		if stream:
			_footstep_sounds.append(stream)

func _unhandled_input(event):
	if _is_animating:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_TAB:
				if not _dialogue_active:
					_inv_open = not _inv_open
					_inv_overlay.visible = _inv_open
					if _inv_open: _draw_inventory()
			KEY_W, KEY_UP:
				if not _dialogue_active:
					_try_move_forward()
			KEY_S, KEY_DOWN:
				if not _dialogue_active:
					_try_move_backward()
			KEY_A, KEY_LEFT:
				if not _dialogue_active:
					var old_dir = _player_dir
					_player_dir = (_player_dir + 3) % 4
					_start_rotate(old_dir)
			KEY_D, KEY_RIGHT:
				if not _dialogue_active:
					var old_dir = _player_dir
					_player_dir = (_player_dir + 1) % 4
					_start_rotate(old_dir)
			KEY_Q:
				if not _dialogue_active:
					_try_strafe_left()
			KEY_E:
				if _dialogue_active:
					_advance_dialogue()
				elif not _dialogue_active:
					_try_strafe_right()
			KEY_SPACE, KEY_F:
				if _dialogue_active:
					_advance_dialogue()
				else:
					_try_interact()
			KEY_1:
				if _dialogue_active:
					_select_response(0)
			KEY_2:
				if _dialogue_active:
					_select_response(1)
			KEY_3:
				if _dialogue_active:
					_select_response(2)
			KEY_4:
				if _dialogue_active:
					_select_response(3)
			KEY_5:
				if _dialogue_active:
					_select_response(4)
			KEY_6:
				if _dialogue_active:
					_select_response(5)

func _try_move_forward():
	var vec: Vector2i = DIR_VECTORS[_player_dir]
	var nx: int = roundi(_player_x) + vec.x
	var ny: int = roundi(_player_y) + vec.y
	if _is_walkable(nx, ny):
		_start_move(nx, ny)

func _try_move_backward():
	var vec: Vector2i = DIR_VECTORS[_player_dir]
	var nx: int = roundi(_player_x) - vec.x
	var ny: int = roundi(_player_y) - vec.y
	if _is_walkable(nx, ny):
		_start_move(nx, ny)

func _try_strafe_left():
	var vec: Vector2i = DIR_VECTORS[(_player_dir + 3) % 4]
	var nx: int = roundi(_player_x) + vec.x
	var ny: int = roundi(_player_y) + vec.y
	if _is_walkable(nx, ny):
		_start_move(nx, ny)

func _try_strafe_right():
	var vec: Vector2i = DIR_VECTORS[(_player_dir + 1) % 4]
	var nx: int = roundi(_player_x) + vec.x
	var ny: int = roundi(_player_y) + vec.y
	if _is_walkable(nx, ny):
		_start_move(nx, ny)

func _try_interact():
	var vec: Vector2i = DIR_VECTORS[_player_dir]
	var fx: int = roundi(_player_x) + vec.x
	var fy: int = roundi(_player_y) + vec.y
	for ent: Dictionary in _entities:
		if ent.grid_x == fx and ent.grid_y == fy:
			if ent.type == "enemy":
				TransitionManager.change_scene("res://scenes/battle/node.tscn")
				return
			if ent.type == "npc" and ent.has("dialogue"):
				_start_dialogue(ent.dialogue as Array, ent.get("name", "Незнакомец"))
				return
			if ent.type == "object":
				_interact_object(ent)
				return

func _interact_object(obj: Dictionary):
	var ot: String = obj.get("object_type", "lore")
	var data: Dictionary = obj.get("data", {})
	var obj_name: String = data.get("name", "Объект")
	match ot:
		"lore":
			var text: String = data.get("description", "Ничего особенного.")
			_show_tip(obj_name + ": " + text)
		"container":
			var loot: Array = data.get("loot", [])
			if loot.is_empty():
				_show_tip(obj_name + " — пусто.")
			else:
				var item_name: String = loot[0] if loot.size() == 1 else loot[randi() % loot.size()]
				PlayerStats.inventory.try_add(Item.new(item_name, "Найден в " + obj_name, 2, Vector2i(1,1), 3))
				_show_tip(item_name + " добавлен в инвентарь.")
				data.loot = loot.duplicate()
				data.loot.erase(item_name)
		"rest":
			PlayerStats.restore_sanity(2)
			PlayerStats.heal(2)
			_show_tip("Вы отдыхаете у " + obj_name + ". +2 Здоровье, +2 Рассудок.")
		"hazard":
			PlayerStats.take_damage(data.get("damage", 2))
			_show_tip(data.get("description", "Ловушка!") + " -" + str(data.get("damage", 2)) + " HP.")

func _update_dialogue_layout():
	if not _dialogue_overlay or not _dialogue_overlay.visible:
		return
	var vs := get_viewport().get_visible_rect().size
	_dialogue_root.set_size(vs)
	_dialogue_root.position = Vector2.ZERO

	var portrait_w: float = vs.x * 0.35
	_dialogue_portrait_bg.set_size(Vector2(portrait_w, vs.y))
	_dialogue_portrait_bg.position = Vector2.ZERO

	if _npc_portrait_texture:
		var tex_size: Vector2 = _npc_portrait_texture.get_size()
		var scale: float = min(portrait_w / tex_size.x, vs.y / tex_size.y) * 0.8
		var spr_w: float = tex_size.x * scale
		var spr_h: float = tex_size.y * scale
		_dialogue_portrait_sprite.set_size(Vector2(spr_w, spr_h))
		_dialogue_portrait_sprite.position = Vector2((portrait_w - spr_w) * 0.5, (vs.y - spr_h) * 0.5)

	_dialogue_name.position = Vector2(portrait_w + 30, 40)
	_dialogue_name.set_size(Vector2(vs.x - portrait_w - 60, 50))

	_dialogue_text.position = Vector2(portrait_w + 40, 100)
	_dialogue_text.set_size(Vector2(vs.x - portrait_w - 80, vs.y * 0.4))

	var resp_y: float = vs.y * 0.55
	for i in _dialogue_responses.size():
		var lbl: Label = _dialogue_responses[i]
		lbl.position = Vector2(portrait_w + 50, resp_y)
		lbl.set_size(Vector2(vs.x - portrait_w - 90, 30))
		resp_y += 34

	_dialogue_prompt.position = Vector2(portrait_w + 20, vs.y - 40)
	_dialogue_prompt.set_size(Vector2(vs.x - portrait_w - 40, 30))

func _start_dialogue(nodes: Array, npc_name: String = "Незнакомец"):
	_dialogue_active = true
	_dialogue_nodes = nodes
	_dialogue_index = 0
	_dialogue_name.text = npc_name
	_dialogue_overlay.visible = true
	_update_dialogue_layout()
	_show_dialogue_node()

func _show_dialogue_node():
	for lbl in _dialogue_responses:
		lbl.visible = false
		lbl.text = ""

	if _dialogue_index < 0 or _dialogue_index >= _dialogue_nodes.size():
		_close_dialogue()
		return

	var node: Dictionary = _dialogue_nodes[_dialogue_index]
	_dialogue_text.text = node.get("text", "")
	var responses: Array = node.get("responses", [])
	_passive_cache.clear()
	var visible_count: int = 0

	for i in responses.size():
		if i >= _dialogue_responses.size():
			break
		var opt: Dictionary = responses[i]
		var show: bool = true
		var check: Dictionary = opt.get("check", {})
		if not check.is_empty() and check.get("passive", false):
			var r := SkillCheck.check(PlayerStats.get_skill(check.get("skill", "composure")), check.get("dc", 10))
			_passive_cache[i] = r.success
			show = r.success
		if show:
			_dialogue_responses[i].set_meta("resp_idx", visible_count)
			_dialogue_responses[i].text = str(visible_count + 1) + ". " + opt.get("text", "")
			_dialogue_responses[i].visible = true
			visible_count += 1
		else:
			_dialogue_responses[i].visible = false

	if visible_count == 0:
		_dialogue_prompt.text = "[E] Закрыть"
	else:
		_dialogue_prompt.text = "[1-" + str(visible_count) + "]"

func _advance_dialogue():
	var node: Dictionary = _dialogue_nodes[_dialogue_index]
	var responses: Array = node.get("responses", [])
	var visible := _count_visible_responses(responses)
	if visible == 0:
		_dialogue_index += 1
		_show_dialogue_node()
	else:
		_select_response(0)

func _count_visible_responses(responses: Array) -> int:
	var count: int = 0
	for i in responses.size():
		var opt: Dictionary = responses[i]
		var check: Dictionary = opt.get("check", {})
		if not check.is_empty() and check.get("passive", false):
			if not _passive_cache.get(i, false):
				continue
		count += 1
	return count

func _on_resp_mouse_entered(label: Label):
	if not _dialogue_active or _dialogue_busy:
		return
	label.add_theme_color_override("font_color", Color(1, 0.95, 0.8))

func _on_resp_mouse_exited(label: Label):
	label.add_theme_color_override("font_color", Color(0.85, 0.8, 0.65))

func _on_resp_gui_input(event: InputEvent, label: Label):
	if not _dialogue_active or _dialogue_busy:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var vis_idx: int = label.get_meta("resp_idx", -1)
		if vis_idx >= 0:
			_select_response(vis_idx)

func _select_response(idx: int):
	if _dialogue_busy:
		return
	_dialogue_busy = true

	var node: Dictionary = _dialogue_nodes[_dialogue_index]
	var responses: Array = node.get("responses", [])
	var actual_idx: int = -1
	var seen: int = 0
	for i in responses.size():
		var opt: Dictionary = responses[i]
		var check: Dictionary = opt.get("check", {})
		if not check.is_empty() and check.get("passive", false):
			if not _passive_cache.get(i, false):
				continue
		if seen == idx:
			actual_idx = i
			break
		seen += 1
	if actual_idx < 0 or actual_idx >= responses.size():
		_dialogue_busy = false
		return

	var chosen: Dictionary = responses[actual_idx]
	var chk: Dictionary = chosen.get("check", {})
	if chk.is_empty():
		_dialogue_busy = false
		_go_to_node(chosen.get("next", -1))
		return

	_dialogue_prompt.text = "Проверка " + SkillCheck.dc_description(chk.get("dc", 10)) + "..."
	var result := SkillCheck.check(PlayerStats.get_skill(chk.get("skill", "composure")), chk.get("dc", 10))
	if result.success:
		_dialogue_prompt.text = "✓ Успех!  (" + str(result.total) + ")"
	else:
		_dialogue_prompt.text = "✗ Провал  (" + str(result.total) + ")"
	await get_tree().create_timer(0.6).timeout

	_dialogue_busy = false
	if result.success:
		_go_to_node(chosen.get("next_pass", chosen.get("next", -1)))
	else:
		_go_to_node(chosen.get("next_fail", chosen.get("next", -1)))

func _go_to_node(idx: int):
	if idx < 0:
		_close_dialogue()
	else:
		_dialogue_index = idx
		_show_dialogue_node()

func _close_dialogue():
	_dialogue_active = false
	_dialogue_overlay.visible = false

func _is_walkable(x: int, y: int) -> bool:
	if x < 0 or x >= _map_data[0].size() or y < 0 or y >= _map_data.size():
		return false
	var tile_val: int = _map_data[y][x]
	return tile_val != TILE_WALL and tile_val != TILE_BLOCKED

func _start_move(tx: int, ty: int):
	_is_animating = true
	_anim_timer = 0.0
	_anim_from_x = _player_x
	_anim_from_y = _player_y
	_anim_to_x = float(tx)
	_anim_to_y = float(ty)
	_anim_from_angle = _current_angle
	_anim_to_angle = _current_angle
	if not _footstep_sounds.is_empty():
		_footstep_player.stream = _footstep_sounds[randi() % _footstep_sounds.size()]
		_footstep_player.play()
	set_process(true)

func _start_rotate(old_dir: int):
	_is_animating = true
	_anim_timer = 0.0
	_anim_from_x = _player_x
	_anim_to_x = _player_x
	_anim_from_y = _player_y
	_anim_to_y = _player_y
	_anim_from_angle = DIR_ANGLES[old_dir]
	_anim_to_angle = DIR_ANGLES[_player_dir]
	set_process(true)

func _process(delta):
	_awareness_timer -= delta
	if _awareness_timer <= 0.0:
		_awareness_timer = _awareness_interval + randf_range(-2.0, 2.0)
		_try_awareness()

	_update_enemies(delta)

	if not _is_animating:
		return
	_anim_timer += delta
	var dur: float = turn_duration if _anim_from_angle != _anim_to_angle and _anim_from_x == _anim_to_x else move_duration
	var t: float = min(_anim_timer / dur, 1.0)
	t = t * t * t * (t * (6.0 * t - 15.0) + 10.0)
	_player_x = lerp(_anim_from_x, _anim_to_x, t)
	_player_y = lerp(_anim_from_y, _anim_to_y, t)
	_current_angle = lerp_angle(_anim_from_angle, _anim_to_angle, t)
	_refresh()
	if t >= 1.0:
		_is_animating = false
		_check_entity()

func _check_entity():
	var rx: int = roundi(_player_x)
	var ry: int = roundi(_player_y)
	for ent: Dictionary in _entities:
		if ent.grid_x == rx and ent.grid_y == ry:
			if ent.type == "enemy":
				TransitionManager.change_scene("res://scenes/battle/node.tscn")

func _update_enemies(delta: float):
	for ent in _entities:
		if ent.type != "enemy": continue
		if ent.get("move_progress", 1.0) < 1.0:
			_tick_enemy_anim(ent, delta)
			continue

		ent.move_timer = ent.get("move_timer", 0.0) - delta
		if ent.move_timer > 0.0: continue

		var interval: float = 0.5 if ent.get("chase_active", false) else 0.9
		ent.move_timer = interval + randf_range(-0.1, 0.1)

		var px: int = roundi(_player_x)
		var py: int = roundi(_player_y)
		var dist: int = abs(ent.grid_x - px) + abs(ent.grid_y - py)

		if dist <= 8 and not _is_blocked(ent.grid_x, ent.grid_y, px, py):
			_try_detect(ent, px, py)

		if ent.get("chase_active", false):
			_enemy_chase(ent, px, py, delta)
		else:
			_enemy_patrol(ent)

func _try_detect(ent: Dictionary, px: int, py: int):
	var dx: int = px - ent.grid_x
	var dy: int = py - ent.grid_y
	var f: int = ent.facing
	var vec: Vector2i = DIR_VECTORS[f]
	var dot: int = vec.x * dx + vec.y * dy

	var chase_chance: float = 0.0
	if dot > 0:
		chase_chance = 1.0
	elif dot == 0:
		chase_chance = 0.5
	else:
		var moving: bool = _is_animating or _dialogue_active
		chase_chance = 0.25 if moving else 0.0

	if randf() < chase_chance and not ent.get("chase_active", false):
		ent.chase_active = true

func _is_blocked(x1: int, y1: int, x2: int, y2: int) -> bool:
	var steps: int = int(sqrt(float((x2-x1)*(x2-x1) + (y2-y1)*(y2-y1))) * 2.0) + 1
	for i in range(1, steps):
		var t: float = float(i) / float(steps)
		var gx: int = int(round(lerp(float(x1), float(x2), t)))
		var gy: int = int(round(lerp(float(y1), float(y2), t)))
		if gx == x2 and gy == y2: break
		if gx >= 0 and gx < _map_data[0].size() and gy >= 0 and gy < _map_data.size():
			if _map_data[gy][gx] == TILE_WALL or _map_data[gy][gx] == TILE_BLOCKED:
				return true
	return false

func _tick_enemy_anim(ent: Dictionary, delta: float):
	ent.move_progress = min(ent.get("move_progress", 1.0) + delta * 6.0, 1.0)
	var t: float = ent.move_progress
	t = t * t * (3.0 - 2.0 * t)
	ent.anim_x = lerp(ent.get("_from_x", float(ent.grid_x)), float(ent.grid_x), t)
	ent.anim_y = lerp(ent.get("_from_y", float(ent.grid_y)), float(ent.grid_y), t)
	if ent.move_progress >= 1.0:
		ent.anim_x = float(ent.grid_x)
		ent.anim_y = float(ent.grid_y)
		ent.stuck_count = 0
	_refresh()

func _enemy_patrol(ent: Dictionary):
	var f: int = ent.facing
	var vec: Vector2i = DIR_VECTORS[f]
	var nx: int = ent.grid_x + vec.x
	var ny: int = ent.grid_y + vec.y
	if _is_walkable(nx, ny):
		_enemy_step_to(ent, nx, ny, f)
		return

	var dirs: Array[int] = [f, (f + 1) % 4, (f + 3) % 4, (f + 2) % 4]
	for d in dirs:
		var v: Vector2i = DIR_VECTORS[d]
		var tx: int = ent.grid_x + v.x
		var ty: int = ent.grid_y + v.y
		if _is_walkable(tx, ty):
			if d == f:
				_enemy_step_to(ent, tx, ty, d)
			else:
				ent.facing = d
			return

func _enemy_chase(ent: Dictionary, px: int, py: int, delta: float):
	var dist: int = abs(ent.grid_x - px) + abs(ent.grid_y - py)
	var blocked: bool = _is_blocked(ent.grid_x, ent.grid_y, px, py)

	if dist > 8 or blocked:
		var timer: float = ent.get("chase_lost_timer", 2.0) - delta
		ent.chase_lost_timer = timer
		if timer <= 0.0:
			ent.chase_active = false
			ent.erase("chase_lost_timer")
			return
	else:
		ent.erase("chase_lost_timer")

	var f: int = ent.facing
	var best_dir: int = f
	var best_prio: int = -1
	var dirs: Array[int] = [f, (f + 1) % 4, (f + 3) % 4, (f + 2) % 4]
	for d in dirs:
		var v: Vector2i = DIR_VECTORS[d]
		var tx: int = ent.grid_x + v.x
		var ty: int = ent.grid_y + v.y
		if not _is_walkable(tx, ty): continue
		var ndx: int = abs(px - tx)
		var ndy: int = abs(py - ty)
		var prio: int = 10 - (ndx + ndy)
		if d != f: prio -= 1
		if prio > best_prio:
			best_prio = prio
			best_dir = d

	if best_dir == f:
		var v: Vector2i = DIR_VECTORS[f]
		_enemy_step_to(ent, ent.grid_x + v.x, ent.grid_y + v.y, f)
	else:
		ent.facing = best_dir

	if ent.grid_x == px and ent.grid_y == py:
		TransitionManager.change_scene("res://scenes/battle/node.tscn")

func _enemy_step_to(ent: Dictionary, nx: int, ny: int, facing: int):
	ent._from_x = float(ent.grid_x)
	ent._from_y = float(ent.grid_y)
	ent.grid_x = nx
	ent.grid_y = ny
	ent.facing = facing
	ent.move_progress = 0.0
	_play_enemy_step(ent)

func _show_tip(msg: String):
	if not _dialogue_active and _awareness_label:
		_awareness_label.text = msg
		get_tree().create_timer(5.0).timeout.connect(func():
			if is_instance_valid(_awareness_label):
				_awareness_label.text = ""
		, CONNECT_ONE_SHOT)

func _try_awareness():
	if _dialogue_active:
		return
	if not _awareness_label:
		return
	var result := SkillCheck.check(PlayerStats.get_skill("intuition"), 12)
	if result.success and not _awareness_pool.is_empty():
		var msg: String = _awareness_pool[randi() % _awareness_pool.size()]
		_awareness_label.text = msg
		get_tree().create_timer(6.0).timeout.connect(func():
			if is_instance_valid(_awareness_label):
				_awareness_label.text = ""
		, CONNECT_ONE_SHOT)

func _setup_minimap():
	_minimap = Control.new()
	_minimap.name = "MiniMap"
	_minimap.modulate = Color(1, 1, 1, 0.7)
	$CRT_Root/GameViewport/UI.add_child(_minimap)
	_minimap.draw.connect(_draw_minimap)

func _draw_minimap():
	var cs: int = 5
	var mw: int = 25 * cs
	var mh: int = 13 * cs
	_minimap.set_size(Vector2(mw, mh))
	_minimap.position = Vector2(829, 0)

	var mx: int = roundi(_player_x)
	var my: int = roundi(_player_y)
	var tw: int = mw / cs
	var th: int = mh / cs
	var ox: int = mx - tw / 2
	var oy: int = my - th / 2

	for by in range(th):
		for bx in range(tw):
			var gx: int = ox + bx
			var gy: int = oy + by
			var c: Color
			if gx == mx and gy == my:
				c = Color(0.2, 0.9, 0.3, 0.85)
			elif gx >= 0 and gx < _map_data[0].size() and gy >= 0 and gy < _map_data.size():
				var t: int = _map_data[gy][gx]
				if t == TILE_WALL or t == TILE_BLOCKED:
					c = Color(0.15, 0.12, 0.1, 0.6)
				else:
					c = Color(0.25, 0.22, 0.18, 0.35)
			else:
				c = Color(0, 0, 0, 0)
			_minimap.draw_rect(Rect2(bx * cs, by * cs, cs, cs), c)

func _refresh():
	if _renderer:
		_renderer.update_view(_player_x + 0.5, _player_y + 0.5, _current_angle, _map_data, _entities)
	if _label:
		_label.text = DIR_NAMES[_player_dir]
	if _minimap:
		_minimap.queue_redraw()
