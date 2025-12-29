@tool
## Popup window for adding new columns to the table.
class_name EditorNewLocaleWindow extends ConfirmationDialog

## Emitted when new locale code is submitted 
## (ie. when pressing "OK" button or Enter on keyboard)
signal locale_added(code: String)

var _line_edit: LineEdit

func _init() -> void:
	self.initial_position =\
			Window.WINDOW_INITIAL_POSITION_CENTER_MAIN_WINDOW_SCREEN
	self.oversampling_override = 1.0
	
	var _panel := PanelContainer.new()
	_panel.size = Vector2(184.0, 43.0)
	_panel.position = Vector2(8.0, 8.0)
	_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_panel)
	
	_line_edit = LineEdit.new()
	_line_edit.set_placeholder("Locale code (e.g. \"en\")")
	_panel.add_child(_line_edit)


func _ready() -> void:
	get_ok_button().pressed.connect(_on_text_submitted)
	
	_line_edit.text_submitted.connect(_on_text_submitted.unbind(1))
	_line_edit.grab_focus.call_deferred()


func _on_text_submitted() -> void:
	locale_added.emit(_line_edit.get_text())
