extends CharacterBody3D

const SPEED = 5.0
const JUMP_VELOCITY = 4.5
const MOUSE_SENSITIVITY = 0.003
const PATROL_SPEED = 1.8
const PATROL_WAIT_TIME = 2.0
const PATROL_RANGE = 4.0
const RAGDOLL_RESET_TIME = 5.0
const DOOR_DISTANCE = 5.0
const CAMERA_SMOOTH_SPEED = 10.0

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var is_possessed = false
var is_ragdoll = false
var controlling_ghost = null
var ragdoll_velocity = Vector3.ZERO
var ragdoll_timer = 0.0
var patrol_target = Vector3.ZERO
var patrol_wait_timer = 0.0
var is_waiting = false
var patrol_origin = Vector3.ZERO
var character_mesh: MeshInstance3D = null
var camera_target_rotation = Vector2.ZERO

@export var role: String = "guard"

@onready var camera_pivot = $CameraPivot
@onready var camera = $CameraPivot/Camera3D
@onready var role_label = $RoleLabel

func _ready():
	camera.current = false
	role_label.visible = false
	add_to_group("npc")
	patrol_origin = global_position
	_pick_patrol_target()
	await get_tree().process_frame
	character_mesh = _find_mesh(self)
	_apply_visuals()

func _find_mesh(node: Node) -> MeshInstance3D:
	for child in node.get_children():
		if child is MeshInstance3D:
			return child
		var found = _find_mesh(child)
		if found:
			return found
	return null

func set_role(r: String):
	role = r
	await get_tree().process_frame
	character_mesh = _find_mesh(self)
	_apply_visuals()

func _apply_visuals():
	role_label.text = role.to_upper()
	var c: Color
	match role:
		"guard":     c = Color(0.3, 0.5, 1.0)
		"janitor":   c = Color(1.0, 0.85, 0.1)
		"executive": c = Color(0.7, 0.2, 1.0)
		_:           c = Color.WHITE
	role_label.modulate = c
	if character_mesh:
		var mat = character_mesh.get_active_material(0)
		mat = StandardMaterial3D.new() if mat == null else mat.duplicate()
		if mat is StandardMaterial3D:
			mat.albedo_color = Color(c.r*0.6+0.4, c.g*0.6+0.4, c.b*0.6+0.4)
		character_mesh.set_surface_override_material(0, mat)

func _pick_patrol_target():
	patrol_target = Vector3(
		clamp(patrol_origin.x + randf_range(-PATROL_RANGE, PATROL_RANGE), -7.0, 7.0),
		patrol_origin.y,
		clamp(patrol_origin.z + randf_range(-PATROL_RANGE, PATROL_RANGE), -7.0, 7.0)
	)
	is_waiting = false

func _find_door() -> Node:
	var doors = get_tree().get_nodes_in_group("door")
	print("Total doors in group: ", doors.size())
	for door in doors:
		print("Door state - is_open: ", door.is_open, ", position: ", door.global_position)
		if not door.is_open:
			var distance = global_position.distance_to(door.global_position)
			print("Checking door at distance: ", distance, ", threshold: ", 4.0)
			if distance <= 4.0:
				print("Door found at distance: ", distance)
				return door
	print("No door found within range")
	return null

func possess(ghost):
	is_possessed = true
	is_ragdoll = false
	ragdoll_timer = 0.0
	controlling_ghost = ghost
	camera.current = true
	if character_mesh:
		character_mesh.rotation.z = 0.0
		character_mesh.rotation.x = 0.0
	role_label.visible = true
	var hud = get_tree().get_first_node_in_group("hud")
	if hud:
		hud.show_role(role)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func unpossess():
	print("unpossess called, is_possessed = ", is_possessed)
	is_possessed = false
	camera.current = false
	await get_tree().process_frame
	controlling_ghost = null
	role_label.visible = false
	var hud = get_tree().get_first_node_in_group("hud")
	if hud:
		hud.hide_role()
	_start_ragdoll()
	print("unpossess completed, camera current: ", camera.current)

func _start_ragdoll():
	is_ragdoll = true
	ragdoll_timer = 0.0
	ragdoll_velocity = Vector3(randf_range(-8.0,8.0), 5.0, randf_range(-8.0,8.0))
	if character_mesh:
		var t = create_tween()
		t.set_parallel(true)
		t.tween_property(character_mesh, "rotation:z", deg_to_rad(90), 0.4)
		t.tween_property(character_mesh, "rotation:x", deg_to_rad(randf_range(-30, 30)), 0.4)
		t.tween_property(character_mesh, "position:y", -0.5, 0.4)
	# Add visual indicator - change color temporarily
	if character_mesh:
		var mat = character_mesh.get_active_material(0)
		if mat:
			mat = mat.duplicate()
			mat.albedo_color = Color(0.8, 0.8, 0.8)
			character_mesh.set_surface_override_material(0, mat)
	# Add screen shake effect
	_shake_camera()
	print("Ragdoll started - NPC cannot be possessed for ", RAGDOLL_RESET_TIME, " seconds")

func _shake_camera():
	var original_pos = camera_pivot.position
	var shake_tween = create_tween()
	shake_tween.set_loops(5)
	shake_tween.set_parallel(true)
	for i in range(5):
		shake_tween.tween_property(camera_pivot, "position:x", original_pos.x + randf_range(-0.1, 0.1), 0.08)
		shake_tween.tween_property(camera_pivot, "position:y", original_pos.y + randf_range(-0.1, 0.1), 0.08)
	shake_tween.tween_property(camera_pivot, "position", original_pos, 0.1)

func _stand_back_up():
	is_ragdoll = false
	ragdoll_velocity = Vector3.ZERO
	if character_mesh:
		var t = create_tween()
		t.set_parallel(true)
		t.tween_property(character_mesh, "rotation:z", 0.0, 0.5)
		t.tween_property(character_mesh, "rotation:x", 0.0, 0.5)
		t.tween_property(character_mesh, "position:y", 0.0, 0.5)
		t.tween_callback(func():
			_apply_visuals()  # Restore original color
			_pick_patrol_target()
		)
	print("Ragdoll ended - NPC can be possessed again")

func _input(event):
	if not is_possessed:
		return
	if event is InputEventMouseMotion:
		camera_target_rotation.x -= event.relative.x * MOUSE_SENSITIVITY
		camera_target_rotation.y -= event.relative.y * MOUSE_SENSITIVITY
		camera_target_rotation.y = clamp(
			camera_target_rotation.y, deg_to_rad(-80), deg_to_rad(80)
		)
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_E:
			print("E pressed while possessed, controlling_ghost = ", controlling_ghost)
			if controlling_ghost:
				controlling_ghost.exit_npc(self)
			else:
				print("ERROR: controlling_ghost is null!")
		if event.keycode == KEY_F:
			print("F pressed, looking for doors...")
			var doors = get_tree().get_nodes_in_group("door")
			print("Total doors in group: ", doors.size())
			var door = _find_door()
			if door:
				print("Door found, trying to open with role: ", role)
				door.try_open(role)
			else:
				print("No door within ", DOOR_DISTANCE, " units. Move closer.")

func _physics_process(delta):
	if is_ragdoll:
		ragdoll_timer += delta
		ragdoll_velocity.y -= gravity * delta
		if is_on_floor():
			ragdoll_velocity.y = 0.0
			ragdoll_velocity.x = move_toward(ragdoll_velocity.x, 0.0, 2.5*delta)
			ragdoll_velocity.z = move_toward(ragdoll_velocity.z, 0.0, 2.5*delta)
		velocity = ragdoll_velocity
		move_and_slide()
		if ragdoll_timer >= RAGDOLL_RESET_TIME:
			_stand_back_up()
		return
	if is_possessed:
		_possessed_movement(delta)
		_smooth_camera_rotation(delta)
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
			_pick_patrol_target()
	else:
		var dir = Vector3(patrol_target.x, global_position.y, patrol_target.z) - global_position
		if dir.length() < 0.5:
			is_waiting = true
			patrol_wait_timer = PATROL_WAIT_TIME
		else:
			dir = dir.normalized()
			velocity.x = dir.x * PATROL_SPEED
			velocity.z = dir.z * PATROL_SPEED
			look_at(global_position + Vector3(dir.x, 0, dir.z), Vector3.UP)
	move_and_slide()

func _possessed_movement(delta):
	if not is_on_floor():
		velocity.y -= gravity * delta
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY
	var dir = (transform.basis * Vector3(
		Input.get_axis("move_left","move_right"), 0,
		Input.get_axis("move_forward","move_back")
	)).normalized()
	
	# Check for doors using raycast
	if dir:
		var ray_dir = dir.normalized()
		var ray_length = 1.5
		var space_state = get_world_3d().direct_space_state
		var query = PhysicsRayQueryParameters3D.create(
			global_position + Vector3(0, 1, 0),
			global_position + Vector3(0, 1, 0) + ray_dir * ray_length,
			collision_mask
		)
		var result = space_state.intersect_ray(query)
		if result:
			var collider = result["collider"]
			if collider.is_in_group("door"):
				dir = Vector3.ZERO
				print("Door raycast hit, blocking movement")
	
	velocity.x = dir.x * SPEED if dir else move_toward(velocity.x, 0, SPEED)
	velocity.z = dir.z * SPEED if dir else move_toward(velocity.z, 0, SPEED)
	move_and_slide()

func _smooth_camera_rotation(delta):
	rotation.y = lerp_angle(rotation.y, camera_target_rotation.x, CAMERA_SMOOTH_SPEED * delta)
	camera_pivot.rotation.x = lerp(camera_pivot.rotation.x, camera_target_rotation.y, CAMERA_SMOOTH_SPEED * delta)
