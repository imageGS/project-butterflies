extends Control
class_name LogBox

var scroll: ScrollContainer
var container: VBoxContainer
var queue: Array = []
var busy: bool = false
var blocked: bool = false
var response_labels: Array[Label] = []
var separator_labels: Array[Label] = []
var check_labels: Array[Label] = []
var saved_labels: Array[Label] = []
var font: Font

func _ready():
	mouse_filter = MOUSE_FILTER_IGNORE
	_setup_inner()
	resized.connect(_on_resized)

func _on_resized():
	if scroll:
		scroll.size = size

func _setup_inner():
	scroll = ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	scroll.size = size
	scroll.position = Vector2.ZERO
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	container = VBoxContainer.new()
	container.name = "Messages"
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_theme_constant_override("separation", 4)
	scroll.add_child(container)

func set_font(f: Font):
	font = f

func set_separation(val: int):
	if is_instance_valid(container):
		container.add_theme_constant_override("separation", val)

func _get_timestamp() -> String:
	var t := Time.get_time_dict_from_system()
	return "[%02d:%02d]" % [t.hour, t.minute]

func add_message(text: String, color: Color = Color(1, 1, 1), tag: String = ""):
	if not is_instance_valid(container):
		return
	if blocked:
		return
	var ts := _get_timestamp()
	queue.append([ts + " " + text, color, tag])
	if not busy:
		_process_queue()

func _process_queue():
	if queue.is_empty():
		return
	busy = true
	var entry: Array = queue.pop_front()
	var full_text: String = entry[0]
	var color: Color = entry[1]
	var tag: String = entry[2] if entry.size() > 2 else ""

	var label := Label.new()
	label.text = full_text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.custom_minimum_size = Vector2(scroll.size.x - 12, 0)
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", 19)
	if font:
		label.add_theme_font_override("font", font)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.visible_characters = 0
	label.set_meta("log_tag", tag)
	container.add_child(label)
	_scroll_after_layout()
	if tag == "check":
		check_labels.append(label)

	var tw := create_tween()
	var duration: float = max(0.1, full_text.length() * 0.015)
	tw.tween_method(func(v: int): label.visible_characters = v, 0, full_text.length(), duration)
	tw.finished.connect(func():
		busy = false
		_process_queue()
	, CONNECT_ONE_SHOT)

func scroll_to_bottom():
	await get_tree().process_frame
	scroll_to_bottom_immediate()

func _scroll_after_layout():
	await get_tree().process_frame
	scroll.scroll_vertical = 2147483647

func scroll_to_bottom_immediate():
	scroll.scroll_vertical = 2147483647

func save() -> Array:
	saved_labels.clear()
	for child in container.get_children():
		if child is Label:
			container.remove_child(child)
			saved_labels.append(child)
	queue.clear()
	busy = false
	return saved_labels

func restore():
	for child in container.get_children():
		if child is Label:
			container.remove_child(child)
			child.queue_free()
	for lbl in saved_labels:
		container.add_child(lbl)
	saved_labels.clear()

func clear_responses():
	for lbl in response_labels:
		lbl.queue_free()
	response_labels.clear()
	for lbl in separator_labels:
		lbl.queue_free()
	separator_labels.clear()

func clear_check_labels():
	for lbl in check_labels:
		if is_instance_valid(lbl):
			container.remove_child(lbl)
			lbl.free()
	check_labels.clear()

func get_scroll_size() -> Vector2:
	return scroll.size

func get_container() -> VBoxContainer:
	return container
