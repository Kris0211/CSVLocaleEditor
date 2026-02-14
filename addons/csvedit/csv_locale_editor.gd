@tool
## Main screen for the CSV Locale Editor
class_name EditorCSVLocaleScreen extends PanelContainer

## Emitted when a save operation has been finished for any reason.
signal save_finished(success: bool)

const _CURRENT_EDIT_TEXT: String = "Currently open: "
const _DATA_DIR: String = "res://"

const KEY_COLUMN_INDEX: int = 1

## CSV delimiter used by the editor.
static var DELIM: String = ProjectSettings.get_setting(
	EditorTranslationsPlugin.SETTINGS_PREFIX + "csv_delimiter",
	","
)

#region PRIVATE
# Dirty flag.
var _dirty: bool = false:
	set(value):
		_dirty = value
		if !_current_edit_label.text.ends_with(" (*)"):
			_current_edit_label.text += " (*)"

var _popup: EditorNewLocaleWindow
var _header_data: PackedStringArray

var _save_shortcut := Shortcut.new()

# Any methods prefixed with two underscores are for UndoRedo calls ONLY.
var __ur: EditorUndoRedoManager
#endregion

#region ONREADY
@onready var _create_button := %CreateButton as Button
@onready var _load_button := %LoadButton as Button
@onready var _save_button := %SaveButton as Button

@onready var _current_edit_label := %CurrentEditLabel as Label

@onready var _search_bar := %SearchBar as LineEdit

@onready var _word_wrap_toggle := %WordWrapToggle as CheckButton

@onready var _new_code_button := %AddLocaleButton as Button
@onready var _new_entry_button := %AddNewEntryButton as Button

@onready var _entries_container := %EntriesContainer as VBoxContainer
@onready var _code_labels_container := %CodeLabelsContainer as HBoxContainer

@onready var _header_scroll := %HeaderScrollContainer as ScrollContainer
@onready var _body_scroll := %BodyScrollContainer as ScrollContainer
#endregion

#region ENGINE_CALLBACKS
func _ready() -> void:
	# Setup shortcut
	var key_event = InputEventKey.new()
	key_event.keycode = KEY_S
	key_event.ctrl_pressed = true
	key_event.command_or_control_autoremap = true
	_save_shortcut.events = [key_event]
	
	# Setup signal connections
	_create_button.pressed.connect(_on_create_pressed)
	_load_button.pressed.connect(_on_load_pressed)
	_save_button.pressed.connect(_on_save_pressed)
	_search_bar.text_changed.connect(_on_search_performed)
	_word_wrap_toggle.toggled.connect(_on_word_wrap_toggled)
	_new_code_button.pressed.connect(_on_add_locale_button_pressed)
	_new_entry_button.pressed.connect(_on_new_entry_pressed)
	_header_scroll.get_h_scroll_bar().value_changed.connect(_on_header_h_scroll)
	_body_scroll.get_h_scroll_bar().value_changed.connect(_on_body_h_scroll)


func _exit_tree() -> void:
	if !_create_button.pressed.is_connected(_on_create_pressed):
		# If one is connected, all the other signals should be too.
		# I COULD check every single one, but that'd be a lot of extra code.
		return
	
	_create_button.pressed.disconnect(_on_create_pressed)
	_load_button.pressed.disconnect(_on_load_pressed)
	_save_button.pressed.disconnect(_on_save_pressed)
	_word_wrap_toggle.toggled.disconnect(_on_word_wrap_toggled)
	_search_bar.text_changed.disconnect(_on_search_performed)
	_new_code_button.pressed.disconnect(_on_add_locale_button_pressed)
	_new_entry_button.pressed.disconnect(_on_new_entry_pressed)
	_header_scroll.get_h_scroll_bar().value_changed.disconnect(_on_header_h_scroll)
	_body_scroll.get_h_scroll_bar().value_changed.disconnect(_on_body_h_scroll)


func _shortcut_input(event: InputEvent) -> void:
	# Accept shortcuts only when in csvedit view
	if is_visible_in_tree() \
			&& _save_shortcut.matches_event(event) \
			&& event.is_pressed() \
			&& !event.is_echo() \
			&& !_header_data.is_empty(): # empty header data = no file edited
		_on_save_pressed()
		accept_event()
		get_viewport().set_input_as_handled()
#endregion

#region API
## Adds a reference to the [EditorUndoRedoManager]. Called by plugin script.
func add_undo_redo(p_manager: EditorUndoRedoManager) -> void:
	if __ur == null:
		__ur = p_manager


## Called by plugin script when user clicks on CSV in the FileSystem dock.
func request_csv_edit(p_path: String) -> void:
	if p_path.is_empty():
		return
	
	_on_load_pressed(p_path)


## Updates layout whenever settings inside [ProjectSettings] are changed.
func reload_editor_layout() -> void:
	DELIM = ProjectSettings.get_setting(
		EditorTranslationsPlugin.SETTINGS_PREFIX + "csv_delimiter"
	)
	
	if DELIM == "\"":
		printerr("TranslationsEditor: Invalid delimiter! Reverting to default.")
		ProjectSettings.set_setting(
			EditorTranslationsPlugin.SETTINGS_PREFIX + "csv_delimiter", ","
		)
		DELIM = ","
	
	for e: Node in _entries_container.get_children():
		var _entry := e as EditorLocaleEntry
		if _entry:
			_entry.refresh_layout()
	
	for l: Node in _code_labels_container.get_children():
		var _label := l as EditorCodeLabel
		if _label:
			var width = \
				ProjectSettings.get_setting(
					EditorTranslationsPlugin.SETTINGS_PREFIX + "key_column_width"
				) \
				if _label.get_index() == KEY_COLUMN_INDEX else \
				ProjectSettings.get_setting(
					EditorTranslationsPlugin.SETTINGS_PREFIX + "entry_width"
				)
			
			_label.set_custom_size(Vector2(width, 40.0))
#endregion

#region EDITOR_SCREEN
func _populate_editor(p_locale_table: EditorLocaleTable) -> void:
	_clear_editor()
	_new_code_button.set_disabled(false)
	_save_button.set_disabled(false)
	
	_header_data = p_locale_table.header_data
	for code: String in _header_data:
		_create_column(code)
	
	for entry: PackedStringArray in p_locale_table.entries:
		_create_entry(_header_data, entry)


func _clear_editor() -> void:
	__ur.clear_history()
	__ur.create_action("Load new CSV table")
	__ur.commit_action()
	
	for c: Node in _code_labels_container.get_children():
		if c is EditorCodeLabel:
			c.free()
	
	for entry: Node in _entries_container.get_children():
		entry.free()
	
	_new_code_button.set_disabled(true)
	_new_entry_button.set_visible(false)


func _on_create_pressed() -> void:
	if _dirty:
		var _popup := _show_question_popup("Save current table?")
		_popup.confirmed.connect((func() -> void:
			_save_and_create.call_deferred()),
			CONNECT_ONE_SHOT
		)
		_popup.canceled.connect((func() -> void:
			_create_new_table()),
			CONNECT_ONE_SHOT
		)
	else:
		_create_new_table()


func _create_new_table() -> void:
	var _locale_data := EditorLocaleTable.create(
		PackedStringArray(["key"]),
		[PackedStringArray([""])]
	)
	_populate_editor(_locale_data)
	_new_entry_button.set_visible(true)
	_current_edit_label.set_visible(true)
	_current_edit_label.set_text(_CURRENT_EDIT_TEXT + "<unsaved>")
	_dirty = true


func _save_and_create() -> void:
	# Wait one frame to ensure previous popup has been freed.
	await get_tree().process_frame 
	_on_save_pressed()
	_create_new_table()


func _on_cell_edited(p_entry: EditorLocaleEntry, p_column_index: int,
		p_old_value: String, p_new_value: String) -> void:
	var _tedit := p_entry.get_cell(p_column_index)
	__ur.create_action("Edit translation")
	__ur.add_do_property(_tedit, &"text", p_new_value)
	__ur.add_undo_property(_tedit, &"text", p_old_value)
	__ur.commit_action()
	
	_dirty = true
#endregion

#region SEARCH
func _on_search_performed(p_query: String) -> void:
	if p_query.is_empty():
		_show_all_entries()
		return
	
	for e: Node in _entries_container.get_children():
		var _entry := e as EditorLocaleEntry
		if _entry == null:
			continue
		
		var _visibility := false
		for text: String in _entry.get_row_data():
			if text.contains(p_query):
				_visibility = true
				break
		
		if _entry.visible != _visibility:
			_entry.set_visible(_visibility)


func _show_all_entries() -> void:
	for e: Node in _entries_container.get_children():
		var _entry := e as EditorLocaleEntry
		if _entry:
			_entry.set_visible(true)
#endregion

#region WORD WRAP
func _on_word_wrap_toggled(p_toggled: bool) -> void:
	for e: Node in _entries_container.get_children():
		var _entry := e as EditorLocaleEntry
		if _entry:
			_entry.toggle_word_wrap(p_toggled)
#endregion

#region SCROLL
func _on_body_h_scroll(p_value: float) -> void:
	_header_scroll.scroll_horizontal = p_value


func _on_header_h_scroll(p_value: float) -> void:
	_body_scroll.scroll_horizontal = p_value
#endregion

#region ROWS
func _on_new_entry_pressed() -> void:
	var index := _entries_container.get_child_count()
	
	__ur.create_action("Add Row")
	__ur.add_do_method(self, &"_create_entry", _header_data, 
		PackedStringArray(), index)
	__ur.add_undo_method(self, &"__handle_remove_entry_impl", index)
	__ur.commit_action()
	
	_dirty = true


func _create_entry(p_codes: PackedStringArray = _header_data, 
		p_entry_data := PackedStringArray(), index: int = -1) -> void:
	var _locale_entry := EditorLocaleEntry.create(p_codes, p_entry_data)
	_entries_container.add_child(_locale_entry)
	if index != -1:
		_entries_container.move_child(_locale_entry, index)
	else:
		_dirty = true
	
	_locale_entry.delete_requested.connect(_remove_entry)
	_locale_entry.cell_edit_committed.connect(_on_cell_edited)


func _remove_entry(p_entry: EditorLocaleEntry) -> void:
	var _popup := _show_confirm_popup(
		"Delete row for key '%s'?" % p_entry.get_key_text()
	)
	_popup.confirmed.connect(_handle_remove_entry.bind(p_entry.get_index()))


func _handle_remove_entry(p_index: int) -> void:
	var _entry := _entries_container.get_child(p_index) as EditorLocaleEntry
	if _entry == null:
		return
	
	var row_data := _entry.get_row_data()
	var codes := _header_data.duplicate()
	
	__ur.create_action("Delete Row")
	__ur.add_do_method(self, &"__handle_remove_entry_impl", p_index)
	__ur.add_undo_method(self, &"_create_entry", codes, row_data, p_index)
	__ur.commit_action()
	
	_dirty = true


func __handle_remove_entry_impl(p_index: int) -> void:
	var _entry := _entries_container.get_child(p_index) as EditorLocaleEntry
	if _entry:
		_entry.queue_free()
#endregion

#region COLUMN
func _on_add_locale_button_pressed() -> void:
	_popup = EditorNewLocaleWindow.new()
	EditorInterface.get_base_control().add_child(_popup)
	_popup.locale_added.connect(_add_new_locale_code)
	_popup.get_cancel_button().pressed.connect(_destroy_popup_window)
	_popup.popup_centered.call_deferred()


func _add_new_locale_code(p_code: String) -> void:
	var index: int = _header_data.size()
	__ur.create_action("Add Locale")
	__ur.add_do_method(self, &"__add_new_locale_impl", p_code, index)
	__ur.add_undo_method(self, &"__handle_column_delete_impl", index + 1)
	__ur.commit_action()


func __add_new_locale_impl(p_code: String, p_index: int) -> void:
	_header_data.insert(p_index, p_code)
	_create_column(p_code, p_index)
	for e: Node in _entries_container.get_children():
		var _entry := e as EditorLocaleEntry
		if _entry:
			_entry.on_locale_added(p_code)
	
	_dirty = true
	if _popup:
		_destroy_popup_window()


func _create_column(p_code: String, p_index: int = -1) -> void:
	var _label := EditorCodeLabel.new()
	_code_labels_container.add_child(_label)
	if p_index != -1:
		# Start from 1 since child(0) is a Button
		_code_labels_container.move_child(_label, p_index + 1)
	
	var _label_index := _label.get_index()
	# Disable deletion of "key" label.
	_label.button.set_disabled(_label_index == KEY_COLUMN_INDEX)
	
	var _width = \
			ProjectSettings.get_setting(
				EditorTranslationsPlugin.SETTINGS_PREFIX + "key_column_width" \
				if _label_index == KEY_COLUMN_INDEX \
				else EditorTranslationsPlugin.SETTINGS_PREFIX + "entry_width"
			)
	
	_label.set_custom_size(Vector2(_width, 40.0))
	_label.set_text(p_code)
	
	_label.line_edit.text_submitted.connect(
		_on_code_changed.bind(_label).unbind(1)
	)
	_label.line_edit.focus_exited.connect(_on_code_changed.bind(_label))
	_label.delete_requested.connect(_delete_column)
	
	_dirty = true


func _delete_column(p_code_label: EditorCodeLabel) -> void:
	var _popup := _show_confirm_popup(
		"Delete locale '%s'?" % p_code_label.get_text()
	)
	_popup.confirmed.connect(
		_handle_column_delete.bind(p_code_label.get_index())
	)


func _handle_column_delete(p_index: int) -> void:
	var array_index: int = p_index - 1 # account for Button
	var code: String = _header_data.get(array_index)
	var values: PackedStringArray = _get_column_data(array_index)
	__ur.create_action("Delete Locale")
	__ur.add_do_method(self, &"__handle_column_delete_impl", p_index)
	__ur.add_undo_method(self, &"__restore_column", array_index, code, values)
	__ur.commit_action()
	
	_dirty = true


func __handle_column_delete_impl(p_index: int) -> void:
	var array_index: int = p_index - 1 # account for Button
	var code: String = _header_data[array_index]
	
	_header_data.remove_at(array_index)
	_code_labels_container.get_child(p_index).queue_free()
	for e: Node in _entries_container.get_children():
		var _entry := e as EditorLocaleEntry
		if _entry:
			_entry.on_locale_removed(p_index)
			_entry.on_locale_updated(_header_data)


func __restore_column(p_index: int, p_code: String, 
		p_values: PackedStringArray) -> void:
	_header_data.insert(p_index, p_code)
	_create_column(p_code, p_index)
	
	var i: int = 0
	for e: Node in _entries_container.get_children():
		var entry := e as EditorLocaleEntry
		if entry:
			entry.on_locale_added(p_code)
			entry.set_cell_text(p_index, p_values[i])
			i += 1


func _get_column_data(p_index: int) -> PackedStringArray:
	var data := PackedStringArray()
	for e: Node in _entries_container.get_children():
		var _entry := e as EditorLocaleEntry
		if _entry:
			data.append(_entry.get_cell(p_index).get_text())
	
	return data


func _on_code_changed(p_code_label: EditorCodeLabel) -> void:
	var index: int = p_code_label.get_index() - 1
	var old_value: String = _header_data[index]
	var new_value: String = p_code_label.line_edit.get_text()
	
	if old_value != new_value:
		_on_code_label_edited(p_code_label, old_value, new_value)


func _on_code_label_edited(p_label: EditorCodeLabel, 
		p_old_value: String, p_new_value: String) -> void:
	__ur.create_action("Edit Locale Code")
	__ur.add_do_property(p_label.line_edit, &"text", p_new_value)
	__ur.add_undo_property(p_label.line_edit, &"text", p_old_value)
	# Offset label index to ignore button (first child)
	__ur.add_do_method(self, &"__update_header_data", 
		p_label.get_index() - 1, p_new_value)
	__ur.add_undo_method(self, &"__update_header_data", 
		p_label.get_index() - 1, p_old_value)
	__ur.commit_action()
	
	_dirty = true


func __update_header_data(p_index: int, p_value: String) -> void:
	_header_data.set(p_index, p_value)
	for e in _entries_container.get_children():
		var entry := e as EditorLocaleEntry
		if entry:
			entry.on_locale_updated(_header_data)
#endregion

#region LOADING
func _on_load_pressed(p_path: String = "") -> void:
	if !_dirty:
		_handle_load_request(p_path)
		return
		
	var _popup := _show_question_popup("Save current table?")
	_popup.confirmed.connect(
		(func() -> void:
			_on_save_pressed()
			save_finished.connect(
				(func(success: bool):
					if success:
						_handle_load_request(p_path)), 
				CONNECT_ONE_SHOT)
			),
	CONNECT_ONE_SHOT)
	
	_popup.canceled.connect(func() -> void:
		_handle_load_request(p_path),
		CONNECT_ONE_SHOT
	)
	
	_popup.custom_action.connect(
		(func(action: String):
			if action == "cancel_all":
				return), 
	CONNECT_ONE_SHOT)


func _handle_load_request(p_path: String = "") -> void:
	if p_path.is_empty():
		var _file_dialog := _show_file_dialog(
			_DATA_DIR,
			PackedStringArray(["*.csv ; CSV Translation File"]),
			EditorFileDialog.FILE_MODE_OPEN_FILE
		)
		_file_dialog.file_selected.connect(_load_csv, CONNECT_ONE_SHOT)
	else:
		_load_csv(p_path)


func _load_csv(p_path: String) -> Error:
	var _file = FileAccess.open(p_path, FileAccess.READ)
	if _file == null:
		var _err: Error = _file.get_open_error()
		printerr("Failed to save file: ", error_string(_err))
		return _err
	
	var _locale_table := ResourceLoader.load(p_path, "", 
			ResourceLoader.CACHE_MODE_IGNORE) as EditorLocaleTable
	_populate_editor(_locale_table)
	
	_file.close()
	_dirty = false
	_new_entry_button.visible = true
	_current_edit_label.visible = true
	_current_edit_label.set_text(_CURRENT_EDIT_TEXT + p_path.get_file())
	
	return Error.OK
#endregion

#region SAVING
func _on_save_pressed() -> void:
	var _file_dialog := _show_file_dialog(
		_DATA_DIR,
		PackedStringArray(["*.csv ; CSV Translation File"]),
		EditorFileDialog.FILE_MODE_SAVE_FILE
	)
	_file_dialog.file_selected.connect(_save_csv, CONNECT_ONE_SHOT)
	_file_dialog.canceled.connect(
		(func() -> void:
			save_finished.emit(false))
	)

func _save_csv(p_path: String) -> Error:
	var _file = FileAccess.open(p_path, FileAccess.WRITE)
	if _file == null:
		var _err: Error = _file.get_open_error()
		printerr("Failed to save file: ", error_string(_err))
		save_finished.emit(false)
		return _err
	
	_file.store_csv_line(_header_data)
	for e: Node in _entries_container.get_children():
		var _entry := e as EditorLocaleEntry
		if _entry:
			_file.store_csv_line(_entry.get_row_data(), DELIM)
	
	_file.close()
	_dirty = false
	save_finished.emit(true)
	
	return Error.OK
#endregion

#region POPUPS
func _show_confirm_popup(p_message: String, 
		p_label: String = "Translations Editor") -> ConfirmationDialog:
	var popup_window := ConfirmationDialog.new()
	
	popup_window.set_hide_on_ok(false)
	popup_window.set_initial_position(
			Window.WINDOW_INITIAL_POSITION_CENTER_SCREEN_WITH_MOUSE_FOCUS)
	popup_window.set_title(p_label)
	popup_window.set_text(p_message)
	
	popup_window.confirmed.connect(
		(func() -> void: 
			popup_window.queue_free())
	)
	popup_window.canceled.connect(
		(func() -> void: 
			popup_window.queue_free())
	)
	
	EditorInterface.get_base_control().add_child(popup_window)
	popup_window.popup.call_deferred()
	
	return popup_window


func _show_question_popup(p_message: String, 
		p_label: String = "Translations Editor") -> ConfirmationDialog:
	var popup_window := ConfirmationDialog.new()
	
	popup_window.set_hide_on_ok(false)
	popup_window.set_initial_position(
			Window.WINDOW_INITIAL_POSITION_CENTER_SCREEN_WITH_MOUSE_FOCUS)
	popup_window.set_title(p_label)
	popup_window.set_text(p_message)
	
	popup_window.get_ok_button().set_text("Save")
	popup_window.get_cancel_button().set_text("Discard")
	popup_window.add_button("Cancel", true, "cancel_all")
	
	popup_window.confirmed.connect(
		(func() -> void: 
			popup_window.queue_free())
	)
	popup_window.canceled.connect(
		(func() -> void: 
			popup_window.queue_free())
	)
	popup_window.custom_action.connect(
		(func(action: String) -> void:
			if action == "cancel_all":
				popup_window.queue_free())
	)
	
	EditorInterface.get_base_control().add_child(popup_window)
	popup_window.popup.call_deferred()
	
	return popup_window


func _show_file_dialog(
	p_dir: String, 
	p_filters := PackedStringArray(),
	p_file_mode := EditorFileDialog.FILE_MODE_OPEN_FILE
) -> EditorFileDialog:
	var file_dialog := EditorFileDialog.new()
	
	file_dialog.set_access(EditorFileDialog.ACCESS_RESOURCES)
	file_dialog.set_initial_position(
			Window.WINDOW_INITIAL_POSITION_CENTER_SCREEN_WITH_MOUSE_FOCUS)
	file_dialog.set_size(Vector2i(1200, 800))
	file_dialog.set_current_dir(p_dir)
	file_dialog.set_filters(p_filters)
	file_dialog.set_file_mode(p_file_mode)
	
	file_dialog.close_requested.connect(
		(func() -> void: file_dialog.queue_free()), 
		CONNECT_ONE_SHOT
	)
	
	EditorInterface.get_base_control().add_child(file_dialog)
	file_dialog.popup.call_deferred()
	
	return file_dialog


func _destroy_popup_window() -> void:
	_popup.hide()
	_popup.queue_free()
	_popup = null
#endregion
