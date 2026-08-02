extends Node

## Библиотека переиспользуемых объектов (EntityTemplate).
## Сканирует resources/templates/entities/<категория>/*.tres, кэширует по id.
## Резолвит спавны: базовые поля шаблона + пер-инстанс overrides.

const ROOT: String = "res://resources/templates/entities"
const OVERRIDABLE: Array[String] = [
	"type", "subtype", "facing", "texture", "extra",
	"light_source", "size", "ceiling_lift", "visual_offset_x",
]

var _templates: Dictionary = {}

func _ready():
	reload()

func reload():
	_templates.clear()
	for path in _scan(ROOT):
		if not ResourceLoader.exists(path):
			continue
		var t: EntityTemplate = load(path)
		if t and not t.id.is_empty() and not _templates.has(t.id):
			_templates[t.id] = t

func _scan(folder: String) -> Array[String]:
	var result: Array[String] = []
	var dir := DirAccess.open(folder)
	if not dir:
		return result
	dir.list_dir_begin()
	var f := dir.get_next()
	while f != "":
		if f == "." or f == "..":
			f = dir.get_next()
			continue
		var p := folder.path_join(f)
		if dir.current_is_dir():
			result.append_array(_scan(p))
		elif f.ends_with(".tres"):
			result.append(p)
		f = dir.get_next()
	dir.list_dir_end()
	result.sort()
	return result

func get_template(id: String) -> EntityTemplate:
	return _templates.get(id, null)

func get_all() -> Array:
	var list: Array = _templates.values()
	list.sort_custom(func(a, b): return _cmp(a, b))
	return list

func get_by_category(cat: String) -> Array:
	var list: Array = []
	for t in _templates.values():
		if t.category == cat:
			list.append(t)
	list.sort_custom(func(a, b): return a.display_name < b.display_name)
	return list

func get_categories() -> Array[String]:
	var cats: Array[String] = []
	for t in _templates.values():
		if not cats.has(t.category):
			cats.append(t.category)
	cats.sort()
	return cats

func _cmp(a: EntityTemplate, b: EntityTemplate) -> bool:
	if a.category != b.category:
		return a.category < b.category
	return a.display_name < b.display_name

## Резолв спавна: без template_id возвращает тот же спавн.
## Иначе — дубликат с базовыми полями шаблона + overrides.
func resolve_spawn(raw: EntitySpawn) -> EntitySpawn:
	var t: EntityTemplate = null
	if not raw.template_id.is_empty():
		t = get_template(raw.template_id)
	var s: EntitySpawn = raw.duplicate()
	if t:
		s.type = t.type
		s.subtype = t.subtype
		s.facing = t.facing
		s.extra = t.extra.duplicate()
		s.light_source = t.light_source.duplicate()
		s.size = t.size
		s.ceiling_lift = t.ceiling_lift
		s.visual_offset_x = t.visual_offset_x
		var st: String = t.get_state_texture()
		if not st.is_empty():
			s.texture = st
	for key in raw.overrides:
		if OVERRIDABLE.has(key):
			s.set(key, raw.overrides[key])
	return s

func update_override(spawn: EntitySpawn, field: String, value):
	if OVERRIDABLE.has(field):
		spawn.overrides[field] = value
	else:
		spawn.overrides.erase(field)

func clear_override(spawn: EntitySpawn, field: String):
	spawn.overrides.erase(field)

func clear_all_overrides(spawn: EntitySpawn):
	spawn.overrides = {}

func set_extra_override(spawn: EntitySpawn, key: String, value):
	var extra: Dictionary = (spawn.overrides.get("extra", {}) if spawn.overrides.has("extra") else {})
	if value == null:
		extra.erase(key)
	else:
		extra[key] = value
	if extra.is_empty():
		spawn.overrides.erase("extra")
	else:
		spawn.overrides["extra"] = extra

func set_light_override(spawn: EntitySpawn, light: Dictionary):
	if light.is_empty():
		spawn.overrides.erase("light_source")
	else:
		spawn.overrides["light_source"] = light

func create_from_spawn(s: EntitySpawn, id: String, display_name: String, category: String) -> EntityTemplate:
	var t := EntityTemplate.new()
	t.id = id
	t.display_name = display_name
	t.category = category
	t.type = s.type
	t.subtype = s.subtype
	t.facing = s.facing
	t.default_state = "front"
	if not s.texture.is_empty():
		t.sprites = { "front": s.texture }
	t.extra = s.extra.duplicate()
	t.light_source = s.light_source.duplicate()
	t.size = s.size
	t.ceiling_lift = s.ceiling_lift
	t.visual_offset_x = s.visual_offset_x
	return t

func save_template(t: EntityTemplate) -> Error:
	if not DirAccess.dir_exists_absolute(ROOT):
		var err0 := DirAccess.make_dir_recursive_absolute(ROOT)
		if err0 != OK:
			return err0
	var cat_dir := ROOT + "/" + t.category
	if not DirAccess.dir_exists_absolute(cat_dir):
		var err1 := DirAccess.make_dir_recursive_absolute(cat_dir)
		if err1 != OK:
			return err1
	var err := ResourceSaver.save(t, "%s/%s.tres" % [cat_dir, t.id])
	if err == OK:
		_templates[t.id] = t
	return err
