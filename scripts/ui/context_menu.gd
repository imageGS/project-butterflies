class_name ContextMenu
extends Control

const ICON_DIR: String = "res://assets/UI/context"
const ICONS: Dictionary = {
	"key": "action_key.png",
	"lockpick": "action_lockpick.png",
	"fist": "action_fist.png",
	"hand": "action_hand.png",
	"interact": "action_hand.png",
	"talk": "action_talk.png",
}

const ITEM_SIZE: float = 44.0
const SPACING: float = 10.0
const PAD: float = 10.0
const HOVER_SCALE: float = 1.3
const ICON_FIT: float = 0.7
const COLOR_BY_ID: Dictionary = {
	"key": Color(0.85, 0.75, 0.5),
	"lockpick": Color(0.6, 0.7, 0.8),
	"fist": Color(0.7, 0.48, 0.38),
	"hand": Color(0.55, 0.7, 0.55),
	"interact": Color(0.55, 0.7, 0.55),
	"talk": Color(0.5, 0.62, 0.78),
}
const BG_COLOR := Color(0.12, 0.12, 0.14, 0.92)
const BG_COLOR_HOVER := Color(0.2, 0.2, 0.24, 0.95)
const BORDER_COLOR := Color(0.35, 0.33, 0.28, 1)
const BORDER_HOVER := Color(0.72, 0.66, 0.5, 1)

var open_now: bool = false
var hovered: int = -1

var _items: Array = []
var _rects: Array = []
var _scales: Array = []
var _cursor_ui: Callable
var _tex: Dictionary = {}

func _init():
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 1000
	visible = false

func open(items: Array, origin: Vector2, parent: Control, font: Font, cursor_ui: Callable):
	_cursor_ui = cursor_ui
	_items = items
	_rects.clear()
	_scales.clear()
	var count: int = _items.size()
	var total_w: float = count * ITEM_SIZE + (count - 1) * SPACING + PAD * 2.0
	var total_h: float = ITEM_SIZE + PAD * 2.0
	var x0: float = clamp(origin.x + 18.0, 4.0, max(4.0, parent.size.x - total_w - 4.0))
	var y0: float = clamp(origin.y - total_h * 0.5, 4.0, max(4.0, parent.size.y - total_h - 4.0))
	position = Vector2(x0, y0)
	size = Vector2(total_w, total_h)
	for i in count:
		_rects.append(Rect2(PAD + i * (ITEM_SIZE + SPACING), PAD, ITEM_SIZE, ITEM_SIZE))
		_scales.append(1.0)
	if get_parent() != parent:
		if is_inside_tree():
			get_parent().remove_child(self)
		parent.add_child(self)
	visible = true
	hovered = -1
	open_now = true
	queue_redraw()

func close():
	open_now = false
	visible = false
	hovered = -1
	if is_inside_tree():
		get_parent().remove_child(self)

func selected() -> String:
	if hovered >= 0 and hovered < _items.size():
		return String(_items[hovered].get("id", ""))
	return ""

func update_menu(delta: float):
	if not open_now or _cursor_ui == null or not _cursor_ui.is_valid():
		return
	var local: Vector2 = _cursor_ui.call() - position
	hovered = -1
	for i in _rects.size():
		if (_rects[i] as Rect2).has_point(local):
			hovered = i
			break
	for i in _scales.size():
		var target: float = 1.0 if i != hovered else HOVER_SCALE
		_scales[i] = lerpf(float(_scales[i]), target, clampf(delta * 12.0, 0.0, 1.0))
	queue_redraw()

func _draw():
	if not open_now:
		return
	for i in _rects.size():
		var r: Rect2 = _rects[i]
		var sc: float = float(_scales[i])
		var c: Vector2 = r.get_center()
		var icon: Texture2D = _icon(String(_items[i].get("id", "")))
		var bg := BG_COLOR
		var border := BORDER_COLOR
		if i == hovered:
			bg = BG_COLOR_HOVER
			border = BORDER_HOVER
		draw_circle(c, ITEM_SIZE * 0.5 * sc + 3.0, bg)
		draw_arc(c, ITEM_SIZE * 0.5 * sc + 3.0, 0.0, TAU, 28, border, 1.6, true)
		if icon:
			var target: float = ITEM_SIZE * ICON_FIT * sc
			var iw: float = icon.get_width()
			var ih: float = icon.get_height()
			var dw := target
			var dh := target
			if iw > 0 and ih > 0:
				if iw >= ih:
					dw = target
					dh = target * (ih / iw)
				else:
					dh = target
					dw = target * (iw / ih)
			draw_texture_rect(icon, Rect2(c.x - dw * 0.5, c.y - dh * 0.5, dw, dh), false)

func _icon(id: String) -> Texture2D:
	if _tex.has(id):
		return _tex[id]
	var t: Texture2D = null
	var fname: String = String(ICONS.get(id, ""))
	if not fname.is_empty():
		t = load(ICON_DIR + "/" + fname) as Texture2D
	if t == null:
		t = _fallback(id)
	_tex[id] = t
	return t

func _fallback(id: String) -> Texture2D:
	var col: Color = Color(0.5, 0.5, 0.5)
	if COLOR_BY_ID.has(id):
		col = COLOR_BY_ID[id]
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.2, 0.2, 0.22, 1))
	match id:
		"fist":
			for y in range(6, 26):
				for x in range(6, 26):
					img.set_pixel(x, y, col)
		"lockpick":
			for t2 in range(30):
				img.set_pixel(31 - t2, t2, col)
				img.set_pixel(31 - t2, t2 + 1, col)
		"key":
			for a2 in range(360):
				var ang: float = deg_to_rad(float(a2))
				img.set_pixel(12 + int(cos(ang) * 7.0), 12 + int(sin(ang) * 7.0), col)
			for t2 in range(14):
				img.set_pixel(18 + t2, 12, col)
				img.set_pixel(18 + t2, 13, col)
			img.set_pixel(22, 12, col); img.set_pixel(22, 13, col)
			img.set_pixel(24, 12, col); img.set_pixel(24, 13, col)
			img.set_pixel(26, 12, col); img.set_pixel(26, 13, col)
		"talk":
			for y in range(6, 26):
				for x in range(6, 26):
					img.set_pixel(x, y, col)
		_:
			for y in range(6, 26):
				for x in range(6, 26):
					img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)
