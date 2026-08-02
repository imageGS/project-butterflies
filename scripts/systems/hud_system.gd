extends Node
class_name HUDSystem

var hud_balls: Array[TextureRect] = []
var hud_ball_angles: Array[float] = [0.0, 0.0, 0.0, 0.0]
var hud_base_pos: Vector2

var ul_window: TextureRect
var dl_window: TextureRect
var stats_panel: StatsPanel
var ul_open: bool = false
var dl_open: bool = false
var ul_on_pos: Vector2
var dl_on_pos: Vector2
var ul_off_pos: Vector2
var dl_off_pos: Vector2

var inv_box: TextureRect
var char_box: TextureRect
var char_sprite: TextureRect
var inv_open: bool = false
var char_open: bool = false
var inv_on_pos: Vector2
var inv_off_pos: Vector2
var char_on_pos: Vector2
var char_off_pos: Vector2
var inv_panel: InventoryPanel
var equip_slots: EquipmentSlots

var _hud_root: Control
var _time_label: Label

signal examine_requested(item_name: String, description: String)

func setup(hud_root: Control, dialogue_system: DialogueSystem, font: Font):
	if not hud_root: return
	_hud_root = hud_root
	hud_base_pos = hud_root.position
	_time_label = _hud_root.get_node_or_null("TimeLabel")
	if _time_label:
		_time_label.add_theme_font_override("font", font)
		_time_label.text = "--:--"
	for ball_name in ["UL_Ball", "UR_Ball", "DL_Ball", "DR_Ball"]:
		var ball: TextureRect = hud_root.get_node_or_null(ball_name)
		if ball: hud_balls.append(ball)
	ul_window = hud_root.get_node_or_null("UL_Window")
	dl_window = hud_root.get_node_or_null("DL_Window")
	if ul_window:
		ul_on_pos = ul_window.position
		ul_off_pos = ul_on_pos - Vector2(ul_window.size.x + 20, 0)
		ul_window.position = ul_off_pos
	if dl_window:
		dl_on_pos = dl_window.position
		dl_off_pos = dl_on_pos - Vector2(dl_window.size.x + 20, 0)
		dl_window.position = dl_off_pos
		stats_panel = StatsPanel.new()
		stats_panel.set_size(dl_window.size - Vector2(20, 20))
		stats_panel.position = Vector2(10, 10)
		dl_window.add_child(stats_panel)

	inv_box = hud_root.get_node_or_null("INV_Box") as TextureRect
	char_box = hud_root.get_node_or_null("CHAR_Box") as TextureRect
	if char_box:
		char_sprite = char_box.get_node_or_null("PlayerInventory") as TextureRect

	if inv_box:
		inv_on_pos = inv_box.position
		inv_off_pos = Vector2(inv_on_pos.x, inv_on_pos.y - inv_box.size.y - 400)
		inv_box.position = inv_off_pos
		inv_box.visible = false

	if char_box:
		char_on_pos = char_box.position
		char_off_pos = Vector2(char_on_pos.x, char_on_pos.y - char_box.size.y - 400)
		char_box.position = char_off_pos
		char_box.visible = false

	if inv_box:
		inv_panel = InventoryPanel.new()
		inv_panel.inventory = PlayerStats.inventory
		inv_panel.position = Vector2(10, 10)
		inv_panel.examine_requested.connect(func(n, d): examine_requested.emit(n, d))
		inv_box.add_child(inv_panel)

	if char_box:
		equip_slots = EquipmentSlots.new()
		equip_slots.position = Vector2(6, 10)
		equip_slots.equipped.connect(_on_equip)
		equip_slots.unequipped.connect(_on_unequip)
		char_box.add_child(equip_slots)
		equip_slots.inventory_panel = inv_panel
	if char_sprite:
		char_sprite.hide()
	if inv_panel:
		inv_panel.equip_slots = equip_slots

	PlayerStats.flashlight_energy_changed.connect(_on_flashlight_energy_changed)
	_update_flashlight_bar()

func _update_flashlight_bar():
	var bar: FlashlightBar = _hud_root.get_node_or_null("FlashlightBar") as FlashlightBar
	if bar:
		bar.update_energy(PlayerStats.flashlight_energy, PlayerStats.max_flashlight_energy)

func _on_flashlight_energy_changed(energy: float, max_energy: float):
	_update_flashlight_bar()

func shake():
	if not _hud_root: return
	var tw := create_tween()
	tw.tween_property(_hud_root, "position", hud_base_pos + Vector2(randf_range(-3, 3), randf_range(-2, 2)), 0.04)
	tw.tween_property(_hud_root, "position", hud_base_pos, 0.08)

func tick_balls(delta: float, brightness: float = 1.0):
	var speed: float = clampf(brightness * 1.2, 0.0, 1.2)
	for i in hud_balls.size():
		var dir: float = -1.0 if i == 0 or i == 2 else 1.0
		hud_ball_angles[i] += delta * speed * dir
		hud_balls[i].rotation = hud_ball_angles[i]
	if _time_label:
		var gt: float = PlayerStats.game_time
		var h: int = floori(gt)
		var m: int = floori((gt - h) * 60.0)
		_time_label.text = "%02d:%02d" % [h, m]

func toggle_inventory():
	if not inv_box or not char_box: return
	if inv_open:
		inv_open = toggle_window(inv_box, inv_open, inv_on_pos, inv_off_pos)
		char_open = toggle_window(char_box, char_open, char_on_pos, char_off_pos)
	else:
		inv_box.show()
		char_box.show()
		inv_open = toggle_window(inv_box, inv_open, inv_on_pos, inv_off_pos)
		char_open = toggle_window(char_box, char_open, char_on_pos, char_off_pos)

func toggle_window(win: TextureRect, open_ref: bool, on_pos: Vector2, off_pos: Vector2) -> bool:
	var tw := create_tween()
	if open_ref:
		tw.tween_property(win, "position", off_pos, 0.2).set_ease(Tween.EASE_IN)
		tw.finished.connect(func(): win.hide())
	else:
		win.show()
		tw.tween_property(win, "position", on_pos, 0.2).set_ease(Tween.EASE_OUT)
	return not open_ref

func add_test_items():
	var inv := PlayerStats.inventory
	if not inv or inv.size() > 0: return
	for id in ItemCatalog.get_item_ids():
		var it := ItemCatalog.create(id)
		if it:
			inv.try_add(it)

func _on_equip(slot_type: int, item: Item):
	pass

func _on_unequip(slot_type: int, item: Item):
	if PlayerStats.inventory:
		PlayerStats.inventory.try_add(item)
