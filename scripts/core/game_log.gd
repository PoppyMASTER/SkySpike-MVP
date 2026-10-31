class_name GameLog
extends RefCounted
## Journal central : chaque message garde sa source et sa gravité, et reste consultable
## dans le panneau de debug. Ne fait jamais planter le jeu.

enum Level { INFO, WARNING, ERROR }

const MAX_ENTRIES := 500

static var entries: Array[Dictionary] = []
static var echo_to_console := true


static func info(source: String, message: String) -> void:
	_add(Level.INFO, source, message)


static func warning(source: String, message: String) -> void:
	_add(Level.WARNING, source, message)


static func error(source: String, message: String) -> void:
	_add(Level.ERROR, source, message)


static func count(level: int) -> int:
	var n := 0
	for e: Dictionary in entries:
		if e.level == level:
			n += 1
	return n


static func clear() -> void:
	entries.clear()


static func _add(level: int, source: String, message: String) -> void:
	entries.append({"level": level, "source": source, "message": message})
	if entries.size() > MAX_ENTRIES:
		entries.pop_front()
	if not echo_to_console:
		return
	var line := "[%s] %s : %s" % [Level.keys()[level], source, message]
	if level == Level.ERROR:
		printerr(line)
	else:
		print(line)
