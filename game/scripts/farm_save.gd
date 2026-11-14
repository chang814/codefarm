extends RefCounted
## Checksummed, staged writes. Keep the last verified save as recovery backup.
const FORMAT := 1
const MAX_BYTES := 8 * 1024 * 1024

static func read_file(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > MAX_BYTES:
		return {}
	var envelope = _parse(file.get_as_text())
	if not envelope is Dictionary or envelope.get("format") != FORMAT:
		return {}
	var payload = envelope.get("payload")
	if not payload is String or payload.sha256_text() != envelope.get("sha256"):
		return {}
	var data = _parse(payload)
	return data if data is Dictionary else {}

static func write_file(path: String, data: Dictionary) -> bool:
	var absolute := ProjectSettings.globalize_path(path)
	if DirAccess.make_dir_recursive_absolute(absolute.get_base_dir()) != OK:
		return false
	var payload := JSON.stringify(data)
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify({"format": FORMAT, "payload": payload, "sha256": payload.sha256_text()}))
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK or read_file(path + ".tmp").is_empty():
		return false
	# Copy rather than rename the old file: it remains intact until replacement.
	if not read_file(path).is_empty():
		if DirAccess.copy_absolute(absolute, absolute + ".bak") != OK:
			return false
	return DirAccess.rename_absolute(absolute + ".tmp", absolute) == OK

# JSON.parse_string logs an engine error on bad input; a damaged save is an
# expected case here, so parse quietly and let the caller fall back.
static func _parse(text: String) -> Variant:
	var json := JSON.new()
	return json.data if json.parse(text) == OK else null
