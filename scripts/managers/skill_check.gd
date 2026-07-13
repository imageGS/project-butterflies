class_name SkillCheck
extends RefCounted

enum Result { CRIT_FAIL, FAIL, SUCCESS, CRIT_SUCCESS }

const CRIT_FAIL_THRESHOLD := 1
const CRIT_SUCCESS_THRESHOLD := 20

static func roll(modifier: int = 0) -> int:
	return randi() % 20 + 1 + modifier

static func check(skill_value: int, dc: int, modifiers: Dictionary = {}) -> Dictionary:
	var raw := randi() % 20 + 1

	var total_mod: int = modifiers.get("bonus", 0) - modifiers.get("penalty", 0)
	if modifiers.get("is_sanity_penalty", false) and PlayerStats.sanity <= 3:
		total_mod -= 2
	if modifiers.get("is_sanity_penalty", false) and PlayerStats.sanity <= 1:
		total_mod -= 2

	var total: int = raw + skill_value + total_mod
	var margin: int = total - dc

	var result: int
	if raw <= CRIT_FAIL_THRESHOLD:
		result = Result.CRIT_FAIL
	elif total >= dc:
		result = Result.CRIT_SUCCESS if raw >= CRIT_SUCCESS_THRESHOLD else Result.SUCCESS
	else:
		result = Result.FAIL

	return {
		"raw": raw,
		"skill": skill_value,
		"modifier": total_mod,
		"total": total,
		"dc": dc,
		"margin": margin,
		"result": result,
		"success": result >= Result.SUCCESS,
		"critical": result == Result.CRIT_FAIL or result == Result.CRIT_SUCCESS,
	}

static func passive_check(skill_value: int, dc: int, modifiers: Dictionary = {}) -> Dictionary:
	return check(skill_value, dc, modifiers)

static func dc_description(dc: int) -> String:
	match dc:
		0, 1, 2, 3, 4: return "Тривиальная"
		5, 6, 7: return "Простая"
		8, 9: return "Лёгкая"
		10, 11, 12: return "Средняя"
		13, 14: return "Сложная"
		15, 16: return "Очень сложная"
		17, 18: return "Экстремальная"
		19, 20: return "Почти невозможная"
		_: return "За пределами"
