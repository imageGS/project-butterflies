class_name EntitySpawn
extends Resource

enum Type { ENEMY, NPC, ITEM, OBJECT }

@export var position: Vector2i = Vector2i(-1, -1)
@export var type: Type = Type.ENEMY
@export var subtype: String = ""
@export var facing: int = 2
@export var dialogue_file: String = ""
@export var extra: Dictionary = {}

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
