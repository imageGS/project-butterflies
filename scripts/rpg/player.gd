extends CharacterBody2D

enum State { IDLE, WALKING, RUNNING, INTERACTING }

@export var walk_speed: float = 120.0
@export var run_speed: float = 300.0
@export var interaction_distance: float = 40.0

var state: int = State.IDLE
var target_position: Vector2
var current_speed: float = 0.0
var target_interactable: Node = null
var _last_click_time: float = 0.0

func _ready():
	_ensure_collision_shape()
	queue_redraw()

func _ensure_collision_shape():
	for child in get_children():
		if child is CollisionShape2D:
			return
	var shape := CollisionShape2D.new()
	shape.shape = CircleShape2D.new()
	shape.shape.radius = 12.0
	add_child(shape)

func _draw():
	var color := Color.WHITE if state == State.IDLE else Color.ORANGE
	draw_rect(Rect2(-16, -32, 32, 48), color)

func _unhandled_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var now := Time.get_ticks_msec() / 1000.0
		var is_double := (now - _last_click_time) < 0.3
		_last_click_time = now

		var global_pos := get_global_mouse_position()
		var space := get_world_2d().direct_space_state
		var query := PhysicsPointQueryParameters2D.new()
		query.position = global_pos
		query.collide_with_areas = true
		query.collision_mask = 2
		var results := space.intersect_point(query)

		target_interactable = null
		for r in results:
			if r.collider.has_method(&"interact"):
				target_interactable = r.collider
				break

		if target_interactable:
			target_position = target_interactable.global_position
			current_speed = walk_speed
			state = State.INTERACTING
		else:
			target_position = global_pos
			current_speed = run_speed if is_double else walk_speed
			state = State.RUNNING if is_double else State.WALKING

func _physics_process(delta):
	match state:
		State.IDLE:
			pass
		State.WALKING, State.RUNNING:
			_move_toward(target_position, delta)
		State.INTERACTING:
			if not is_instance_valid(target_interactable):
				state = State.IDLE
				target_interactable = null
				return
			var dist := global_position.distance_to(target_interactable.global_position)
			if dist <= interaction_distance:
				target_interactable.interact()
				state = State.IDLE
				target_interactable = null
			else:
				target_position = target_interactable.global_position
				_move_toward(target_position, delta)
	queue_redraw()

func _move_toward(pos: Vector2, delta: float):
	var dir := pos - global_position
	var dist := dir.length()
	if dist < 5.0:
		velocity = Vector2.ZERO
		state = State.IDLE
		return
	velocity = dir.normalized() * current_speed
	move_and_slide()
