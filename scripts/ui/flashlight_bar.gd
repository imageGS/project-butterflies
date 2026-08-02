extends Control
class_name FlashlightBar

var _tex: Texture2D
var _frame: int = 0

const FRAME_H := 3
const GAP := 13
const TOTAL_FRAMES := 6
const ATLAS_PATH := "res://assets/UI/flashlight.png"

func _ready():
	_tex = load(ATLAS_PATH) as Texture2D
	custom_minimum_size = Vector2(72, 9)
	queue_redraw()

func update_energy(energy: float, max_energy: float):
	if not _tex: return
	var ratio: float = 0.0 if max_energy <= 0.0 else energy / max_energy
	if ratio <= 0.0:
		_frame = TOTAL_FRAMES - 1
	elif ratio >= 1.0:
		_frame = 0
	else:
		_frame = TOTAL_FRAMES - 1 - int(ratio * (TOTAL_FRAMES - 1))
		_frame = clamp(_frame, 0, TOTAL_FRAMES - 1)
	queue_redraw()

func _draw():
	if not _tex: return
	var w := _tex.get_width()
	var y := _frame * (FRAME_H + GAP)
	var src := Rect2(0, y, w, FRAME_H)
	var dst := Rect2(0, 0, w * 3, FRAME_H * 3)
	draw_texture_rect_region(_tex, dst, src)
