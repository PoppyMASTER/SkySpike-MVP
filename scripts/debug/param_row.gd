class_name ParamRow
extends VBoxContainer
## Une ligne du panneau sandbox pour un paramètre : nom, curseur, champ numérique, unité,
## bornes, mode d'application et bouton de réinitialisation. Écrit uniquement via ParamStore.

const COLOR_NORMAL := Color(0.92, 0.94, 0.97)
const COLOR_OUTSIDE := Color("ffb347")
const APPLY_BADGES: Dictionary = {
	ParamDef.ApplyMode.IMMEDIATE: "",
	ParamDef.ApplyMode.NEXT_RALLY: "  [prochain rallye]",
	ParamDef.ApplyMode.NEXT_MATCH: "  [prochain match]",
}

var store: ParamStore
var def: ParamDef
var _slider: HSlider
var _spin: SpinBox
var _title: Label
var _bounds: Label
var _updating := false


func setup(param_store: ParamStore, param_def: ParamDef) -> void:
	store = param_store
	def = param_def
	tooltip_text = def.description
	_title = Label.new()
	_title.text = "%s (%s)%s" % [def.label, def.unit, APPLY_BADGES[def.apply_mode]]
	_title.tooltip_text = def.description
	_title.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_title)
	var row := HBoxContainer.new()
	add_child(row)
	_slider = HSlider.new()
	_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_slider.step = def.step
	row.add_child(_slider)
	_spin = SpinBox.new()
	_spin.step = def.step
	_spin.custom_minimum_size.x = 96
	_spin.allow_greater = true
	_spin.allow_lesser = true
	row.add_child(_spin)
	var reset := Button.new()
	reset.text = "↺"
	reset.tooltip_text = "Valeur par défaut : %s" % def.default_value
	reset.pressed.connect(func() -> void: store.reset(def.id))
	row.add_child(reset)
	_bounds = Label.new()
	_bounds.add_theme_font_size_override("font_size", 11)
	_bounds.modulate = Color(1, 1, 1, 0.6)
	add_child(_bounds)
	_slider.value_changed.connect(_on_input)
	_spin.value_changed.connect(_on_input)
	store.value_changed.connect(func(id: StringName, _v: float) -> void:
		if id == def.id:
			refresh())
	store.experimental_changed.connect(func(_on: bool) -> void: refresh())
	refresh()


func refresh() -> void:
	_updating = true
	var lo := def.experimental_min if store.experimental_mode else def.min_value
	var hi := def.experimental_max if store.experimental_mode else def.max_value
	_slider.min_value = lo
	_slider.max_value = hi
	var value := store.get_value(def.id)
	_slider.value = value
	_spin.value = value
	_bounds.text = "bornes %s – %s · défaut %s%s" % [def.min_value, def.max_value, def.default_value,
		(" · exp. %s – %s" % [def.experimental_min, def.experimental_max]) if store.experimental_mode else ""]
	_title.modulate = COLOR_OUTSIDE if store.is_outside_normal(def.id) else COLOR_NORMAL
	_updating = false


func _on_input(value: float) -> void:
	if _updating:
		return
	if store.set_value(def.id, value) != ParamStore.SetResult.ACCEPTED:
		refresh()   # valeur refusée : on réaffiche la valeur réelle
