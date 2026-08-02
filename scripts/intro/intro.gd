extends Control

@onready var _background: ColorRect = $CRT_Root/GameViewport/UIRoot/Background
@onready var _dialogue_system: DialogueSystem = $CRT_Root/GameViewport/UIRoot/DialogueSystem
@onready var _log_system: LogBox = $CRT_Root/GameViewport/UIRoot/HUDOverlay/LogBox
@onready var _glass_overlay: ColorRect = $GlassOverlay
@onready var _crt_root: Control = $CRT_Root
@onready var _ui_root: Control = $CRT_Root/GameViewport/UIRoot
@onready var _sub_viewport: SubViewport = $CRT_Root/GameViewport

var _nodes: Array = []
var _music_player: AudioStreamPlayer
var _punch_player: AudioStreamPlayer
var _glass_break_player: AudioStreamPlayer

func _ready():
	_background.color = Color.BLACK
	_setup_music()
	_load_dialogue()
	_setup_dialogue_system()
	_dialogue_system.dialogue_ended.connect(_on_intro_ended, CONNECT_ONE_SHOT)
	_dialogue_system.start(_nodes, "", true, {
		"continue_hint": true,
		"char_delay": 0.08,
		"pause_duration": 0.7,
		"comma_pause": 0.3,
		"slow_char_delay": 0.32,
	})

func _setup_music():
	_music_player = AudioStreamPlayer.new()
	_music_player.stream = load("res://audio/music/intro_loop_2.ogg")
	_music_player.stream.loop = true
	_music_player.volume_db = -12.0
	add_child(_music_player)
	_music_player.play()

func _load_dialogue():
	var file := FileAccess.get_file_as_string("res://dialogues/intro.json")
	if not file:
		push_error("Intro: dialogue file not found")
		return
	var data: Variant = JSON.parse_string(file)
	if not data or typeof(data) != TYPE_DICTIONARY:
		push_error("Intro: invalid JSON")
		return
	_nodes = data.get("nodes", [])

func _setup_dialogue_system():
	var fd := FontFile.new()
	fd.font_data = load("res://font/Silver.ttf")
	_log_system.set_font(fd)
	_dialogue_system.setup(
		$CRT_Root/GameViewport/UIRoot/HUDOverlay/DialoguePortraitWindow,
		$CRT_Root/GameViewport/UIRoot/HUDOverlay/DialogueBoxWindow,
		$CRT_Root/GameViewport/UIRoot/HUDOverlay/DialoguePortraitWindow/DialoguePortrait,
		$CRT_Root/GameViewport/UIRoot/HUDOverlay/DialoguePortraitWindow/DialogueName,
		$CRT_Root/GameViewport/UIRoot/HUDOverlay/DialogueBoxWindow/DialogueText,
		_log_system,
		load("res://sprites/npc/17_sprite.png"),
	)

func _on_intro_ended():
	_setup_sfx_players()
	_start_shatter_sequence()
	var tw := create_tween()
	tw.tween_property(_music_player, "volume_db", -80.0, 2.5)
	tw.finished.connect(func(): _music_player.stop())

func _setup_sfx_players():
	_punch_player = AudioStreamPlayer.new()
	_punch_player.volume_db = -10.0
	add_child(_punch_player)
	_glass_break_player = AudioStreamPlayer.new()
	_glass_break_player.volume_db = -12.0
	add_child(_glass_break_player)

func _start_shatter_sequence():
	_shake(4.0, 0.2)
	_punch_player.stream = load("res://audio/ui/dialogue/punch_1.ogg")
	_punch_player.play()
	await get_tree().create_timer(1.0).timeout
	_shake(5.0, 0.22)
	_punch_player.stream = load("res://audio/ui/dialogue/punch_2.ogg")
	_punch_player.play()
	await get_tree().create_timer(1.0).timeout
	_shake(7.0, 0.3)
	_punch_player.stream = load("res://audio/ui/dialogue/punch_1.ogg")
	_punch_player.play()
	_glass_break_player.stream = load("res://audio/ui/dialogue/glass_break.ogg")
	_glass_break_player.play()
	# Capture frame, hide UI, show glass overlay
	var img := _sub_viewport.get_texture().get_image()
	var captured := ImageTexture.create_from_image(img)
	_ui_root.visible = false
	var mat := _glass_overlay.material as ShaderMaterial
	mat.set_shader_parameter("use_captured", true)
	mat.set_shader_parameter("captured_tex", captured)
	_glass_overlay.visible = true
	var tw := create_tween()
	tw.tween_method(func(val: float): mat.set_shader_parameter("fall_progress", val), 0.0, 1.0, 1.5).set_trans(Tween.TRANS_SINE)
	tw.finished.connect(func():
		PlayerStats.set_flag("intro_seen")
		TransitionManager.change_scene("res://scenes/dungeon/dungeon_gameplay.tscn")
	)

func _shake(intensity: float, duration: float):
	var original_pos := _crt_root.position
	var tw := create_tween()
	tw.tween_method(func(t: float):
		var shake_x := sin(t * PI * 4.0) * intensity
		var shake_y := cos(t * PI * 4.0) * intensity * 0.5
		_crt_root.position = original_pos + Vector2(shake_x, shake_y)
	, 0.0, 1.0, duration)
	tw.finished.connect(func(): _crt_root.position = original_pos)

func _unhandled_input(event: InputEvent):
	if not _dialogue_system.active:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE, KEY_ENTER:
				_dialogue_system.advance()
				get_viewport().set_input_as_handled()
