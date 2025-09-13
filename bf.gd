extends Node2D

var texture: Texture2D
var animations := {}  # animation_name → Array[Rect2]
var current_animation := "idle_dance"
var current_frame := 0
var frame_time := 0
var time_accumulator := 0.0

func _ready():
	texture = load("res://assets/images/Player_Assets.png")
	var xml = XMLParser.new()

	if xml.open("res://assets/images/Player_Assets.xml") != OK:
		push_error("Failed to open XML file")
		return

	# Initialize animation arrays
	animations["idle_dance"] = []
	animations["note_up"] = []
	animations["note_down"] = []
	animations["note_left"] = []
	animations["note_right"] = []

	# Parse XML and extract frames
	while xml.read() == OK:
		if xml.get_node_type() != XMLParser.NODE_ELEMENT:
			continue

		if xml.get_node_name() == "SubTexture":
			var frame_name := ""
			var x := 0
			var y := 0
			var width := 0
			var height := 0

			for i in xml.get_attribute_count():
				var attr_name = xml.get_attribute_name(i)
				var attr_value = xml.get_attribute_value(i)

				match attr_name:
					"name":
						frame_name = attr_value
					"x":
						x = int(attr_value)
					"y":
						y = int(attr_value)
					"width":
						width = int(attr_value)
					"height":
						height = int(attr_value)

			# Add idle frames
			if frame_name.begins_with("BF idle dance instance 1"):
				var frame_number = frame_name.substr(frame_name.length() - 4, 4).to_int()
				if frame_number >= 0 and frame_number <= 13:
					animations["idle_dance"].append(Rect2(x, y, width, height))

			# Add directional note frames (excluding MISS)
			elif frame_name.begins_with("BF NOTE") and not frame_name.contains("MISS"):
				var frame_number = frame_name.substr(frame_name.length() - 4, 4).to_int()
				if frame_number >= 0 and frame_number <= 13:
					if frame_name.contains("UP"):
						animations["note_up"].append(Rect2(x, y, width, height))
					elif frame_name.contains("DOWN"):
						animations["note_down"].append(Rect2(x, y, width, height))
					elif frame_name.contains("LEFT"):
						animations["note_left"].append(Rect2(x, y, width, height))
					elif frame_name.contains("RIGHT"):
						animations["note_right"].append(Rect2(x, y, width, height))

	queue_redraw()

func _process(delta):
	time_accumulator += delta
	if time_accumulator >= frame_time:
		time_accumulator = 0.0
		current_frame += 1

		var frames = animations.get(current_animation, [])
		if current_frame >= frames.size():
			current_frame = 0  # loop animation

		queue_redraw()

	# Input check every frame
	if Input.is_action_pressed("ui_up"):
		if current_animation != "note_up":
			current_animation = "note_up"
			current_frame = 0
	elif Input.is_action_pressed("ui_down"):
		if current_animation != "note_down":
			current_animation = "note_down"
			current_frame = 0
	elif Input.is_action_pressed("ui_left"):
		if current_animation != "note_left":
			current_animation = "note_left"
			current_frame = 0
	elif Input.is_action_pressed("ui_right"):
		if current_animation != "note_right":
			current_animation = "note_right"
			current_frame = 0
	else:
		if current_animation != "idle_dance":
			current_animation = "idle_dance"
			current_frame = 0

func _draw():
	var frames = animations.get(current_animation, [])
	if texture and frames.size() > 0:
		var region = frames[current_frame]
		draw_texture_rect_region(texture, Rect2(Vector2.ZERO, region.size), region)
