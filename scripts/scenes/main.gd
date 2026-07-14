extends Node

const _melt_shader := preload("res://shaders/melt.gdshader")

# ---------------------------------------------------- Константы боя

const PLAYER_HIT_DC := 12
const PLAYER_DAMAGE := 6
const ENEMY_DAMAGE := 4
const ENEMY_TURN_DELAY := 0.8
const LIMB_NAMES := ["head", "torso", "arm_left", "arm_right", "leg_left", "leg_right"]
const LIMB_MAX_HP := {"head": 5, "torso": 10, "arm_left": 6, "arm_right": 6, "leg_left": 6, "leg_right": 6}
const LIMB_NAMES_RU := {"head": "голову", "torso": "торс", "arm_left": "левую руку", "arm_right": "правую руку", "leg_left": "левую ногу", "leg_right": "правую ногу"}

# Действия (особые атаки)
const ACTIONS := {
	"precise_strike": {"name": "Точный удар", "skill": "composure", "dc": 9, "dmg": 6, "desc": "Хладнокровие (DC 9)"},
	"power_strike":  {"name": "Силовой удар", "skill": "stamina", "dc": 12, "dmg": 10, "desc": "Стойкость (DC 12, урон 10)"},
	"quick_strike":  {"name": "Быстрый удар", "skill": "agility", "dc": 12, "dmg": 5, "desc": "Подвижность (DC 12, -1 к защите врага)"},
}
const ACTION_NAMES := ["precise_strike", "power_strike", "quick_strike"]

# Специальные action (monster path)
const MERCY_ACTIONS := {}

# Режимы выбора цели для атаки/действия/предмета
enum SelectionMode { NONE, ATTACK, ACTION, ITEM }
const FLEE_DC := 10

var enemy_stunned: bool = false
var _execute_btn: Button

# ---------------------------------------------------- Настраиваемые ссылки
@export_group("UI")
@export var enemy_status_label: Label
@export var player_status_label: Label
@export var log_label: Label
@export var main_menu: HBoxContainer
@export var attack_submenu: VBoxContainer
@export var action_submenu: VBoxContainer
@export var item_submenu: VBoxContainer
@export var ui_root: Control
@export var damage_vignette: ColorRect

@export_group("Enemy Visual")
@export var enemy_container: Control
@export var blood_particles: CPUParticles2D
@export var remains_sprite: TextureRect       # спрайт останков (труп)
@export var head_rect: TextureRect
@export var torso_rect: TextureRect
@export var arm_left_rect: TextureRect
@export var arm_right_rect: TextureRect
@export var leg_left_rect: TextureRect
@export var leg_right_rect: TextureRect

@export_group("Death FX")
@export var death_sound: AudioStreamPlayer2D     # звук смерти (опционально)
@export var death_blood_amount: int = 60       # сколько частиц в залпе
@export var death_shake: float = 14.0          # сила тряски при смерти
@export var death_pause: float = 0.25          # пауза перед появлением останков

@export_group("Feedback")
@export var impact_sound: AudioStreamPlayer2D   # звук попадания (устарел, плеер создаётся в коде)
@export var swing_sound: AudioStreamPlayer2D    # звук замаха/удара
@export var miss_sound: AudioStreamPlayer2D     # звук промаха
@export var player_hit_sound: AudioStreamPlayer2D  # звук получения урона игроком
@export var bgm_player: AudioStreamPlayer2D     # саундтрек
@export var hit_video_player: VideoStreamPlayer
@export var hit_video_player_2: VideoStreamPlayer
@export var heal_video_player: VideoStreamPlayer
@export var hit_video_duration: float = 0.4
@export var handheld_shake_intensity: float = 0.8
@export var handheld_shake_speed: float = 2.0

@export_group("Volume")
@export_range(-80, 24, 0.1) var music_volume_db: float = -6.0
@export_range(-80, 24, 0.1) var sfx_volume_db: float = 0.0

# ---------------------------------------------------- Состояние боя
enum State {
	PLAYER_INPUT,      # ждём выбор игрока
	PLAYER_ACTING,     # проигрывается атака игрока
	ENEMY_ACTING,      # ходит враг
	BATTLE_OVER        # бой окончен
}
var state: int = State.PLAYER_INPUT
var attack_mode_active: bool = false

var rat: Combatant
var player: Combatant
var enemy_parts: Dictionary = {}      # limb_name -> TextureRect
var attack_buttons: Dictionary = {}   # limb_name -> Button

# Текущий контекст выбора цели
var selection_mode: int = SelectionMode.NONE
var selection_context: Dictionary = {}

# "Ручная камера"
var original_ui_root_position: Vector2
var handheld_offset: Vector2 = Vector2.ZERO
var target_handheld_offset: Vector2 = Vector2.ZERO
var hit_shake_amount: float = 0.0
var _breath_parts: Dictionary = {}
var _impact_player: AudioStreamPlayer
var _ui_sound_player: AudioStreamPlayer

const BODY_SMALL_1 := preload("res://audio/gore/body_hit_small_1.wav")
const BODY_SMALL_2 := preload("res://audio/gore/body_hit_small_2.wav")
const BODY_SMALL_3 := preload("res://audio/gore/body_hit_small_3.wav")
const BODY_SMALL_4 := preload("res://audio/gore/body_hit_small_4.wav")
const BODY_FINISHER_1 := preload("res://audio/gore/body_hit_finisher_1.wav")
const BODY_FINISHER_2 := preload("res://audio/gore/body_hit_finisher_2.wav")
const BODY_FINISHER_3 := preload("res://audio/gore/body_hit_finisher_3.wav")
const BODY_FINISHER_4 := preload("res://audio/gore/body_hit_finisher_4.wav")
const FACE_SMALL_1 := preload("res://audio/gore/face_hit_small_1.wav")
const FACE_SMALL_2 := preload("res://audio/gore/face_hit_small_2.wav")
const FACE_SMALL_3 := preload("res://audio/gore/face_hit_small_3.wav")
const FACE_SMALL_4 := preload("res://audio/gore/face_hit_small_4.wav")
const FACE_FINISHER_1 := preload("res://audio/gore/face_hit_finisher_1.wav")
const FACE_FINISHER_2 := preload("res://audio/gore/face_hit_finisher_2.wav")
const FACE_FINISHER_3 := preload("res://audio/gore/face_hit_finisher_3.wav")

var _impact_banks: Dictionary = {
	"body_small": [BODY_SMALL_1, BODY_SMALL_2, BODY_SMALL_3, BODY_SMALL_4],
	"body_finisher": [BODY_FINISHER_1, BODY_FINISHER_2, BODY_FINISHER_3, BODY_FINISHER_4],
	"face_small": [FACE_SMALL_1, FACE_SMALL_2, FACE_SMALL_3, FACE_SMALL_4],
	"face_finisher": [FACE_FINISHER_1, FACE_FINISHER_2, FACE_FINISHER_3],
}

const MUSIC_1 := preload("res://audio/music/scav_fight_1.mp3")
const MUSIC_2 := preload("res://audio/music/scav_fight_2.mp3")
var _music_tracks: Array = [MUSIC_1, MUSIC_2]

const UI_SELECT := preload("res://audio/ui/select.ogg")
const UI_CLICK := preload("res://audio/ui/click.ogg")

# ==================================================== Звуки

func _setup_audio():
	_impact_player = AudioStreamPlayer.new()
	_impact_player.name = "ImpactPlayer"
	_impact_player.bus = &"Master"
	_impact_player.volume_db = sfx_volume_db
	add_child(_impact_player)

	if not swing_sound:
		swing_sound = AudioStreamPlayer2D.new()
		swing_sound.name = "SwingSound"
		add_child(swing_sound)
	if swing_sound:
		swing_sound.volume_db = sfx_volume_db

	if not miss_sound:
		miss_sound = AudioStreamPlayer2D.new()
		miss_sound.name = "MissSound"
		add_child(miss_sound)
	if miss_sound:
		miss_sound.volume_db = sfx_volume_db

	if not player_hit_sound:
		player_hit_sound = AudioStreamPlayer2D.new()
		player_hit_sound.name = "PlayerHitSound"
		add_child(player_hit_sound)
	if player_hit_sound:
		player_hit_sound.volume_db = sfx_volume_db

	if death_sound:
		death_sound.volume_db = sfx_volume_db

	_ui_sound_player = AudioStreamPlayer.new()
	_ui_sound_player.name = "UISoundPlayer"
	_ui_sound_player.bus = &"Master"
	_ui_sound_player.volume_db = sfx_volume_db
	add_child(_ui_sound_player)

	if not bgm_player:
		bgm_player = AudioStreamPlayer2D.new()
		bgm_player.name = "BGMPlayer"
		add_child(bgm_player)
	if bgm_player:
		bgm_player.stop()
		bgm_player.volume_db = music_volume_db
		bgm_player.stream = _music_tracks[randi() % _music_tracks.size()]
		if not bgm_player.finished.is_connected(_restart_bgm):
			bgm_player.finished.connect(_restart_bgm)
		bgm_player.play()

func _restart_bgm():
	if bgm_player:
		bgm_player.play()

func _play_swing():
	if swing_sound:
		swing_sound.play()

func _play_impact(limb_name: String, finisher: bool = false):
	if not _impact_player:
		return
	var is_head := limb_name == "head"
	var key := ("face" if is_head else "body") + ("_finisher" if finisher else "_small")
	var bank: Array = _impact_banks.get(key, [])
	if bank.is_empty():
		return
	_impact_player.stream = bank[randi() % bank.size()]
	_impact_player.play()

func _play_miss():
	if not _impact_player: return
	var i: int = randi() % 3 + 1
	_impact_player.stream = load("res://audio/gore/miss_%d.wav" % i)
	_impact_player.play()

func _play_player_hit():
	if player_hit_sound:
		player_hit_sound.play()

func _play_ui_select():
	if _ui_sound_player:
		_ui_sound_player.stream = UI_SELECT
		_ui_sound_player.play()

func _play_ui_click():
	if _ui_sound_player:
		_ui_sound_player.stream = UI_CLICK
		_ui_sound_player.play()

# ==================================================== Инициализация
func _ready():
	if enemy_container == null:
		push_error("enemy_container not assigned!")
		return

	enemy_parts = {
		"head": head_rect, "torso": torso_rect,
		"arm_left": arm_left_rect, "arm_right": arm_right_rect,
		"leg_left": leg_left_rect, "leg_right": leg_right_rect,
	}

	# Диагностика: ловим дубли ссылок на спрайты
	var seen: Dictionary = {}
	for limb_name in enemy_parts:
		var rect = enemy_parts[limb_name]
		if rect == null:
			push_warning("Спрайт для '%s' не назначен!" % limb_name)
			continue
		if seen.has(rect):
			push_error("ДУБЛЬ! '%s' и '%s' указывают на один узел %s" % [seen[rect], limb_name, rect.name])
		else:
			seen[rect] = limb_name

	for limb_name in enemy_parts:
		var rect: TextureRect = enemy_parts[limb_name]
		if rect:
			_breath_parts[limb_name] = rect.position

	player = PlayerStats.create_combatant()
	new_rat()

	player.inventory = [
		Item.new("Аптечка", "Восстанавливает 4 HP", 4),
		Item.new("Аптечка", "Восстанавливает 4 HP", 4),
		Item.new("Бинт", "Восстанавливает 2 HP", 2),
	]

	_setup_main_menu()
	_setup_attack_submenu()
	_setup_action_submenu()
	_setup_item_submenu()

	if damage_vignette:
		damage_vignette.modulate.a = 0.0
	for vp in [hit_video_player, hit_video_player_2, heal_video_player]:
		if vp:
			vp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ui_root:
		original_ui_root_position = ui_root.position

	_setup_audio()
	update_all_status()
	enable_player_ui()

func _setup_main_menu():
	if not main_menu:
		return
	_connect_button(main_menu.get_node("BtnAttack"), _on_attack_pressed)
	_connect_button(main_menu.get_node("BtnAction"), _on_action_pressed)
	_connect_button(main_menu.get_node("BtnItem"),   _on_item_pressed)
	_connect_button(main_menu.get_node("BtnFlee"),   _on_flee_pressed)

func _setup_attack_submenu():
	if not attack_submenu:
		return
	for limb_name in LIMB_NAMES:
		var node_name := "Btn" + _to_pascal_case(limb_name)  # head -> BtnHead, arm_left -> BtnArmLeft
		var btn: Button = attack_submenu.get_node(node_name)
		attack_buttons[limb_name] = btn
		_connect_button(btn, _on_limb_selected.bind(limb_name))

	_connect_button(attack_submenu.get_node("BtnBack"), _on_back_pressed)
	attack_submenu.hide()

func _to_pascal_case(snake: String) -> String:
	var result := ""
	for word in snake.split("_"):
		result += word.capitalize()
	return result

# Безопасное подключение сигнала (без дублирования)
func _connect_button(btn: Button, callback: Callable):
	if not btn:
		return
	if btn.pressed.is_connected(callback):
		btn.pressed.disconnect(callback)
	if btn.pressed.is_connected(_play_ui_click):
		btn.pressed.disconnect(_play_ui_click)
	btn.pressed.connect(callback)
	btn.pressed.connect(_play_ui_click)
	if not btn.mouse_entered.is_connected(_play_ui_select):
		btn.mouse_entered.connect(_play_ui_select)

# ==================================================== Хелперы
func _log(text: String, append: bool = false):
	if not log_label:
		return
	if append:
		log_label.text += text
	else:
		log_label.text = text

func _roll_d20(modifier: int = 0) -> int:
	return SkillCheck.roll(modifier)

# ==================================================== Враг
func new_rat():
	rat = Combatant.new("Крыса-падальщик", {"stamina": 3, "agility": 5})
	state = State.PLAYER_INPUT          # сброс состояния при рестарте
	_log("Появилась свежая крыса!")

	if remains_sprite:
		remains_sprite.visible = false  # прячем труп прошлой крысы
		remains_sprite.position = Vector2(-4, 294)
	if enemy_container:
		enemy_container.position = Vector2.ZERO
		enemy_container.remove_meta("original_pos")

	sync_enemy_sprites()
	update_attack_buttons()
	update_all_status()

# Приводит видимость спрайтов в точное соответствие состоянию крысы
func sync_enemy_sprites():
	if not rat: return
	for limb_name in enemy_parts:
		var rect: TextureRect = enemy_parts[limb_name]
		var limb: Limb = rat.limbs.get(limb_name)
		if rect and limb:
			rect.visible = not limb.is_destroyed()
			if limb.is_broken():
				rect.modulate = Color(1, 0.4, 0.4, 1)
			else:
				rect.modulate = Color(1, 1, 1, 1)

func update_attack_buttons():
	if not rat:
		return
	for limb_name in attack_buttons:
		var btn: Button = attack_buttons[limb_name]
		var limb = rat.limbs.get(limb_name)
		if btn and limb:
			btn.disabled = limb.is_destroyed()

# ==================================================== Главное меню
func _on_attack_pressed():
	if state != State.PLAYER_INPUT or attack_mode_active:
		return
	attack_mode_active = true
	selection_mode = SelectionMode.ATTACK
	selection_context = {}
	update_attack_buttons()
	main_menu.hide()
	attack_submenu.show()
	_log("Выберите часть тела для атаки...")

func _on_action_pressed():
	if state != State.PLAYER_INPUT or attack_mode_active:
		return
	attack_mode_active = true
	selection_mode = SelectionMode.NONE
	main_menu.hide()
	action_submenu.show()
	if _execute_btn and rat:
		_execute_btn.visible = rat.destroyed_limb_count() >= 2
	_log("Выберите тип атаки...")

func _on_item_pressed():
	if state != State.PLAYER_INPUT or attack_mode_active:
		return
	attack_mode_active = true
	main_menu.hide()
	_refresh_item_submenu()
	item_submenu.show()
	_log("Выберите предмет...")

func _on_flee_pressed():
	if state != State.PLAYER_INPUT or attack_mode_active:
		return
	state = State.PLAYER_ACTING
	disable_player_ui()
	_attempt_flee()

# ==================================================== Назад / Отмена
func _on_back_pressed():
	cancel_action()

func cancel_action():
	attack_mode_active = false
	selection_mode = SelectionMode.NONE
	selection_context = {}
	action_submenu.hide()
	item_submenu.hide()
	attack_submenu.hide()
	main_menu.show()
	_log("Отменено.")

# ==================================================== Выбор цели
func _on_limb_selected(limb_name: String):
	if state != State.PLAYER_INPUT or not attack_mode_active:
		return

	# Для атаки/действия — цель должна быть жива
	if selection_mode in [SelectionMode.ATTACK, SelectionMode.ACTION]:
		if not rat.is_alive():
			return
		if rat.limbs.has(limb_name) and rat.limbs[limb_name].is_destroyed():
			return

	# Для предмета — можно лечить и сломанные
	if selection_mode == SelectionMode.ITEM:
		if limb_name not in player.limbs:
			return

	# Блокируем ввод
	state = State.PLAYER_ACTING
	attack_mode_active = false
	attack_submenu.hide()
	action_submenu.hide()
	item_submenu.hide()
	main_menu.hide()

	match selection_mode:
		SelectionMode.ATTACK:
			_player_turn_coroutine(limb_name)
		SelectionMode.ACTION:
			_player_action_coroutine(limb_name)
		SelectionMode.ITEM:
			_use_item(limb_name)

func _player_turn_coroutine(limb_name: String):
	_play_swing()
	_play_random_hit_video()
	await get_tree().create_timer(hit_video_duration).timeout

	var dead := _player_attack(limb_name)
	update_all_status()
	update_attack_buttons()

	if dead or not rat.is_alive():
		await play_enemy_death()      # ЭФФЕКТ СМЕРТИ (ждём завершения)
		end_battle("win")
		return

	switch_to_enemy_turn()

func _play_random_hit_video():
	var videos: Array[VideoStreamPlayer] = []
	for vp in [hit_video_player, hit_video_player_2]:
		if vp and vp.stream:
			videos.append(vp)
	if videos.is_empty():
		return
	var chosen := videos[randi() % videos.size()]
	for v in videos:
		if v != chosen:
			v.stop()
	chosen.stream_position = 0.0
	chosen.play()

func _play_heal_video():
	if not heal_video_player or not heal_video_player.stream:
		return
	for vp in [hit_video_player, hit_video_player_2]:
		if vp:
			vp.stop()
	heal_video_player.stream_position = 0.0
	heal_video_player.play()

# ==================================================== Атака игрока
func _player_attack(part: String) -> bool:
	if not rat.is_alive():
		_log("Крыса уже мертва.")
		return true

	var roll := _roll_d20()
	var agility: int = player.get_skill("agility")
	var total := roll + agility

	if total < PLAYER_HIT_DC:
		_log("Промах по %s (d20=%d+%d=%d < %d)" % [part, roll, agility, total, PLAYER_HIT_DC])
		_play_miss()
		return false

	var limb: Limb = rat.limbs[part]
	var was_broken: bool = limb.is_broken()
	var dmg: int = limb.take_damage(PLAYER_DAMAGE)
	rat.take_total_damage(2)

	if was_broken and limb.is_destroyed():
		_log("Вы РАЗРУШИЛИ %s! (dmg=%d)" % [LIMB_NAMES_RU[part], dmg], true)
		PlayerStats.change_humanity(-1)
		enemy_stunned = true
		play_hit_feedback(part, true)
	elif limb.is_broken() and not was_broken:
		_log("Вы СЛОМАЛИ %s! (dmg=%d)" % [LIMB_NAMES_RU[part], dmg], true)
		enemy_stunned = true
		play_hit_feedback(part, false)
	else:
		_log("Попадание в %s (−%d). [%d HP]" % [LIMB_NAMES_RU[part], dmg, limb.hp])
		_play_impact(part, false)

	sync_enemy_sprites()
	update_all_status()

	if not rat.is_alive():
		_log("\nВРАГ ПОВЕРЖЕН!", true)
		return true

	return false

# ==================================================== Эффектная смерть врага
func play_enemy_death():

	# 4. Тряска "смертельного удара"
	hit_shake_amount = death_shake

	# 5. Звук смерти
	if death_sound and death_sound.stream:
		death_sound.play()
		
		# 1. Анимация таяния пикселей
	var melt_mats: Array[ShaderMaterial] = []
	for limb_name in enemy_parts:
		var rect: TextureRect = enemy_parts[limb_name]
		if rect and rect.texture:
			var sm := ShaderMaterial.new()
			sm.shader = _melt_shader
			sm.set("shader_parameter/meltiness", 6.0)
			rect.material = sm
			melt_mats.append(sm)

	if not melt_mats.is_empty():
		var melt_tween := create_tween()
		melt_tween.set_trans(Tween.TRANS_LINEAR)
		for sm in melt_mats:
			melt_tween.parallel().tween_method(_set_melt.bind(sm), 0.0, 0.6, 0.6)
		await melt_tween.finished

	# 2. Прячем все части тела и убираем шейдер
	for limb_name in enemy_parts:
		var rect: TextureRect = enemy_parts[limb_name]
		if rect:
			rect.material = null
			rect.visible = false

	# 7. Показываем останки на месте крысы
	if remains_sprite:
		remains_sprite.visible = true
		if enemy_container and enemy_container.has_meta("original_pos"):
			remains_sprite.position.y -= 120

func _set_melt(v: float, sm: ShaderMaterial):
	sm.set("shader_parameter/progress", v)

# Центр крысы для позиционирования частиц (с учётом scale)
func _get_enemy_center() -> Vector2:
	if torso_rect:
		var r := torso_rect.get_global_rect()
		return r.position + r.size * 0.5
	if enemy_container:
		return enemy_container.global_position
	return Vector2.ZERO

# ==================================================== Ход врага
func switch_to_enemy_turn():
	state = State.ENEMY_ACTING
	disable_player_ui()
	if enemy_stunned:
		enemy_stunned = false
		_log("Враг ошеломлён и пропускает ход!", true)
		state = State.PLAYER_INPUT
		enable_player_ui()
		return
	if rat.limbs["head"].is_broken() or rat.limbs["head"].is_destroyed():
		_log("Голова врага сломана — пропуск хода!", true)
		state = State.PLAYER_INPUT
		enable_player_ui()
		return
	await get_tree().create_timer(ENEMY_TURN_DELAY).timeout
	if state != State.ENEMY_ACTING: return
	if not rat.is_alive():
		await play_enemy_death()
		end_battle("win")
		return
	enemy_attack()

func enemy_attack():
	if state != State.ENEMY_ACTING: return
	if not rat.is_alive(): return
	var target_limb: String = rat.get_random_alive_limb()
	if target_limb == "": return
	_log("\nКрыса атакует вашу %s!" % LIMB_NAMES_RU[target_limb], true)
	var roll := _roll_d20()
	var enemy_skill: int = rat.get_skill("agility")
	var total := roll + enemy_skill
	var dc: int = 8 + player.get_skill("agility")
	if total >= dc:
		var limb: Limb = player.limbs[target_limb]
		var was_b: bool = limb.is_broken()
		limb.take_damage(ENEMY_DAMAGE)
		player.take_total_damage(2)
		if was_b and limb.is_destroyed():
			_log("Попадание! %s РАЗРУШЕНА! (%d+%d=%d)" % [LIMB_NAMES_RU[target_limb], roll, enemy_skill, total], true)
		elif limb.is_broken() and not was_b:
			_log("Попадание! %s СЛОМАНА! (%d+%d=%d)" % [LIMB_NAMES_RU[target_limb], roll, enemy_skill, total], true)
		else:
			_log("Попадание! (%d+%d=%d >= %d)" % [roll, enemy_skill, total, dc], true)
		play_player_hit_feedback()
	else:
		_log("Промах! (%d+%d=%d < %d)" % [roll, enemy_skill, total, dc], true)
	update_all_status()
	if not player.is_alive():
		end_battle("lose")
	else:
		switch_to_player_turn()

func switch_to_player_turn():
	state = State.PLAYER_INPUT
	enable_player_ui()

# ==================================================== Управление интерфейсом
func disable_player_ui():
	if main_menu: main_menu.hide()
	if attack_submenu: attack_submenu.hide()
	if action_submenu: action_submenu.hide()
	if item_submenu: item_submenu.hide()

func enable_player_ui():
	if main_menu: main_menu.show()
	selection_mode = SelectionMode.NONE
	selection_context = {}

func end_battle(result: String):
	if state == State.BATTLE_OVER:
		return
	state = State.BATTLE_OVER
	disable_player_ui()
	if result == "win":
		_log("\n\n--- ПОБЕДА! ---", true)
	elif result == "fled":
		_log("\n\n--- ВЫ СБЕЖАЛИ! ---", true)
	else:
		_log("\n\n--- ПОРАЖЕНИЕ... ---", true)
	await get_tree().create_timer(2.5).timeout
	TransitionManager.change_scene("res://scenes/dungeon/test_dungeon_mechanics.tscn")

# ==================================================== Подменю действий
func _setup_action_submenu():
	if not action_submenu:
		action_submenu = VBoxContainer.new()
		action_submenu.name = "ActionSubMenu"
		action_submenu.z_index = 5
		action_submenu.position = Vector2(106, 155)
		ui_root.add_child(action_submenu)

	for action_name in ACTION_NAMES:
		var info = ACTIONS[action_name]
		var btn := RippleButton.new()
		btn.text = info["name"] + "\n" + info["desc"]
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		_connect_button(btn, _on_action_selected.bind(action_name))
		action_submenu.add_child(btn)

	var back_btn := RippleButton.new()
	back_btn.text = "Назад"
	back_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_connect_button(back_btn, _on_back_pressed)
	action_submenu.add_child(back_btn)

	_execute_btn = RippleButton.new()
	_execute_btn.text = "Добить (−1 Человечность)"
	_execute_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_connect_button(_execute_btn, _on_execute_pressed)
	action_submenu.add_child(_execute_btn)
	_execute_btn.hide()
	action_submenu.hide()

func _setup_item_submenu():
	if not item_submenu:
		item_submenu = VBoxContainer.new()
		item_submenu.name = "ItemSubMenu"
		item_submenu.z_index = 5
		item_submenu.position = Vector2(106, 155)
		ui_root.add_child(item_submenu)

	var back_btn := RippleButton.new()
	back_btn.text = "Назад"
	back_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_connect_button(back_btn, _on_back_pressed)
	item_submenu.add_child(back_btn)
	item_submenu.hide()

func _refresh_item_submenu():
	for child in item_submenu.get_children():
		if child is Button and child.text != "Назад":
			child.queue_free()

	for i in range(player.inventory.size()):
		var it: Item = player.inventory[i]
		var btn := RippleButton.new()
		btn.text = "%s — %s (x%d)" % [it.name, it.description, _count_items(it.name)]
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		_connect_button(btn, _on_item_selected.bind(i))
		item_submenu.add_child(btn)
	# Move back button to end
	var back = null
	for child in item_submenu.get_children():
		if child is Button and child.text == "Назад":
			back = child
			break
	if back:
		item_submenu.move_child(back, -1)

func _count_items(item_name: String) -> int:
	var count := 0
	for it in player.inventory:
		if it.name == item_name:
			count += 1
	return count

# ==================================================== Выбор действия
func _on_action_selected(action_name: String):
	if state != State.PLAYER_INPUT or not attack_mode_active:
		return
	selection_mode = SelectionMode.ACTION
	selection_context = {"action": action_name}
	action_submenu.hide()
	update_attack_buttons()
	attack_submenu.show()
	_log("Выберите конечность для %s..." % ACTIONS[action_name]["name"])

func _on_item_selected(item_index: int):
	if state != State.PLAYER_INPUT or not attack_mode_active:
		return
	selection_mode = SelectionMode.ITEM
	selection_context = {"item_index": item_index}
	item_submenu.hide()
	for btn in attack_buttons.values():
		btn.disabled = false
	attack_submenu.show()
	_log("Выберите конечность для лечения...")

# ==================================================== Исполнение: Действие
func _player_action_coroutine(limb_name: String):
	var action_name: String = selection_context.get("action", "")
	if action_name == "":
		switch_to_enemy_turn()
		return

	_play_swing()
	_play_random_hit_video()
	await get_tree().create_timer(hit_video_duration).timeout

	var action = ACTIONS[action_name]
	var skill: String = action["skill"]
	var dc: int = action["dc"]
	var dmg: int = action["dmg"]

	var roll := _roll_d20()
	var skill_val := player.get_skill(skill)
	var total := roll + skill_val

	if total >= dc:
		rat.limbs[limb_name].take_damage(dmg)
		rat.take_total_damage(3)
		_log("%s: d20=%d+%d=%d >= %d — попадание! (%d урона по %s)" % [action["name"], roll, skill_val, total, dc, dmg, LIMB_NAMES_RU[limb_name]])
		var was_finisher: bool = rat.limbs[limb_name].is_broken()
		if was_finisher:
			_log("\n%s уничтожена!" % limb_name.capitalize(), true)
		play_hit_feedback(limb_name, was_finisher)
	else:
		_log("%s: d20=%d+%d=%d < %d — промах!" % [action["name"], roll, skill_val, total, dc])
		_play_miss()

	update_all_status()
	update_attack_buttons()

	if not rat.is_alive():
		await play_enemy_death()
		end_battle("win")
		return

	switch_to_enemy_turn()

# ==================================================== Исполнение: Предмет
func _use_item(limb_name: String):
	var item_index: int = selection_context.get("item_index", -1)
	if item_index < 0 or item_index >= player.inventory.size():
		switch_to_enemy_turn()
		return

	var item: Item = player.inventory[item_index]
	var limb = player.limbs[limb_name]

	_play_heal_video()

	if limb.is_broken() or limb.is_destroyed():
		limb.broken = false
		limb.destroyed = false
		limb.hp = 1
	limb.hp = min(limb.hp + item.heal_amount, limb.max_hp)

	_log("Вы использовали %s на %s (+%d HP)" % [item.name, LIMB_NAMES_RU[limb_name], item.heal_amount])
	player.inventory.remove_at(item_index)
	update_all_status()

	switch_to_enemy_turn()

# ==================================================== Исполнение: Побег
func _attempt_flee():
	var roll := _roll_d20()
	var player_agi := player.get_skill("agility")
	var enemy_agi := rat.get_skill("agility")
	var total := roll + player_agi
	var dc := FLEE_DC + enemy_agi

	if total >= dc:
		_log("Вы убежали! (d20=%d+%d=%d >= %d)" % [roll, player_agi, total, dc])
		end_battle("fled")
	else:
		_log("Не удалось убежать! (d20=%d+%d=%d < %d)" % [roll, player_agi, total, dc])
		switch_to_enemy_turn()

# ==================================================== Статусы
func _on_execute_pressed():
	action_submenu.hide()
	var snd := load("res://audio/gore/execute_%d.wav" % (randi() % 2 + 1))
	_impact_player.stream = snd
	_impact_player.play()
	PlayerStats.change_humanity(-1)
	_log("Безжалостное добивание... (−1 Человечность, сейчас: %d)" % PlayerStats.humanity, true)
	await get_tree().create_timer(0.8).timeout
	await play_enemy_death()
	end_battle("win")

func update_all_status():
	if enemy_status_label:
		enemy_status_label.text = _build_status_text(rat, "Жива")
	if player_status_label:
		player_status_label.text = _build_status_text(player, "Жив") + "\nЧеловечность: %d" % PlayerStats.humanity

func _build_status_text(c: Combatant, alive_word: String) -> String:
	var text := "== %s ==\n" % c.char_name
	text += "HP: %d/%d\n" % [c.total_hp, c.max_total_hp]
	for key in c.limbs:
		var limb: Limb = c.limbs[key]
		if limb.is_destroyed():
			text += "%s: УНИЧТОЖЕНА\n" % key
		elif limb.is_broken():
			text += "%s: СЛОМАНА\n" % key
		else:
			text += "%s: %d hp\n" % [key, limb.hp]
	text += "%s: %s" % [alive_word, str(c.is_alive())]
	return text

# ==================================================== Визуальная отдача
func play_hit_feedback(limb_name: String, finisher: bool = false):
	if enemy_container:
		var pos := enemy_container.position
		var tw := create_tween()
		tw.tween_property(enemy_container, "position", pos + Vector2(6, 0), 0.04)
		tw.tween_property(enemy_container, "position", pos - Vector2(6, 0), 0.04)
		tw.tween_property(enemy_container, "position", pos + Vector2(0, -4), 0.04)
		tw.tween_property(enemy_container, "position", pos, 0.04)

	var rect: TextureRect = enemy_parts.get(limb_name)
	if rect and blood_particles:
		var r := rect.get_global_rect()
		blood_particles.global_position = r.position + r.size * 0.5
		blood_particles.restart()

	_play_impact(limb_name, finisher)

	if finisher and limb_name in ["leg_left", "leg_right"] and enemy_container:
		var l: Limb = rat.limbs.get("leg_left")
		var r: Limb = rat.limbs.get("leg_right")
		if l and r and l.is_destroyed() and r.is_destroyed():
			if not enemy_container.has_meta("original_pos"):
				enemy_container.set_meta("original_pos", enemy_container.position)
			var tw := create_tween()
			tw.tween_property(enemy_container, "position", enemy_container.position + Vector2(0, 120), 0.5).set_ease(Tween.EASE_OUT)

func play_player_hit_feedback():
	if enemy_container:
		var orig := enemy_container.scale
		var sw := create_tween()
		sw.tween_property(enemy_container, "scale", orig * 1.2, 0.08)
		sw.tween_property(enemy_container, "scale", orig, 0.12)

	hit_shake_amount = 8.0
	_play_player_hit()
	_play_impact("torso", false)
	if damage_vignette:
		damage_vignette.modulate.a = 0.6
		var tween := create_tween()
		tween.tween_property(damage_vignette, "modulate:a", 0.0, 0.4)

# ==================================================== Ручная камера
func _process(delta: float):
	if rat and rat.is_alive():
		var breath := sin(Time.get_ticks_msec() * 0.002) * 2.0
		for limb_name in _breath_parts:
			if limb_name.begins_with("leg"):
				continue
			var rect: TextureRect = enemy_parts.get(limb_name)
			if rect and rect.visible:
				rect.position = _breath_parts[limb_name] + Vector2(0, breath)

	if not ui_root:
		return

	if handheld_shake_intensity > 0.0:
		if randf() < 0.02:
			target_handheld_offset = Vector2(
				randf_range(-handheld_shake_intensity, handheld_shake_intensity),
				randf_range(-handheld_shake_intensity, handheld_shake_intensity)
			)
		handheld_offset = handheld_offset.lerp(target_handheld_offset, delta * handheld_shake_speed)

	var extra_offset := Vector2.ZERO
	if hit_shake_amount > 0.0:
		hit_shake_amount = max(0.0, hit_shake_amount - delta * 15.0)
		extra_offset = Vector2(
			randf_range(-hit_shake_amount, hit_shake_amount),
			randf_range(-hit_shake_amount, hit_shake_amount)
		)

	ui_root.position = original_ui_root_position + handheld_offset + extra_offset
