class_name StatsPanel
extends Control

var _hp_bar: ColorRect
var _hp_label: Label
var _sp_bar: ColorRect
var _sp_label: Label
var _cycle_label: Label

func _ready():
	_hp_bar = ColorRect.new()
	_hp_bar.color = Color(0.7, 0.15, 0.15, 0.8)
	_hp_bar.set_size(Vector2(0, 12))
	_hp_bar.position = Vector2(0, 40)
	add_child(_hp_bar)
	_hp_label = Label.new()
	_hp_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7, 1))
	_hp_label.add_theme_font_size_override("font_size", 14)
	_hp_label.position = Vector2(4, 18)
	add_child(_hp_label)

	_sp_bar = ColorRect.new()
	_sp_bar.color = Color(0.15, 0.5, 0.7, 0.8)
	_sp_bar.set_size(Vector2(0, 12))
	_sp_bar.position = Vector2(0, 100)
	add_child(_sp_bar)
	_sp_label = Label.new()
	_sp_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7, 1))
	_sp_label.add_theme_font_size_override("font_size", 14)
	_sp_label.position = Vector2(4, 78)
	add_child(_sp_label)

	_cycle_label = Label.new()
	_cycle_label.add_theme_color_override("font_color", Color(0.6, 0.55, 0.45, 0.8))
	_cycle_label.add_theme_font_size_override("font_size", 12)
	_cycle_label.position = Vector2(4, 130)
	add_child(_cycle_label)

func refresh():
	var max_w: float = size.x - 8
	var hp_ratio: float = float(PlayerStats.health) / float(PlayerStats.max_health)
	var sp_ratio: float = float(PlayerStats.sanity) / float(PlayerStats.max_sanity)
	var hp_w: float = max_w * hp_ratio
	var sp_w: float = max_w * sp_ratio
	var tw_hp := create_tween()
	tw_hp.tween_property(_hp_bar, "size:x", hp_w, 0.3)
	var tw_sp := create_tween()
	tw_sp.tween_property(_sp_bar, "size:x", sp_w, 0.3)
	_hp_label.text = "HP: %d/%d" % [PlayerStats.health, PlayerStats.max_health]
	_sp_label.text = "SAN: %d/%d" % [PlayerStats.sanity, PlayerStats.max_sanity]
	_cycle_label.text = "Цикл: %d" % PlayerStats.cycle
