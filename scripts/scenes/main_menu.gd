extends Node

@export_group("Audio")
@export_range(-80, 24, 0.1) var ui_volume_db: float = -6.0

const SELECT_SOUND := preload("res://audio/ui/select.ogg")
const CLICK_SOUND := preload("res://audio/ui/click.ogg")
const INTRO_SOUND := preload("res://audio/ui/intro.ogg")

var state: int = 0
var intro_timer: float = 0.0
var _intro_static: ColorRect
var _menu_list: VBoxContainer
var _btn_new: Button
var _btn_quit: Button

func _ready():
	_intro_static = get_node_or_null("CRT_Root/GameViewport/UIRoot/IntroStatic")
	_menu_list = get_node_or_null("CRT_Root/GameViewport/UIRoot/MenuList")
	_setup_audio()
	_setup_buttons()
	_start_intro()

func _setup_audio():
	var p := AudioStreamPlayer.new()
	p.bus = &"Master"
	p.volume_db = ui_volume_db
	p.name = "Audio"
	add_child(p)

func _setup_buttons():
	if not _menu_list: return
	_btn_new = _menu_list.get_node_or_null("BtnNewGame")
	_btn_quit = _menu_list.get_node_or_null("BtnQuit")
	if _btn_new:
		_btn_new.pressed.connect(func(): _play_click(); _start_game())
		_btn_new.mouse_entered.connect(_play_select)
	if _btn_quit:
		_btn_quit.pressed.connect(func(): _play_click(); get_tree().quit())
		_btn_quit.mouse_entered.connect(_play_select)

func _start_intro():
	state = 0
	intro_timer = 0.0
	if _menu_list: _menu_list.hide()
	if _intro_static:
		_intro_static.show()
		_intro_static.modulate.a = 1.0
	var p: AudioStreamPlayer = get_node_or_null("Audio")
	if p:
		p.stream = INTRO_SOUND
		p.play()

func _show_menu():
	state = 1
	if _intro_static: _intro_static.hide()
	if _menu_list: _menu_list.show()
	if _btn_new: _btn_new.grab_focus()

func _process(delta):
	if state == 0:
		intro_timer += delta
		if _intro_static:
			_intro_static.modulate.a = 0.3 + randf() * 0.7
		if intro_timer >= 2.5:
			_show_menu()

func _play_select():
	var p: AudioStreamPlayer = get_node_or_null("Audio")
	if p and not p.playing:
		p.stream = SELECT_SOUND
		p.play()

func _play_click():
	var p: AudioStreamPlayer = get_node_or_null("Audio")
	if p:
		p.stream = CLICK_SOUND
		p.play()

func _start_game():
	state = 2
	TransitionManager.change_scene("res://scenes/dungeon/test_dungeon_mechanics.tscn")
