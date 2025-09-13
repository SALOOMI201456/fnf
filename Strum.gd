extends Node2D

var atlas_texture: Texture2D
var frame_data: Dictionary = {}

var arrow_order: Array[String] = ["left", "down", "up", "right"] as Array[String]

var arrow_idle: Dictionary = {
	"left": "arrow static instance 10000",
	"down": "arrow static instance 20000",
	"up": "arrow static instance 40000",
	"right": "arrow static instance 30000"
} as Dictionary

var arrow_confirm: Dictionary = {
	"left": ["left press instance 10000", "left press instance 10001", "left press instance 10002", "left press instance 10003"] as Array[String],
	"down": ["down press instance 10000", "down press instance 10001", "down press instance 10002", "down press instance 10003"] as Array[String],
	"up": ["up press instance 10000", "up press instance 10001", "up press instance 10002", "up press instance 10003"] as Array[String],
	"right": ["right press instance 10000", "right press instance 10001", "right press instance 10002", "right press instance 10003"] as Array[String]
} as Dictionary

var current_frames: Dictionary = {
	"left": "arrow static instance 10000",
	"down": "arrow static instance 20000",
	"up": "arrow static instance 40000",
	"right": "arrow static instance 30000"
} as Dictionary

var spacing: int = 160

# Modchart data
var modchart_data: Dictionary = {}
var switch_events: Array = []
var current_switch: Dictionary = {}
var bpm: float = 120.0
var cur_step: int = 0

func _ready() -> void:
	atlas_texture = load("res://assets/images/NOTEStatic_assets.png")
	parse_xml("res://assets/images/NOTEStatic_assets.xml")
	load_modchart("res://assets/modchartBroken.json")
	set_process(true)
	queue_redraw()

func parse_xml(path: String) -> void:
	var xml: XMLParser = XMLParser.new()
	if xml.open(path) != OK:
		push_error("Failed to open XML file: " + path)
		return

	while xml.read() == OK:
		if xml.get_node_type() == XMLParser.NODE_ELEMENT and xml.get_node_name() == "SubTexture":
			var name_attr: String = xml.get_named_attribute_value("name")
			var x_attr: int = xml.get_named_attribute_value("x").to_int()
			var y_attr: int = xml.get_named_attribute_value("y").to_int()
			var w_attr: int = xml.get_named_attribute_value("width").to_int()
			var h_attr: int = xml.get_named_attribute_value("height").to_int()
			frame_data[name_attr] = Rect2(x_attr, y_attr, w_attr, h_attr)

func load_modchart(path: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Failed to open modchart JSON")
		return

	var text: String = file.get_as_text()
	var parsed: Variant = JSON.parse_string(text)

	if typeof(parsed) == TYPE_DICTIONARY and parsed.has("modchart"):
		modchart_data = parsed as Dictionary
		switch_events = modchart_data["modchart"].get("switches", []) as Array
		bpm = float(modchart_data["modchart"].get("bpm", 120))
	else:
		push_error("Modchart JSON is missing or malformed")

func _process(_delta: float) -> void:
	for dir: String in arrow_order:
		var action: String = "ui_" + dir
		if Input.is_action_pressed(action):
			var frames: Array[String] = arrow_confirm[dir]
			current_frames[dir] = frames[randi() % frames.size()]
		else:
			current_frames[dir] = arrow_idle[dir]

	cur_step = int((Time.get_ticks_msec() / 1000.0) * (bpm / 15.0))
	current_switch = {}
	for event in switch_events:
		if event.has("step") and int(event["step"]) == cur_step:
			current_switch = event
			break

	queue_redraw()

func _draw() -> void:
	for i: int in range(arrow_order.size()):
		var dir: String = arrow_order[i]
		var frame_name: String = current_frames[dir]
		if not frame_data.has(frame_name):
			continue

		var region: Rect2 = frame_data[frame_name]
		var base_x: float = position.x - (arrow_order.size() * spacing / 2.0) + float(i * spacing)
		var base_y: float = position.y
		var mod_x: float = base_x
		var mod_y: float = base_y

		if current_switch.has("tweens"):
			for tween in current_switch["tweens"]:
				if int(tween["index"]) == i + 4:
					if tween.has("formula"):
						mod_x = eval_formula(tween["formula"], base_x, base_y, cur_step)
					if tween.has("formula_y"):
						mod_y = eval_formula(tween["formula_y"], base_x, base_y, cur_step)
					break

		var draw_pos: Vector2 = Vector2(mod_x, mod_y)
		draw_texture_rect_region(
			atlas_texture,
			Rect2(draw_pos - region.size / 2.0, region.size),
			region
		)

func eval_formula(expr: String, base_x: float, base_y: float, beat: float) -> float:
	expr = expr.replace("base_x", str(base_x))
	expr = expr.replace("base_y", str(base_y))
	expr = expr.replace("beat", str(beat))
	expr = expr.replace("PI", str(PI))
	expr = expr.replace("TAU", str(TAU))
	expr = expr.replace("center_x", str(position.x))
	expr = expr.replace("center_y", str(position.y))
	var expression: Expression = Expression.new()
	if expression.parse(expr) != OK:
		push_warning("Failed to parse formula: " + expr)
		return base_x
	var result: Variant = expression.execute()
	if result == null:
		push_warning("Formula returned null: " + expr)
		return base_x
	return float(result)
