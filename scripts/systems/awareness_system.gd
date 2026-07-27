extends Node
class_name AwarenessSystem

var timer: float = 0.0
var interval: float = 8.0
var pool: Array[String] = [
	"Вы замечаете странные царапины на стенах.",
	"Откуда-то доносится запах сырости и металла.",
	"Краем глаза вы замечаете движение в темноте.",
	"Пол под ногами слегка вибрирует.",
	"Где-то капает вода. Звук эхом разносится по тоннелю.",
	"Тишина слишком плотная. Словно метро затаило дыхание.",
	"На стене следы когтей. Свежие.",
	"Воздух становится тяжелее. Вы чувствуете давление в висках.",
	"Лампы мигают. На мгновение тьма становится абсолютной.",
	"По полу пробегает крыса. Обычная, не падальщик.",
]

var dialogue_system: DialogueSystem
var log_system: LogBox


func setup(ds: DialogueSystem, ls: LogBox):
	dialogue_system = ds
	log_system = ls


func process(delta: float):
	timer -= delta
	if timer <= 0.0:
		timer = interval + randf_range(-2.0, 2.0)
		if dialogue_system.active: return
		var result := SkillCheck.check(PlayerStats.get_skill("intuition"), 12)
		if result.success and not pool.is_empty():
			var msg: String = pool[randi() % pool.size()]
			log_system.add_message(msg, Color(0.5, 1.0, 0.5))
