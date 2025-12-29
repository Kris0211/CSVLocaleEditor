@tool
## A loader for CSV files for tool's internal use.
class_name EditorLocaleTableLoader extends ResourceFormatLoader


func _get_recognized_extensions() -> PackedStringArray:
	return ["csv"]


func _handles_type(type: StringName) -> bool:
	return type == &"EditorLocaleTable"


func _get_resource_type(path: String) -> String:
	return "EditorLocaleTable"


func _load(path: String, original_path: String, 
		use_sub_threads: bool, cache_mode: int) -> Variant:
	var _file := FileAccess.open(path, FileAccess.READ)
	if _file == null:
		printerr("Failed to load file at path %s: %s" %\
				[path, error_string(_file.get_error())])
		return null
	
	var _header_data := _file.get_csv_line(EditorCSVLocaleScreen.DELIM)
	var _entries: Array[PackedStringArray] = []
	
	var _file_length = _file.get_length()
	while _file.get_position() < _file_length:
		var _line := _file.get_csv_line(EditorCSVLocaleScreen.DELIM)
		_entries.append(_line)
	
	return EditorLocaleTable.create(_header_data, _entries)
