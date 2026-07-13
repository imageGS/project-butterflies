extends Control

@export_group("Scene References")
@export var central_viewport: Control
@export var dialogue_box: DialogueBox

@export_group("Player")
@export var player_scene: PackedScene

var _player: Node2D
var _is_dialogue_open: bool = false

func _ready():
	_setup_world()

func _setup_world():
	_player = (player_scene.instantiate() if player_scene else preload("res://scripts/rpg/player.gd").new())
	central_viewport.add_child(_player)
	_player.position = central_viewport.size / 2.0

	var vp_size := central_viewport.size

	var tree := Interactable.new()
	tree.interaction_label = "Old Tree"
	tree.tooltip = "A gnarled tree carved with symbols. It hums faintly."
	tree.position = vp_size / 2.0 + Vector2(-250, -30)
	central_viewport.add_child(tree)
	tree.interacted.connect(_on_interacted.bind(tree))

	var shrine := Interactable.new()
	shrine.interaction_label = "Shrine"
	shrine.tooltip = "A crumbling shrine to a forgotten saint. A single candle burns inside."
	shrine.position = vp_size / 2.0 + Vector2(230, 40)
	central_viewport.add_child(shrine)
	shrine.interacted.connect(_on_interacted.bind(shrine))

	var barrel := Interactable.new()
	barrel.interaction_label = "Barrel"
	barrel.tooltip = "A weathered barrel. Something rattles inside."
	barrel.position = vp_size / 2.0 + Vector2(-80, -180)
	central_viewport.add_child(barrel)
	barrel.interacted.connect(_on_interacted.bind(barrel))

func _on_interacted(interactable: Interactable):
	if _is_dialogue_open:
		return
	_open_dialogue(interactable)

func _open_dialogue(interactable: Interactable):
	if not dialogue_box:
		return
	_is_dialogue_open = true
	dialogue_box.show_for(interactable)
	dialogue_box.set_text("You approach the %s. %s" % [interactable.interaction_label.to_lower(), interactable.tooltip])
	dialogue_box.clear_options()
	dialogue_box.add_option("Examine.", _on_option_examine.bind(interactable))
	dialogue_box.add_option("Leave.", _on_option_leave)

func _on_option_examine(interactable: Interactable):
	match interactable.interaction_label:
		"Old Tree":
			dialogue_box.set_text("The symbols on the bark shift as you watch. The humming grows louder, then fades.")
			dialogue_box.clear_options()
			dialogue_box.add_option("Touch the tree.", _close_dialogue)
			dialogue_box.add_option("Step back.", _close_dialogue)
		"Shrine":
			dialogue_box.set_text("The candle inside never burns down. A name is carved into the stone — long worn away.")
			dialogue_box.clear_options()
			dialogue_box.add_option("Bow briefly.", _close_dialogue)
			dialogue_box.add_option("Take a candle.", _close_dialogue)
		_:
			dialogue_box.set_text("There is nothing else of note.")
			dialogue_box.clear_options()
			dialogue_box.add_option("...", _close_dialogue)

func _on_option_leave():
	_close_dialogue()

func _close_dialogue():
	_is_dialogue_open = false
	if dialogue_box:
		dialogue_box.close()


