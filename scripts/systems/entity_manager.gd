extends Node
class_name EntityManager

enum Dir { NORTH, EAST, SOUTH, WEST }

var entities: Array = []
var map_manager: MapManager
var dialogue_system: DialogueSystem

func setup(mm: MapManager, ds: DialogueSystem):
	map_manager = mm
	dialogue_system = ds


func setup_entities(station_data) -> Array:
	entities = []
	if PlayerStats._pending_corpse.x >= 0:
		entities.append({
			"grid_x": PlayerStats._pending_corpse.x, "grid_y": PlayerStats._pending_corpse.y,
			"color": Color(0.5, 0.1, 0.1, 0.6),
			"type": "object", "object_type": "lore",
			"data": { "name": "Труп", "description": "Вы убили это существо в бою." },
		})
		PlayerStats._pending_corpse = Vector2i(-1, -1)

	if station_data:
		for raw: EntitySpawn in station_data.entity_spawns:
			var spawn: EntitySpawn = TemplateLibrary.resolve_spawn(raw)
			var ent: Dictionary = _create_entity_from_spawn(spawn)
			if not ent.is_empty():
				entities.append(ent)
		for exit: ExitData in station_data.exits:
			entities.append({ "grid_x": exit.position.x, "grid_y": exit.position.y, "color": Color(1, 0.9, 0.2, 0.9), "type": "exit_marker" })

	_spawn_floor_clutter()
	return entities


func get_entity_at(gx: int, gy: int) -> Dictionary:
	for ent in entities:
		if ent.get("grid_x") == gx and ent.get("grid_y") == gy:
			return ent
	return {}


func has_wall_neighbor(gx: int, gy: int) -> bool:
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			var nx: int = gx + dx; var ny: int = gy + dy
			if nx < 0 or ny < 0 or ny >= map_manager.map_data.size() or nx >= map_manager.map_data[0].size(): continue
			if not map_manager.is_walkable(nx, ny): return true
	return false


func _spawn_floor_clutter():
	var decals: Array[String] = ["garbage.png"]
	var weights: Array[float] = [1.0]
	var sizes: Array[float] = [0.25]
	var cache: Dictionary = {}
	for dn in decals:
		var t := load("res://assets/textures/decal/" + dn) as Texture2D
		if t: cache[dn] = t
	if cache.is_empty(): return

	var occupied: Dictionary = {}
	for ent in entities:
		if ent.has("grid_x") and ent.has("grid_y"):
			occupied["%d,%d" % [ent.grid_x, ent.grid_y]] = true

	var total: int = map_manager.map_data.size() * map_manager.map_data[0].size()
	for _i in range(int(total * 0.1)):
		var gx: int = randi() % map_manager.map_data[0].size()
		var gy: int = randi() % map_manager.map_data.size()
		if not map_manager.is_walkable(gx, gy): continue
		if occupied.has("%d,%d" % [gx, gy]): continue
		if has_wall_neighbor(gx, gy): continue

		var r: float = randf()
		var sum: float = 0.0
		var idx: int = 0
		for w in weights.size():
			sum += weights[w]
			if r <= sum: idx = w; break

		var tex: Texture2D = cache.get(decals[idx], null)
		if not tex: continue
		occupied["%d,%d" % [gx, gy]] = true
		entities.append({
			"grid_x": gx, "grid_y": gy,
			"texture": tex,
			"type": "object", "object_type": "floor_decal",
			"size": sizes[idx],
		})


func _create_entity_from_spawn(spawn: EntitySpawn) -> Dictionary:
	match spawn.type:
		EntitySpawn.Type.ENEMY:
			return _create_enemy_entity(spawn)
		EntitySpawn.Type.NPC:
			return _create_npc_entity(spawn)
		EntitySpawn.Type.ITEM:
			return _create_item_entity(spawn)
		EntitySpawn.Type.OBJECT:
			return _create_object_entity(spawn)
	return {}


func _create_enemy_entity(spawn: EntitySpawn) -> Dictionary:
	var subtype: String = spawn.subtype
	if subtype.is_empty(): subtype = "bunny"
	var tex_base: String = "res://sprites/enemy/bunny/bunny_enemy" if subtype == "bunny" else "res://sprites/enemy/scav_enemy_1"
	var tex_f: Texture2D = load(tex_base + ".png") as Texture2D
	var tex_b: Texture2D = load("res://sprites/enemy/bunny/bunny_enemy_back.png") as Texture2D if subtype == "bunny" else tex_f
	var tex_l: Texture2D = load("res://sprites/enemy/bunny/bunny_enemy_left.png") as Texture2D if subtype == "bunny" else tex_f
	var tex_r: Texture2D = load("res://sprites/enemy/bunny/bunny_enemy_right.png") as Texture2D if subtype == "bunny" else tex_f
	var tex_c: Texture2D = load("res://sprites/enemy/bunny/bunny_enemy_chase.png") as Texture2D if subtype == "bunny" else tex_f
	var audio := AudioStreamPlayer.new()
	audio.volume_db = -4.0
	add_child(audio)
	return {
		"grid_x": spawn.position.x, "grid_y": spawn.position.y,
		"anim_x": float(spawn.position.x), "anim_y": float(spawn.position.y),
		"color": Color(0.8, 0.2, 0.2),
		"type": "enemy",
		"facing": spawn.facing,
		"textures": { "front": tex_f, "back": tex_b, "left": tex_l, "right": tex_r, "chase": tex_c },
		"move_progress": 1.0,
		"move_timer": randf_range(0.5, 1.0),
		"chase_active": false,
		"audio_player": audio,
	}


func _create_npc_entity(spawn: EntitySpawn) -> Dictionary:
	var subtype: String = spawn.subtype
	if subtype.is_empty(): subtype = "wanderer"
	var name: String = spawn.extra.get("name", "")
	var dialogue: Array = []
	var parsed: Variant = null
	var paths: Array[String] = [
		"res://dialogues/%s/main.json" % subtype,
		"res://dialogues/%s.json" % subtype,
	]
	for p in paths:
		if FileAccess.file_exists(p):
			var file := FileAccess.get_file_as_string(p)
			if file:
				parsed = JSON.parse_string(file)
				if parsed is Dictionary: break
	if parsed is Dictionary:
		var d: Dictionary = parsed
		if name.is_empty():
			name = d.get("name", "Незнакомец")
		if d.has("nodes") and typeof(d["nodes"]) == TYPE_ARRAY:
			dialogue = d["nodes"]
		elif dialogue_system and dialogue_system.has_method("convert_nodes"):
			dialogue = dialogue_system.convert_nodes(d)
	if name.is_empty():
		name = "Незнакомец"
	var ent: Dictionary = {
		"grid_x": spawn.position.x, "grid_y": spawn.position.y,
		"color": Color(0.2, 0.6, 0.2),
		"type": "npc",
		"name": name,
		"dialogue": dialogue,
	}
	if not spawn.texture.is_empty():
		var visual := _resolve_entity_visuals(spawn.texture)
		if visual.has("texture"): ent["texture"] = visual["texture"]
		if visual.has("textures"): ent["textures"] = visual["textures"]
	return ent


func _create_item_entity(spawn: EntitySpawn) -> Dictionary:
	var subtype: String = spawn.subtype
	if subtype.is_empty(): subtype = "misc"
	return {
		"grid_x": spawn.position.x, "grid_y": spawn.position.y,
		"color": Color(0.2, 0.9, 0.2),
		"type": "object",
		"object_type": "container",
		"data": { "name": subtype, "description": "Лежит на полу.", "loot": [subtype] },
	}


func _create_object_entity(spawn: EntitySpawn) -> Dictionary:
	var subtype: String = spawn.subtype
	if subtype.is_empty(): subtype = "lore"
	var data: Dictionary = spawn.extra.duplicate()
	if not data.has("name"):
		data.name = subtype
	if not data.has("description"):
		data.description = "Ничего особенного."
	var ent: Dictionary = {
		"grid_x": spawn.position.x, "grid_y": spawn.position.y,
		"color": Color(0.6, 0.6, 0.6),
		"type": "object",
		"object_type": subtype,
		"data": data,
		"size": spawn.size,
	}
	if not spawn.light_source.is_empty():
		ent["light_source"] = spawn.light_source.duplicate()
	if not spawn.texture.is_empty():
		var visual := _resolve_entity_visuals(spawn.texture)
		if visual.has("texture"): ent["texture"] = visual["texture"]
		if visual.has("textures"): ent["textures"] = visual["textures"]
		if visual.has("front_on") and not data.has("tv_front_on"): data.tv_front_on = visual["front_on"]
		if visual.has("front_off") and not data.has("tv_front_off"): data.tv_front_off = visual["front_off"]
	if data.has("color") and data["color"] is Array and data["color"].size() >= 3:
		ent["color"] = Color(data["color"][0], data["color"][1], data["color"][2])
	if spawn.ceiling_lift != 0.0:
		ent["ceiling_lift"] = spawn.ceiling_lift
	if spawn.visual_offset_x != 0.0:
		ent["visual_offset_x"] = spawn.visual_offset_x
	if spawn.facing != 2:
		ent["facing"] = spawn.facing
	return ent


func _resolve_entity_visuals(tid: String) -> Dictionary:
	if tid.ends_with(".png"):
		var t := load("res://" + tid) as Texture2D
		if t: return { "texture": t }
		return {}
	var base: String = ("res://" + tid).trim_suffix("/")
	var result: Dictionary = {}
	var dir := DirAccess.open(base)
	if not dir: return {}
	var front: Texture2D = null
	var back: Texture2D = null
	var left: Texture2D = null
	var right: Texture2D = null
	var other: Texture2D = null
	var front_on: Texture2D = null
	var front_off: Texture2D = null
	dir.list_dir_begin()
	var f := dir.get_next()
	while f != "":
		if not dir.current_is_dir() and f.ends_with(".png"):
			var t := load(base + "/" + f) as Texture2D
			if t:
				if f.contains("front_on"):
					if not front_on: front_on = t
				elif f.contains("front_off"):
					if not front_off: front_off = t
				elif f.contains("front"):
					if not front: front = t
				elif f.contains("back"):
					if not back: back = t
				elif f.contains("side_l") or f.contains("left") or f.contains("_l."):
					if not left: left = t
				elif f.contains("side_r") or f.contains("right") or f.contains("_r."):
					if not right: right = t
				elif not other:
					other = t
		f = dir.get_next()
	dir.list_dir_end()
	if front or back or left or right:
		if not front and front_off: front = front_off
		if not front: front = other
		if not front: front = back if back else (left if left else right)
		if not back: back = front
		if not left: left = front
		if not right: right = front
		result["textures"] = { "front": front, "back": back, "left": left, "right": right }
	elif other:
		result["texture"] = other
	if front_on: result["front_on"] = front_on
	if front_off: result["front_off"] = front_off
	return result
