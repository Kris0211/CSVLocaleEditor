## A button that can detect RMB click and shift-click
class_name SmartUIButton extends Button

signal shift_left_pressed
signal right_pressed

func _gui_input(event: InputEvent) -> void:
	var _ev := event as InputEventMouseButton
	if !_ev || _ev.is_echo() || !_ev.is_released():
		return
	
	accept_event()
	match _ev.button_index:
		MOUSE_BUTTON_LEFT:
			if _ev.shift_pressed:
				shift_left_pressed.emit()
		MOUSE_BUTTON_RIGHT:
			right_pressed.emit()
