@tool
class_name EditorTranslationsPlugin extends EditorPlugin

const PLUGIN_NAME := "Translations"
#const PLUGIN_ICON := null
const SETTINGS_PREFIX := "addons/translations_plugin/"
const MAIN_PANEL := preload("res://addons/csvedit/csv_locale_editor.tscn")

var _main_panel_instance: EditorCSVLocaleScreen = null


func _enter_tree() -> void:
	_main_panel_instance = MAIN_PANEL.instantiate() as EditorCSVLocaleScreen
	if _main_panel_instance == null:
		printerr("Failed to enable plugin '%s'" % PLUGIN_NAME)
		return
	
	EditorInterface.get_editor_main_screen().add_child(_main_panel_instance)
	_make_visible(false)
	
	_register_settings()
	ProjectSettings.settings_changed.connect(_on_settings_changed)
	
	_main_panel_instance.add_undo_redo(get_undo_redo())


func _exit_tree():
	if _main_panel_instance:
		_main_panel_instance.queue_free()
	
	# Uncomment only if you need to remove all settings.
	# (e.g. when removing plugin from project)
	#_clear_settings()


func _has_main_screen():
	return true


func _make_visible(visible: bool):
	if _main_panel_instance:
		_main_panel_instance.set_visible(visible)


func _get_plugin_name():
	return PLUGIN_NAME


func _get_plugin_icon():
	return EditorInterface.get_editor_theme()\
		.get_icon(&"Translation", &"EditorIcons")
	#return PLUGIN_ICON


func _handles(object: Object) -> bool:
	return object is EditorLocaleTable


func _edit(resource: Object) -> void:
	if resource is EditorLocaleTable:
		_make_visible(true)
		_main_panel_instance.request_csv_edit(resource.get_path())


#region PROJECT_SETTINGS
func _register_settings():
	_add_setting(
		"entry_width",
		150,
		TYPE_INT,
		PROPERTY_HINT_RANGE,
		"90,800,10"
	)
	
	_add_setting(
		"entry_height",
		80,
		TYPE_INT,
		PROPERTY_HINT_RANGE,
		"60,400,10"
	)
	
	_add_setting(
		"key_column_width",
		150,
		TYPE_INT,
		PROPERTY_HINT_RANGE,
		"80,800,10"
	)
	
	_add_setting(
		"csv_delimiter",
		",",
		TYPE_STRING
	)
	
	ProjectSettings.save()


func _add_setting(
	p_name: String, 
	p_default: Variant,
	p_type: Variant.Type,
	p_hint: PropertyHint = PROPERTY_HINT_NONE, 
	p_hint_string: String = ""
) -> void:
	var path := SETTINGS_PREFIX + p_name
	
	if !ProjectSettings.has_setting(path):
		ProjectSettings.set_setting(path, p_default)
		ProjectSettings.set_initial_value(path, p_default)
		ProjectSettings.set_as_basic(path, true)
	
	ProjectSettings.add_property_info({
		"name": path,
		"type": p_type,
		"hint": p_hint,
		"hint_string": p_hint_string
	})


func _clear_settings() -> void:
	ProjectSettings.clear(SETTINGS_PREFIX + "entry_width")
	ProjectSettings.clear(SETTINGS_PREFIX + "entry_height")
	ProjectSettings.clear(SETTINGS_PREFIX + "key_column_width")
	ProjectSettings.clear(SETTINGS_PREFIX + "csv_delimiter")
	ProjectSettings.save()


func _on_settings_changed():
	_main_panel_instance.reload_editor_layout()
#endregion
