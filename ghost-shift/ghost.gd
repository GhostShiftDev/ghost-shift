extends CharacterBody3D

const FLY_SPEED = 6.0
const MOUSE_SENSITIVITY = 0.003

@onready var camera_pivot = $CameraPivot
@onready var camera = $CameraPivot/Camera3D
var nearby_npc = null

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _unhandled_input(event):
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		camera_pivot.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
		camera_pivot.rotation.x = clamp(camera_pivot.rotation.x, deg_to_rad(-80), deg_to_rad(80))

	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		if event.keycode == KEY_E and nearby_npc:
			possess_npc(nearby_npc)

func possess_npc(npc):
	npc.possess(self)
	camera.current = false
	visible = false
	set_physics_process(false)
	set_process_unhandled_input(false)

func exit_npc(npc):
	npc.unpossess()
	global_position = npc.global_position
	camera.current = true
	visible = true
	set_physics_process(true)
	set_process_unhandled_input(true)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func set_nearby_npc(npc):
	nearby_npc = npc

func _on_detection_zone_body_entered(body):
	if body.has_method("possess"):
		nearby_npc = body

func _on_detection_zone_body_exited(body):
	if body == nearby_npc:
		nearby_npc = null

func _physics_process(delta):
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	var vertical = 0.0
	if Input.is_action_pressed("ui_accept"):
		vertical = 1.0
	if Input.is_action_pressed("move_down"):
		vertical = -1.0

	velocity = direction * FLY_SPEED
	velocity.y = vertical * FLY_SPEED

	move_and_slide()
