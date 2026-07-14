class_name Limb
extends RefCounted

var name: String
var hp: int
var max_hp: int
var broken: bool = false
var destroyed: bool = false
var debuff: String

func _init(_name: String, _hp: int, _debuff: String):
	name = _name
	hp = _hp
	max_hp = _hp
	debuff = _debuff

func is_intact() -> bool:
	return hp > 0

func is_broken() -> bool:
	return broken and not destroyed

func is_destroyed() -> bool:
	return destroyed

func take_damage(dmg: int) -> int:
	var actual: int = dmg
	if is_broken():
		actual = int(dmg * 1.5)
	hp -= actual
	if hp <= 0:
		if not broken:
			hp = 0
			broken = true
		else:
			destroyed = true
	return actual

func broken_debuff_score() -> int:
	return 1 if broken else 0

func destroyed_debuff_score() -> int:
	return 2 if destroyed else 0

func get_debuff_text() -> String:
	if destroyed: return debuff.replace("штраф", "сильный штраф")
	if broken: return debuff
	return ""
