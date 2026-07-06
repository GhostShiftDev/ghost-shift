extends CanvasLayer

var time_left = 60.0
var doors_opened = 0
var total_doors = 3
var game_over = false

var timer_label: Label
var doors_label: Label
var result_label: Label
var role_display: Label

func _ready():
	add_to_group("hud")
	_build_ui()

func _build_ui():
	var root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# Timer — top left
	timer_label = Label.new()
	timer_label.position = Vector2(20, 20)
	timer_label.add_theme_font_size_override("font_size", 28)
	timer_label.add_theme_color_override("font_color", Color.WHITE)
	timer_label.text = "TIME: 60"
	root.add_child(timer_label)

	# Doors counter — top left below timer
	doors_label = Label.new()
	doors_label.position = Vector2(20, 60)
	doors_label.add_theme_font_size_override("font_size", 28)
	doors_label.add_theme_color_override("font_color", Color.YELLOW)
	doors_label.text = "DOORS: 0/3"
	root.add_child(doors_label)

	# Controls hint — bottom left, fixed pixel position
	var hint_label = Label.new()
	hint_label.position = Vector2(20, 620)
	hint_label.add_theme_font_size_override("font_size", 20)
	hint_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	hint_label.text = "E = Possess/Exit   F = Interact"
	root.add_child(hint_label)

	# Role display — bottom center, shown when possessing
	# Uses fixed pixel position instead of anchor preset
	role_display = Label.new()
	role_display.position = Vector2(500, 620)
	role_display.custom_minimum_size = Vector2(400, 60)
	role_display.add_theme_font_size_override("font_size", 26)
	role_display.add_theme_color_override("font_color", Color.WHITE)
	role_display.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	role_display.visible = false
	role_display.text = ""
	root.add_child(role_display)

	# Result label — center screen
	result_label = Label.new()
	result_label.position = Vector2(500, 300)
	result_label.custom_minimum_size = Vector2(400, 80)
	result_label.add_theme_font_size_override("font_size", 48)
	result_label.add_theme_color_override("font_color", Color.WHITE)
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.visible = false
	result_label.text = ""
	root.add_child(result_label)

func _process(delta):
	if game_over:
		return
	time_left -= delta
	var seconds = max(0, int(time_left))
	timer_label.text = "TIME: " + str(seconds)
	doors_label.text = "DOORS: " + str(doors_opened) + "/" + str(total_doors)
	if time_left <= 10:
		timer_label.add_theme_color_override("font_color", Color.RED)
	if time_left <= 0:
		_end_game(false)

func door_opened():
	doors_opened += 1
	doors_label.text = "DOORS: " + str(doors_opened) + "/" + str(total_doors)
	if doors_opened >= total_doors:
		_end_game(true)

func show_role(role: String):
	var role_color: Color
	match role:
		"guard":     role_color = Color(0.3, 0.5, 1.0)
		"janitor":   role_color = Color(1.0, 0.85, 0.1)
		"executive": role_color = Color(0.7, 0.2, 1.0)
		_:           role_color = Color.WHITE
	role_display.add_theme_color_override("font_color", role_color)
	role_display.text = "YOU ARE: " + role.to_upper() + "\n[F] Open door    [E] Exit body"
	role_display.visible = true

func hide_role():
	role_display.visible = false

func _end_game(won: bool):
	game_over = true
	result_label.visible = true
	if won:
		result_label.text = "HEIST COMPLETE!"
		result_label.add_theme_color_override("font_color", Color.GREEN)
	else:
		result_label.text = "HEIST FAILED!"
		result_label.add_theme_color_override("font_color", Color.RED)
	await get_tree().create_timer(3.0).timeout
	get_tree().reload_current_scene()
