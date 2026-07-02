extends CanvasLayer

var time_left = 60.0
var doors_opened = 0
var total_doors = 3
var game_over = false

# UI nodes — built in code so anchors are always correct
var timer_label: Label
var doors_label: Label
var result_label: Label

func _ready():
	add_to_group("hud")
	_build_ui()

func _build_ui():
	# Root control that fills the whole screen
	var root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# Timer label — top left
	timer_label = Label.new()
	timer_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	timer_label.position = Vector2(20, 20)
	timer_label.add_theme_font_size_override("font_size", 28)
	timer_label.add_theme_color_override("font_color", Color.WHITE)
	timer_label.text = "TIME: 60"
	root.add_child(timer_label)

	# Doors label — top left below timer
	doors_label = Label.new()
	doors_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	doors_label.position = Vector2(20, 60)
	doors_label.add_theme_font_size_override("font_size", 28)
	doors_label.add_theme_color_override("font_color", Color.YELLOW)
	doors_label.text = "DOORS: 0/3"
	root.add_child(doors_label)

	# Role hint label — bottom left, shows what role you currently are
	var hint_label = Label.new()
	hint_label.name = "HintLabel"
	hint_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	hint_label.position = Vector2(20, -60)
	hint_label.add_theme_font_size_override("font_size", 22)
	hint_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	hint_label.text = "E = Possess/Exit   F = Interact"
	root.add_child(hint_label)

	# Result label — center screen, hidden until game ends
	result_label = Label.new()
	result_label.set_anchors_preset(Control.PRESET_CENTER)
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

	# Flash timer red when under 10 seconds
	if time_left <= 10:
		timer_label.add_theme_color_override("font_color", Color.RED)
	
	if time_left <= 0:
		_end_game(false)

func door_opened():
	doors_opened += 1
	doors_label.text = "DOORS: " + str(doors_opened) + "/" + str(total_doors)
	if doors_opened >= total_doors:
		_end_game(true)

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