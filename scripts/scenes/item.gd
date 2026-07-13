class_name Item
extends RefCounted

var name: String
var description: String
var heal_amount: int

func _init(_name: String, _description: String, _heal: int):
	name = _name
	description = _description
	heal_amount = _heal
