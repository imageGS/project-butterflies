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
	limbs = _default_limbs()

func _default_limbs() -> Dictionary:
	return {
		"head":       Limb.new("head", 8, "пропуск хода"),
		"torso":      Limb.new("torso", 14, "удвоение урона по пулу HP"),
		"arm_left":   Limb.new("arm_left", 8, "нельзя атаковать левой"),
		"arm_right":  Limb.new("arm_right", 8, "нельзя атаковать правой"),
		"leg_left":   Limb.new("leg_left", 8, "штраф к защите"),
		"leg_right":  Limb.new("leg_right", 8, "штраф к защите"),
	}

func set_enemy_limbs(limb_data: Dictionary):
	for key in limb_data:
		var ld: Dictionary = limb_data[key]
		var l := Limb.new(key, ld.get("hp", 6), ld.get("debuff", ""))
		l.action = ld.get("action", {})
		limbs[key] = l

func get_available_actions() -> Dictionary:
	var acts: Dictionary = {}
	for key in LIMB_NAMES:
		var l: Limb = limbs.get(key)
		if l and not l.is_destroyed():
			if not l.action.is_empty() and not l.is_broken():
				acts[key] = l.action
	return acts

const LIMB_NAMES := ["head", "torso", "arm_left", "arm_right", "leg_left", "leg_right"]

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
