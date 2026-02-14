@tool
class_name EditorLocaleEntry extends HBoxContainer

## Emitted when this [EditorLocaleEntry] should be deleted.
signal delete_requested(instance: EditorLocaleEntry)
## Emitted when any of the entry's [TextEdit] content has been modified.
signal cell_edit_committed(instance: EditorLocaleEntry, 
		column_index: int, old_value: String, new_value: String)

## Custom size for the LocaleEntry control.
var custom_size := Vector2(
	ProjectSettings.get_setting(
		EditorTranslationsPlugin.SETTINGS_PREFIX + "entry_width"
	),
	ProjectSettings.get_setting(
		EditorTranslationsPlugin.SETTINGS_PREFIX + "entry_height"
	)
)

var key_column_width: int = ProjectSettings.get_setting(
	EditorTranslationsPlugin.SETTINGS_PREFIX + "key_column_width"
)

var _row_data: PackedStringArray
var _delete_button: Button
var _last_edited_cell: TextEdit = null
var _last_edited_value: String
var _word_wrap_enabled: bool = true

## Creates and returns a new instance of [EditorLocaleEntry].
static func create(p_codes: PackedStringArray, 
		p_entries := PackedStringArray()) -> EditorLocaleEntry:
	
	var this := EditorLocaleEntry.new()
	
	var _button := Button.new()
	_button.text = "X"
	_button.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	
	this.add_child(_button)
	this._delete_button = _button
	this._delete_button.pressed.connect(this.request_deletion)
	
	this._row_data.resize(p_codes.size())
	
	for i: int in p_codes.size():
		var code: String = p_codes[i]
		var _tedit := TextEdit.new()
		_tedit.custom_minimum_size = this.custom_size
		this._apply_tedit_settings(_tedit, code, i == 0)
		this.add_child(_tedit)
		
		_tedit.focus_entered.connect(this._on_cell_focus_entered.bind(_tedit))
		_tedit.focus_exited.connect(this._on_cell_focus_exited.bind(_tedit))
	
	if !p_entries.is_empty():
		this._row_data = p_entries
		for i: int in p_entries.size():
			# offset by 1 since first child is Button
			var _tedit := this.get_child(i + 1) as TextEdit
			if _tedit:
				_tedit.set_text(p_entries[i])
	
	return this


func _exit_tree() -> void:
	if _delete_button.pressed.is_connected(request_deletion):
		_delete_button.pressed.disconnect(request_deletion)


## Emits the [signal delete_requested] signal.
func request_deletion() -> void:
	delete_requested.emit(self)


## Returns a reference to [TextEdit] located in [param index] column.
func get_cell(p_index: int) -> TextEdit:
	return get_child(p_index + 1) as TextEdit


## Returns the text inside "key" column.
func get_key_text() -> String:
	var _tedit := get_child(1) as TextEdit # child 0 is a button
	if _tedit:
		var _text := _tedit.get_text()
		if !_text.is_empty():
			return _text
	return "empty key"


## Returns a [PackedStringArray] where each element
## corresponds to a [TextEdit] cell in this row.
func get_row_data() -> PackedStringArray:
	return _row_data


## Sets text inside [TextEdit] cell.
func set_cell_text(p_index: int, p_value: String) -> void:
	var _tedit := get_child(p_index + 1)
	if _tedit:
		_tedit.set_text(p_value)
		_row_data[p_index] = p_value


## Callback for when a column is added.
func on_locale_added(p_code: String) -> void:
	var _tedit := TextEdit.new()
	_apply_tedit_settings(_tedit, p_code, false)
	add_child(_tedit)
	
	_tedit.focus_entered.connect(_on_cell_focus_entered.bind(_tedit))
	_tedit.focus_exited.connect(_on_cell_focus_exited.bind(_tedit))
	
	_row_data.append("")


## Callback for when a column is removed.
func on_locale_removed(p_index: int) -> void:
	# don't offset - index already includes Button
	var _tedit := get_child(p_index) as TextEdit
	if _tedit:
		_tedit.queue_free()
	
	_row_data.remove_at(p_index - 1)


## Callback for when a column is renamed.
func on_locale_updated(p_codes: PackedStringArray) -> void:
	for i: int in p_codes.size():
		# offset by 1 since first child is Button
		var _tedit := get_child(i + 1) as TextEdit
		if _tedit:
			_tedit.set_placeholder(p_codes[i])


## Toggles the word wrap for all [TextEdit]s.
func toggle_word_wrap(p_enabled: bool) -> void:
	_word_wrap_enabled = p_enabled
	for i: int in range(1, get_child_count()):
		var _tedit := get_child(i) as TextEdit
		if _tedit:
			_tedit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY \
					if _word_wrap_enabled else TextEdit.LINE_WRAPPING_NONE


## Refreshes the cell layout to match new settings 
## (as denoted in [ProjectSettings]).
func refresh_layout() -> void:
	custom_size = Vector2(
		ProjectSettings.get_setting(
			EditorTranslationsPlugin.SETTINGS_PREFIX + "entry_width"
		),
		ProjectSettings.get_setting(
			EditorTranslationsPlugin.SETTINGS_PREFIX + "entry_height"
		)
	)
	
	key_column_width = ProjectSettings.get_setting(
		EditorTranslationsPlugin.SETTINGS_PREFIX + "key_column_width"
	)
	
	for i: int in get_child_count():
		var _tedit := get_child(i) as TextEdit
		if _tedit:
			# button is at 0, first tedit (key) is at 1
			_apply_tedit_settings(_tedit, _tedit.placeholder_text, i == 1)


func _apply_tedit_settings(p_tedit: TextEdit, p_placeholder: String, 
		p_is_key: bool = false) -> void:
	p_tedit.placeholder_text = p_placeholder
	p_tedit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY \
			if _word_wrap_enabled else TextEdit.LINE_WRAPPING_NONE
	p_tedit.custom_minimum_size.y = custom_size.y
	if p_is_key:
		p_tedit.custom_minimum_size.x = key_column_width
	else:
		p_tedit.custom_minimum_size.x = custom_size.x


func _on_cell_focus_entered(p_tedit: TextEdit) -> void:
	_last_edited_cell = p_tedit
	_last_edited_value = p_tedit.get_text()


func _on_cell_focus_exited(p_tedit: TextEdit) -> void:
	if p_tedit != _last_edited_cell:
		return
	
	var old_value: String = _last_edited_value
	var new_value: String = p_tedit.get_text()
	
	_last_edited_cell = null
	
	if old_value == new_value:
		return
	
	var column_index: int = p_tedit.get_index() - 1
	_row_data[column_index] = new_value
	cell_edit_committed.emit(self, column_index, old_value, new_value)
