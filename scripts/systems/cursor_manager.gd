extends Node

## Менеджер контекстных курсоров.
## Загружает текстуры из assets/UI/cursor и переключает системный курсор
## через Input.set_custom_mouse_cursor. Точки клика (hotspot'ы) можно подгонять
## в HOTSPOTS — они подобраны по геометрии альфа-канала спрайтов.

const DIR: String = "res://assets/UI/cursor"

const SCALE: float = 1.2

const HOTSPOTS: Dictionary = {
	"pointer": Vector2(1, 1),
	"eye": Vector2(15, 10),
	"hand": Vector2(11, 4),
	"talk": Vector2(12, 4),
	"locked": Vector2(11, 19),
	"gear": Vector2(15, 15),
	"pinch": Vector2(11, 16),
	"no_action": Vector2(16, 17),
	"left": Vector2(22, 7),
	"right": Vector2(22, 7),
}

var _textures: Dictionary = {}
var _current: String = ""

## Когда true — системный курсор не ставится, состояние хранится только для
## виртуального курсора внутри GameViewport (на него действует CRT-шейдер).
var virtual: bool = false

## Прячет системный курсор наглухо: MOUSE_MODE_HIDDEN + прозрачная текстура.
## Без прозрачной текстуры Godot на Windows перекрывает hidden при движении
## мыши над Control (CRT_Display) — он заново ставит OS-курсор-стрелку.
func hide_system_cursor():
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	Input.set_custom_mouse_cursor(ImageTexture.create_from_image(img), Input.CURSOR_ARROW)
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)

func _ready():
	for kind in HOTSPOTS.keys():
		var path: String = DIR + "/cursor_" + kind + ".png"
		var tex := load(path) as Texture2D
		if tex:
			_textures[kind] = _scaled(tex, SCALE)
		else:
			push_warning("CursorManager: не найден курсор " + path)

func _scaled(tex: Texture2D, scale: float) -> Texture2D:
	var img: Image = tex.get_image()
	if not img or scale <= 1.0:
		return tex
	img.convert(Image.FORMAT_RGBA8)
	var w: int = int(round(img.get_width() * scale))
	var h: int = int(round(img.get_height() * scale))
	img.resize(w, h, Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(img)

func set_cursor(kind: String):
	if kind == _current:
		return
	_current = kind
	if virtual:
		return
	var tex: Texture2D = _textures.get(kind, null)
	if not tex:
		return
	var hotspot: Vector2 = HOTSPOTS.get(kind, Vector2(0, 0)) * SCALE
	Input.set_custom_mouse_cursor(tex, Input.CURSOR_ARROW, hotspot)

func reset():
	if _current == "" and _textures.is_empty():
		return
	_current = ""
	if virtual:
		return
	Input.set_custom_mouse_cursor(null, Input.CURSOR_ARROW)

func get_current_cursor() -> Dictionary:
	if _current.is_empty() or not _textures.has(_current):
		return {}
	return {
		"tex": _textures[_current],
		"hotspot": HOTSPOTS.get(_current, Vector2.ZERO) * SCALE,
	}
