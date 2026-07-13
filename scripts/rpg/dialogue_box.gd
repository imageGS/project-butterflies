class_name DialogueBox
extends Control

var portrait: TextureRect
var npc_name: Label
var dialogue_text: RichTextLabel
var options_container: VBoxContainer

var _current_interactable: Interactable

func _ready():
	_setup_layout()
	hide()

func _setup_layout():
	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.7)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var hbox := HBoxContainer.new()
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 16)
	hbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	add_child(hbox)

	portrait = TextureRect.new()
	portrait.custom_minimum_size = Vector2(200, 0)
	portrait.size_flags_vertical = Control.SIZE_EXPAND_FILL
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hbox.add_child(portrait)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hbox.add_child(right)

	npc_name = Label.new()
	npc_name.add_theme_font_size_override("font_size", 22)
	npc_name.add_theme_color_override("font_color", Color(0.9, 0.7, 0.3))
	npc_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_child(npc_name)

	dialogue_text = RichTextLabel.new()
	dialogue_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dialogue_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dialogue_text.bbcode_enabled = true
	dialogue_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(dialogue_text)

	options_container = VBoxContainer.new()
	options_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	options_container.alignment = BoxContainer.ALIGNMENT_END
	right.add_child(options_container)

func show_for(interactable: Interactable):
	_current_interactable = interactable
	_apply_portrait(interactable)
	if npc_name:
		npc_name.text = interactable.interaction_label
	show()

func set_text(text: String):
	if dialogue_text:
		dialogue_text.text = text

func add_option(text: String, callback: Callable):
	var btn := Button.new()
	btn.text = text
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.pressed.connect(callback)
	options_container.add_child(btn)

func clear_options():
	for child in options_container.get_children():
		child.queue_free()

func close():
	hide()
	_current_interactable = null

func _apply_portrait(interactable: Interactable):
	if not portrait:
		return
	match interactable.interaction_label:
		"Shrine":
			portrait.color = Color(0.6, 0.4, 0.2)
		"Old Tree":
			portrait.color = Color(0.2, 0.6, 0.1)
		"Barrel":
			portrait.color = Color(0.5, 0.3, 0.15)
		_:
			portrait.color = Color.GRAY
