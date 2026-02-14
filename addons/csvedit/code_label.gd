@tool
class_name EditorCodeLabel extends PanelContainer

signal delete_requested(instance: EditorCodeLabel)
signal code_edited(instance: EditorCodeLabel, 
	old_value: String, new_value: String)

const _BUTTON_SIZE := Vector2(40.0, 40.0)

var line_edit: LineEdit
var button: Button 

var _previous_value: String


func _init() -> void:
	var _hbox := HBoxContainer.new()
	_hbox.add_theme_constant_override(&"separation", 0)
	add_child(_hbox)
	
	line_edit = LineEdit.new()
	line_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line_edit.custom_minimum_size = Vector2(80.0 - _BUTTON_SIZE.x, 40.0)
	_hbox.add_child(line_edit)
	
	button = Button.new()
	button.size_flags_horizontal = Control.SIZE_SHRINK_END
	button.custom_minimum_size = Vector2(20.0, 40.0)
	button.text = "X"
	button.flat = true
	_hbox.add_child(button)
	
	line_edit.focus_entered.connect(_on_focus_entered)
	line_edit.focus_exited.connect(_on_text_updated)
	line_edit.text_submitted.connect(_on_text_updated.unbind(1))


func _ready() -> void:
	var _stylebox := StyleBoxFlat.new()
	_stylebox.bg_color = Color("181818ff")
	add_theme_stylebox_override(&"panel", _stylebox)
	
	button.pressed.connect(request_deletion)


func _exit_tree() -> void:
	if button.pressed.is_connected(request_deletion):
		button.pressed.disconnect(request_deletion)


func request_deletion() -> void:
	delete_requested.emit(self)


func set_custom_size(p_size: Vector2) -> void:
	self.set_custom_minimum_size(p_size)
	line_edit.set_custom_minimum_size(p_size - _BUTTON_SIZE)


## Wrapper to get text directly from [LineEdit].
func get_text() -> String:
	return line_edit.text


## Wrapper to set text directly on [LineEdit].
func set_text(p_text: String) -> void:
	line_edit.text = p_text


func _on_focus_entered() -> void:
	_previous_value = line_edit.get_text()


func _on_text_updated() -> void:
	var new_value := line_edit.get_text()
	if new_value != _previous_value:
		code_edited.emit(self, _previous_value, new_value)
