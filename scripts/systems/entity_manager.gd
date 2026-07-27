extends Node
class_name EntityManager

enum Dir { NORTH, EAST, SOUTH, WEST }

var entities: Array = []
var map_manager: MapManager
var dialogue_system: DialogueSystem

func setup(mm: MapManager, ds: DialogueSystem):
	map_manager = mm
	dialogue_system = ds


func setup_entities(station_data, is_shelter: bool) -> Array:
	entities = []
	if PlayerStats._pending_corpse.x >= 0:
		entities.append({
			"grid_x": PlayerStats._pending_corpse.x, "grid_y": PlayerStats._pending_corpse.y,
			"color": Color(0.5, 0.1, 0.1, 0.6),
			"type": "object", "object_type": "lore",
			"data": { "name": "Труп", "description": "Вы убили это существо в бою." },
		})
		PlayerStats._pending_corpse = Vector2i(-1, -1)

	if station_data and not station_data.entity_spawns.is_empty():
		for spawn: EntitySpawn in station_data.entity_spawns:
			var ent: Dictionary = _create_entity_from_spawn(spawn)
			if not ent.is_empty():
				entities.append(ent)
	elif is_shelter:
		entities.append({ "grid_x": 3, "grid_y": 5, "color": Color(0.3, 0.5, 0.7), "type": "object", "object_type": "rest",
			"data": { "name": "кровать", "description": "Старая кровать." }})
		entities.append({ "grid_x": 10, "grid_y": 10, "color": Color(0.4, 0.8, 0.4), "type": "object", "object_type": "lore",
			"data": { "name": "ТВ", "description": "Работает. Помехи, потом голос: «...проход открыт в западном крыле». И снова помехи." }})
		entities.append({ "grid_x": 1, "grid_y": 3, "color": Color(1.0, 0.6, 0.2), "type": "object", "object_type": "light", "size": 0.25,
			"data": { "name": "Свеча", "description": "Огарок свечи в жестяной банке." },
			"light_source": { "radius": 120.0, "intensity": 0.8, "color": Color(1.0, 0.65, 0.3), "flicker": 0.12, "height": 0.8 }})
		entities.append({ "grid_x": 13, "grid_y": 3, "color": Color(1.0, 0.6, 0.2), "type": "object", "object_type": "light", "size": 0.25,
			"data": { "name": "Свеча", "description": "Огарок свечи в жестяной банке." },
			"light_source": { "radius": 120.0, "intensity": 0.8, "color": Color(1.0, 0.65, 0.3), "flicker": 0.12, "height": 0.8 }})
		var medkit_tex := load("res://sprites/entity/medkit.png") as Texture2D
		entities.append({ "grid_x": 7, "grid_y": 10, "texture": medkit_tex, "type": "object", "object_type": "container",
			"data": { "name": "Аптечка", "loot": ["Медикаменты"] }, "size": 0.2})
		var kitsu_portrait := load("res://sprites/npc/kitsu/kitsu_front.png") as Texture2D
		var kitsu_front := load("res://sprites/npc/kitsu/kitsu_front.png") as Texture2D
		var kitsu_back := load("res://sprites/npc/kitsu/kitsu_back.png") as Texture2D
		var kitsu_left := load("res://sprites/npc/kitsu/kitsu_left.png") as Texture2D
		var kitsu_right := load("res://sprites/npc/kitsu/kitsu_right.png") as Texture2D
		var kitsu_dialogue: Array = []
		var f := FileAccess.get_file_as_string("res://dialogues/kitsu/main.json")
		if f:
			var d: Variant = JSON.parse_string(f)
			if d and typeof(d) == TYPE_DICTIONARY:
				kitsu_dialogue = dialogue_system.convert_nodes(d)
		entities.append({ "grid_x": 5, "grid_y": 5, "color": Color(0.2, 0.6, 0.2), "type": "npc", "name": "Кицунэ", "texture": kitsu_portrait, "textures": { "front": kitsu_front, "back": kitsu_back, "left": kitsu_left, "right": kitsu_right }, "dialogue": kitsu_dialogue })
	else:
		_setup_fallback_entities()

	if station_data:
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
	var decals: Array[String] = ["garbage.png", "crack.png"]
	var weights: Array[float] = [0.2, 0.8]
	var sizes: Array[float] = [0.25, 0.2]
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
	var tex_f: Texture2D = load(tex_base + ".png") if subtype == "bunny" else load(tex_base + ".png")
	var tex_b: Texture2D = load("res://sprites/enemy/bunny/bunny_enemy_back.png") if subtype == "bunny" else tex_f
	var tex_l: Texture2D = load("res://sprites/enemy/bunny/bunny_enemy_left.png") if subtype == "bunny" else tex_f
	var tex_r: Texture2D = load("res://sprites/enemy/bunny/bunny_enemy_right.png") if subtype == "bunny" else tex_f
	var tex_c: Texture2D = load("res://sprites/enemy/bunny/bunny_enemy_chase.png") if subtype == "bunny" else tex_f
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
	var portrait: Texture2D = load("res://sprites/npc/17_sprite.png")
	var name: String = "Незнакомец"
	var dialogue: Array = []
	if subtype == "wanderer":
		var file := FileAccess.get_file_as_string("res://dialogues/wanderer.json")
		if file:
			var data: Dictionary = JSON.parse_string(file)
			if data:
				name = data.get("name", name)
				dialogue = data.get("nodes", [])
	return {
		"grid_x": spawn.position.x, "grid_y": spawn.position.y,
		"color": Color(0.2, 0.6, 0.2),
		"type": "npc",
		"name": name,
		"texture": portrait,
		"dialogue": dialogue,
	}


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
	return {
		"grid_x": spawn.position.x, "grid_y": spawn.position.y,
		"color": Color(0.6, 0.6, 0.6),
		"type": "object",
		"object_type": subtype,
		"data": data,
	}


func _setup_fallback_entities():
	var tex_f := load("res://sprites/enemy/bunny/bunny_enemy.png")
	var tex_b := load("res://sprites/enemy/bunny/bunny_enemy_back.png")
	var tex_l := load("res://sprites/enemy/bunny/bunny_enemy_left.png")
	var tex_r := load("res://sprites/enemy/bunny/bunny_enemy_right.png")
	var spawns: Array[Dictionary] = [
		{ "pos": Vector2i(2, 10), "dir": Dir.SOUTH },
		{ "pos": Vector2i(46, 10), "dir": Dir.SOUTH },
		{ "pos": Vector2i(25, 2), "dir": Dir.EAST },
	]
	for s in spawns:
		var audio := AudioStreamPlayer.new()
		audio.volume_db = -4.0
		add_child(audio)
		entities.append({
			"grid_x": s.pos.x, "grid_y": s.pos.y,
			"anim_x": float(s.pos.x), "anim_y": float(s.pos.y),
			"color": Color(0.8, 0.2, 0.2),
			"type": "enemy",
			"facing": s.dir,
			"textures": { "front": tex_f, "back": tex_b, "left": tex_l, "right": tex_r, "chase": load("res://sprites/enemy/bunny/bunny_enemy_chase.png") },
			"move_progress": 1.0,
			"move_timer": randf_range(0.5, 1.0),
			"chase_active": false,
			"audio_player": audio,
		})

	var objects: Array[Dictionary] = [
		{ "grid_x": 1, "grid_y": 9, "type": "object", "object_type": "container", "data": { "name": "Рюкзак", "description": "Чей-то брошенный рюкзак.", "loot": ["Консервы", "Бинт"] }},
		{ "grid_x": 16, "grid_y": 13, "type": "object", "object_type": "lore", "data": { "name": "Стена", "description": "Кто-то выцарапал: «NEW DAWN — ЭТО АД». Буквы дрожат." }},
		{ "grid_x": 28, "grid_y": 15, "type": "object", "object_type": "rest", "data": { "name": "скамья", "description": "Обшарпанная деревянная скамья." }},
		{ "grid_x": 28, "grid_y": 22, "type": "object", "object_type": "container", "data": { "name": "Ящик", "description": "Деревянный ящик с инструментами.", "loot": ["Аптечка"] }},
		{ "grid_x": 19, "grid_y": 20, "type": "object", "object_type": "lore", "data": { "name": "Труп", "description": "Тело в форме охранника. В кармане пусто. Нашивка: NEW DAWN." }},
		{ "grid_x": 36, "grid_y": 23, "type": "object", "object_type": "container", "data": { "name": "Сейф", "description": "Небольшой сейф. Код сбит, но дверца открыта.", "loot": ["Патроны", "Золотая монета"] }},
		{ "grid_x": 1, "grid_y": 22, "type": "object", "object_type": "lore", "data": { "name": "Газета", "description": "Скомканная газета. Заголовок: «ПРОПАЖА ЛЮДЕЙ В МЕТРО — ПОЛИЦИЯ БЕССИЛЬНА». Дата — полгода назад." }},
		{ "grid_x": 24, "grid_y": 24, "type": "object", "object_type": "lore", "data": { "name": "Алтарь", "description": "Странная конструкция в центре лабиринта. Свечи, символы. Кто-то проводил здесь ритуал." }},
		# Torches with dynamic lighting
		{ "grid_x": 8, "grid_y": 5, "color": Color(1.0, 0.6, 0.2), "type": "object", "object_type": "light", "size": 0.15,
			"data": { "name": "Факел", "description": "Пламя факела освещает коридор." },
			"light_source": { "radius": 200.0, "intensity": 1.0, "color": Color(1.0, 0.55, 0.2), "flicker": 0.15, "height": 1.0 }},
		{ "grid_x": 23, "grid_y": 7, "color": Color(1.0, 0.6, 0.2), "type": "object", "object_type": "light", "size": 0.15,
			"data": { "name": "Факел", "description": "Пламя факела освещает коридор." },
			"light_source": { "radius": 200.0, "intensity": 1.0, "color": Color(1.0, 0.55, 0.2), "flicker": 0.15, "height": 1.0 }},
		{ "grid_x": 20, "grid_y": 24, "color": Color(1.0, 0.6, 0.2), "type": "object", "object_type": "light", "size": 0.15,
			"data": { "name": "Факел", "description": "Пламя факела освещает коридор." },
			"light_source": { "radius": 200.0, "intensity": 1.0, "color": Color(1.0, 0.55, 0.2), "flicker": 0.15, "height": 1.0 }},
		{ "grid_x": 38, "grid_y": 21, "color": Color(1.0, 0.6, 0.2), "type": "object", "object_type": "light", "size": 0.15,
			"data": { "name": "Факел", "description": "Пламя факела освещает коридор." },
			"light_source": { "radius": 200.0, "intensity": 1.0, "color": Color(1.0, 0.55, 0.2), "flicker": 0.15, "height": 1.0 }},
	]
	for o in objects:
		entities.append(o)

	var file := FileAccess.get_file_as_string("res://dialogues/wanderer.json")
	if file:
		var data: Dictionary = JSON.parse_string(file)
		if data and data.has("nodes"):
			entities.append({
				"grid_x": 35, "grid_y": 23,
				"color": Color(0.2, 0.6, 0.2),
				"type": "npc",
				"name": data.get("name", "Незнакомец"),
				"texture": load("res://sprites/npc/17_sprite.png"),
				"dialogue": data.nodes,
			})
