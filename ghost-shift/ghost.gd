extends CharacterBody3D

const FLY_SPEED = 6.0
const MOUSE_SENSITIVITY = 0.003
const POSSESS_DISTANCE = 2.0

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
@onready var camera_pivot = $CameraPivot
@onready var camera = $CameraPivot/Camera3D
@onready var collision = $CollisionShape3D

func _ready():
	# Ghost phases through everything by disabling its own collision
	collision.disabled = true
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _unhandled_input(event):
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		camera_pivot.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
		camera_pivot.rotation.x = clamp(
			camera_pivot.rotation.x, deg_to_rad(-80), deg_to_rad(80)
		)
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		if event.keycode == KEY_E:
			_try_possess()

func _try_possess():
	# Find closest NPC within range
	var npcs = get_tree().get_nodes_in_group("npc")
	var closest = null
	var closest_dist = POSSESS_DISTANCE
	for npc in npcs:
		if npc.is_ragdoll:
			print("Cannot possess - NPC is in ragdoll state")
			continue
		var d = global_position.distance_to(npc.global_position)
		if d < closest_dist:
			closest_dist = d
			closest = npc
	if closest:
		possess_npc(closest)

func possess_npc(npc):
	# Turn off ghost camera
	camera.current = false
	
	# Call NPC possess which will turn on NPC camera
	npc.possess(self)
	
	# Hide ghost
	visible = false
	set_physics_process(false)
	set_process_unhandled_input(false)
	
	print("possess_npc completed, ghost camera current: ", camera.current, ", npc camera current: ", npc.camera.current)

func exit_npc(npc):
	print("exit_npc called, unpossessing NPC")
	
	# Turn off NPC camera first
	npc.camera.current = false
	
	# Unpossess the NPC (this sets is_possessed = false)
	npc.unpossess()
	
	# Position ghost above and behind NPC
	global_position = npc.global_position + Vector3(0, 3.0, 3.0)
	
	# Make ghost visible
	visible = true
	show()
	
	# Enable ghost systems
	set_physics_process(true)
	set_process_unhandled_input(true)
	collision.disabled = false
	
	# Turn on ghost camera
	camera.current = true
	
	# Capture mouse
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	print("exit_npc completed, ghost position: ", global_position, ", ghost visible: ", visible, ", ghost camera current: ", camera.current, ", npc camera current: ", npc.camera.current)

func _physics_process(delta):
	var input_dir = Input.get_vector(
		"move_left", "move_right", "move_forward", "move_back"
	)
	var direction = (
		transform.basis * Vector3(input_dir.x, 0, input_dir.y)
	).normalized()
	var vertical = 0.0
	if Input.is_action_pressed("ui_accept"):
		vertical = 1.0
	if Input.is_action_pressed("move_down"):
		vertical = -1.0
	velocity = direction * FLY_SPEED
	velocity.y = vertical * FLY_SPEED
	move_and_slide()