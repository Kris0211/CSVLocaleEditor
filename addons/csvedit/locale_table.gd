## CSV as imported Resource. 
## Used internally by this tool's [ResourceLoader].
@tool
class_name EditorLocaleTable extends Resource

## Header data, corresponding to first line inside CSV file
@export_storage var header_data: PackedStringArray
## Remaining content of the CSV file as an [Array] of [PackedStringArray]s.
@export_storage var entries: Array[PackedStringArray]

## Creates and returns a new instance of [EditorLocaleTable].
static func create(p_header_data: PackedStringArray, 
		p_entries: Array[PackedStringArray]) -> EditorLocaleTable:
	var this := EditorLocaleTable.new()
	this.header_data = p_header_data
	this.entries = p_entries
	return this
