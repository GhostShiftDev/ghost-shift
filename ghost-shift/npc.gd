extends CharacterBody3D

const SPEED = 5.0
const JUMP_VELOCITY = 4.5
const MOUSE_SENSITIVITY = 0.003
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

var is_possessed = false
var is_ragdoll = false
var controlling_ghost = null
var ragdoll_velocity = Vector3.ZERO
var ragdoll_timer = 0.0

@onready var camera_pivot = $CameraPivot
@onready var camera = $CameraPivot/Camera3D
@onready var mesh = $MeshInstance3D

func _ready():
	camera.current = false

func possess(ghost):
	is_possessed = true
	is_ragdoll = false
	ragdoll_timer = 0.0
	controlling_ghost = ghost
	camera.current = true
	# Reset upright when re-possessed
	mesh.rotation.z = 0.0
	mesh.rotation.x = 0.0
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func unpossess():
	is_possessed = false
	camera.current = false
	controlling_ghost = null
	_start_ragdoll()

func _start_ragdoll():
	is_ragdoll = true
	ragdoll_timer = 0.0
	# Strong random launch velocity — this is what makes it fly sideways
	var rand_x = randf_range(-6.0, 6.0)
	var rand_z = randf_range(-6.0, 6.0)
	ragdoll_velocity = Vector3(rand_x, 3.0, rand_z)
	# Tilt the MESH only (not the whole body) so physics still works
	var tween = create_tween()
	tween.tween_property(mesh, "rotation:z", deg_to_rad(90), 0.3)

func _unhandled_input(event):
	if not is_possessed:
		return
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		camera_pivot.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
		camera_pivot.rotation.x = clamp(
			camera_pivot.rotation.x,
			deg_to_rad(-80),
			deg_to_rad(80)
		)
	if event is InputEventKey and event.pressed and event.keycode == KEY_E:
		if controlling_ghost:
			controlling_ghost.exit_npc(self)

func _physics_process(delta):
	if is_ragdoll:
		ragdoll_timer += delta
		# Apply gravity to ragdoll
		ragdoll_velocity.y -= gravity * delta
		# Friction only kicks in after it hits the floor, slowly
		if is_on_floor():
			ragdoll_velocity.y = 0.0
			# Slow horizontal slide gradually — feels like sliding body
			ragdoll_velocity.x = move_toward(ragdoll_velocity.x, 0.0, 2.5 * delta)
			ragdoll_velocity.z = move_toward(ragdoll_velocity.z, 0.0, 2.5 * delta)
			# Tip the mesh more once it hits ground
			if ragdoll_timer < 0.1:
				var tween = create_tween()
				tween.tween_property(mesh, "rotation:z", deg_to_rad(90), 0.2)
		velocity = ragdoll_velocity
		move_and_slide()
		return

	if not is_possessed:
		if not is_on_floor():
			velocity.y -= gravity * delta
		else:
			velocity.y = 0
		move_and_slide()
		return

	if not is_on_floor():
		velocity.y -= gravity * delta

	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	var input_dir = Input.get_vector(
		"move_left", "move_right", "move_forward", "move_back"
	)
	var direction = (
		transform.basis * Vector3(input_dir.x, 0, input_dir.y)
	).normalized()

	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()