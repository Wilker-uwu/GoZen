class_name DataManager extends Node


func save_data(a_path: String) -> int:
	var l_file: FileAccess = FileAccess.open(a_path, FileAccess.WRITE)
	if FileAccess.get_open_error():
		return ERR_FILE_CANT_OPEN
	var l_data: Dictionary = {}
	for l_property: Dictionary in get_property_list():
		var l_usage: int = l_property.usage
		var l_name: String = l_property.name
		if ((l_usage == 4096 || l_usage == 4102) && l_name[0] != '_'):
			l_data[l_name] = get(l_name)
	l_file.store_string(var_to_str(l_data))
	if l_file.get_error() != 0:
		return l_file.get_error()
	l_file.close()
	return OK


func load_data(a_path: String) -> int:
	if (FileAccess.file_exists(a_path)):
		var l_file: FileAccess = FileAccess.open(a_path, FileAccess.READ)
		if FileAccess.get_open_error():
			return ERR_FILE_CANT_OPEN
		var l_data: Dictionary = str_to_var(l_file.get_as_text())
		for l_key: String in l_data.keys():
			set(l_key, l_data[l_key])
		if l_file.get_error() != 0:
			return l_file.get_error()
		l_file.close()
		return OK
	return ERR_FILE_NOT_FOUND
