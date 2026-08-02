class_name EntityTemplate
extends Resource

## Переиспользуемый объект-префаб: текстуры/состояния, размер, лут, свет.
## Станции ссылаются на него через EntitySpawn.template_id; изменения
## шаблона распространяются на все инстансы, кроме переопределённых полей.

@export var id: String = ""
@export var display_name: String = ""
@export var category: String = "decor"
@export var type: EntitySpawn.Type = EntitySpawn.Type.OBJECT
@export var subtype: String = ""
@export var facing: int = 2
## Состояние -> путь текстуры (без "res://"), напр. {"front": "sprites/entity/tv"}.
## У объектов с состояниями: {"front_on": "...", "front_off": "..."}.
@export var sprites: Dictionary = {}
@export var default_state: String = "front"
@export var extra: Dictionary = {}
@export var light_source: Dictionary = {}
@export var size: float = 0.3
@export var ceiling_lift: float = 0.0
@export var visual_offset_x: float = 0.0

func get_state_texture() -> String:
	if sprites.has(default_state) and sprites[default_state] is String:
		return sprites[default_state]
	if sprites.has("front") and sprites["front"] is String:
		return sprites["front"]
	return ""

func has_light() -> bool:
	return not light_source.is_empty()
