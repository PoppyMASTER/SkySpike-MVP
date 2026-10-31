class_name AnimSheet
extends Node2D
## Planche-contact des animations (outil de vérification, `-- --anim-sheet DOSSIER`) : une ligne par clip,
## cinq poses réparties dans le clip, mannequin posé sur une ligne de sol. Sert à regarder les poses.

const COLUMNS := 5
const CELL := Vector2(310.0, 290.0)
const PIXELS_PER_METER := 95.0
const MARGIN := Vector2(20.0, 28.0)

var _labels: Array = []   # [position, texte]
var _grounds: Array[Vector2] = []


func build(library: ClipLibrary, character: CharacterDefinition, clip_ids: Array, team_color: Color) -> void:
	var animator := RigAnimator.new(library, character)
	for row in clip_ids.size():
		var clip := library.get_clip(clip_ids[row])
		for col in COLUMNS:
			var share := float(col) / float(COLUMNS - 1) if not clip.loop else float(col) / float(COLUMNS)
			var t := share * clip.duration_s
			var origin := MARGIN + Vector2(CELL.x * (col + 0.5), CELL.y * (row + 1) - 24.0)
			var rig := MannequinRig.new()
			rig.build(animator.dims, team_color)
			var frame := animator.evaluate_clip(clip, t, clip.grounded or clip.air_legs != "")
			rig.apply(frame)
			var lift := Vector2(0.0, -0.8 * PIXELS_PER_METER) if not clip.grounded else Vector2.ZERO
			rig.place(origin + lift, PIXELS_PER_METER, 1)
			add_child(rig)
			_grounds.append(origin)
			_labels.append([origin + Vector2(-CELL.x * 0.45, 16.0), "%s  t=%.2f s" % [clip.id, t]])


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), Color("0d1726"))
	for g: Vector2 in _grounds:
		draw_line(g + Vector2(-CELL.x * 0.45, 0.0), g + Vector2(CELL.x * 0.45, 0.0), Color(1, 1, 1, 0.25), 1.0)
	var font := ThemeDB.fallback_font
	for l: Array in _labels:
		draw_string(font, l[0], l[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, 0.7))
