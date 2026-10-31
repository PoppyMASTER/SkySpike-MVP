class_name GameData
extends RefCounted
## Chargement de toutes les données au démarrage : définitions de paramètres, presets,
## personnages. Point d'assemblage (couche app) : rien ici ne contient de règle de jeu.

var params: ParamStore
var presets := PresetStore.new()
var characters: CharacterRepository
var issues: Array[LoadIssue] = []


static func load_default() -> GameData:
	var data := GameData.new()
	data.load_from(ParamDefLoader.DEFAULT_PATH, PresetStore.BUILTIN_DIR, PresetStore.USER_DIR, CharacterRepository.DATA_ROOT)
	return data


func load_from(param_defs_path: String, builtin_presets: String, user_presets: String, data_root: String) -> void:
	issues.clear()
	var defs := ParamDefLoader.load_defs(param_defs_path, issues)
	params = ParamStore.new(defs)
	presets.load_all(builtin_presets, user_presets)
	issues.append_array(presets.issues)
	characters = CharacterRepository.new(data_root)
	characters.load_all()
	issues.append_array(characters.issues)
	for issue: LoadIssue in issues:
		issue.write_to_log()
	GameLog.info("Données", "%d paramètres, %d presets, %d personnages, %d problème(s)" % [
		params.ids().size(), presets.ids().size(), characters.ids().size(), issues.size()])


## Applique un preset (base comprise) par-dessus les valeurs par défaut.
func apply_preset(id: String) -> Array[String]:
	params.experimental_mode = false
	params.reset_all()
	return params.apply_values(presets.resolve(id), presets.is_experimental(id))
