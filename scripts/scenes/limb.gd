class_name Limb
extends RefCounted

var name: String
var hp: int
var max_hp: int
var is_alive: bool = true
var debuff: String
var fragile: bool = false

func _init(_name: String, _hp: int, _debuff: String):
	name = _name
	hp = _hp
	max_hp = _hp
	debuff = _debuff

func take_damage(damage: int) -> int:
	var dmg: int = damage
	if fragile:
		dmg = int(damage * 1.5)
		fragile = false
	hp -= dmg
	if hp <= 0:
		hp = 0
		is_alive = false
		return dmg
	fragile = true
	return dmg
