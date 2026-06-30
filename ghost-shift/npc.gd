extends CharacterBody3D

const SPEED = 5.0
const JUMP_VELOCITY = 4.5
const MOUSE_SENSITIVITY = 0.003
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

var is_possessed = false
var controlling_ghost = null  # NEW — remembers which ghost possessed this body

@onready var camera_pivot = $CameraPivot
@onready var camera = $CameraPivot/Camera3D

func _ready():
	# NPCs start unpossessed — camera off, no player control
	camera.current = false

func possess(ghost):
	is_possessed = true
	controlling_ghost = ghost  # NEW — remember who's controlling us
	camera.current = true
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func unpossess():
	is_possessed = false
	camera.current = false
	controlling_ghost = null

func _unhandled_input(event):
	if not is_possessed:
		return
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		camera_pivot.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
		camera_pivot.rotation.x = clamp(camera_pivot.rotation.x, deg_to_rad(-80), deg_to_rad(80))

		# NEW — pressing E while possessed exits back to ghost
	if event is InputEventKey and event.pressed and event.keycode == KEY_E:
		if controlling_ghost:
			controlling_ghost.exit_npc(self)

func _physics_process(delta):
	if not is_possessed:
		return  # Idle NPCs do nothing for now — AI comes later

	if not is_on_floor():
		velocity.y -= gravity * delta

	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()
