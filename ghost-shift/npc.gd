extends CharacterBody3D

const SPEED = 5.0
const JUMP_VELOCITY = 4.5
const MOUSE_SENSITIVITY = 0.003
const PATROL_SPEED = 1.8
const PATROL_WAIT_TIME = 2.0
const PATROL_RANGE = 4.0
const RAGDOLL_RESET_TIME = 3.0

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

var is_possessed = false
var is_ragdoll = false
var controlling_ghost = null
var ragdoll_velocity = Vector3.ZERO
var ragdoll_timer = 0.0

@export var role: String = "guard"

var patrol_target: Vector3 = Vector3.ZERO
var patrol_wait_timer: float = 0.0
var is_waiting: bool = false
var patrol_origin: Vector3 = Vector3.ZERO
var nearby_door = null
var character_mesh: MeshInstance3D = null

@onready var camera_pivot = $CameraPivot
@onready var camera = $CameraPivot/Camera3D
@onready var role_label = $RoleLabel

func _ready():
	camera.current = false
	# Bug 4 fix: force camera behind the character in code
	# regardless of what's set in the scene file
	camera.position = Vector3(0, 0.5, -4)
	camera_pivot.position = Vector3(0, 1.6, 0)

	# Bug 1 fix: guarantee NPC collides with layer 1 (walls + doors)
	set_collision_layer_value(1, true)
	set_collision_mask_value(1, true)

	# Bug 3 fix: never show world-space label — role shown in HUD instead
	role_label.visible = false

	add_to_group("npc")
	patrol_origin = global_position
	_pick_new_patrol_target()
	await get_tree().process_frame
	character_mesh = _find_mesh(self)
	_apply_role_visuals()

func _find_mesh(node: Node) -> MeshInstance3D:
	for child in node.get_children():
		if child is MeshInstance3D:
			return child
		var found = _find_mesh(child)
		if found:
			return found
	return null

func set_role(new_role: String):
	role = new_role
	await get_tree().process_frame
	character_mesh = _find_mesh(self)
	_apply_role_visuals()

func _apply_role_visuals():
	role_label.text = role.to_upper()
	var role_color: Color
	match role:
		"guard":
			role_color = Color(0.3, 0.5, 1.0)
		"janitor":
			role_color = Color(1.0, 0.85, 0.1)
		"executive":
			role_color = Color(0.7, 0.2, 1.0)
		_:
			role_color = Color(1.0, 1.0, 1.0)
	role_label.modulate = role_color
	if character_mesh:
		var mat = character_mesh.get_active_material(0)
		if mat == null:
			mat = StandardMaterial3D.new()
		else:
			mat = mat.duplicate()
		if mat is StandardMaterial3D:
			mat.albedo_color = Color(
				role_color.r * 0.6 + 0.4,
				role_color.g * 0.6 + 0.4,
				role_color.b * 0.6 + 0.4,
				1.0
			)
		character_mesh.set_surface_override_material(0, mat)

func _pick_new_patrol_target():
	# Tighter clamp — keeps NPCs well inside room boundaries away from doors
	var rand_x = randf_range(-PATROL_RANGE, PATROL_RANGE)
	var rand_z = randf_range(-PATROL_RANGE, PATROL_RANGE)
	patrol_target = Vector3(
		clamp(patrol_origin.x + rand_x, -6.0, 6.0),
		patrol_origin.y,
		clamp(patrol_origin.z + rand_z, -6.0, 6.0)
	)
	is_waiting = false

func possess(ghost):
	is_possessed = true
	is_ragdoll = false
	ragdoll_timer = 0.0
	controlling_ghost = ghost
	camera.current = true
	if character_mesh:
		character_mesh.rotation.z = 0.0
		character_mesh.rotation.x = 0.0
	# Bug 3 fix: tell HUD which role we are instead of showing world label
	var hud = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_role"):
		hud.show_role(role)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func unpossess():
	is_possessed = false
	camera.current = false
	controlling_ghost = null
	# Tell HUD to hide role label
	var hud = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("hide_role"):
		hud.hide_role()
	_start_ragdoll()

func _start_ragdoll():
	is_ragdoll = true
	ragdoll_timer = 0.0
	var rand_x = randf_range(-6.0, 6.0)
	var rand_z = randf_range(-6.0, 6.0)
	ragdoll_velocity = Vector3(rand_x, 3.0, rand_z)
	if character_mesh:
		var tween = create_tween()
		tween.tween_property(character_mesh, "rotation:z", deg_to_rad(90), 0.3)

func _stand_back_up():
	is_ragdoll = false
	ragdoll_velocity = Vector3.ZERO
	if character_mesh:
		var tween = create_tween()
		tween.tween_property(character_mesh, "rotation:z", 0.0, 0.3)
		tween.tween_property(character_mesh, "rotation:x", 0.0, 0.3)
	_pick_new_patrol_target()

# Bug 2 fix: use _input() not _unhandled_input() so F key always fires
# when possessed, regardless of other nodes consuming events
func _input(event):
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
			else:
				# Debug — remove after confirming F works
				print("F pressed but no nearby_door — are you standing at a door?")

func _physics_process(delta):
	if is_ragdoll:
		ragdoll_timer += delta
		ragdoll_velocity.y -= gravity * delta
		if is_on_floor():
			ragdoll_velocity.y = 0.0
			ragdoll_velocity.x = move_toward(ragdoll_velocity.x, 0.0, 2.5 * delta)
			ragdoll_velocity.z = move_toward(ragdoll_velocity.z, 0.0, 2.5 * delta)
		velocity = ragdoll_velocity
		move_and_slide()
		if ragdoll_timer >= RAGDOLL_RESET_TIME:
			_stand_back_up()
		return
	if is_possessed:
		_possessed_movement(delta)
		return
	_patrol_movement(delta)

func _patrol_movement(delta):
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
		var target_flat = Vector3(
			patrol_target.x, global_position.y, patrol_target.z
		)
		var dir = (target_flat - global_position)
		var dist = dir.length()
		if dist < 0.5:
			is_waiting = true
			patrol_wait_timer = PATROL_WAIT_TIME
		else:
			dir = dir.normalized()
			velocity.x = dir.x * PATROL_SPEED
			velocity.z = dir.z * PATROL_SPEED
			var look_target = global_position + Vector3(dir.x, 0.0, dir.z)
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