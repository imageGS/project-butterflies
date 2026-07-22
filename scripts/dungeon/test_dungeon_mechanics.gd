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
const TILE_RAIL := 9

@export var move_duration: float = 0.25
@export var turn_duration: float = 0.2

var _player_x: float = 10.0
var _player_y: float = 3.0
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

var _npc_portrait_texture: Texture2D
var _dialogue_prompt: Label
var _dialogue_responses: Array[Label] = []
var _dialogue_nodes: Array = []
var _dialogue_index: int = 0
var _dialogue_active: bool = false
var _dialogue_busy: bool = false
var _passive_cache: Dictionary = {}

var _dialogue_portrait_on_pos: Vector2
var _dialogue_portrait_off_pos: Vector2
var _dialogue_box_on_pos: Vector2
var _dialogue_box_off_pos: Vector2

@onready var _renderer: Control = $CRT_Root/GameViewport/UI/CentralViewport/DungeonView
@onready var _label: Label = $CRT_Root/GameViewport/UI/CentralViewport/DungeonView/InfoLabel
@onready var _awareness_label: Label = $CRT_Root/GameViewport/UI/AwarenessLabel
@onready var _minimap_ctrl: MinimapControl = $CRT_Root/GameViewport/UI/HUDOverlay/UL_Window/Minimap
@onready var _dialogue_portrait_window: TextureRect = $CRT_Root/GameViewport/UI/HUDOverlay/DialoguePortraitWindow
@onready var _dialogue_box_window: TextureRect = $CRT_Root/GameViewport/UI/HUDOverlay/DialogueBoxWindow
@onready var _dialogue_portrait: TextureRect = $CRT_Root/GameViewport/UI/HUDOverlay/DialoguePortraitWindow/DialoguePortrait
@onready var _dialogue_name: Label = $CRT_Root/GameViewport/UI/HUDOverlay/DialoguePortraitWindow/DialogueName
@onready var _dialogue_text: Label = $CRT_Root/GameViewport/UI/HUDOverlay/DialogueBoxWindow/DialogueText
@onready var _dialogue_responses_root: VBoxContainer = $CRT_Root/GameViewport/UI/DialogueResponses

# HUD elements above UI_BACK (z_index 5+)
var _hud_balls: Array[TextureRect] = []
var _hud_ball_angles: Array[float] = [0.0, 0.0, 0.0, 0.0]
var _hud_base_pos: Vector2

var _ul_window: TextureRect
var _dl_window: TextureRect
var _stats_panel: StatsPanel
var _ul_open: bool = false
var _dl_open: bool = false
var _ul_on_pos: Vector2
var _dl_on_pos: Vector2
var _ul_off_pos: Vector2
var _dl_off_pos: Vector2

@export var shelter_mode: bool = false  # deprecated, station_data defines the level
@export var station_data: StationData
@export_group("Lighting")
@export var light_ambient: float = 0.15:
	set(v): light_ambient = v; _apply_light_settings()
@export var light_dither: float = 6.0:
	set(v): light_dither = v; _apply_light_settings()
@export var light_pixel_size: float = 2.0:
	set(v): light_pixel_size = v; _apply_light_settings()
@export var light_glow_amount: float = 0.0:
	set(v): light_glow_amount = v; _apply_light_settings()
@export var light_softness: float = 0.3:
	set(v): light_softness = v; _apply_light_settings()
@export var light_curve: float = 1.6:
	set(v): light_curve = v; _apply_light_settings()
@export var player_light_radius: float = 300.0:
	set(v): player_light_radius = v; _apply_player_light()
@export var player_light_intensity: float = 1.2:
	set(v): player_light_intensity = v; _apply_player_light()
@export var player_light_color: Color = Color(1.0, 0.95, 0.8):
	set(v): player_light_color = v; _apply_player_light()

var _light_mat: ShaderMaterial
var _player_light_node: Node2D
var _flashlight_on: bool = true

func _apply_light_settings():
	if not _light_mat: return
	_light_mat.set_shader_parameter("ambient", light_ambient)
	_light_mat.set_shader_parameter("dither_levels", light_dither)
	_light_mat.set_shader_parameter("dither_pixel_size", light_pixel_size)
	_light_mat.set_shader_parameter("light_glow", light_glow_amount)
	_light_mat.set_shader_parameter("softness", light_softness)
	_light_mat.set_shader_parameter("light_curve", light_curve)

func _apply_player_light():
	if not _player_light_node: return
	_player_light_node.radius = player_light_radius
	_player_light_node.intensity = player_light_intensity
	_player_light_node.color = player_light_color

func _ready():
	_load_station()
	_setup_entities()
	_current_angle = DIR_ANGLES[_player_dir]
	_setup_dialogue_ui()
	_setup_audio()
	_setup_hud()
	_setup_lighting()
	_refresh()
	if station_data and station_data.station_name == "Убежище":
		return
	_awareness_timer = _awareness_interval

func _load_station():
	if not PlayerStats.current_station:
		if station_data:
			PlayerStats.current_station = station_data
		else:
			PlayerStats.current_station = load("res://resources/stations/shelter.tres")
	station_data = PlayerStats.current_station

	var spawn: Vector2i = station_data.spawn
	var dir: int = station_data.spawn_dir
	if PlayerStats.flags.has("_transition_spawn"):
		spawn = PlayerStats.flags["_transition_spawn"]
		PlayerStats.flags.erase("_transition_spawn")
	if PlayerStats.flags.has("_transition_dir"):
		dir = PlayerStats.flags["_transition_dir"]
		PlayerStats.flags.erase("_transition_dir")

	_build_from_station_data()
	if _renderer:
		if station_data.ceiling_enabled and not station_data.ceiling_texture.is_empty():
			_renderer.set_ceiling(station_data.ceiling_texture)
		var meta := MapMeta.new()
		meta.load_from_json(station_data.map_file.get_basename() + ".meta.json")
		_renderer.wall_decors = meta.cells
		if meta.cells.has("_floor_"):
			var fd: Dictionary = meta.cells["_floor_"]
			var ft: String = fd.get("texture", "")
			if not ft.is_empty():
				_renderer.set_floor_texture(ft)
		meta.cells.erase("_floor_")
		_renderer.wall_decors = meta.cells
	_player_x = float(spawn.x)
	_player_y = float(spawn.y)
	_player_dir = dir

func _build_test_level():
	if station_data:
		_build_from_station_data()
		return
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
				"O": row.append(TILE_WALL)
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

	# Выходы на внешнем кольце
	_set_tile(10, 1, TILE_EXIT)
	_set_tile(2, 10, TILE_EXIT)
	_set_tile(46, 10, TILE_EXIT)

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
	if PlayerStats._pending_corpse.x >= 0:
		_entities.append({
			"grid_x": PlayerStats._pending_corpse.x, "grid_y": PlayerStats._pending_corpse.y,
			"color": Color(0.5, 0.1, 0.1, 0.6),
			"type": "object", "object_type": "lore",
			"data": { "name": "Труп", "description": "Вы убили это существо в бою." },
		})
		PlayerStats._pending_corpse = Vector2i(-1, -1)

	var is_shelter: bool = station_data != null and station_data.station_name == "Убежище"
	if station_data and not station_data.entity_spawns.is_empty():
		for spawn: EntitySpawn in station_data.entity_spawns:
			var ent: Dictionary = _create_entity_from_spawn(spawn)
			if not ent.is_empty():
				_entities.append(ent)
	elif is_shelter:
		_entities.append({ "grid_x": 3, "grid_y": 5, "color": Color(0.3, 0.5, 0.7), "type": "object", "object_type": "rest",
			"data": { "name": "кровать", "description": "Старая кровать." }})
		_entities.append({ "grid_x": 10, "grid_y": 10, "color": Color(0.4, 0.8, 0.4), "type": "object", "object_type": "lore",
			"data": { "name": "ТВ", "description": "Работает. Помехи, потом голос: «...проход открыт в западном крыле». И снова помехи." }})
	else:
		_setup_fallback_entities()

	# Маркеры выходов из station_data
	if station_data:
		for exit: ExitData in station_data.exits:
			_entities.append({ "grid_x": exit.position.x, "grid_y": exit.position.y, "color": Color(1, 0.9, 0.2, 0.9), "type": "exit_marker" })

func _create_entity_from_spawn(spawn: EntitySpawn) -> Dictionary:
	match spawn.type:
		EntitySpawn.Type.ENEMY:
			return _create_enemy_entity(spawn)
		EntitySpawn.Type.NPC:
			return _create_npc_entity(spawn)
		EntitySpawn.Type.ITEM:
			return _create_item_entity(spawn)
		EntitySpawn.Type.OBJECT:
			return _create_object_entity(spawn)
	return {}

func _create_enemy_entity(spawn: EntitySpawn) -> Dictionary:
	var subtype: String = spawn.subtype
	if subtype.is_empty(): subtype = "bunny"
	var tex_base: String = "res://sprites/enemy/bunny/bunny_enemy" if subtype == "bunny" else "res://sprites/enemy/scav_enemy_1"
	var tex_f: Texture2D = load(tex_base + ".png") if subtype == "bunny" else load(tex_base + ".png")
	var tex_b: Texture2D = load("res://sprites/enemy/bunny/bunny_enemy_back.png") if subtype == "bunny" else tex_f
	var tex_l: Texture2D = load("res://sprites/enemy/bunny/bunny_enemy_left.png") if subtype == "bunny" else tex_f
	var tex_r: Texture2D = load("res://sprites/enemy/bunny/bunny_enemy_right.png") if subtype == "bunny" else tex_f
	var tex_c: Texture2D = load("res://sprites/enemy/bunny/bunny_enemy_chase.png") if subtype == "bunny" else tex_f
	var audio := AudioStreamPlayer.new()
	audio.volume_db = -4.0
	add_child(audio)
	return {
		"grid_x": spawn.position.x, "grid_y": spawn.position.y,
		"anim_x": float(spawn.position.x), "anim_y": float(spawn.position.y),
		"color": Color(0.8, 0.2, 0.2),
		"type": "enemy",
		"facing": spawn.facing,
		"textures": { "front": tex_f, "back": tex_b, "left": tex_l, "right": tex_r, "chase": tex_c },
		"move_progress": 1.0,
		"move_timer": randf_range(0.5, 1.0),
		"chase_active": false,
		"audio_player": audio,
	}

func _create_npc_entity(spawn: EntitySpawn) -> Dictionary:
	var subtype: String = spawn.subtype
	if subtype.is_empty(): subtype = "wanderer"
	var portrait: Texture2D = load("res://sprites/npc/17_sprite.png")
	var name: String = "Незнакомец"
	var dialogue: Array = []
	if subtype == "wanderer":
		var file := FileAccess.get_file_as_string("res://dialogues/wanderer.json")
		if file:
			var data: Dictionary = JSON.parse_string(file)
			if data:
				name = data.get("name", name)
				dialogue = data.get("nodes", [])
	return {
		"grid_x": spawn.position.x, "grid_y": spawn.position.y,
		"color": Color(0.2, 0.6, 0.2),
		"type": "npc",
		"name": name,
		"texture": portrait,
		"dialogue": dialogue,
	}

func _create_item_entity(spawn: EntitySpawn) -> Dictionary:
	var subtype: String = spawn.subtype
	if subtype.is_empty(): subtype = "misc"
	return {
		"grid_x": spawn.position.x, "grid_y": spawn.position.y,
		"color": Color(0.2, 0.9, 0.2),
		"type": "object",
		"object_type": "container",
		"data": { "name": subtype, "description": "Лежит на полу.", "loot": [subtype] },
	}

func _create_object_entity(spawn: EntitySpawn) -> Dictionary:
	var subtype: String = spawn.subtype
	if subtype.is_empty(): subtype = "lore"
	var data: Dictionary = spawn.extra.duplicate()
	if not data.has("name"):
		data.name = subtype
	if not data.has("description"):
		data.description = "Ничего особенного."
	return {
		"grid_x": spawn.position.x, "grid_y": spawn.position.y,
		"color": Color(0.6, 0.6, 0.6),
		"type": "object",
		"object_type": subtype,
		"data": data,
	}

func _setup_fallback_entities():
	# Враги
	var tex_f := load("res://sprites/enemy/bunny/bunny_enemy.png")
	var tex_b := load("res://sprites/enemy/bunny/bunny_enemy_back.png")
	var tex_l := load("res://sprites/enemy/bunny/bunny_enemy_left.png")
	var tex_r := load("res://sprites/enemy/bunny/bunny_enemy_right.png")
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

	# Объекты
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

	# NPC
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
	# Store on/off positions for slide animations
	_dialogue_portrait_on_pos = _dialogue_portrait_window.position
	_dialogue_portrait_off_pos = _dialogue_portrait_on_pos - Vector2(300, 0)
	_dialogue_box_on_pos = _dialogue_box_window.position
	_dialogue_box_off_pos = _dialogue_box_on_pos + Vector2(0, 300)

	# Hide windows off-screen initially
	_dialogue_portrait_window.position = _dialogue_portrait_off_pos
	_dialogue_box_window.position = _dialogue_box_off_pos
	_dialogue_portrait_window.visible = false
	_dialogue_box_window.visible = false
	_dialogue_responses_root.visible = false

	# Default portrait texture
	_npc_portrait_texture = load("res://sprites/npc/17_sprite.png")
	_dialogue_portrait.texture = _npc_portrait_texture

	# Create response labels inside the bottom panel container
	for i in 6:
		var resp: Label = Label.new()
		resp.add_theme_color_override("font_color", Color(0.85, 0.8, 0.65))
		resp.add_theme_font_size_override("font_size", 18)
		resp.text = ""
		resp.visible = false
		resp.mouse_filter = Control.MOUSE_FILTER_STOP
		resp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		resp.gui_input.connect(_on_resp_gui_input.bind(resp))
		resp.mouse_entered.connect(_on_resp_mouse_entered.bind(resp))
		resp.mouse_exited.connect(_on_resp_mouse_exited.bind(resp))
		_dialogue_responses_root.add_child(resp)
		_dialogue_responses.append(resp)

	_dialogue_prompt = Label.new()
	_dialogue_prompt.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	_dialogue_prompt.add_theme_font_size_override("font_size", 18)
	_dialogue_prompt.text = ""
	_dialogue_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_dialogue_prompt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dialogue_responses_root.add_child(_dialogue_prompt)

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
			KEY_W, KEY_UP:
				if not _dialogue_active:
					_try_move_forward()
					_held_cooldown = 0.12
			KEY_S, KEY_DOWN:
				if not _dialogue_active:
					_try_move_backward()
					_held_cooldown = 0.12
			KEY_A, KEY_LEFT:
				if not _dialogue_active:
					var old_dir = _player_dir
					_player_dir = (_player_dir + 3) % 4
					_start_rotate(old_dir)
					_held_cooldown = 0.08
			KEY_D, KEY_RIGHT:
				if not _dialogue_active:
					var old_dir = _player_dir
					_player_dir = (_player_dir + 1) % 4
					_start_rotate(old_dir)
					_held_cooldown = 0.08
			KEY_R:
				if not _dialogue_active:
					var old_dir = _player_dir
					_player_dir = (_player_dir + 2) % 4
					_start_rotate(old_dir)
					_held_cooldown = 0.08
			KEY_Q:
				if not _dialogue_active:
					_try_strafe_left()
					_held_cooldown = 0.12
			KEY_E:
				if _dialogue_active:
					_advance_dialogue()
				elif not _dialogue_active:
					_try_strafe_right()
					_held_cooldown = 0.12
			KEY_SPACE, KEY_F:
				if _dialogue_active:
					_advance_dialogue()
				else:
					_try_interact()
			KEY_L:
				if not _dialogue_active:
					_flashlight_on = not _flashlight_on
			KEY_M:
				if not _dialogue_active and _ul_window:
					_ul_open = _toggle_window(_ul_window, _ul_open, _ul_on_pos, _ul_off_pos)
			KEY_H:
				if not _dialogue_active and _dl_window:
					_dl_open = _toggle_window(_dl_window, _dl_open, _dl_on_pos, _dl_off_pos)
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
			PlayerStats._limb_snapshot.clear()
			if _stats_panel: _stats_panel.refresh()
			_show_tip("Вы отдыхаете у " + obj_name + ". +2 Здоровье, +2 Рассудок.")
		"hazard":
			PlayerStats.take_damage(data.get("damage", 2))
			if _stats_panel: _stats_panel.refresh()
			_show_tip(data.get("description", "Ловушка!") + " -" + str(data.get("damage", 2)) + " HP.")

func _set_dialogue_portrait(portrait_path: String):
	if portrait_path.is_empty():
		_dialogue_portrait.texture = _npc_portrait_texture
		return
	var tex := load(portrait_path) as Texture2D
	if tex:
		_dialogue_portrait.texture = tex
	else:
		_dialogue_portrait.texture = _npc_portrait_texture

func _start_dialogue(nodes: Array, npc_name: String = "Незнакомец"):
	_dialogue_active = true
	_dialogue_nodes = nodes
	_dialogue_index = 0
	_dialogue_name.text = npc_name
	_dialogue_portrait_window.visible = true
	_dialogue_box_window.visible = true
	_dialogue_responses_root.visible = true
	var tw := create_tween().set_parallel()
	tw.tween_property(_dialogue_portrait_window, "position", _dialogue_portrait_on_pos, 0.25).set_ease(Tween.EASE_OUT)
	tw.tween_property(_dialogue_box_window, "position", _dialogue_box_on_pos, 0.25).set_ease(Tween.EASE_OUT)
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
	var portrait_path: String = node.get("portrait", "")
	_set_dialogue_portrait(portrait_path)
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

func _setup_hud():
	var hud: Control = $CRT_Root/GameViewport/UI/HUDOverlay
	if not hud: return
	_hud_base_pos = hud.position
	for ball_name in ["UL_Ball", "UR_Ball", "DL_Ball", "DR_Ball"]:
		var ball: TextureRect = hud.get_node_or_null(ball_name)
		if ball: _hud_balls.append(ball)
	_ul_window = hud.get_node_or_null("UL_Window")
	_dl_window = hud.get_node_or_null("DL_Window")
	if _ul_window:
		_ul_on_pos = _ul_window.position
		_ul_off_pos = _ul_on_pos - Vector2(_ul_window.size.x + 20, 0)
		_ul_window.position = _ul_off_pos
	if _dl_window:
		_dl_on_pos = _dl_window.position
		_dl_off_pos = _dl_on_pos - Vector2(_dl_window.size.x + 20, 0)
		_dl_window.position = _dl_off_pos
		_stats_panel = StatsPanel.new()
		_stats_panel.set_size(_dl_window.size - Vector2(20, 20))
		_stats_panel.position = Vector2(10, 10)
		_dl_window.add_child(_stats_panel)

func _setup_lighting():
	var shader := load("res://shaders/light_fog.gdshader") as Shader
	if not shader: return
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("occlusion_enabled", false)
	_light_mat = mat
	_apply_light_settings()
	
	var cr := ColorRect.new()
	cr.name = "LightOverlay"
	cr.set_anchors_preset(Control.PRESET_FULL_RECT)
	cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cr.material = mat
	$CRT_Root/GameViewport.add_child(cr)
	$CRT_Root/GameViewport.move_child(cr, $CRT_Root/GameViewport.get_child_count() - 1)
	
	var pl: Node2D = load("res://scripts/player_light.gd").new() as Node2D
	pl.name = "PlayerLight"
	_player_light_node = pl
	_apply_player_light()
	$CRT_Root/GameViewport.add_child(pl)

func _update_lighting():
	if not _light_mat or not _player_light_node: return
	var vp := $CRT_Root/GameViewport
	if not vp: return
	var pos_arr := PackedVector2Array()
	var rad_arr := PackedFloat32Array()
	var col_arr := PackedVector3Array()
	var int_arr := PackedFloat32Array()
	var n: Node2D = _player_light_node
	pos_arr.append(n.position)
	rad_arr.append(n.radius)
	col_arr.append(Vector3(n.color.r, n.color.g, n.color.b))
	var intensity: float = player_light_intensity if _flashlight_on else 0.01
	int_arr.append(intensity)
	_light_mat.set_shader_parameter("light_count", 1)
	_light_mat.set_shader_parameter("light_positions", pos_arr)
	_light_mat.set_shader_parameter("light_radii", rad_arr)
	_light_mat.set_shader_parameter("light_colors", col_arr)
	_light_mat.set_shader_parameter("light_intensities", int_arr)
	_light_mat.set_shader_parameter("obstructor_count", 0)

func _toggle_window(win: TextureRect, open_ref: bool, on_pos: Vector2, off_pos: Vector2) -> bool:
	var tw := create_tween()
	if open_ref:
		tw.tween_property(win, "position", off_pos, 0.2).set_ease(Tween.EASE_IN)
	else:
		tw.tween_property(win, "position", on_pos, 0.2).set_ease(Tween.EASE_OUT)
	return not open_ref

func _shake_hud():
	var hud: Control = $CRT_Root/GameViewport/UI/HUDOverlay
	if not hud: return
	var tw := create_tween()
	tw.tween_property(hud, "position", _hud_base_pos + Vector2(randf_range(-3, 3), randf_range(-2, 2)), 0.04)
	tw.tween_property(hud, "position", _hud_base_pos, 0.08)

func _tick_hud_balls(delta: float):
	for i in _hud_balls.size():
		_hud_ball_angles[i] += delta * 1.2
		_hud_balls[i].rotation = _hud_ball_angles[i]

func _ask_leave_station():
	PlayerStats.current_station = load("res://resources/stations/shelter.tres")
	var exit_dialogue := [
		{ "text": "Выход из станции. Уйти?", "responses": [
			{ "text": "Да, уйти в убежище.", "next": 1 },
			{ "text": "Нет, остаться.", "next": -1 },
		]},
		{ "text": "Вы покидаете станцию и направляетесь в убежище.", "responses": [
			{ "text": "...", "next": -2 },
		]},
	]
	_start_dialogue(exit_dialogue, "Выход")

func _go_to_node(idx: int):
	if idx <= -2:
		_close_dialogue()
		TransitionManager.change_scene("res://scenes/dungeon/test_dungeon_mechanics.tscn")
	elif idx < 0:
		_close_dialogue()
	else:
		_dialogue_index = idx
		_show_dialogue_node()

func _close_dialogue():
	_dialogue_active = false
	var tw := create_tween().set_parallel()
	tw.tween_property(_dialogue_portrait_window, "position", _dialogue_portrait_off_pos, 0.2).set_ease(Tween.EASE_IN)
	tw.tween_property(_dialogue_box_window, "position", _dialogue_box_off_pos, 0.2).set_ease(Tween.EASE_IN)
	await tw.finished
	_dialogue_portrait_window.visible = false
	_dialogue_box_window.visible = false
	_dialogue_responses_root.visible = false

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
	if station_data and station_data.tileset:
		var tile_val: int = _map_data[ty][tx] if ty < _map_data.size() and tx < _map_data[ty].size() else 0
		var ts := station_data.tileset as StationTileset
		if ts:
			var snd := ts.get_step_sound_for_tile(tile_val) as AudioStream
			if snd:
				_footstep_player.stream = snd
				_footstep_player.play()
	_shake_hud()
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
	_shake_hud()

func _process(delta):
	_update_lighting()
	_awareness_timer -= delta
	if _awareness_timer <= 0.0:
		_awareness_timer = _awareness_interval + randf_range(-2.0, 2.0)
		_try_awareness()

	_update_enemies(delta)
	_tick_hud_balls(delta)

	if not _is_animating:
		_process_held_input(delta)
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

var _held_cooldown: float = 0.0
var _world_frozen: bool = false

func _process_held_input(delta: float):
	_held_cooldown -= delta
	if _held_cooldown > 0.0 or _dialogue_active: return
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		_try_move_forward(); _held_cooldown = 0.15
	elif Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		_try_move_backward(); _held_cooldown = 0.15
	elif Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		var old = _player_dir; _player_dir = (_player_dir + 3) % 4; _start_rotate(old); _held_cooldown = 0.10
	elif Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		var old = _player_dir; _player_dir = (_player_dir + 1) % 4; _start_rotate(old); _held_cooldown = 0.10
	elif Input.is_key_pressed(KEY_Q):
		_try_strafe_left(); _held_cooldown = 0.15
	elif Input.is_key_pressed(KEY_E):
		_try_strafe_right(); _held_cooldown = 0.15
	elif Input.is_key_pressed(KEY_R):
		var old = _player_dir; _player_dir = (_player_dir + 2) % 4; _start_rotate(old); _held_cooldown = 0.10

func _check_entity():
	var rx: int = roundi(_player_x)
	var ry: int = roundi(_player_y)
	for ent: Dictionary in _entities:
		if ent.grid_x == rx and ent.grid_y == ry:
			if ent.type == "enemy":
				_world_frozen = true
				PlayerStats._pending_corpse = Vector2i(ent.grid_x, ent.grid_y)
				TransitionManager.change_scene("res://scenes/battle/node.tscn")
	var tile_val: int = _map_data[ry][rx] if ry < _map_data.size() and rx < _map_data[0].size() else TILE_WALL
	if tile_val == TILE_EXIT and not _dialogue_active:
		var exit: ExitData = station_data.get_exit_at(Vector2i(rx, ry)) if station_data else null
		if exit:
			_transition_to_station(exit)
		else:
			_ask_leave_station()

func _transition_to_station(exit: ExitData):
	var target: StationData = exit.resolve_target_station()
	if not target:
		_ask_leave_station()
		return
	PlayerStats.current_station = target
	var spawn: Vector2i = exit.resolve_spawn(target.spawn)
	var dir: int = exit.resolve_dir(target.spawn_dir)
	PlayerStats.flags["_transition_spawn"] = spawn
	PlayerStats.flags["_transition_dir"] = dir
	TransitionManager.change_scene("res://scenes/dungeon/test_dungeon_mechanics.tscn")

func _update_enemies(delta: float):
	if _world_frozen: return
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
	var dist: int = abs(ent.grid_x - px) + abs(ent.grid_y - py)

	var max_range: int = 8
	var chase_chance: float = 0.0
	if dot > 0:
		max_range = 8; chase_chance = 1.0
	elif dot == 0:
		max_range = 6; chase_chance = 0.5
	else:
		max_range = 3
		var moving: bool = _is_animating or _dialogue_active
		chase_chance = 0.25 if moving else 0.0

	if dist > max_range: return

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

	if dist > 10 or blocked:
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

func _build_height_data():
	if _map_data.is_empty(): return
	_renderer.height_data = []
	for y in _map_data.size():
		var row: Array = []; row.resize(_map_data[y].size()); row.fill(0.0)
		_renderer.height_data.append(row)
	# Rails = lower level
	for y in _map_data.size():
		for x in _map_data[y].size():
			if _map_data[y][x] == TILE_RAIL:
				_renderer.height_data[y][x] = -1.0
			elif _map_data[y][x] == TILE_STAIRS:
				_renderer.height_data[y][x] = -0.5

func _refresh():
	if _renderer:
		_renderer.update_view(_player_x + 0.5, _player_y + 0.5, _current_angle, _map_data, _entities)
		_renderer.update_height(_renderer.height_data)
	if _label:
		_label.text = DIR_NAMES[_player_dir]
	if _minimap_ctrl:
		_minimap_ctrl.update_map(_map_data, roundi(_player_x), roundi(_player_y))
	if _stats_panel:
		_stats_panel.refresh()

func _build_from_station_data():
	var sd: StationData = station_data
	var text: String = FileAccess.get_file_as_string(sd.map_file)
	var rows: PackedStringArray = text.split("\n", false)
	_map_data = []
	for y in rows.size():
		var row: Array = []; var line: String = rows[y]
		for x in line.length():
			match line[x]:
				"#": row.append(TILE_WALL)
				"E": row.append(TILE_EXIT)
				"D": row.append(TILE_DOOR)
				"L": row.append(TILE_LOCKED)
				"S": row.append(TILE_STAIRS)
				"R": row.append(TILE_RAIL)
				"I": row.append(TILE_ITEM)
				"O": row.append(TILE_WALL)
				"B": row.append(TILE_BLOCKED)
				"@", "N", "+", ".": row.append(TILE_FLOOR)
				" ": row.append(TILE_WALL)
				_: row.append(TILE_FLOOR)
		_map_data.append(row)
	if _renderer: _renderer.fog_distance = sd.fog_distance
	if sd.outer_ring:
		# Рельсы (нижний уровень, 2 тайла сверху)
		for x in range(0, 48): _set_tile(x, 0, TILE_RAIL); _set_tile(x, 1, TILE_RAIL)
		# Лестница вниз с рельс
		_carve(9, 2, 11, 4, TILE_STAIRS)
		# Внешнее кольцо (сдвинуто, уступает рельсам)
		_carve(2, 2, 45, 2)
		_carve(2, 44, 45, 45)
		_carve(1, 3, 2, 43)
		_carve(45, 3, 46, 43)
		_carve_diag(6, 6, 18, 18)
		_carve_diag(40, 8, 28, 20)
		_carve_diag(10, 40, 24, 28)
		_carve(35, 22, 37, 24)
		_set_tile(36, 23, TILE_ITEM); _set_tile(34, 22, TILE_DOOR)
		_set_tile(2, 46, TILE_ITEM)
		# spiral
		var spiral: Array[Vector2i] = [Vector2i(24,20),Vector2i(24,19),Vector2i(23,19),Vector2i(22,19),Vector2i(22,20),Vector2i(22,21),Vector2i(23,21),Vector2i(24,21),Vector2i(24,22),Vector2i(25,22),Vector2i(25,21),Vector2i(25,20),Vector2i(25,19),Vector2i(25,18),Vector2i(24,18),Vector2i(23,18),Vector2i(22,18),Vector2i(22,17),Vector2i(23,17),Vector2i(24,17),Vector2i(25,17),Vector2i(25,16),Vector2i(24,16),Vector2i(23,16),Vector2i(22,16),Vector2i(22,15),Vector2i(23,15),Vector2i(24,15),Vector2i(25,15),Vector2i(25,14),Vector2i(24,14),Vector2i(23,14),Vector2i(23,13),Vector2i(24,13),Vector2i(25,13),Vector2i(25,12),Vector2i(24,12),Vector2i(23,12),Vector2i(23,11),Vector2i(24,11),Vector2i(25,11),Vector2i(25,10),Vector2i(24,10),Vector2i(23,10)]
		for pt in spiral: _set_tile(pt.x, pt.y, TILE_FLOOR)
		_set_tile(24, 24, TILE_FLOOR); _set_tile(46, 46, TILE_FLOOR)
		_set_tile(19, 22, TILE_FLOOR); _carve(19, 20, 20, 21); _set_tile(19, 20, TILE_ITEM)
		_set_tile(3, 5, TILE_ITEM); _set_tile(45, 9, TILE_ITEM); _set_tile(7, 33, TILE_ITEM); _set_tile(41, 37, TILE_ITEM); _set_tile(15, 43, TILE_ITEM)
		_set_tile(10, 1, TILE_EXIT); _set_tile(2, 10, TILE_EXIT); _set_tile(46, 10, TILE_EXIT)
	_build_height_data()
