class_name EntitySpawn
extends Resource

enum Type { ENEMY, NPC, ITEM, OBJECT }

@export var position: Vector2i = Vector2i(-1, -1)
@export var type: Type = Type.ENEMY
@export var subtype: String = ""
@export var facing: int = 2
@export var extra: Dictionary = {}
@export var light_source: Dictionary = {}
@export var texture: String = ""
@export var size: float = 0.3
@export var ceiling_lift: float = 0.0
@export var visual_offset_x: float = 0.0
@export var template_id: String = ""
@export var overrides: Dictionary = {}

func get_type_name() -> String:
	match type:
		Type.ENEMY: return "enemy"
		Type.NPC: return "npc"
		Type.ITEM: return "item"
		Type.OBJECT: return "object"
		_: return "unknown"

func display_name() -> String:
	var base: String = get_type_name()
	if subtype.is_empty():
		return base
	return base + ":" + subtype
