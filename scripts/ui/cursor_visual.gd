extends Control
class_name CursorVisual

## Внутрипотоковый курсор: рисуется внутри GameViewport, поэтому на него
## действует CRT-шейдер (warp, wobble, scanlines, цветовые смещения).
## Системный курсор при этом скрыт (Input.MOUSE_MODE_HIDDEN).

var _tex: Texture2D
var _hotspot: Vector2 = Vector2.ZERO

var crt: ColorRect
var svp: SubViewport

func _ready():
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 1000
	z_as_relative = false
	var viewport_parent: Node = get_parent()
	if viewport_parent:
		svp = viewport_parent as SubViewport
		var crt_root: Node = viewport_parent.get_parent()
		if crt_root:
			crt = crt_root.get_node_or_null("CRT_Display") as ColorRect
	visible = true

func show_cursor(tex: Texture2D, hotspot: Vector2):
	if tex == _tex and hotspot == _hotspot:
		return
	_tex = tex
	_hotspot = hotspot
	queue_redraw()

func update_position(window_mouse: Vector2):
	if not crt or not svp:
		return
	var sx: float = float(svp.size.x) / maxf(crt.size.x, 1.0)
	var sy: float = float(svp.size.y) / maxf(crt.size.y, 1.0)
	var p := Vector2(
		(window_mouse.x - crt.global_position.x) * sx,
		(window_mouse.y - crt.global_position.y) * sy
	)
	position = p - _hotspot

func _draw():
	if _tex:
		draw_texture(_tex, Vector2.ZERO)
