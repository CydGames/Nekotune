extends Sprite3D

var target_time: float = 0.0
var scroll_speed: float = 0.0
var hit_zone_x: float = 0.0
var spawn_y: float = 0.0
var note_type: String = "Don"

@onready var music_player = get_parent().get_node("MusicPlayer")

func _ready():
	if note_type == "Ka":
		modulate = Color(0, 0.6, 1) # Blue
	else:
		modulate = Color(1, 0.2, 0.2) # Red
	update_position()

func _process(_delta):
	update_position()
	
	# Auto-Miss Logic
	if get_smooth_time() > target_time + 0.2:
		if is_in_group("notes"):
			get_parent().reset_combo()
			remove_from_group("notes")
		queue_free()

func update_position():
	if !music_player: return
	var distance_to_hit = (target_time - get_smooth_time()) * scroll_speed
	position.x = hit_zone_x + distance_to_hit
	position.y = spawn_y
	position.z = 0

func get_smooth_time() -> float:
	return music_player.get_playback_position() + AudioServer.get_time_since_last_mix() - AudioServer.get_output_latency()
