class_name EnemyData
extends Resource

@export var char_name: String = ""
@export var total_hp: int = 20
@export var stamina: int = 3
@export var agility: int = 5

@export var head: LimbData
@export var torso: LimbData
@export var arm_right: LimbData
@export var arm_left: LimbData
@export var leg_right: LimbData
@export var leg_left: LimbData

func to_combatant() -> Combatant:
	var c := Combatant.new(char_name, {"stamina": stamina, "agility": agility})
	c.total_hp = total_hp; c.max_total_hp = total_hp
	for ld in [head, torso, arm_right, arm_left, leg_right, leg_left]:
		if ld:
			var l := Limb.new(ld.limb_name, ld.hp, ld.debuff)
			if ld.action: l.action = {"name": ld.action.action_name, "dmg": ld.action.dmg, "desc": ld.action.desc}
			c.limbs[ld.limb_name] = l
	return c
