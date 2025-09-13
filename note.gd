extends Node2D

# Assets
var atlas_texture: Texture2D
var frame_data: Dictionary = {}

# Note directions
var arrow_order: Array[String] = ["left", "down", "up", "right"]
var note_frames: Dictionary = {
	"left": "pruiple0000",
	"down": "blueee0000",
	"up": "greennn0000",
	"right": "red0000"
} as Dictionary

# Layout
var spacing: int = 160
var scroll_speed: float = 0.6
var note_spawn_offset: float = 0.0  # Spawn instantly
var hit_window: float = 120.0

# Chart data
var chart_data: Dictionary = {}
var player_notes: Array = []
var active_notes: Array = []

func _ready() -> void:
	position = Vector2(640, 400)  # Strumline center
	atlas_texture = load("res://assets/images/NOTEColors_assets.png")
	parse_xml("res://assets/images/NOTEColors_assets.xml")
	load_chart("res://assets/data/chart.json")

	for key in note_frames.keys():
		if not frame_data.has(note_frames[key]):
			push_warning("Missing frame: " + note_frames[key])

	print("Total notes loaded:", player_notes.size())
	set_process(true)
	queue_redraw()

func parse_xml(path: String) -> void:
	var xml: XMLParser = XMLParser.new()
	if xml.open(path) != OK:
		push_error("Failed to open XML file")
		return

	while xml.read() == OK:
		if xml.get_node_type() == XMLParser.NODE_ELEMENT and xml.get_node_name() == "SubTexture":
			var frame_name: String = xml.get_named_attribute_value("name")
			var x: int = xml.get_named_attribute_value("x").to_int()
			var y: int = xml.get_named_attribute_value("y").to_int()
			var w: int = xml.get_named_attribute_value("width").to_int()
			var h: int = xml.get_named_attribute_value("height").to_int()
			frame_data[frame_name] = Rect2(x, y, w, h)

func load_chart(path: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Failed to open chart JSON")
		return

	var text: String = file.get_as_text()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY or not parsed.has("song"):
		push_error("Malformed chart JSON")
		return

	chart_data = parsed["song"]
	var sections: Array = chart_data.get("notes", []) as Array

	for section in sections:
		if section.get("mustHitSection", false):
			for note in section.get("sectionNotes", []):
				if typeof(note) != TYPE_ARRAY or note.size() < 3:
					continue
				var time: float = float(note[0])
				var dir: int = int(note[1])
				var sustain: float = float(note[2])
				player_notes.append({
					"time": time,
					"dir": dir,
					"sustain": sustain,
					"hit": false,
					"spawned": false
				})

func _process(_delta: float) -> void:
	var song_time: float = Time.get_ticks_msec()

	for note in player_notes:
		if not note["spawned"] and song_time >= note["time"] - note_spawn_offset:
			note["spawned"] = true
			active_notes.append(note)
			print("Spawned note:", note["dir"], "at", note["time"])

	for note in active_notes:
		if note["hit"]:
			continue
		var dir: String = arrow_order[note["dir"]]
		var action: String = "ui_" + dir
		var time_diff: float = abs(note["time"] - song_time)
		if time_diff <= hit_window and Input.is_action_just_pressed(action):
			note["hit"] = true
			print("Hit:", dir, "at", song_time)

	queue_redraw()

func _draw() -> void:
	var song_time: float = Time.get_ticks_msec()

	for note in active_notes:
		if note["hit"]:
			continue
		var dir_index: int = note["dir"]
		var dir: String = arrow_order[dir_index]
		var frame_name: String = note_frames[dir]
		if not frame_data.has(frame_name):
			continue

		var region: Rect2 = frame_data[frame_name]
		var time_until_hit: float = note["time"] - song_time
		var y_offset: float = clamp(time_until_hit * scroll_speed, -500, 500)

		# Explicit positioning
		var lane_x: float = position.x - (arrow_order.size() * spacing / 2.0) + float(dir_index * spacing)
		var lane_y: float = position.y + y_offset

		draw_texture_rect_region(
			atlas_texture,
			Rect2(Vector2(lane_x, lane_y) - region.size / 2.0, region.size),
			region
		)
