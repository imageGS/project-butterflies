class_name DialogueSystem
extends Node

signal dialogue_started(npc_name: String)
signal dialogue_ended

var active: bool = false
var busy: bool = false
var log_allowed: bool = false

var log_system: LogBox

@onready var _portrait_window: TextureRect
@onready var _box_window: TextureRect
@onready var _portrait: TextureRect
@onready var _name_label: Label
@onready var _text_label

var _nodes: Array = []
var _index: int = 0
var _default_portrait: Texture2D
var _passive_cache: Dictionary = {}

var _portrait_on_pos: Vector2
var _portrait_off_pos: Vector2
var _box_on_pos: Vector2
var _box_off_pos: Vector2

var _type_player: AudioStreamPlayer
var _burst_player: AudioStreamPlayer
var _continue_hint: Label
var _pitch_map: Dictionary = {}
var _default_blip_stream: AudioStreamWAV
var _speaker_streams: Dictionary = {}

var _is_narration: bool = false
var _shake_active: bool = false
var _shake_intensity: float = 2.0
var _shake_label_pos: Vector2
var _shake_tween: Tween
var _skip_requested: bool = false
var _slow_type: bool = false
var _slow_char_delay: float = 0.32
var _char_delay: float = 0.04
var _sentence_pause_duration: float = 0.35
var _comma_pause_duration: float = 0.0
var _continue_hint_enabled: bool = false

func setup(
	portrait_window: TextureRect,
	box_window: TextureRect,
	portrait_node: TextureRect,
	name_label: Label,
	text_label,
	log: LogBox,
	default_portrait: Texture2D
):
	_portrait_window = portrait_window
	_box_window = box_window
	_portrait = portrait_node
	_name_label = name_label
	_text_label = text_label
	log_system = log
	_default_portrait = default_portrait

	_portrait_on_pos = portrait_window.position
	_portrait_off_pos = _portrait_on_pos + Vector2(300, 0)
	_box_on_pos = box_window.position
	_box_off_pos = _box_on_pos + Vector2(0, 300)

	_portrait_window.position = _portrait_off_pos
	_box_window.position = _box_off_pos
	_portrait_window.visible = false
	_box_window.visible = false

	_portrait.texture = default_portrait
	_text_label.add_theme_font_override("normal_font", log.font)
	_text_label.add_theme_font_size_override("normal_font_size", 32)
	_name_label.add_theme_font_override("font", log.font)
	_name_label.add_theme_font_size_override("font_size", 32)

	_setup_continue_hint()
	_setup_audio()

func _setup_audio():
	_type_player = AudioStreamPlayer.new()
	_default_blip_stream = _generate_blip()
	_type_player.stream = _default_blip_stream
	_type_player.volume_db = -8.0
	add_child(_type_player)
	_burst_player = AudioStreamPlayer.new()
	_burst_player.stream = load("res://audio/ui/dialogue/explosion.ogg")
	_burst_player.volume_db = -10.0
	add_child(_burst_player)
	_pitch_map = {
		"Кицунэ": 1.8,
		"Странник": 1.2,
	}
	_speaker_streams["Кицунэ"] = load("res://audio/ui/dialogue/kitsu.ogg")
	_speaker_streams["Силуэт"] = load("res://audio/ui/dialogue/silhouette.ogg")

func _setup_continue_hint():
	_continue_hint = Label.new()
	_continue_hint.text = "SPACE, чтобы продолжить"
	_continue_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_continue_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_continue_hint.add_theme_font_size_override("font_size", 22)
	_continue_hint.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85, 1.0))
	_continue_hint.add_theme_font_override("font", log_system.font)
	_continue_hint.position = Vector2(60, 135)
	_continue_hint.size = Vector2(400, 28)
	_continue_hint.visible = false
	_box_window.add_child(_continue_hint)

func _show_continue_hint():
	_continue_hint.visible = true
	var tw := create_tween().set_loops()
	tw.tween_property(_continue_hint, "modulate:a", 0.15, 0.8).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(_continue_hint, "modulate:a", 0.5, 0.8).set_ease(Tween.EASE_IN_OUT)

func _hide_continue_hint():
	if is_instance_valid(_continue_hint):
		_continue_hint.visible = false
		_continue_hint.modulate.a = 0.5

func _generate_blip(freq: float = 800.0, duration: float = 0.035, vol: float = 0.4) -> AudioStreamWAV:
	var sample_rate: float = 22050.0
	var num_samples: int = int(sample_rate * duration)
	var data := PackedByteArray()
	data.resize(num_samples * 2)
	for i in num_samples:
		var t: float = float(i) / sample_rate
		var envelope: float = 1.0 - (t / duration)
		var sample: float = sin(2.0 * PI * freq * t) * vol * envelope
		var val: int = int(sample * 32767.0)
		val = clamp(val, -32768, 32767)
		var lo: int = val & 0xFF
		var hi: int = (val >> 8) & 0xFF
		data[i * 2] = lo
		data[i * 2 + 1] = hi
	var wav := AudioStreamWAV.new()
	wav.data = data
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = int(sample_rate)
	wav.stereo = false
	return wav

func start(nodes: Array, npc_name: String = "Незнакомец", is_narration: bool = false, settings: Dictionary = {}):
	active = true
	busy = false
	_nodes = nodes
	_index = 0
	_is_narration = is_narration
	_continue_hint_enabled = settings.get("continue_hint", false)
	_char_delay = settings.get("char_delay", 0.04)
	_sentence_pause_duration = settings.get("pause_duration", 0.35)
	_comma_pause_duration = settings.get("comma_pause", 0.0)
	_slow_char_delay = settings.get("slow_char_delay", 0.32)
	_name_label.text = npc_name
	_portrait_window.modulate.a = 1.0
	_box_window.modulate.a = 1.0
	_portrait_window.visible = not is_narration
	_name_label.visible = not is_narration
	_box_window.visible = true
	dialogue_started.emit(npc_name)
	var tw := create_tween().set_parallel()
	if not is_narration:
		tw.tween_property(_portrait_window, "position", _portrait_on_pos, 0.25).set_ease(Tween.EASE_OUT)
	tw.tween_property(_box_window, "position", _box_on_pos, 0.25).set_ease(Tween.EASE_OUT)
	_show_node()

func close():
	active = false
	busy = false
	_hide_continue_hint()
	log_system.clear_responses()
	log_system.clear_check_labels()
	var tw := create_tween().set_parallel()
	tw.tween_property(_portrait_window, "position", _portrait_off_pos, 0.2).set_ease(Tween.EASE_IN)
	tw.tween_property(_box_window, "position", _box_off_pos, 0.2).set_ease(Tween.EASE_IN)
	tw.tween_property(_portrait_window, "modulate:a", 0.0, 0.15)
	tw.tween_property(_box_window, "modulate:a", 0.0, 0.15)
	tw.finished.connect(func():
		_portrait_window.visible = false
		_box_window.visible = false
		_portrait_window.modulate.a = 1.0
		_box_window.modulate.a = 1.0
		dialogue_ended.emit()
	, CONNECT_ONE_SHOT)

func advance():
	if not active:
		return
	if busy:
		_skip_requested = true
		return
	var node: Dictionary = _nodes[_index]
	var responses: Array = node.get("responses", [])
	var visible := _count_visible(responses)
	if visible == 0:
		_index = node.get("next", _index + 1)
		_show_node()
	else:
		_select(0)

func convert_nodes(data: Dictionary) -> Array:
	var node_map: Dictionary = {}
	var start_name: String = ""
	for key in data.keys():
		if key == "name": continue
		if not (data[key] is Dictionary): continue
		var d: Dictionary = data[key]
		if d.has("text"):
			if key == "start":
				start_name = key
				continue
			node_map[key] = node_map.size()
	if not start_name.is_empty():
		var reindexed: Dictionary = {}
		reindexed[start_name] = 0
		for k in node_map.keys():
			reindexed[k] = reindexed.size()
		node_map = reindexed
	var nodes: Array = []
	nodes.resize(node_map.size())
	for key in node_map.keys():
		var idx: int = node_map[key]
		var d: Dictionary = data[key]
		var node: Dictionary = {}
		var text_arr: Array = d.get("text", [])
		var lines: PackedStringArray = []
		for line in text_arr:
			lines.append(str(line))
		node["text"] = "\n".join(lines)
		var icon: String = d.get("icon", "")
		if not icon.is_empty():
			node["portrait"] = "res://sprites/npc/" + icon + ".png"
		var choices: Array = d.get("choices", [])
		var responses: Array = []
		for c in choices:
			var resp: Dictionary = {}
			resp["text"] = c.get("text", "")
			var next_name: String = c.get("next", "")
			if not next_name.is_empty() and node_map.has(next_name):
				resp["next"] = node_map[next_name]
			else:
				resp["next"] = -1
			var check_str: String = c.get("check", "")
			if not check_str.is_empty():
				var parts: Array = check_str.split(" ", false)
				if parts.size() >= 2:
					resp["check"] = {"skill": parts[0], "dc": int(parts[1])}
			var show_str: String = c.get("show_only_if", "")
			if not show_str.is_empty():
				var sp: Array = show_str.split(" ", false)
				if sp.size() >= 4:
					if not resp.has("check"):
						resp["check"] = {}
					resp["check"]["skill"] = sp[1]
					resp["check"]["dc"] = int(sp[2])
					resp["check"]["passive"] = true
			responses.append(resp)
		node["responses"] = responses
		nodes[idx] = node
	return nodes

func _set_portrait(portrait_path: String):
	if portrait_path.is_empty():
		_portrait.texture = _default_portrait
		return
	var tex := load(portrait_path) as Texture2D
	if tex:
		_portrait.texture = tex
	else:
		_portrait.texture = _default_portrait

func _show_node():
	_hide_continue_hint()
	log_system.clear_responses()
	log_system.clear_check_labels()

	if _index < 0 or _index >= _nodes.size():
		close()
		return

	busy = true

	var node: Dictionary = _nodes[_index]
	var raw_text: String = node.get("text", "")

	var is_narrator_node: bool = node.get("narrator", false)
	var speaker: String = node.get("speaker", "")

	# Apply narrator/speaker mode
	if is_narrator_node:
		_portrait_window.visible = false
		_name_label.visible = false
	elif not speaker.is_empty():
		_name_label.text = speaker
		_name_label.visible = true
		_portrait_window.visible = false
	else:
		_portrait_window.visible = not _is_narration
		_name_label.visible = not _is_narration
		_set_portrait(node.get("portrait", ""))

	# Strip all BBCode tags for iteration; keep display_text with color for RichTextLabel
	var display_text: String = raw_text
	display_text = display_text.replace("[shake]", "").replace("[/shake]", "")
	var clean_text: String = display_text
	var bb_re := RegEx.new()
	bb_re.compile("\\[\\/?\\w+(?:=\\w+)?\\]")
	clean_text = bb_re.sub(clean_text, "", true)
	_text_label.text = display_text
	_text_label.visible_characters = 0

	var total: int = clean_text.length()
	var char_delay: float = _char_delay
	var pause_duration: float = _sentence_pause_duration
	var npc_name: String = _name_label.text
	var pitch: float = _pitch_map.get(npc_name, 1.0)
	if is_instance_valid(_type_player):
		_type_player.pitch_scale = pitch
		var custom_stream: AudioStream = _speaker_streams.get(speaker, null)
		if custom_stream == null:
			custom_stream = _speaker_streams.get(npc_name, null)
		if custom_stream:
			_type_player.stream = custom_stream
		else:
			_type_player.stream = _default_blip_stream

	# Build shake regions mapped to clean_text positions
	var search_from: int = 0
	var shake_regions: Array[Vector2i] = []
	var shake_tag: String = "[shake]"
	var shake_close: String = "[/shake]"
	while true:
		var tag_start: int = raw_text.find(shake_tag, search_from)
		if tag_start < 0: break
		var tag_end: int = raw_text.find(shake_close, tag_start + shake_tag.length())
		if tag_end < 0: break
		var shake_content: String = raw_text.substr(tag_start + shake_tag.length(), tag_end - (tag_start + shake_tag.length()))
		# Map position in raw_text to position in clean_text (all tags stripped)
		var before_raw: String = raw_text.substr(0, tag_start)
		var clean_before: String = bb_re.sub(before_raw.replace("[shake]", "").replace("[/shake]", ""), "", true)
		var clean_content: String = bb_re.sub(shake_content, "", true)
		var clean_start: int = clean_before.length()
		var clean_end: int = clean_start + clean_content.length()
		shake_regions.append(Vector2i(clean_start, clean_end))
		search_from = tag_end + shake_close.length()

	# Check word_burst mode
	var word_burst: bool = node.get("word_burst", false)

	# Type out text
	_shake_active = false
	if is_instance_valid(_shake_tween):
		_shake_tween.kill()
		_shake_tween = null

		if word_burst:
			var words: PackedStringArray = clean_text.split(" ", false)
			var typed_pos: int = 0
			for w_idx in words.size():
				if _skip_requested:
					_text_label.visible_characters = total
					_skip_requested = false
					if is_instance_valid(_burst_player):
						_burst_player.stop()
					break
				var w: String = words[w_idx]
				typed_pos += w.length()
				_text_label.visible_characters = typed_pos
				if is_instance_valid(_burst_player):
					_burst_player.pitch_scale = 1.0 + (w_idx % 3) * 0.15
					_burst_player.play()
				await get_tree().create_timer(1.0).timeout
				typed_pos += 1
	else:
		for i in range(1, total + 1):
			if _skip_requested:
				_text_label.visible_characters = total
				_skip_requested = false
				if is_instance_valid(_type_player):
					_type_player.stop()
				break
			_text_label.visible_characters = i

			var in_shake: bool = false
			for region in shake_regions:
				if i > region.x and i <= region.y:
					in_shake = true
					break

			if in_shake:
				if not _shake_active:
					_shake_active = true
					_shake_label_pos = _text_label.position
					_shake_tween = create_tween().set_loops()
					_shake_tween.tween_method(_shake_offset, 0.0, 1.0, 0.05)
			else:
				if _shake_active:
					_shake_active = false
					if is_instance_valid(_shake_tween):
						_shake_tween.kill()
						_shake_tween = null
					_text_label.position = _shake_label_pos

			var current_delay: float = _slow_char_delay if in_shake else char_delay

			if is_instance_valid(_type_player):
				var ch: String = clean_text[i - 1]
				if ch != ' ' and ch != '\t' and ch != '\n':
					_type_player.play()
			await get_tree().create_timer(current_delay).timeout
			if i < total:
				var prev: String = clean_text[i - 1]
				if prev == '.' or prev == '!' or prev == '?':
					await get_tree().create_timer(pause_duration).timeout
				elif prev == ',':
					await get_tree().create_timer(_comma_pause_duration).timeout

	# Stop any lingering sounds
	if is_instance_valid(_type_player):
		_type_player.stop()
	if is_instance_valid(_burst_player):
		_burst_player.stop()

	# Reset position after typing
	_shake_active = false
	if is_instance_valid(_shake_tween):
		_shake_tween.kill()
		_shake_tween = null
	_text_label.position = _shake_label_pos if _shake_label_pos != Vector2() else _text_label.position

	busy = false
	if _continue_hint_enabled:
		_show_continue_hint()

	var responses: Array = node.get("responses", [])
	_passive_cache.clear()
	var visible_count: int = 0

	for i in responses.size():
		var opt: Dictionary = responses[i]
		var show: bool = true
		var check: Dictionary = opt.get("check", {})
		if not check.is_empty() and check.get("passive", false):
			var r := SkillCheck.check(PlayerStats.get_skill(check.get("skill", "composure")), check.get("dc", 10))
			_passive_cache[i] = r.success
			show = r.success
		if show:
			var resp_label := _create_response_label(str(visible_count + 1) + ". " + opt.get("text", ""), visible_count)
			log_system.response_labels.append(resp_label)
			log_system.get_container().add_child(resp_label)
			visible_count += 1

	await log_system.scroll_to_bottom()


func _shake_offset(v: float):
	if not _shake_active or not is_instance_valid(_text_label):
		return
	var offset_x: float = randf_range(-_shake_intensity, _shake_intensity)
	var offset_y: float = randf_range(-_shake_intensity, _shake_intensity)
	_text_label.position = _shake_label_pos + Vector2(offset_x, offset_y)

func _create_response_label(text: String, visible_idx: int) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	lbl.custom_minimum_size = Vector2(log_system.get_scroll_size().x - 12, 0)
	lbl.add_theme_color_override("font_color", Color(0.85, 0.8, 0.65))
	lbl.add_theme_font_size_override("font_size", 21)
	lbl.add_theme_font_override("font", log_system.font)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	lbl.mouse_filter = Control.MOUSE_FILTER_STOP
	lbl.set_meta("resp_idx", visible_idx)
	lbl.gui_input.connect(_on_label_gui_input.bind(lbl))
	lbl.mouse_entered.connect(func():
		if active and not busy and is_instance_valid(lbl):
			lbl.add_theme_color_override("font_color", Color(1, 0.95, 0.8))
	)
	lbl.mouse_exited.connect(func():
		if is_instance_valid(lbl):
			lbl.add_theme_color_override("font_color", Color(0.85, 0.8, 0.65))
	)
	return lbl

func _on_label_gui_input(event: InputEvent, label: Label):
	if not active or busy:
		return
	if not is_instance_valid(label):
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var vis_idx: int = label.get_meta("resp_idx", -1)
		if vis_idx >= 0:
			_select(vis_idx)

func _count_visible(responses: Array) -> int:
	var count: int = 0
	for i in responses.size():
		var opt: Dictionary = responses[i]
		var check: Dictionary = opt.get("check", {})
		if not check.is_empty() and check.get("passive", false):
			if not _passive_cache.get(i, false):
				continue
		count += 1
	return count

func _select(vis_idx: int):
	if busy:
		return
	busy = true

	var node: Dictionary = _nodes[_index]
	var responses: Array = node.get("responses", [])
	var actual_idx: int = -1
	var seen: int = 0
	for i in responses.size():
		var opt: Dictionary = responses[i]
		var check: Dictionary = opt.get("check", {})
		if not check.is_empty() and check.get("passive", false):
			if not _passive_cache.get(i, false):
				continue
		if seen == vis_idx:
			actual_idx = i
			break
		seen += 1
	if actual_idx < 0 or actual_idx >= responses.size():
		busy = false
		return

	var chosen: Dictionary = responses[actual_idx]
	var chk: Dictionary = chosen.get("check", {})
	if chk.is_empty():
		busy = false
		_go_to(chosen.get("next", -1))
		return

	log_system.clear_responses()
	log_allowed = true
	log_system.add_message("Проверка " + SkillCheck.dc_description(chk.get("dc", 10)) + "...", Color(0.5, 0.8, 1.0), "check")
	var result := SkillCheck.check(PlayerStats.get_skill(chk.get("skill", "composure")), chk.get("dc", 10))
	if result.success:
		log_system.add_message("✓ Успех!  (" + str(result.total) + ")", Color(0.5, 1.0, 0.5), "check")
	else:
		log_system.add_message("✗ Провал  (" + str(result.total) + ")", Color(1.0, 0.4, 0.4), "check")
	log_allowed = false
	while log_system.busy or not log_system.queue.is_empty():
		await get_tree().process_frame
	await get_tree().create_timer(1.5).timeout

	busy = false
	if result.success:
		_go_to(chosen.get("next_pass", chosen.get("next", -1)))
	else:
		_go_to(chosen.get("next_fail", chosen.get("next", -1)))

func select_response(vis_idx: int):
	_select(vis_idx)

func _go_to(idx: int):
	if idx <= -2:
		close()
		TransitionManager.change_scene("res://scenes/dungeon/dungeon_gameplay.tscn")
	elif idx < 0:
		close()
	else:
		_index = idx
		_show_node()
