extends Node

signal health_depleted
signal sanity_depleted

enum Skill { COMPOSURE, STAMINA, AGILITY, RESOURCEFULNESS, INTUITION }
const SKILL_NAMES := ["composure", "stamina", "agility", "resourcefulness", "intuition"]
const SKILL_NAMES_RU := ["Хладнокровие", "Стойкость", "Подвижность", "Находчивость", "Интуиция"]

@export var composure: int = 6
@export var stamina: int = 5
@export var agility: int = 4
@export var resourcefulness: int = 3
@export var intuition: int = 2

@export var health: int = 10
@export var max_health: int = 10
@export var sanity: int = 10
@export var max_sanity: int = 10
@export var humanity: int = 10

@export var death_count: int = 0
@export var cycle: int = 0

var inventory: InventoryGrid = InventoryGrid.new()
var flags: Dictionary = {}

var _pending_corpse: Vector2i = Vector2i(-1, -1)
var _just_won: bool = false

func has_flag(key: String) -> bool:
	return flags.get(key, false) == true

func set_flag(key: String):
	flags[key] = true

func clear_flag(key: String):
	flags.erase(key)

func get_skill(skill_name: String) -> int:
	match skill_name:
		"composure": return composure
		"stamina": return stamina
		"agility": return agility
		"resourcefulness": return resourcefulness
		"intuition": return intuition
	return 1

func set_skill(skill_name: String, value: int):
	match skill_name:
		"composure": composure = value
		"stamina": stamina = value
		"agility": agility = value
		"resourcefulness": resourcefulness = value
		"intuition": intuition = value

func get_skill_list() -> Dictionary:
	return {
		"composure": composure,
		"stamina": stamina,
		"agility": agility,
		"resourcefulness": resourcefulness,
		"intuition": intuition,
	}

func take_damage(amount: int) -> bool:
	health = max(0, health - amount)
	if health <= 0:
		health_depleted.emit()
		return true
	return false

func heal(amount: int):
	health = min(max_health, health + amount)

func lose_sanity(amount: int) -> bool:
	sanity = max(0, sanity - amount)
	if sanity <= 0:
		sanity_depleted.emit()
		return true
	return false

func restore_sanity(amount: int):
	sanity = min(max_sanity, sanity + amount)

func change_humanity(amount: int):
	humanity = clamp(humanity + amount, 0, 10)

var _limb_snapshot: Dictionary = {}

func save_limb_state(c: Combatant):
	_limb_snapshot.clear()
	for key in c.limbs:
		var l: Limb = c.limbs[key]
		_limb_snapshot[key] = {"hp": l.hp, "broken": l.broken, "destroyed": l.destroyed}

func restore_limb_state(c: Combatant):
	if _limb_snapshot.is_empty(): return
	for key in _limb_snapshot:
		if c.limbs.has(key):
			var s: Dictionary = _limb_snapshot[key]
			var l: Limb = c.limbs[key]
			l.hp = s.get("hp", l.max_hp)
			l.broken = s.get("broken", false)
			l.destroyed = s.get("destroyed", false)

func create_combatant() -> Combatant:
	var c := Combatant.new("№13", get_skill_list())
	restore_limb_state(c)
	var flat: Array = []
	for i in inventory.size():
		flat.append(inventory.get_item(i))
	c.inventory = flat
	return c

func reset():
	composure = 6; stamina = 5; agility = 4
	resourcefulness = 3; intuition = 2
	health = 10; max_health = 10
	sanity = 10; max_sanity = 10
	humanity = 10
	death_count = 0
	cycle = 0
	inventory.slots.clear()
	flags.clear()
	_limb_snapshot.clear()
