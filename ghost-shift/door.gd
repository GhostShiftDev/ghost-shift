extends StaticBody3D

@export var required_role: String = "guard"
var is_open = false
var is_animating = false

@onready var mesh = $MeshInstance3D
@onready var wrong_label = $WrongLabel

func _ready():
	add_to_group("door")
	wrong_label.visible = false
	wrong_label.no_depth_test = true
	wrong_label.position = Vector3(0, 2.5, 0)
	_set_color()

func _set_color():
	var mat = StandardMaterial3D.new()
	match required_role:
		"guard":     mat.albedo_color = Color(0.2, 0.4, 1.0)
		"janitor":   mat.albedo_color = Color(1.0, 0.8, 0.1)
		"executive": mat.albedo_color = Color(0.5, 0.1, 0.8)
	mesh.set_surface_override_material(0, mat)

func try_open(role: String):
	if is_open or is_animating:
		return
	if role == required_role:
		_open()
	else:
		_wrong()

func _open():
	is_open = true
	is_animating = true
	# Disable collision so players can walk through
	$CollisionShape3D.disabled = true
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.0, 1.0, 0.3)
	mesh.set_surface_override_material(0, mat)
	var t = create_tween()
	t.tween_property(self, "position:y", position.y + 4.0, 0.5)
	t.tween_callback(func(): is_animating = false)
	var hud = get_tree().get_first_node_in_group("hud")
	if hud:
		hud.door_opened()

func _wrong():
	is_animating = true
	var sx = position.x
	var original_color = mesh.get_surface_override_material(0).albedo_color if mesh.get_surface_override_material(0) else Color.WHITE
	
	# Flash red with emission
	var red = StandardMaterial3D.new()
	red.albedo_color = Color(1.0, 0.0, 0.0)
	red.emission_enabled = true
	red.emission = Color(1.0, 0.0, 0.0)
	red.emission_energy_multiplier = 3.0
	red.roughness = 0.3
	mesh.set_surface_override_material(0, red)
	
	# Show wrong label with dramatic effect
	wrong_label.visible = true
	wrong_label.modulate = Color.RED
	wrong_label.text = "WRONG ROLE!"
	
	var t = create_tween()
	t.set_parallel(true)
	
	# Shake animation
	t.tween_property(self, "position:x", sx+0.3, 0.06)
	t.tween_property(self, "position:x", sx-0.3, 0.06)
	t.tween_property(self, "position:x", sx+0.25, 0.06)
	t.tween_property(self, "position:x", sx-0.25, 0.06)
	t.tween_property(self, "position:x", sx+0.2, 0.06)
	t.tween_property(self, "position:x", sx-0.2, 0.06)
	t.tween_property(self, "position:x", sx+0.15, 0.06)
	t.tween_property(self, "position:x", sx, 0.06)
	
	# Color flash back to original
	t.tween_interval(0.3)
	t.tween_callback(func():
		_set_color()
		wrong_label.visible = false
		is_animating = false
	)
