
extends Node

const CAMERA_ZOOM := 0.8
const SAVE_PATH := "user://boxing_progress.json"
const BOXER_SCENE := "res://Scenes/enemies/ChichoMedina.tscn"

const ROUNDS_TO_WIN := 2
const TOTAL_ROUNDS := 3
const ROUND_DURATION := 60.0
const KO_DISPLAY_DURATION := 1.5
const BREAK_DURATION := 3.0

const GOLD_COLOR := Color("#f4cf72")
const RED_COLOR := Color("#ff4657")
const TEXT_COLOR := Color("#f4f5f7")
const MUTED_COLOR := Color("#aab0bf")
const PANEL_COLOR := Color("#171b25")
const HEALTH_COLOR := Color("#f04d5d")
const STAMINA_COLOR := Color("#328bff")

@onready var ring: Node2D = get_node_or_null("Ring")

var progress: Dictionary = {
	"wins": 0,
	"losses": 0
}

var camera: Camera2D
var player: BoxerBase
var enemy: BoxerBase

var fight_ui: CanvasLayer
var hud: Control
var menu_overlay: Control

var player_health_bar: ProgressBar
var player_stamina_bar: ProgressBar
var enemy_health_bar: ProgressBar
var enemy_stamina_bar: ProgressBar

var player_health_value: Label
var player_stamina_value: Label
var enemy_health_value: Label
var enemy_stamina_value: Label

var player_title_label: Label
var enemy_title_label: Label
var round_label: Label
var timer_label: Label
var score_label: Label
var result_label: Label

var save_button: Button
var continue_button: Button
var saved_progress: Dictionary = {}

var round_timer: float = ROUND_DURATION
var break_timer: float = 0.0
var current_round: int = 1
var player_round_wins: int = 0
var enemy_round_wins: int = 0

var fight_started := false
var fight_finished := false
var waiting_next_round := false
var announcement_id := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	load_progress()

	if ring == null:
		push_error("Main: Ring node is missing.")
		return

	_setup_camera()
	_setup_ui()
	show_main_menu()


func _process(delta: float) -> void:
	if fight_finished:
		return

	if waiting_next_round:
		break_timer = maxf(0.0, break_timer - delta)

		if break_timer > 0.0:
			if is_instance_valid(timer_label):
				timer_label.text = "BREAK  %02d" % ceili(break_timer)
		else:
			_start_next_round()

		return

	if not fight_started:
		return

	round_timer = maxf(0.0, round_timer - delta)
	_update_timer_label()

	if round_timer <= 0.0:
		_end_round_by_time()


# --------------------------------------------------
# CAMERA
# --------------------------------------------------

func _setup_camera() -> void:
	var old_camera := get_node_or_null("FightCamera")

	if old_camera != null:
		remove_child(old_camera)
		old_camera.queue_free()

	camera = Camera2D.new()
	camera.name = "FightCamera"
	camera.zoom = Vector2(CAMERA_ZOOM, CAMERA_ZOOM)
	camera.position_smoothing_enabled = false
	add_child(camera)

	var background := ring.get_node_or_null("Background") as Sprite2D

	if background == null:
		background = ring.get_node_or_null("backround") as Sprite2D

	if background != null and background.texture != null:
		camera.global_position = background.to_global(
			background.get_rect().get_center()
		)
	else:
		camera.global_position = ring.global_position

	camera.make_current()


# --------------------------------------------------
# UI HELPERS
# --------------------------------------------------

func _panel_style(
	background: Color,
	border: Color,
	border_width: int = 1,
	radius: int = 6
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 7.0
	style.content_margin_right = 7.0
	style.content_margin_top = 4.0
	style.content_margin_bottom = 4.0
	return style


func _make_label(
	parent: Control,
	label_name: String,
	text_value: String,
	pos: Vector2,
	label_size: Vector2,
	font_size: int,
	color: Color
) -> Label:
	var label := Label.new()
	label.name = label_name
	label.text = text_value
	label.position = pos
	label.size = label_size
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label


func _style_button(
	button: Button,
	background: Color,
	border: Color
) -> void:
	button.add_theme_stylebox_override(
		"normal", _panel_style(background, border)
	)
	button.add_theme_stylebox_override(
		"hover",
		_panel_style(background.lightened(0.12), border.lightened(0.12))
	)
	button.add_theme_stylebox_override(
		"pressed", _panel_style(background.darkened(0.12), border)
	)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.add_theme_color_override("font_color", TEXT_COLOR)
	button.add_theme_font_size_override("font_size", 13)


func _create_bar(
	parent: Control,
	bar_name: String,
	pos: Vector2,
	width: float,
	color: Color,
	height: float
) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.name = bar_name
	bar.position = pos
	bar.size = Vector2(width, height)
	bar.min_value = 0
	bar.max_value = 100
	bar.value = 100
	bar.show_percentage = false

	bar.add_theme_stylebox_override(
		"background",
		_panel_style(Color("#282d38"), Color("#555c6b"), 1, 5)
	)
	bar.add_theme_stylebox_override(
		"fill",
		_panel_style(color, color.lightened(0.12), 1, 5)
	)

	parent.add_child(bar)
	return bar


func _clear_ui() -> void:
	if not is_instance_valid(fight_ui):
		return

	for child in fight_ui.get_children():
		fight_ui.remove_child(child)
		child.queue_free()

	hud = null
	menu_overlay = null

	player_health_bar = null
	player_stamina_bar = null
	enemy_health_bar = null
	enemy_stamina_bar = null

	player_health_value = null
	player_stamina_value = null
	enemy_health_value = null
	enemy_stamina_value = null

	player_title_label = null
	enemy_title_label = null
	round_label = null
	timer_label = null
	score_label = null
	result_label = null

	save_button = null
	continue_button = null


func _setup_ui() -> void:
	if is_instance_valid(fight_ui):
		fight_ui.queue_free()

	fight_ui = CanvasLayer.new()
	fight_ui.name = "FightUI"
	fight_ui.layer = 5
	add_child(fight_ui)


# --------------------------------------------------
# MAIN MENU
# --------------------------------------------------

func show_main_menu() -> void:
	fight_started = false
	fight_finished = false
	waiting_next_round = false
	break_timer = 0.0
	announcement_id += 1

	_clear_ui()

	var background := ColorRect.new()
	background.name = "MenuBackground"
	background.color = Color(0.035, 0.045, 0.065, 0.97)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fight_ui.add_child(background)

	var top_line := ColorRect.new()
	top_line.color = Color("#a83240")
	top_line.size = Vector2(960, 5)
	background.add_child(top_line)

	menu_overlay = Control.new()
	menu_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fight_ui.add_child(menu_overlay)

	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -260
	panel.offset_right = 260
	panel.offset_top = -200
	panel.offset_bottom = 200
	panel.add_theme_stylebox_override(
		"panel", _panel_style(PANEL_COLOR, Color("#a83b48"), 2, 10)
	)
	menu_overlay.add_child(panel)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 13)
	panel.add_child(layout)

	var title := _make_label(
		layout, "TitleLabel", "PIXEL BOXING CLUB",
		Vector2.ZERO, Vector2(480, 48), 28, GOLD_COLOR
	)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var subtitle := _make_label(
		layout, "SubtitleLabel", "CHICHO MEDINA  •  LOCAL FIGHT",
		Vector2.ZERO, Vector2(480, 25), 12, MUTED_COLOR
	)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var start_button := Button.new()
	start_button.name = "StartButton"
	start_button.text = "START FIGHT"
	start_button.custom_minimum_size = Vector2(0, 42)
	_style_button(start_button, Color("#a83240"), Color("#f06b76"))
	start_button.pressed.connect(start_fight)
	layout.add_child(start_button)

	continue_button = Button.new()
	continue_button.text = "CONTINUE SAVED PROGRESS"
	continue_button.custom_minimum_size = Vector2(0, 38)
	_style_button(continue_button, Color("#283b42"), Color("#4b9d92"))
	continue_button.pressed.connect(_resume_saved_progress)
	layout.add_child(continue_button)

	var progress_button := Button.new()
	progress_button.text = "VIEW CAREER RECORD"
	progress_button.custom_minimum_size = Vector2(0, 38)
	_style_button(progress_button, Color("#252c38"), Color("#5c6579"))
	progress_button.pressed.connect(show_progress)
	layout.add_child(progress_button)

	var exit_button := Button.new()
	exit_button.text = "EXIT"
	exit_button.custom_minimum_size = Vector2(0, 35)
	_style_button(exit_button, Color("#252c38"), Color("#5c6579"))
	exit_button.pressed.connect(_exit_game)
	layout.add_child(exit_button)

	continue_button.disabled = saved_progress.is_empty()


# --------------------------------------------------
# FIGHT HUD
# --------------------------------------------------

func _setup_fight_ui() -> void:
	_clear_ui()

	hud = Control.new()
	hud.name = "HUD"
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fight_ui.add_child(hud)

	player_title_label = _make_label(
		hud, "PlayerLabel", "PLAYER",
		Vector2(28, 10), Vector2(300, 22), 15, GOLD_COLOR
	)

	_make_label(
		hud, "PlayerHealthCaption", "HEALTH",
		Vector2(29, 32), Vector2(90, 12), 9, MUTED_COLOR
	)

	player_health_bar = _create_bar(
		hud, "PlayerHealthBar",
		Vector2(28, 44), 300, HEALTH_COLOR, 17
	)

	player_health_value = _make_label(
		hud, "PlayerHealthValue", "100 / 100",
		Vector2(250, 32), Vector2(78, 12), 9, TEXT_COLOR
	)
	player_health_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	_make_label(
		hud, "PlayerStaminaCaption", "STAMINA",
		Vector2(29, 64), Vector2(90, 12), 9, MUTED_COLOR
	)

	player_stamina_bar = _create_bar(
		hud, "PlayerStaminaBar",
		Vector2(28, 76), 300, STAMINA_COLOR, 13
	)

	player_stamina_value = _make_label(
		hud, "PlayerStaminaValue", "100 / 100",
		Vector2(250, 64), Vector2(78, 12), 9, TEXT_COLOR
	)
	player_stamina_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	enemy_title_label = _make_label(
		hud, "EnemyLabel", "OPPONENT",
		Vector2(632, 10), Vector2(300, 22), 15, GOLD_COLOR
	)
	enemy_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	var enemy_health_caption := _make_label(
		hud, "EnemyHealthCaption", "HEALTH",
		Vector2(842, 32), Vector2(90, 12), 9, MUTED_COLOR
	)
	enemy_health_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	enemy_health_bar = _create_bar(
		hud, "EnemyHealthBar",
		Vector2(632, 44), 300, HEALTH_COLOR, 17
	)

	enemy_health_value = _make_label(
		hud, "EnemyHealthValue", "100 / 100",
		Vector2(632, 32), Vector2(78, 12), 9, TEXT_COLOR
	)

	var enemy_stamina_caption := _make_label(
		hud, "EnemyStaminaCaption", "STAMINA",
		Vector2(842, 64), Vector2(90, 12), 9, MUTED_COLOR
	)
	enemy_stamina_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	enemy_stamina_bar = _create_bar(
		hud, "EnemyStaminaBar",
		Vector2(632, 76), 300, STAMINA_COLOR, 13
	)

	enemy_stamina_value = _make_label(
		hud, "EnemyStaminaValue", "100 / 100",
		Vector2(632, 64), Vector2(78, 12), 9, TEXT_COLOR
	)

	var timer_panel := Panel.new()
	timer_panel.position = Vector2(382, 8)
	timer_panel.size = Vector2(196, 82)
	timer_panel.add_theme_stylebox_override(
		"panel", _panel_style(PANEL_COLOR, Color("#b94a52"), 2, 9)
	)
	hud.add_child(timer_panel)

	var brand := _make_label(
		hud, "BrandLabel", "PIXEL BOXING CLUB",
		Vector2(386, 12), Vector2(188, 15), 10, MUTED_COLOR
	)
	brand.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	round_label = _make_label(
		hud, "RoundLabel", "ROUND 1",
		Vector2(386, 28), Vector2(188, 25), 18, GOLD_COLOR
	)
	round_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	timer_label = _make_label(
		hud, "TimerLabel", "01:00",
		Vector2(386, 52), Vector2(188, 23), 15, TEXT_COLOR
	)
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	score_label = _make_label(
		hud, "ScoreLabel", "ROUNDS  0 - 0",
		Vector2(386, 94), Vector2(188, 20), 11, TEXT_COLOR
	)
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	save_button = Button.new()
	save_button.text = "SAVE PROGRESS"
	save_button.position = Vector2(793, 119)
	save_button.size = Vector2(139, 29)
	save_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_style_button(save_button, Color("#252c38"), Color("#5c6579"))
	save_button.pressed.connect(save_progress)
	hud.add_child(save_button)

	result_label = _make_label(
		hud, "ResultLabel", "",
		Vector2(150, 180), Vector2(660, 120), 28, RED_COLOR
	)
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	_make_controls_panel()
	_update_stats_ui()
	_update_round_label()
	_update_timer_label()


func _make_controls_panel() -> void:
	var controls_panel := PanelContainer.new()
	controls_panel.position = Vector2(24, 472)
	controls_panel.size = Vector2(912, 54)
	controls_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	controls_panel.add_theme_stylebox_override(
		"panel", _panel_style(Color("#121620"), Color("#454b5c"), 1, 7)
	)
	hud.add_child(controls_panel)

	var controls_row := HBoxContainer.new()
	controls_row.add_theme_constant_override("separation", 7)
	controls_panel.add_child(controls_row)

	for caption in [
		"A / D  MOVE", "W  JUMP", "S  CROUCH", "J  JAB",
		"K  HEAVY", "L  KICK", "U  SPECIAL", "I  BLOCK"
	]:
		var chip := PanelContainer.new()
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		chip.custom_minimum_size = Vector2(0, 32)
		chip.add_theme_stylebox_override(
			"panel", _panel_style(Color("#242a36"), Color("#555d70"), 1, 5)
		)
		controls_row.add_child(chip)

		var label := Label.new()
		label.text = caption
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 10)
		label.add_theme_color_override("font_color", TEXT_COLOR)
		chip.add_child(label)


func _update_stats_ui() -> void:
	if not is_instance_valid(player) or not is_instance_valid(enemy):
		return

	if is_instance_valid(player_title_label):
		player_title_label.text = player.boxer_name
	if is_instance_valid(enemy_title_label):
		enemy_title_label.text = enemy.boxer_name

	if is_instance_valid(player_health_bar):
		player_health_bar.max_value = maxf(1.0, player.max_health)
		player_health_bar.value = player.health
	if is_instance_valid(player_stamina_bar):
		player_stamina_bar.max_value = maxf(1.0, player.max_stamina)
		player_stamina_bar.value = player.stamina
	if is_instance_valid(enemy_health_bar):
		enemy_health_bar.max_value = maxf(1.0, enemy.max_health)
		enemy_health_bar.value = enemy.health
	if is_instance_valid(enemy_stamina_bar):
		enemy_stamina_bar.max_value = maxf(1.0, enemy.max_stamina)
		enemy_stamina_bar.value = enemy.stamina

	if is_instance_valid(player_health_value):
		player_health_value.text = "%d / %d" % [
			roundi(player.health), roundi(player.max_health)
		]
	if is_instance_valid(player_stamina_value):
		player_stamina_value.text = "%d / %d" % [
			roundi(player.stamina), roundi(player.max_stamina)
		]
	if is_instance_valid(enemy_health_value):
		enemy_health_value.text = "%d / %d" % [
			roundi(enemy.health), roundi(enemy.max_health)
		]
	if is_instance_valid(enemy_stamina_value):
		enemy_stamina_value.text = "%d / %d" % [
			roundi(enemy.stamina), roundi(enemy.max_stamina)
		]

	if is_instance_valid(score_label):
		score_label.text = "ROUNDS  %d - %d" % [
			player_round_wins, enemy_round_wins
		]

	if is_instance_valid(save_button):
		save_button.disabled = (
			not fight_started
			or waiting_next_round
			or fight_finished
		)


func _update_timer_label() -> void:
	if not is_instance_valid(timer_label):
		return

	var seconds := ceili(maxf(0.0, round_timer))
	timer_label.text = "%02d:%02d" % [
		int(seconds / 60), seconds % 60
	]
	timer_label.add_theme_color_override(
		"font_color", RED_COLOR if seconds <= 10 else TEXT_COLOR
	)


func _update_round_label() -> void:
	if is_instance_valid(round_label):
		round_label.text = "ROUND %d" % current_round


# --------------------------------------------------
# FIGHT SETUP
# --------------------------------------------------

func start_fight() -> void:
	_start_new_match()


func _start_new_match() -> void:
	announcement_id += 1
	fight_started = false
	fight_finished = false
	waiting_next_round = false
	break_timer = 0.0

	if not _spawn_boxers():
		return

	current_round = 1
	player_round_wins = 0
	enemy_round_wins = 0
	round_timer = ROUND_DURATION

	_start_round()


func _spawn_boxers() -> bool:
	if not ResourceLoader.exists(BOXER_SCENE):
		push_error("Scene not found: " + BOXER_SCENE)
		_show_message("ERROR: BOXER SCENE NOT FOUND")
		return false

	var packed := load(BOXER_SCENE) as PackedScene

	if packed == null:
		push_error("Could not load scene: " + BOXER_SCENE)
		_show_message("ERROR: COULD NOT LOAD BOXER SCENE")
		return false

	_remove_boxers()

	var new_player := packed.instantiate() as BoxerBase
	var new_enemy := packed.instantiate() as BoxerBase

	if new_player == null or new_enemy == null:
		if is_instance_valid(new_player):
			new_player.free()
		if is_instance_valid(new_enemy):
			new_enemy.free()

		push_error("ChichoMedina.tscn must use BoxerBase.gd.")
		_show_message("ERROR: INVALID BOXER SCENE")
		return false

	player = new_player
	enemy = new_enemy

	player.name = "Player"
	enemy.name = "Enemy"

	ring.add_child(player)
	ring.add_child(enemy)

	player.boxer_name = "PLAYER"
	player.is_player = true

	enemy.boxer_name = "OPPONENT"
	enemy.is_player = false

	player.position = Vector2(-100, 0)
	enemy.position = Vector2(100, 0)

	player.opponent = enemy
	enemy.opponent = player

	player.stats_changed.connect(_on_stats_changed)
	enemy.stats_changed.connect(_on_stats_changed)

	player.knocked_out.connect(_on_knockout)
	enemy.knocked_out.connect(_on_knockout)

	return true


func _remove_boxers() -> void:
	if is_instance_valid(player):
		player.queue_free()

	if is_instance_valid(enemy):
		enemy.queue_free()

	player = null
	enemy = null


func _start_round() -> void:
	if not is_instance_valid(player) or not is_instance_valid(enemy):
		return

	player.reset_for_round()
	enemy.reset_for_round()

	player.opponent = enemy
	enemy.opponent = player

	player.position = Vector2(-100, 0)
	enemy.position = Vector2(100, 0)

	round_timer = ROUND_DURATION
	break_timer = 0.0
	fight_started = true
	fight_finished = false
	waiting_next_round = false

	_setup_fight_ui()
	_update_stats_ui()
	_update_round_label()
	_update_timer_label()

	if current_round == 1:
		_show_announcement("FIGHT!", 1.5)
	else:
		_show_announcement("ROUND %d" % current_round, 1.2)


func _on_stats_changed(_boxer: BoxerBase) -> void:
	_update_stats_ui()


# --------------------------------------------------
# ROUND FLOW
# --------------------------------------------------

func _on_knockout(boxer: BoxerBase) -> void:
	if not fight_started or fight_finished or waiting_next_round:
		return

	fight_started = false

	if boxer == player:
		enemy_round_wins += 1
		_show_round_result("YOU GOT KNOCKED OUT")
	else:
		player_round_wins += 1
		_show_round_result("OPPONENT KNOCKED OUT!")


func _end_round_by_time() -> void:
	if not fight_started or fight_finished or waiting_next_round:
		return

	fight_started = false

	if not is_instance_valid(player) or not is_instance_valid(enemy):
		return

	if player.health > enemy.health:
		player_round_wins += 1
		_show_round_result("ROUND WON!")
	elif enemy.health > player.health:
		enemy_round_wins += 1
		_show_round_result("ROUND LOST!")
	else:
		_show_round_result("ROUND DRAW!")


func _show_round_result(message: String) -> void:
	if fight_finished:
		return

	announcement_id += 1
	waiting_next_round = true
	break_timer = 0.0

	_update_stats_ui()

	if is_instance_valid(result_label):
		result_label.text = message
		result_label.add_theme_color_override("font_color", GOLD_COLOR)

	if is_instance_valid(score_label):
		score_label.text = "ROUNDS  %d - %d" % [
			player_round_wins, enemy_round_wins
		]

	await get_tree().create_timer(KO_DISPLAY_DURATION).timeout

	if not is_inside_tree() or fight_finished:
		return

	if player_round_wins >= ROUNDS_TO_WIN:
		_finish_fight(true)
		return

	if enemy_round_wins >= ROUNDS_TO_WIN:
		_finish_fight(false)
		return

	if current_round >= TOTAL_ROUNDS:
		if player_round_wins > enemy_round_wins:
			_finish_fight(true)
		elif enemy_round_wins > player_round_wins:
			_finish_fight(false)
		else:
			_finish_fight(false, true)
		return

	break_timer = BREAK_DURATION

	if is_instance_valid(result_label):
		result_label.text = message + "\n\nNEXT ROUND SOON"

	if is_instance_valid(timer_label):
		timer_label.text = "BREAK  03"

	_update_stats_ui()


func _start_next_round() -> void:
	if not waiting_next_round or fight_finished:
		return

	current_round += 1
	_start_round()


func _finish_fight(player_won: bool, is_draw: bool = false) -> void:
	fight_started = false
	fight_finished = true
	waiting_next_round = false
	break_timer = 0.0
	announcement_id += 1

	if player_won:
		progress["wins"] = int(progress.get("wins", 0)) + 1
		_show_final_result("VICTORY!")
	elif is_draw:
		_show_final_result("DRAW!")
	else:
		progress["losses"] = int(progress.get("losses", 0)) + 1
		_show_final_result("DEFEAT")

	save_progress()


func _show_final_result(message: String) -> void:
	if not is_instance_valid(hud):
		return

	if is_instance_valid(result_label):
		result_label.text = message
		result_label.add_theme_color_override(
			"font_color",
			GOLD_COLOR if message == "VICTORY!" else RED_COLOR
		)

	if is_instance_valid(timer_label):
		timer_label.text = "FIGHT OVER"

	if is_instance_valid(round_label):
		round_label.text = "FINAL RESULT"

	if is_instance_valid(score_label):
		score_label.text = "FINAL SCORE  %d - %d" % [
			player_round_wins, enemy_round_wins
		]

	if is_instance_valid(save_button):
		save_button.visible = false

	var rematch_button := Button.new()
	rematch_button.text = "REMATCH"
	rematch_button.position = Vector2(350, 330)
	rematch_button.size = Vector2(120, 40)
	_style_button(rematch_button, Color("#a83240"), Color("#f06b76"))
	rematch_button.pressed.connect(_start_rematch)
	hud.add_child(rematch_button)

	var menu_button := Button.new()
	menu_button.text = "MAIN MENU"
	menu_button.position = Vector2(490, 330)
	menu_button.size = Vector2(120, 40)
	_style_button(menu_button, Color("#252c38"), Color("#5c6579"))
	menu_button.pressed.connect(show_main_menu)
	hud.add_child(menu_button)


func _start_rematch() -> void:
	announcement_id += 1
	_start_new_match()


func _show_announcement(message: String, duration: float = 1.5) -> void:
	if not is_instance_valid(result_label):
		return

	announcement_id += 1
	var current_id := announcement_id

	result_label.text = message
	result_label.add_theme_color_override("font_color", RED_COLOR)

	await get_tree().create_timer(duration).timeout

	if not is_inside_tree() or not is_instance_valid(result_label):
		return

	if (
		current_id == announcement_id
		and not waiting_next_round
		and not fight_finished
	):
		result_label.text = ""


func _show_message(message: String) -> void:
	fight_started = false
	fight_finished = false
	waiting_next_round = false
	announcement_id += 1

	_clear_ui()

	var error_screen := Control.new()
	error_screen.name = "ErrorScreen"
	error_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fight_ui.add_child(error_screen)

	var background := ColorRect.new()
	background.color = Color(0.035, 0.045, 0.065, 0.97)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	error_screen.add_child(background)

	var label := _make_label(
		error_screen,
		"ErrorLabel",
		message,
		Vector2(30, 30),
		Vector2(700, 70),
		22,
		RED_COLOR
	)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var button := Button.new()
	button.text = "BACK TO MAIN MENU"
	button.position = Vector2(30, 115)
	button.size = Vector2(220, 42)

	_style_button(button, Color("#a83240"), Color("#f06b76"))
	button.pressed.connect(show_main_menu)
	error_screen.add_child(button)


# --------------------------------------------------
# CAREER RECORD
# --------------------------------------------------

func show_progress() -> void:
	fight_started = false
	fight_finished = false
	waiting_next_round = false
	break_timer = 0.0
	announcement_id += 1

	_clear_ui()

	var screen := Control.new()
	screen.name = "ProgressScreen"
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fight_ui.add_child(screen)

	var background := ColorRect.new()
	background.name = "ProgressBackground"
	background.color = Color(0.035, 0.045, 0.065, 0.97)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(background)

	_make_label(
		screen, "ProgressTitle", "CAREER RECORD",
		Vector2(30, 30), Vector2(500, 50), 32, GOLD_COLOR
	)

	_make_label(
		screen, "WinsLabel",
		"WINS: %d" % int(progress.get("wins", 0)),
		Vector2(30, 100), Vector2(300, 35), 22, TEXT_COLOR
	)

	_make_label(
		screen, "LossesLabel",
		"LOSSES: %d" % int(progress.get("losses", 0)),
		Vector2(30, 145), Vector2(300, 35), 22, TEXT_COLOR
	)

	var back_button := Button.new()
	back_button.name = "BackButton"
	back_button.text = "BACK"
	back_button.position = Vector2(30, 215)
	back_button.size = Vector2(180, 42)

	_style_button(back_button, Color("#252c38"), Color("#5c6579"))
	back_button.pressed.connect(show_main_menu)
	screen.add_child(back_button)


# --------------------------------------------------
# SAVE / LOAD
# --------------------------------------------------

func save_progress() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)

	if file == null:
		push_error("Could not save progress.")
		return

	file.store_string(JSON.stringify(progress))
	file.close()

	saved_progress = progress.duplicate(true)

	if is_instance_valid(continue_button):
		continue_button.disabled = saved_progress.is_empty()


func load_progress() -> void:
	progress = {
		"wins": 0,
		"losses": 0
	}
	saved_progress.clear()

	if not FileAccess.file_exists(SAVE_PATH):
		return

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)

	if file == null:
		push_error("Could not read progress.")
		return

	var content := file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(content)

	if parsed is Dictionary:
		progress["wins"] = int(parsed.get("wins", 0))
		progress["losses"] = int(parsed.get("losses", 0))
		saved_progress = progress.duplicate(true)


func _resume_saved_progress() -> void:
	# Se conserva el registro de carrera, pero no el estado de la pelea.
	start_fight()


# --------------------------------------------------
# EXIT
# --------------------------------------------------

func _exit_game() -> void:
	get_tree().quit()
