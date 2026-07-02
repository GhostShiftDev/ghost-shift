extends StaticBody3D

@export var required_role: String = "guard"
var is_open = false
var is_playing_feedback = false

@onready var mesh = $MeshInstance3D
@onready var wrong_label = $WrongLabel

func _ready():
	# Make sure wrong label starts hidden
	wrong_label.visible = false

func try_open(role: String):
	if is_open:
		return
	if is_playing_feedback:
		return

	if role == required_role:
		_open_door()
	else:
		_wrong_role_feedback()

func _open_door():
	is_open = true
	# Flash green briefly then slide door up
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.0, 1.0, 0.3)
	mesh.set_surface_override_material(0, mat)

	var tween = create_tween()
	tween.tween_property(self, "position:y", position.y + 4.0, 0.6)

	# Tell the HUD
	var hud = get_tree().get_first_node_in_group("hud")
	if hud:
		hud.door_opened()

func _wrong_role_feedback():
	is_playing_feedback = true

	# Flash red
	var original_mat = StandardMaterial3D.new()
	original_mat.albedo_color = Color(0.8, 0.8, 0.8)

	var red_mat = StandardMaterial3D.new()
	red_mat.albedo_color = Color(1.0, 0.0, 0.0)

	mesh.set_surface_override_material(0, red_mat)

	# Show "WRONG ROLE!" label above door
	wrong_label.visible = true

	# Shake door left/right for comedic effect
	var shake_tween = create_tween()
	shake_tween.tween_property(self, "position:x", position.x + 0.15, 0.05)
	shake_tween.tween_property(self, "position:x", position.x - 0.15, 0.05)
	shake_tween.tween_property(self, "position:x", position.x + 0.15, 0.05)
	shake_tween.tween_property(self, "position:x", position.x, 0.05)

	# Reset after 0.8 seconds
	await get_tree().create_timer(0.8).timeout
	mesh.set_surface_override_material(0, original_mat)
	wrong_label.visible = false
	is_playing_feedback = false