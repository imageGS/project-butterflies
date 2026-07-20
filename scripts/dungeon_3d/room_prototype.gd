extends Node3D

# =============================================================================
# Prototype room — CSG geometry, player, exit trigger.
# =============================================================================

@onready var _player: CharacterBody3D = $Player
@onready var _exit_area: Area3D = $ExitTrigger
@onready var _exit_label: Label3D = $ExitTrigger/Label3D

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_exit_area.body_entered.connect(_on_exit_trigger)
	_exit_label.visible = false

func _on_exit_trigger(body: Node3D):
	if body == _player:
		_exit_label.visible = true

func _on_exit_trigger_exit(body: Node3D):
	if body == _player:
		_exit_label.visible = false

func _input(event: InputEvent):
	if not _exit_label.visible: return
	if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		print("[Room] Exit triggered — переход в другую сцену.")
		# TransitionManager.change_scene("res://scenes/menu/main_menu.tscn")
