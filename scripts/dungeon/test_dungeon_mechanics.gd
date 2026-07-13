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

@export var move_duration: float = 0.12
@export var turn_duration: float = 0.08

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

@onready var _renderer: Control = $DungeonView
@onready var _label: Label = $DungeonView/InfoLabel

func _ready():
	_build_test_level()
	_setup_entities()
	_current_angle = DIR_ANGLES[_player_dir]
	_setup_dialogue_ui()
	_setup_audio()
	_refresh()

func _build_test_level():
	_map_data = []
	_map_data.append([1, 1, 1, 1, 1, 1, 1, 1])
	_map_data.append([1, 0, 0, 0, 0, 0, 0, 1])
	_map_data.append([1, 0, 0, 0, 0, 0, 0, 1])
	_map_data.append([1, 0, 0, 0, 0, 0, 0, 1])
	_map_data.append([1, 0, 0, 0, 0, 0, 0, 1])
	_map_data.append([1, 0, 0, 0, 0, 0, 0, 1])
	_map_data.append([1, 0, 0, 0, 0, 0, 0, 1])
	_map_data.append([1, 1, 1, 1, 1, 1, 1, 1])

func _setup_entities():
	_entities = []
	_entities.append({ "grid_x": 3, "grid_y": 3, "color": Color(0.8, 0.2, 0.2), "type": "enemy", "texture": load("res://sprites/enemy/bunny/bunny_enemy.png") })
	_entities.append({ "grid_x": 5, "grid_y": 5, "color": Color(0.2, 0.6, 0.2), "type": "npc", "name": "Таинственный странник", "texture": load("res://sprites/npc/17_sprite.png"), "dialogue": [
		{ "text": "Привет, путник. Давно тебя не видел в этих краях.", "responses": [
			{ "text": "Мы знакомы?", "next": 1 },
			{ "text": "Кто ты?", "next": 2 },
			{ "text": "Мне некогда.", "next": 3 }
		]},
		{ "text": "Ты просто не помнишь. Но это неважно. Важно то, что ты здесь.", "responses": [
			{ "text": "Что ты имеешь в виду?", "next": 2 },
			{ "text": "Ладно, мне пора.", "next": 3 }
		]},
		{ "text": "Это место — не просто подземелье. Оно дышит. Оно помнит. Будь осторожен, что тревожишь.", "responses": [
			{ "text": "Я запомню.", "next": -1 }
		]},
		{ "text": "Как знаешь. Но помни — обратной дороги может не быть.", "responses": [
			{ "text": "...", "next": -1 }
		]}
	]})

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
			KEY_SPACE, KEY_E:
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

func _try_interact():
	var vec: Vector2i = DIR_VECTORS[_player_dir]
	var fx: int = roundi(_player_x) + vec.x
	var fy: int = roundi(_player_y) + vec.y
	for ent: Dictionary in _entities:
		if ent.grid_x == fx and ent.grid_y == fy:
			if ent.type == "enemy":
				TransitionManager.change_scene("res://scenes/battle/node.tscn")
			elif ent.type == "npc" and ent.has("dialogue"):
				_start_dialogue(ent.dialogue as Array, ent.get("name", "Незнакомец"))
			return

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

	if responses.is_empty():
		_dialogue_prompt.text = "[E] Закрыть"
		return

	for i in responses.size():
		if i < _dialogue_responses.size():
			var opt: Dictionary = responses[i]
			_dialogue_responses[i].text = str(i + 1) + ". " + opt.get("text", "")
			_dialogue_responses[i].visible = true

	_dialogue_prompt.text = "[1-" + str(responses.size()) + "]"

func _advance_dialogue():
	var node: Dictionary = _dialogue_nodes[_dialogue_index]
	var responses: Array = node.get("responses", [])
	if responses.is_empty():
		_dialogue_index += 1
		_show_dialogue_node()
	else:
		_select_response(0)

func _select_response(idx: int):
	var node: Dictionary = _dialogue_nodes[_dialogue_index]
	var responses: Array = node.get("responses", [])
	if idx < 0 or idx >= responses.size():
		return
	var next_idx: int = responses[idx].get("next", -1)
	if next_idx < 0:
		_close_dialogue()
		return
	_dialogue_index = next_idx
	_show_dialogue_node()

func _close_dialogue():
	_dialogue_active = false
	_dialogue_overlay.visible = false

func _is_walkable(x: int, y: int) -> bool:
	if x < 0 or x >= _map_data[0].size() or y < 0 or y >= _map_data.size():
		return false
	return _map_data[y][x] == TILE_FLOOR

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
	if not _is_animating:
		set_process(false)
		return
	_anim_timer += delta
	var dur: float = turn_duration if _anim_from_angle != _anim_to_angle and _anim_from_x == _anim_to_x else move_duration
	var t: float = min(_anim_timer / dur, 1.0)
	t = t * t * (3.0 - 2.0 * t)
	_player_x = lerp(_anim_from_x, _anim_to_x, t)
	_player_y = lerp(_anim_from_y, _anim_to_y, t)
	_current_angle = lerp_angle(_anim_from_angle, _anim_to_angle, t)
	_refresh()
	if t >= 1.0:
		_is_animating = false
		set_process(false)
		_check_entity()

func _check_entity():
	var rx: int = roundi(_player_x)
	var ry: int = roundi(_player_y)
	for ent: Dictionary in _entities:
		if ent.grid_x == rx and ent.grid_y == ry:
			if ent.type == "enemy":
				TransitionManager.change_scene("res://scenes/battle/node.tscn")

func _refresh():
	if _renderer:
		_renderer.update_view(_player_x + 0.5, _player_y + 0.5, _current_angle, _map_data, _entities)
	if _label:
		_label.text = DIR_NAMES[_player_dir]
