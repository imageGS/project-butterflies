extends Node

@export_group("Visual")
@export var logo_texture: Texture2D
@export var glitch_intro_duration: float = 2.5
@export var glitch_interval: float = 6.0
@export var glitch_chance: float = 0.3
@export var blink_interval: float = 0.5

@export_group("Node References")
@export var ui_root: Control
@export var logo_rect: TextureRect
@export var press_key_label: Label
@export var glitch_overlay: ColorRect
@export var intro_static: ColorRect

@export_group("Audio")
@export_range(-80, 24, 0.1) var ui_volume_db: float = 0.0
@export var intro_sound_player: AudioStreamPlayer
@export var ui_sound_player: AudioStreamPlayer

const SELECT_SOUND := preload("res://audio/ui/select.ogg")
const CLICK_SOUND := preload("res://audio/ui/click.ogg")
const INTRO_SOUND := preload("res://audio/ui/intro.ogg")

var state: int = 0  # 0 = intro glitch, 1 = menu, 2 = transitioning
var intro_timer: float = 0.0
var glitch_timer: float = 0.0
var blink_timer: float = 0.0
var logo_base_pos: Vector2

func _ready():
	if logo_rect:
		logo_base_pos = logo_rect.position
	_setup_audio()
	_start_intro()

func _setup_audio():
	if not intro_sound_player:
		intro_sound_player = AudioStreamPlayer.new()
		intro_sound_player.name = "IntroSoundPlayer"
		intro_sound_player.bus = &"Master"
		add_child(intro_sound_player)
	intro_sound_player.stream = INTRO_SOUND
	intro_sound_player.volume_db = ui_volume_db

	if not ui_sound_player:
		ui_sound_player = AudioStreamPlayer.new()
		ui_sound_player.name = "UISoundPlayer"
		ui_sound_player.bus = &"Master"
		add_child(ui_sound_player)
	ui_sound_player.volume_db = ui_volume_db

func _start_intro():
	state = 0
	intro_timer = 0.0
	if logo_rect: logo_rect.hide()
	if press_key_label: press_key_label.hide()
	if glitch_overlay: glitch_overlay.hide()
	if intro_static:
		intro_static.show()
		intro_static.modulate.a = 1.0
	if intro_sound_player:
		intro_sound_player.stop()
		intro_sound_player.play()

func _process(delta):
	match state:
		0:
			intro_timer += delta
			if intro_static:
				intro_static.modulate.a = 0.3 + randf() * 0.7
			if logo_rect:
				logo_rect.position = logo_base_pos + Vector2(randf_range(-5, 5), 0)
			if intro_timer >= glitch_intro_duration:
				_show_menu()

		1:
			glitch_timer += delta
			blink_timer += delta

			if press_key_label:
				press_key_label.visible = int(blink_timer / blink_interval) % 2 == 0

			if glitch_timer >= glitch_interval:
				glitch_timer = 0.0
				if randf() < glitch_chance:
					_trigger_glitch()

func _show_menu():
	state = 1
	glitch_timer = 0.0
	blink_timer = 0.0
	if intro_static: intro_static.hide()
	if glitch_overlay: glitch_overlay.hide()
	if logo_rect:
		logo_rect.show()
		logo_rect.position = logo_base_pos
	if press_key_label: press_key_label.show()

func _trigger_glitch():
	if logo_rect:
		logo_rect.position.x = logo_base_pos.x + randf_range(-10, 10)
	if glitch_overlay:
		glitch_overlay.show()
		glitch_overlay.modulate.a = 0.4
		await get_tree().create_timer(0.06).timeout
		glitch_overlay.hide()
	if logo_rect:
		var tween := create_tween()
		tween.tween_property(logo_rect, "position", logo_base_pos, 0.12).set_ease(Tween.EASE_OUT)

func _input(event):
	if state != 1:
		return
	if event is InputEventKey or event is InputEventMouseButton:
		if event.pressed:
			if ui_sound_player:
				ui_sound_player.stream = CLICK_SOUND
				ui_sound_player.play()
			_start_game()

func _start_game():
	state = 2
	TransitionManager.change_scene("res://scenes/dungeon_test.tscn")
