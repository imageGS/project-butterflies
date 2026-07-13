class_name Limb
extends RefCounted

var name: String
var hp: int
var is_alive: bool = true
var debuff: String

func _init(_name: String, _hp: int, _debuff: String):
	name = _name
	hp = _hp
	debuff = _debuff

func take_damage(damage: int):
	hp -= damage
	if hp <= 0:
		hp = 0
		is_alive = false
		print("  !!! ", name, " выведена из строя. Эффект: ", debuff)
