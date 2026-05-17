extends Node2D
class_name FrameHero
#Frame mana
@onready var control: Control = $control
@onready var name_label: Label = $control/name
@onready var cost_label: Label = $control/cost
@onready var type_label: Label = $control/type
@onready var rules_label: Label = $control/rules
@onready var stats_label: Label = $control/stats

func apply_data(data: Dictionary) -> void:
	if name_label: name_label.text = str(data.get("name", ""))
	if cost_label: cost_label.text = str(data.get("cost", 0))
	if type_label: type_label.text = str(data.get("type", ""))
	if rules_label: rules_label.text = str(data.get("rules", ""))
	if stats_label:
		var a := int(data.get("atk", 0))
		var d := int(data.get("def", 0))
		stats_label.text = "%d/%d" % [a, d]

func set_frame_texture(path: String) -> void:
	if $FrameUI/Frame:
		$FrameUI/Frame.texture = load(path)
