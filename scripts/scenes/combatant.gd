class_name Combatant
extends RefCounted

var char_name: String
var skills: Dictionary
var limbs: Dictionary = {}
var inventory: Array = []
var total_hp: int = 20
var max_total_hp: int = 20

func _init(_name: String, _skills: Dictionary):
	char_name = _name
	skills = _skills
	limbs = {
		"head":       Limb.new("head", 8, "пропуск хода"),
		"torso":      Limb.new("torso", 14, "удвоение урона по пулу HP"),
		"arm_left":   Limb.new("arm_left", 8, "нельзя атаковать левой"),
		"arm_right":  Limb.new("arm_right", 8, "нельзя атаковать правой"),
		"leg_left":   Limb.new("leg_left", 8, "штраф к защите"),
		"leg_right":  Limb.new("leg_right", 8, "штраф к защите"),
	}

func get_skill(skill_name: String) -> int:
	var base: int = skills.get(skill_name, 0)
	var penalty: int = 0
	for key in limbs:
		var l: Limb = limbs[key]
		if l.destroyed:
			penalty += 3
		elif l.broken:
			penalty += 1
	return max(0, base - penalty)

func get_skill_raw(skill_name: String) -> int:
	return skills.get(skill_name, 0)

func is_alive() -> bool:
	return total_hp > 0

func take_total_damage(amount: int):
	total_hp = max(0, total_hp - amount)
	_check_vitals()

func _check_vitals():
	if limbs["head"].is_destroyed() or limbs["torso"].is_destroyed():
		total_hp = 0

func destroyed_limb_count() -> int:
	var c: int = 0
	for key in limbs:
		if limbs[key].destroyed: c += 1
	return c

func broken_limb_count() -> int:
	var c: int = 0
	for key in limbs:
		if limbs[key].broken: c += 1
	return c

func get_random_alive_limb() -> String:
	var alive_limbs := []
	for key in limbs:
		if not limbs[key].destroyed:
			alive_limbs.append(key)
	if alive_limbs.is_empty(): return ""
	return alive_limbs[randi() % alive_limbs.size()]
