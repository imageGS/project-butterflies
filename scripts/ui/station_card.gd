extends CanvasLayer
class_name StationCard

signal done

var _station_name: String
var _time_string: String

func _init(station_name: String, time: float):
	_station_name = station_name
	var h := int(time)
	var m := int(fmod(time, 1.0) * 60)
	_time_string = "%02d:%02d" % [h, m]

func _ready():
	layer = 127

	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 1)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var font := FontFile.new()
	font.font_data = load("res://font/Silver.ttf")

	var name_label := Label.new()
	name_label.name = "StationName"
	name_label.text = _station_name
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_override("font", font)
	name_label.add_theme_font_size_override("font_size", 64)
	name_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	name_label.set_anchors_preset(Control.PRESET_CENTER)
	name_label.visible_ratio = 0.0
	add_child(name_label)

	var time_label := Label.new()
	time_label.name = "StationTime"
	time_label.text = _time_string
	time_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	time_label.add_theme_font_override("font", font)
	time_label.add_theme_font_size_override("font_size", 32)
	time_label.add_theme_color_override("font_color", Color(0.7, 0.65, 0.5, 0.0))
	time_label.set_anchors_preset(Control.PRESET_CENTER)
	time_label.position = Vector2(0, 80)
	add_child(time_label)

	_start_animation(name_label, time_label, bg)

func _start_animation(name_label: Label, time_label: Label, bg: ColorRect):
	var dur: float = min(2.0, 0.08 * _station_name.length())

	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(name_label, "visible_ratio", 1.0, dur)
	tween.tween_interval(0.5)
	tween.tween_callback(func(): _fade_in_time(time_label))
	tween.tween_interval(1.0)
	tween.tween_callback(func(): _fade_out(bg, name_label, time_label))
	tween.tween_interval(0.5)
	tween.tween_callback(func(): done.emit(); queue_free())

func _fade_in_time(label: Label):
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(label, "modulate", Color(0.7, 0.65, 0.5, 1.0), 0.5)

func _fade_out(bg: ColorRect, name_label: Label, time_label: Label):
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(bg, "modulate", Color(1, 1, 1, 0), 0.5)
	tween.parallel().tween_property(name_label, "modulate", Color(1, 1, 1, 0), 0.5)
	tween.parallel().tween_property(time_label, "modulate", Color(1, 1, 1, 0), 0.5)
