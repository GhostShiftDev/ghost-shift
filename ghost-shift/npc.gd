extends CharacterBody3D

const SPEED = 5.0
const JUMP_VELOCITY = 4.5
const MOUSE_SENSITIVITY = 0.003
const PATROL_SPEED = 1.8
const PATROL_WAIT_TIME = 2.0
const PATROL_RANGE = 6.0

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

var is_possessed = false
var is_ragdoll = false
var controlling_ghost = null
var ragdoll_velocity = Vector3.ZERO
var ragdoll_timer = 0.0

# Role — set by GameManager at start
var role: String = "guard"

# Patrol state
var patrol_target: Vector3 = Vector3.ZERO
var patrol_wait_timer: float = 0.0
var is_waiting: bool = false
var patrol_origin: Vector3 = Vector3.ZERO

# Nearby door for interaction
var nearby_door = null

@onready var camera_pivot = $CameraPivot
@onready var camera = $CameraPivot/Camera3D
@onready var mesh = $MeshInstance3D
@onready var role_label = $RoleLabel

func _ready():
	camera.current = false
	role_label.visible = false
	# Remember where we started for patrol range
	patrol_origin = global_position
	# Pick first patrol target immediately
	_pick_new_patrol_target()

func set_role(new_role: String):
	role = new_role
	role_label.text = role.to_upper()
	# Color-code the NPC mesh by role so they look different
	var mat = StandardMaterial3D.new()
	match role:
		"guard":
			mat.albedo_color = Color(0.2, 0.4, 1.0)    # Blue
		"janitor":
			mat.albedo_color = Color(1.0, 0.8, 0.1)    # Yellow
		"executive":
			mat.albedo_color = Color(0.5, 0.1, 0.8)    # Purple
	mesh.set_surface_override_material(0, mat)

func _pick_new_patrol_target():
	# Random point within PATROL_RANGE of starting position
	var rand_x = randf_range(-PATROL_RANGE, PATROL_RANGE)
	var rand_z = randf_range(-PATROL_RANGE, PATROL_RANGE)
	patrol_target = patrol_origin + Vector3(rand_x, 0, rand_z)
	is_waiting = false

func possess(ghost):
	is_possessed = true
	is_ragdoll = false
	ragdoll_timer = 0.0
	controlling_ghost = ghost
	camera.current = true
	mesh.rotation.z = 0.0
	mesh.rotation.x = 0.0
	role_label.visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func unpossess():
	is_possessed = false
	camera.current = false
	controlling_ghost = null
	role_label.visible = false
	_start_ragdoll()

func _start_ragdoll():
	is_ragdoll = true
	ragdoll_timer = 0.0
	var rand_x = randf_range(-6.0, 6.0)
	var rand_z = randf_range(-6.0, 6.0)
	ragdoll_velocity = Vector3(rand_x, 3.0, rand_z)
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
			deg_to_rad(-80), deg_to_rad(80)
		)
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_E:
			if controlling_ghost:
				controlling_ghost.exit_npc(self)
		if event.keycode == KEY_F:
			if nearby_door:
				nearby_door.try_open(role)

func _physics_process(delta):
	if is_ragdoll:
		ragdoll_timer += delta
		ragdoll_velocity.y -= gravity * delta
		if is_on_floor():
			ragdoll_velocity.y = 0.0
			ragdoll_velocity.x = move_toward(ragdoll_velocity.x, 0.0, 2.5 * delta)
			ragdoll_velocity.z = move_toward(ragdoll_velocity.z, 0.0, 2.5 * delta)
			if ragdoll_timer < 0.1:
				var tween = create_tween()
				tween.tween_property(mesh, "rotation:z", deg_to_rad(90), 0.2)
		velocity = ragdoll_velocity
		move_and_slide()
		return

	if is_possessed:
		_possessed_movement(delta)
		return

	# --- PATROL (not possessed, not ragdolling) ---
	_patrol_movement(delta)

func _patrol_movement(delta):
	# Apply gravity
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0

	if is_waiting:
		patrol_wait_timer -= delta
		velocity.x = move_toward(velocity.x, 0.0, PATROL_SPEED)
		velocity.z = move_toward(velocity.z, 0.0, PATROL_SPEED)
		if patrol_wait_timer <= 0.0:
			_pick_new_patrol_target()
	else:
		var target_flat = Vector3(patrol_target.x, global_position.y, patrol_target.z)
		var dir = (target_flat - global_position)
		var dist = dir.length()

		if dist < 0.5:
			# Reached target — wait before picking next
			is_waiting = true
			patrol_wait_timer = PATROL_WAIT_TIME
		else:
			dir = dir.normalized()
			velocity.x = dir.x * PATROL_SPEED
			velocity.z = dir.z * PATROL_SPEED
			# Face direction of movement smoothly
			var look_target = global_position + Vector3(dir.x, 0, dir.z)
			look_at(look_target, Vector3.UP)

	move_and_slide()

func _possessed_movement(delta):
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

func set_nearby_door(door):
	nearby_door = door