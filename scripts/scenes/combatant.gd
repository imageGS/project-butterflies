class_name Combatant
extends RefCounted

var char_name: String
var skills: Dictionary          # {"stamina": 5, ...}
var limbs: Dictionary = {}      # {"head": Limb, ...}
var inventory: Array = []       # Array of Item

func _init(_name: String, _skills: Dictionary):
	char_name = _name
	skills = _skills
	limbs = {
		"head":       Limb.new("head", 5, "смерть/вырубание"),
		"torso":      Limb.new("torso", 10, "тяжёлое ранение"),
		"arm_left":   Limb.new("arm_left", 6, "нельзя атаковать левой"),
		"arm_right":  Limb.new("arm_right", 6, "нельзя атаковать правой"),
		"leg_left":   Limb.new("leg_left", 6, "штраф к бегу/уклонению"),
		"leg_right":  Limb.new("leg_right", 6, "штраф к бегу/уклонению"),
	}

# Возвращает значение навыка с учётом штрафов за сломанные конечности
func get_skill(skill_name: String) -> int:
	var base: int = skills.get(skill_name, 0)
	var penalty: int = 0
	if not limbs["arm_left"].is_alive:
		penalty += 2
	if not limbs["arm_right"].is_alive:
		penalty += 2
	if not limbs["leg_left"].is_alive:
		penalty += 2
	if not limbs["leg_right"].is_alive:
		penalty += 2
	return max(0, base - penalty)

# Без штрафов (для базовых проверок)
func get_skill_raw(skill_name: String) -> int:
	return skills.get(skill_name, 0)

func is_alive() -> bool:
	return limbs["head"].is_alive and limbs["torso"].is_alive

func print_status():
	print("--- ", char_name, " ---")
	for key in limbs:
		var limb = limbs[key]
		var status = str(limb.hp) + " hp" if limb.is_alive else "СЛОМАНА"
		print("  ", key, ": ", status)

func get_random_alive_limb() -> String:
	var alive_limbs = []
	for key in limbs:
		if limbs[key].is_alive:
			alive_limbs.append(key)
	if alive_limbs.size() == 0:
		return ""
	return alive_limbs[randi() % alive_limbs.size()]
