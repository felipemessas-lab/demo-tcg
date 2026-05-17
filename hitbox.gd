extends Area2D

signal clicked

func _input_event(_viewport, event, _shape_idx) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		print("hitbox click!")
		emit_signal("clicked")
