extends StaticBody3D

@export var required_role: String = "guard"
var is_open = false
var is_animating = false

@onready var mesh = $MeshInstance3D
@onready var wrong_label = $WrongLabel

func _ready():
	wrong_label.visible = false
	wrong_label.no_depth_test = true
	_apply_door_color()

func _apply_door_color():
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
		_open_door()
	else:
		_wrong_feedback()

func _open_door():
	is_open = true
	is_animating = true
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.0, 1.0, 0.3)
	mesh.set_surface_override_material(0, mat)
	var tween = create_tween()
	tween.tween_property(self, "position:y", position.y + 4.0, 0.5)
	tween.tween_callback(func(): is_animating = false)
	var hud = get_tree().get_first_node_in_group("hud")
	if hud:
		hud.door_opened()

func _wrong_feedback():
	is_animating = true
	var start_x = position.x
	var red_mat = StandardMaterial3D.new()
	red_mat.albedo_color = Color(1.0, 0.0, 0.0)
	mesh.set_surface_override_material(0, red_mat)
	wrong_label.visible = true
	var tween = create_tween()
	tween.tween_property(self, "position:x", start_x + 0.15, 0.05)
	tween.tween_property(self, "position:x", start_x - 0.15, 0.05)
	tween.tween_property(self, "position:x", start_x + 0.10, 0.05)
	tween.tween_property(self, "position:x", start_x, 0.05)
	tween.tween_callback(func():
		_apply_door_color()
		wrong_label.visible = false
		is_animating = false
	)

func _on_interact_zone_body_entered(body):
	if body.has_method("set_nearby_door"):
		body.set_nearby_door(self)

func _on_interact_zone_body_exited(body):
	if body.has_method("set_nearby_door"):
		body.set_nearby_door(null)