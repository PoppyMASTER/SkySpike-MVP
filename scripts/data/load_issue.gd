class_name LoadIssue
extends RefCounted
## Problème rencontré en chargeant un fichier de données : où, quoi, et ce qui a été fait.

enum Severity { WARNING, ERROR }

var severity: int
var file: String
## Chemin du champ dans le JSON, ex. "keyframes[2].pose.forearm_l" ("" = fichier entier).
var field: String
var message: String


static func make(severity_value: int, file_path: String, field_path: String, text: String) -> LoadIssue:
	var issue := LoadIssue.new()
	issue.severity = severity_value
	issue.file = file_path
	issue.field = field_path
	issue.message = text
	return issue


func is_error() -> bool:
	return severity == Severity.ERROR


func describe() -> String:
	var where := file if field == "" else "%s → %s" % [file, field]
	return "%s : %s" % [where, message]


## Recopie dans le journal central.
func write_to_log() -> void:
	if is_error():
		GameLog.error("Données", describe())
	else:
		GameLog.warning("Données", describe())
