class_name SandboxPanel
extends PanelContainer
## Panneau de réglage (F1). Ne met pas le match en pause. Modifie les paramètres
## uniquement via ParamStore et contrôle la simulation via l'API de MatchRunner.
## Touches : F1 panneau, F2 zones de contact, P pause, N un tick, R relancer (même graine).
## Onglets : Contrôle (contrôles + presets), un onglet par groupe de paramètres, Données.

const PANEL_WIDTH := 460.0
const GROUP_TITLES: Dictionary = {
	"simulation": "Simulation",
	"physics": "Physique",
	"court": "Terrain",
	"player": "Joueur",
	"contact": "Contacts",
	"assist": "Visée",
	"block": "Contre",
	"rules": "Règles",
	"ai": "IA",
	"conversion": "Stats → physique",
}
const EXPORT_DIR := "user://exports"

var runner: MatchRunner
var _tabs: TabContainer
var _seed_field: SpinBox
var _preset_list: OptionButton
var _preset_name: LineEdit
var _status: Label
var _data_text: RichTextLabel


func _ready() -> void:
	runner = owner as MatchRunner
	visible = false
	call_deferred("_build")


func _build() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.08, 0.12, 0.94)
	style.set_content_margin_all(10)
	add_theme_stylebox_override("panel", style)
	anchor_left = 1.0
	anchor_right = 1.0
	anchor_bottom = 1.0
	offset_left = -PANEL_WIDTH
	_tabs = TabContainer.new()
	add_child(_tabs)
	_tabs.add_child(_scrolled("Contrôle", _build_controls()))
	var groups: Dictionary = {}
	for id: StringName in runner.data.params.ids():
		var def := runner.data.params.get_def(id)
		if not groups.has(def.group):
			groups[def.group] = VBoxContainer.new()
		var row := ParamRow.new()
		groups[def.group].add_child(row)
		row.setup(runner.data.params, def)
	for group: String in groups:
		_tabs.add_child(_scrolled(GROUP_TITLES.get(group, group), groups[group]))
	_data_text = RichTextLabel.new()
	_data_text.fit_content = true
	_data_text.selection_enabled = true
	_tabs.add_child(_scrolled("Données", _data_text))
	_refresh_data_tab()


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.physical_keycode:
		KEY_F1:
			visible = not visible
			_refresh_data_tab()
		KEY_F2:
			if runner.view != null:
				runner.view.show_zones = not runner.view.show_zones
		KEY_P:
			runner.set_paused(not runner.is_paused())
		KEY_N:
			runner.step_once()
		KEY_R:
			runner.restart(runner.current_state.seed_value)


# ------------------------------------------------------------------ onglet Simulation
func _build_controls() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_child(_heading("Contrôle"))
	var row := HBoxContainer.new()
	box.add_child(row)
	row.add_child(_button("Pause / reprise", func() -> void: runner.set_paused(not runner.is_paused())))
	row.add_child(_button("+1 tick", runner.step_once))
	var speeds := HBoxContainer.new()
	box.add_child(speeds)
	for scale: float in [0.25, 0.5, 1.0]:
		speeds.add_child(_button("×%s" % scale, func() -> void:
			runner.data.params.set_value(ParamIds.TIME_SCALE, scale)))
	box.add_child(_heading("Joueur contrôlé (au prochain lancement)"))
	var slot_list := OptionButton.new()
	for label in ["Attaquant bleu", "Passeur bleu", "Défenseur bleu", "Aucun (IA contre IA)"]:
		slot_list.add_item(label)
	slot_list.selected = runner.human_slot if runner.human_slot >= 0 else 3
	slot_list.item_selected.connect(func(index: int) -> void:
		runner.human_slot = index if index < 3 else -1)
	box.add_child(slot_list)
	var aim_row := HBoxContainer.new()
	box.add_child(aim_row)
	aim_row.add_child(_button("Visée assistée", func() -> void: runner.data.params.set_value(ParamIds.AIM_MODE, 1.0)))
	aim_row.add_child(_button("Visée manuelle", func() -> void: runner.data.params.set_value(ParamIds.AIM_MODE, 0.0)))
	box.add_child(_heading("Graine"))
	var seed_row := HBoxContainer.new()
	box.add_child(seed_row)
	_seed_field = SpinBox.new()
	_seed_field.max_value = 2147483647
	_seed_field.value = runner.current_state.seed_value
	_seed_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	seed_row.add_child(_seed_field)
	seed_row.add_child(_button("Relancer le match", func() -> void: runner.restart(int(_seed_field.value))))
	box.add_child(_heading("Presets"))
	_preset_list = OptionButton.new()
	box.add_child(_preset_list)
	_fill_presets()
	var preset_row := HBoxContainer.new()
	box.add_child(preset_row)
	preset_row.add_child(_button("Charger", _load_selected_preset))
	preset_row.add_child(_button("Tout réinitialiser", func() -> void:
		runner.data.params.reset_all()
		_set_status("Valeurs par défaut rétablies.")))
	_preset_name = LineEdit.new()
	_preset_name.placeholder_text = "nom_du_preset (a-z, 0-9, _)"
	box.add_child(_preset_name)
	var save_row := HBoxContainer.new()
	box.add_child(save_row)
	save_row.add_child(_button("Enregistrer", _save_preset))
	save_row.add_child(_button("Exporter le preset actif", _export_preset))
	var experimental := CheckButton.new()
	experimental.text = "Mode expérimental (bornes élargies)"
	experimental.button_pressed = runner.data.params.experimental_mode
	experimental.toggled.connect(func(on: bool) -> void: runner.data.params.experimental_mode = on)
	runner.data.params.experimental_changed.connect(func(on: bool) -> void: experimental.set_pressed_no_signal(on))
	box.add_child(experimental)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_status)
	return box


func _fill_presets() -> void:
	_preset_list.clear()
	for id: String in runner.data.presets.ids():
		_preset_list.add_item(id)


func _load_selected_preset() -> void:
	if _preset_list.selected < 0:
		return
	var id := _preset_list.get_item_text(_preset_list.selected)
	var problems := runner.data.apply_preset(id)
	_set_status("Preset « %s » chargé%s" % [id, (" avec %d problème(s) : %s" % [problems.size(), "; ".join(problems)]) if not problems.is_empty() else "."])


func _save_preset() -> void:
	var preset_id := _preset_name.text.strip_edges()
	if RegEx.create_from_string("^[a-z0-9_]+$").search(preset_id) == null:
		_set_status("Nom invalide : lettres minuscules, chiffres et _ uniquement.")
		return
	var preset := runner.data.params.to_preset(preset_id)
	preset.base = "default"
	var err := runner.data.presets.save_user(preset)
	_set_status("Enregistré dans user://presets/%s.json" % preset_id if err == OK else "Échec de l'enregistrement (%s)." % error_string(err))
	_fill_presets()


func _export_preset() -> void:
	var stamp := Time.get_datetime_string_from_system().replace(":", "-")
	var path := EXPORT_DIR.path_join("preset_%s.json" % stamp)
	var err := JsonLoader.save_object(path, runner.data.params.to_preset("export_" + stamp.replace("-", "_").replace("T", "_").to_lower()).to_dict())
	_set_status("Exporté : %s" % ProjectSettings.globalize_path(path) if err == OK else "Échec de l'export (%s)." % error_string(err))


# ------------------------------------------------------------------ onglet Données
func _refresh_data_tab() -> void:
	if _data_text == null:
		return
	var lines := PackedStringArray()
	lines.append("[b]Personnages chargés (%d)[/b]" % runner.data.characters.ids().size())
	for id: String in runner.data.characters.ids():
		var c := runner.data.characters.get_character(id)
		lines.append("• " + c.describe())
		for f: String in c.fallbacks:
			lines.append("    repli : " + f)
	lines.append("")
	lines.append("[b]Problèmes de données (%d)[/b]" % runner.data.issues.size())
	for issue: LoadIssue in runner.data.issues:
		lines.append(("[color=#ff7070]ERREUR[/color] " if issue.is_error() else "[color=#ffcf3c]avert.[/color] ") + issue.describe())
	_data_text.text = "\n".join(lines)


# ------------------------------------------------------------------ outils
func _scrolled(title: String, content: Control) -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.name = title
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	return scroll


func _heading(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 16)
	return l


func _button(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(action)
	return b


func _set_status(text: String) -> void:
	_status.text = text
