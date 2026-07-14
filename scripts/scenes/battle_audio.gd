extends Node

var sfx_volume_db: float = -8.0
var _impact_player: AudioStreamPlayer
var _ui_sound_player: AudioStreamPlayer
var _impact_banks: Dictionary = {}

func setup(parent: Node, vol: float = -8.0):
	sfx_volume_db = vol
	_impact_player = AudioStreamPlayer.new()
	_impact_player.name = "ImpactPlayer"
	_impact_player.bus = &"Master"
	_impact_player.volume_db = sfx_volume_db
	parent.add_child(_impact_player)
	_ui_sound_player = AudioStreamPlayer.new()
	_ui_sound_player.name = "UISoundPlayer"
	_ui_sound_player.bus = &"Master"
	parent.add_child(_ui_sound_player)

func load_banks():
	_impact_banks = {
		"face_small":    _load_sfx(["impact/head_hit_1", "impact/head_hit_2"]),
		"face_finisher": _load_sfx(["impact/head_crush_1"]),
		"body_small":    _load_sfx(["impact/body_hit_1", "impact/body_hit_2"]),
		"body_finisher": _load_sfx(["impact/body_crush_1"]),
	}

func _load_sfx(paths: Array) -> Array:
	var arr: Array = []
	for p in paths:
		var s := load("res://audio/sfx/%s.wav" % p)
		if s: arr.append(s)
	return arr

func play_impact(limb_name: String, finisher: bool = false):
	if not _impact_player: return
	var key := ("face" if limb_name == "head" else "body") + ("_finisher" if finisher else "_small")
	var bank: Array = _impact_banks.get(key, [])
	if bank.is_empty(): return
	_impact_player.stream = bank[randi() % bank.size()]
	_impact_player.play()

func play_miss():
	if not _impact_player: return
	var i: int = randi() % 3 + 1
	_impact_player.stream = load("res://audio/gore/miss_%d.wav" % i)
	_impact_player.play()

func play_execute():
	if not _impact_player: return
	var i: int = randi() % 2 + 1
	_impact_player.stream = load("res://audio/gore/execute_%d.wav" % i)
	_impact_player.play()

func play_ui_select():
	if not _ui_sound_player: return
	_ui_sound_player.stream = load("res://audio/ui/select.ogg")
	_ui_sound_player.play()

func play_ui_click():
	if not _ui_sound_player: return
	_ui_sound_player.stream = load("res://audio/ui/click.ogg")
	_ui_sound_player.play()
