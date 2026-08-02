extends Node
class_name TransitionSystem

var dialogue_system: DialogueSystem

func setup(ds: DialogueSystem):
	dialogue_system = ds

func transition_to_station(exit: ExitData):
	var target: StationData = exit.resolve_target_station()
	if not target:
		ask_leave_station()
		return
	PlayerStats.current_station = target
	var spawn: Vector2i = exit.resolve_spawn(target.spawn)
	var dir: int = exit.resolve_dir(target.spawn_dir)
	PlayerStats.flags["_transition_spawn"] = spawn
	PlayerStats.flags["_transition_dir"] = dir

	var card := StationCard.new(target.station_name, target.time_of_day)
	add_child(card)
	await card.done

	TransitionManager.change_scene("res://scenes/dungeon/dungeon_gameplay.tscn")

func ask_leave_station():
	PlayerStats.current_station = load("res://resources/stations/shelter.tres")
	var exit_dialogue := [
		{ "text": "Выход из станции. Уйти?", "responses": [
			{ "text": "Да, уйти в убежище.", "next": 1 },
			{ "text": "Нет, остаться.", "next": -1 },
		]},
		{ "text": "Вы покидаете станцию и направляетесь в убежище.", "responses": [
			{ "text": "...", "next": -2 },
		]},
	]
	dialogue_system.start(exit_dialogue, "Выход")
