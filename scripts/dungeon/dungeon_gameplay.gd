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

var _player_movement: PlayerMovement
var _map_manager: MapManager
var _entities: Array = []
var _entity_manager: EntityManager
var _audio_system: AudioSystem

var _log_system: LogBox
var _awareness_system: AwarenessSystem

var _mono_font: Font
var _dialogue_system: DialogueSystem
var _interaction_system: InteractionSystem
var _enemy_ai: EnemyAI
var _hud_system: HUDSystem
var _transition_system: TransitionSystem

@onready var _renderer: Control = $CRT_Root/GameViewport/UI/CentralViewport/DungeonView
@onready var _label: Label = $CRT_Root/GameViewport/UI/CentralViewport/DungeonView/InfoLabel
@onready var _minimap_ctrl: MinimapControl = $CRT_Root/GameViewport/UI/HUDOverlay/UL_Window/Minimap

@export var shelter_mode: bool = false  # deprecated, station_data defines the level
@export var station_data: StationData
@export_group("Lighting")
@export var light_ambient: float = 0.15
@export var light_dither: float = 6.0
@export var light_pixel_size: float = 2.0
@export var light_glow_amount: float = 0.0
@export var light_softness: float = 0.3
@export var light_curve: float = 1.6
@export var player_light_radius: float = 300.0
@export var player_light_intensity: float = 1.2
@export var player_light_color: Color = Color(1.0, 0.95, 0.8)

var _lighting_system: LightingSystem

func _ready():
	var fd := FontFile.new()
	fd.font_data = load("res://font/Silver.ttf")
	_mono_font = fd
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_map_manager = MapManager.new()
	add_child(_map_manager)
	_map_manager.setup(_renderer)

	_dialogue_system = DialogueSystem.new()
	add_child(_dialogue_system)
	_dialogue_system.dialogue_started.connect(_on_dialogue_started)
	_dialogue_system.dialogue_ended.connect(_on_dialogue_ended)

	_log_system = $CRT_Root/GameViewport/UI/HUDOverlay/LogBox
	_log_system.set_font(_mono_font)

	_dialogue_system.setup(
		$CRT_Root/GameViewport/UI/HUDOverlay/DialoguePortraitWindow,
		$CRT_Root/GameViewport/UI/HUDOverlay/DialogueBoxWindow,
		$CRT_Root/GameViewport/UI/HUDOverlay/DialoguePortraitWindow/DialoguePortrait,
		$CRT_Root/GameViewport/UI/HUDOverlay/DialoguePortraitWindow/DialogueName,
		$CRT_Root/GameViewport/UI/HUDOverlay/DialogueBoxWindow/DialogueText,
		_log_system,
		load("res://sprites/npc/17_sprite.png"),
	)

	_player_movement = PlayerMovement.new()
	add_child(_player_movement)
	_load_station()
	_entity_manager = EntityManager.new()
	add_child(_entity_manager)
	_entity_manager.setup(_map_manager, _dialogue_system)
	_entities = _entity_manager.setup_entities(station_data, station_data != null and station_data.station_name == "Убежище")
	_audio_system = AudioSystem.new()
	add_child(_audio_system)
	_audio_system.setup(self)
	_player_movement.setup(
		_map_manager, _audio_system,
		func(): return _dialogue_system.active,
		func(): return _hud_system.inv_open,
		func(): _refresh(),
		func(): _hud_system.shake(),
		move_duration, turn_duration
	)

	_hud_system = HUDSystem.new()
	add_child(_hud_system)
	_hud_system.setup($CRT_Root/GameViewport/UI/HUDOverlay, _dialogue_system, _mono_font)
	_hud_system.examine_requested.connect(_on_examine_item)

	_transition_system = TransitionSystem.new()
	add_child(_transition_system)
	_transition_system.setup(_dialogue_system)

	_awareness_system = AwarenessSystem.new()
	add_child(_awareness_system)
	_awareness_system.setup(_dialogue_system, _log_system)
	if station_data and station_data.station_name != "Убежище":
		_awareness_system.timer = _awareness_system.interval

	_interaction_system = InteractionSystem.new()
	add_child(_interaction_system)
	_interaction_system.setup(
		_renderer, _dialogue_system, _log_system, _map_manager,
		func(): return _player_movement.player_x,
		func(): return _player_movement.player_y,
		func(): return _player_movement.player_dir,
		_mono_font,
		func(): if _hud_system.stats_panel: _hud_system.stats_panel.refresh(),
		station_data
	)
	_interaction_system.entities = _entities
	_interaction_system.entity_interacted.connect(_on_entity_interacted)

	_enemy_ai = EnemyAI.new()
	add_child(_enemy_ai)
	_enemy_ai.setup(
		func(x, y): return _map_manager.is_walkable(x, y),
		func(x1, y1, x2, y2): return _map_manager.is_blocked(x1, y1, x2, y2),
		func(ent): _audio_system.play_enemy_step(ent, _player_movement.player_x, _player_movement.player_y),
		func(): _refresh(),
		func(): return _dialogue_system.active,
	)

	_lighting_system = LightingSystem.new()
	add_child(_lighting_system)
	_lighting_system.setup($CRT_Root/GameViewport)
	_lighting_system.apply_light_settings(light_ambient, light_dither, light_pixel_size, light_glow_amount, light_softness, light_curve)
	_lighting_system.apply_player_light(player_light_radius, player_light_intensity, player_light_color)

	_hud_system.add_test_items()
	_renderer.precache_outlines(_entities)
	_refresh()

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

	_map_manager.build_from_station_data(station_data)
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
	_player_movement.player_x = float(spawn.x)
	_player_movement.player_y = float(spawn.y)
	_player_movement.player_dir = dir
	_player_movement.current_angle = DIR_ANGLES[_player_movement.player_dir]

func _unhandled_input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_TAB:
				_hud_system.toggle_inventory()
				return
			KEY_R:
				if _hud_system.inv_open and _hud_system.inv_panel:
					_hud_system.inv_panel.rotate_focused_item()
					return
			KEY_M:
				if not _dialogue_system.active and _hud_system.ul_window:
					_hud_system.ul_open = _hud_system.toggle_window(_hud_system.ul_window, _hud_system.ul_open, _hud_system.ul_on_pos, _hud_system.ul_off_pos)
					return
			KEY_H:
				if not _dialogue_system.active and _hud_system.dl_window:
					_hud_system.dl_open = _hud_system.toggle_window(_hud_system.dl_window, _hud_system.dl_open, _hud_system.dl_on_pos, _hud_system.dl_off_pos)
					return
	if _player_movement.is_animating or _hud_system.inv_open:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_W, KEY_UP:
				if not _dialogue_system.active:
					_player_movement.try_move_forward()
					_player_movement.held_cooldown = 0.12
			KEY_S, KEY_DOWN:
				if not _dialogue_system.active:
					_player_movement.try_move_backward()
					_player_movement.held_cooldown = 0.12
			KEY_A, KEY_LEFT:
				if not _dialogue_system.active:
					var old_dir = _player_movement.player_dir
					_player_movement.player_dir = (_player_movement.player_dir + 3) % 4
					_player_movement.start_rotate(old_dir)
					_player_movement.held_cooldown = 0.08
			KEY_D, KEY_RIGHT:
				if not _dialogue_system.active:
					var old_dir = _player_movement.player_dir
					_player_movement.player_dir = (_player_movement.player_dir + 1) % 4
					_player_movement.start_rotate(old_dir)
					_player_movement.held_cooldown = 0.08
			KEY_R:
				if not _dialogue_system.active:
					var old_dir = _player_movement.player_dir
					_player_movement.player_dir = (_player_movement.player_dir + 2) % 4
					_player_movement.start_rotate(old_dir)
					_player_movement.held_cooldown = 0.08
			KEY_Q:
				if not _dialogue_system.active:
					_player_movement.try_strafe_left()
					_player_movement.held_cooldown = 0.12
			KEY_E:
				if _dialogue_system.active:
					_dialogue_system.advance()
				elif not _dialogue_system.active:
					_player_movement.try_strafe_right()
					_player_movement.held_cooldown = 0.12
			KEY_SPACE, KEY_F:
				if not _dialogue_system.active:
					_interaction_system.try_interact()
			KEY_L:
				if not _dialogue_system.active:
					_lighting_system.flashlight_on = not _lighting_system.flashlight_on
			KEY_M:
				if not _dialogue_system.active and _hud_system.ul_window:
					_hud_system.ul_open = _hud_system.toggle_window(_hud_system.ul_window, _hud_system.ul_open, _hud_system.ul_on_pos, _hud_system.ul_off_pos)
			KEY_H:
				if not _dialogue_system.active and _hud_system.dl_window:
					_hud_system.dl_open = _hud_system.toggle_window(_hud_system.dl_window, _hud_system.dl_open, _hud_system.dl_on_pos, _hud_system.dl_off_pos)
			KEY_1:
				if _dialogue_system.active:
					_dialogue_system.select_response(0)
			KEY_2:
				if _dialogue_system.active:
					_dialogue_system.select_response(1)
			KEY_3:
				if _dialogue_system.active:
					_dialogue_system.select_response(2)
			KEY_4:
				if _dialogue_system.active:
					_dialogue_system.select_response(3)
			KEY_5:
				if _dialogue_system.active:
					_dialogue_system.select_response(4)
			KEY_6:
				if _dialogue_system.active:
					_dialogue_system.select_response(5)



func _process(delta):
	_lighting_system.update_lighting(light_ambient, light_dither, light_pixel_size, light_glow_amount, light_softness, light_curve, player_light_radius, player_light_intensity, player_light_color)
	_awareness_system.process(delta)

	_enemy_ai.sync_state(_entities, _map_manager.map_data, _player_movement.player_x, _player_movement.player_y, _player_movement.is_animating)
	_enemy_ai.update(delta)
	_hud_system.tick_balls(delta)

	if not _player_movement.is_animating:
		if not _hud_system.inv_open:
			_player_movement.process_held_input(delta)
		if _renderer:
			_renderer._project_entities()
			_renderer.queue_redraw_walls()
		if not _hud_system.inv_open and not _dialogue_system.active:
			_interaction_system.update_mouse_hover(get_viewport().get_mouse_position())
			_interaction_system.update_tooltip()
			_interaction_system.check_click_interact()
		return

	var t: float = _player_movement.update_animation(delta)
	if t >= 0.0:
		_refresh()
		if _renderer: _renderer._project_entities()
		_interaction_system.update_mouse_hover(get_viewport().get_mouse_position())
		_interaction_system.update_tooltip()
		_interaction_system.check_click_interact()
		if t >= 1.0:
			_interaction_system.check_entity()



func _on_examine_item(item_name: String, description: String):
	_log_system.add_message("Вы осматриваете %s." % item_name)
	_log_system.add_message(description)

func _on_dialogue_started(npc_name: String):
	_log_system.save()
	_log_system.set_separation(0)

func _on_dialogue_ended():
	_log_system.restore()
	_log_system.set_separation(4)
	_log_system.scroll_to_bottom()

func _on_entity_interacted(ent: Dictionary):
	if ent.get("type") == "enemy":
		PlayerStats._pending_corpse = Vector2i(ent.grid_x, ent.grid_y)
		TransitionManager.change_scene("res://scenes/battle/node.tscn")
	elif ent.get("type") == "exit":
		var exit: ExitData = station_data.get_exit_at(Vector2i(ent.grid_x, ent.grid_y)) if station_data else null
		if exit: _transition_system.transition_to_station(exit)

func _refresh():
	if _renderer:
		_renderer.update_view(_player_movement.player_x + 0.5, _player_movement.player_y + 0.5, _player_movement.current_angle, _map_manager.map_data, _entities)
		_renderer.update_height(_renderer.height_data)
	if _label:
		_label.text = DIR_NAMES[_player_movement.player_dir]
	if _minimap_ctrl:
		_minimap_ctrl.update_map(_map_manager.map_data, roundi(_player_movement.player_x), roundi(_player_movement.player_y))
	if _hud_system.stats_panel:
		_hud_system.stats_panel.refresh()
