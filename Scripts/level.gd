extends Node3D

@export_group("Song Files")
@export_file("*.txt") var beatmap_file: String = ""

@export_group("Rhythm Settings")
@export var scroll_speed: float = 12.0
@export var spawn_ahead: float = 3.0
@export var hit_zone_x: float = -5.0
@export var ghost_filter_gap: float = 0.2
@export var note_height: float = 0.0

@export_group("Judgment Settings")
@export var hit_window: float = 0.10 # The "Outer Door" (Good)
@export var great_window: float = 0.07 # The "Middle Ring"
@export var perfect_window: float = 0.03 # The "Bullseye"

# --- NODES ---
@onready var music_player = $MusicPlayer
@onready var don_player = $DonPlayer
@onready var ka_player = $KaPlayer
@onready var hit_zone_sprite = $HitZone

# UI Nodes
@onready var score_label = $CanvasLayer/HUD/ScoreLabel
@onready var combo_label = $CanvasLayer/HUD/ComboLabel
@onready var judgment_label = $CanvasLayer/HUD/JudgmentLabel
@onready var pause_menu = $CanvasLayer/HUD/PauseMenu
@onready var pause_button = $CanvasLayer/HUD/PauseBtn/PauseBtn
@onready var start_menu = $CanvasLayer/HUD/StartMenu 

@export var note_scene: PackedScene

# --- DATA ---
var beat_data = []
var current_note_index = 0
var score: int = 0
var combo: int = 0
var is_game_started = false

signal minigame_exited # for city demo only

func _ready():
	randomize()
	beat_data = load_beatmap(beatmap_file)
	beat_data.sort_custom(func(a, b): return a[0] < b[0])
	
	# Reset Labels
	score_label.text = "Score: 0"
	combo_label.text = ""
	judgment_label.text = ""
	
	# UI Setup: Show Start Menu, Hide Game HUD
	start_menu.visible = true       # Show Start Menu
	pause_menu.visible = false
	score_label.visible = false     # Hide HUD
	combo_label.visible = false     # Hide HUD
	
	hit_zone_sprite.position.y = note_height
	
	# IMPORTANT: Do NOT play music yet!
	# music_player.play() <--- REMOVED THIS
	is_game_started = false

func _process(_delta):
	# IF PAUSED: Stop the spawning logic entirely
	if get_tree().paused: return
	
	if !music_player.playing and !get_tree().paused: return

	var time = get_smooth_time()

	while current_note_index < beat_data.size() and beat_data[current_note_index][0] <= time + spawn_ahead:
		var note_info = beat_data[current_note_index]
		if note_info[0] > time:
			spawn_note(note_info[0], note_info[1])
		current_note_index += 1

func spawn_note(t_time, t_type):
	if note_scene == null: return
	var n = note_scene.instantiate()
	n.target_time = t_time
	n.note_type = t_type
	n.scroll_speed = scroll_speed
	n.hit_zone_x = hit_zone_x
	n.spawn_y = note_height
	
	# IMPORTANT: Force notes to be "Pausable" so they freeze
	n.process_mode = Node.PROCESS_MODE_PAUSABLE
	
	add_child(n)
	n.add_to_group("notes")

func _input(event):
	# 1. Check for Start Input (Any Key)
	if not is_game_started:
		if event is InputEventKey and event.pressed:
			begin_countdown()
		return # Stop here, don't allow pausing or hitting notes yet
	
	# 2. Check for Pause Input (P Key)
	if event is InputEventKey and event.pressed and (event.keycode == KEY_P or event.keycode == KEY_ESCAPE):
		toggle_pause()
	
	# 3. If Game is Paused, IGNORE inputs below here
	if get_tree().paused:
		return

	# 4. Game Inputs
	if event.is_action_pressed("hit_left"):
		check_for_hit("Don")
	elif event.is_action_pressed("hit_right"):
		check_for_hit("Ka")

# --- NEW FUNCTIONS TO HANDLE START LOGIC ---

func begin_countdown():
	if is_game_started: return
	is_game_started = true
	
	# Hide the start menu
	start_menu.visible = false
	
	# Reset judgment label for countdown use
	judgment_label.modulate = Color(1, 1, 1, 1)
	judgment_label.scale = Vector2(1.5, 1.5) # Optional: make it big
	
	judgment_label.text = "3"
	await get_tree().create_timer(0.8).timeout
	
	judgment_label.text = "2"
	await get_tree().create_timer(0.8).timeout
	
	judgment_label.text = "1"
	await get_tree().create_timer(0.8).timeout
	
	judgment_label.text = "GO!"
	
	start_game()
	
	# Clear "GO!" after a moment
	await get_tree().create_timer(0.5).timeout
	judgment_label.text = ""

func start_game():
	# Show the HUD elements
	score_label.visible = true
	combo_label.visible = true
	
	# Start the music (which starts the game loop)
	music_player.play()

# -------------------------------------------

func toggle_pause():
	var is_paused = !get_tree().paused
	get_tree().paused = is_paused
	
	pause_menu.visible = is_paused
	pause_button.visible = !is_paused
	music_player.stream_paused = is_paused
	
	if is_paused:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	else:
		pass

func check_for_hit(type):
	var song_time = get_smooth_time()
	var best_note = null
	var smallest_diff = hit_window
	
	var all_notes = get_tree().get_nodes_in_group("notes")
	
	for note in all_notes:
		if note.note_type == type:
			var diff = abs(note.target_time - song_time)
			if diff < smallest_diff:
				smallest_diff = diff
				best_note = note

	if best_note:
		if type == "Don":
			don_player.play()
			trigger_flash(Color(1.0, 0.8, 0.2))
		else:
			ka_player.play()
			trigger_flash(Color(0.2, 0.8, 1.0))
			
		process_score(smallest_diff)
		best_note.remove_from_group("notes")
		best_note.queue_free()

func trigger_flash(flash_color: Color):
	var tween = create_tween()
	hit_zone_sprite.modulate = flash_color
	hit_zone_sprite.scale = Vector3(0.1, 0.1, 0.1)
	tween.set_parallel(true)
	tween.tween_property(hit_zone_sprite, "modulate", Color(1, 1, 1), 0.15)
	tween.tween_property(hit_zone_sprite, "scale", Vector3(0.11, 0.11, 0.11), 0.15)

func process_score(diff):
	combo += 1
	var rating = "GOOD"
	var points = 20
	
	if diff <= perfect_window:
		rating = "PERFECT"
		points = 100
	elif diff <= great_window:
		rating = "GREAT"
		points = 50

	score += points
	update_ui(rating)

func update_ui(rating):
	score_label.text = "Score: " + str(score)
	combo_label.text = str(combo) + " COMBO" if combo > 1 else ""
	
	judgment_label.text = rating
	judgment_label.modulate.a = 1.0
	judgment_label.pivot_offset = judgment_label.size / 2
	
	var target_scale = 1.0
	match rating:
		"PERFECT":
			judgment_label.modulate = Color(1.0, 0.84, 0.0)
			target_scale = 1.6
		"GREAT":
			judgment_label.modulate = Color(0.0, 1.0, 0.0)
			target_scale = 1.3
		"GOOD":
			judgment_label.modulate = Color(1.0, 1.0, 1.0)
			target_scale = 1.1
		"MISS":
			judgment_label.modulate = Color(1.0, 0.2, 0.2)
			target_scale = 1.0

	var tween = create_tween()
	judgment_label.scale = Vector2(1,1)
	tween.tween_property(judgment_label, "scale", Vector2(target_scale, target_scale), 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(0.2)
	tween.tween_property(judgment_label, "modulate:a", 0.0, 0.3)

func reset_combo():
	combo = 0
	update_ui("MISS")

func get_smooth_time() -> float:
	return music_player.get_playback_position() + AudioServer.get_time_since_last_mix() - AudioServer.get_output_latency()

func load_beatmap(filepath):
	var data = []
	var last_added_time = -1.0
	if FileAccess.file_exists(filepath):
		var file = FileAccess.open(filepath, FileAccess.READ)
		while !file.eof_reached():
			var line = file.get_line()
			if line != "":
				var parts = line.split("\t")
				if parts.size() >= 2:
					var c_time = float(parts[0])
					if c_time > last_added_time + ghost_filter_gap:
						var label = parts[parts.size()-1].strip_edges()
						var type = "Don"
						if label == "B": type = "Ka" if randf() > 0.7 else "Don"
						else: type = label
						data.append([c_time, type])
						last_added_time = c_time
	return data

# This function must be connected via the Editor's Node tab
func _on_start_pressed() -> void:
	begin_countdown()


func _on_quit_pressed() -> void:
	get_tree().quit()
