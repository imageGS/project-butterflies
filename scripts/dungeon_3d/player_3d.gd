extends CharacterBody3D

# =============================================================================
# DOOM-style player controller — WASD + mouse, blocky collision.
# =============================================================================

@export var move_speed: float = 3.0
@export var mouse_sensitivity: float = 0.002
@export var friction: float = 0.85

@onready var _camera: Camera3D = $Camera3D
@onready var _capsule: CollisionShape3D = $CollisionShape3D

func _ready():
	if _camera:
		_camera.position = Vector3(0, 0.8, 0)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _input(event: InputEvent):
	if event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed:
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		if _camera:
			_camera.rotate_x(-event.relative.y * mouse_sensitivity)
			_camera.rotation.x = clamp(_camera.rotation.x, -PI * 0.4, PI * 0.15)

func _physics_process(_delta: float):
	var input_dir := Vector3.ZERO
	
	if Input.is_key_pressed(KEY_W): input_dir.z -= 1.0
	if Input.is_key_pressed(KEY_S): input_dir.z += 1.0
	if Input.is_key_pressed(KEY_A): input_dir.x -= 1.0
	if Input.is_key_pressed(KEY_D): input_dir.x += 1.0
	
	if input_dir.length() > 0.0:
		input_dir = input_dir.normalized()
		var move_dir := global_transform.basis * input_dir
		move_dir.y = 0.0
		move_dir = move_dir.normalized()
		velocity.x = lerp(velocity.x, move_dir.x * move_speed, 1.0 - friction)
		velocity.z = lerp(velocity.z, move_dir.z * move_speed, 1.0 - friction)
	else:
		velocity.x *= friction
		velocity.z *= friction
		if abs(velocity.x) < 0.01: velocity.x = 0.0
		if abs(velocity.z) < 0.01: velocity.z = 0.0
	
	if not is_on_floor():
		velocity.y -= 9.8 * _delta
	else:
		velocity.y = 0.0
	
	move_and_slide()
