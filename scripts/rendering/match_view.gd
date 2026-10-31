class_name MatchView
extends Node2D
## Rendu du match : terrain, filet, six mannequins articulés (MannequinRig), puis une couche « overlay »
## (ballon, zones, indicateur, score, debug). Lit uniquement MatchState et l'alpha d'interpolation fournis par
## MatchRunner ; n'écrit jamais dans la simulation. L'animation dépend du temps de SIMULATION (RigAnimator),
## pas du nombre d'images affichées.

const VISIBLE_WIDTH_M := 22.0
const GROUND_RATIO := 0.82
const COLOR_SKY := Color("0d1726")
const COLOR_GROUND := Color("1f3a4d")
const COLOR_LINE := Color("e8f0f2")
const COLOR_GRID := Color(1, 1, 1, 0.07)
const COLOR_NET := Color("c9d3d8")
const COLOR_NET_TAPE := Color("ffffff")
const COLOR_TEAM: Array[Color] = [Color("4f9dde"), Color("e0524f")]   # équipe du joueur = bleu, adverse = rouge
## Aperçu d'animation (debug) : position (m) et agrandissement du mannequin isolé.
const PREVIEW_X_M := -7.5
const PREVIEW_ZOOM := 1.5

var previous_state: MatchState
var current_state: MatchState
var alpha := 0.0
var font: Font
## Réglages d'affichage (lecture seule) : opacité, teinte, durée de la prévision du service.
var params: ParamStore
## Effets de frappe (impacts, traînée, vitesse, caméra) : purement visuels, pilotés par le temps de simulation.
var fx := ImpactFx.new()
var camera_px := Vector2.ZERO

## Réglages de debug (touches F2 à F5, panneau F1 → Animation).
var show_zones := false
var show_skeleton := false
var show_pivots := false
var show_anim_info := false
## Vitesse de lecture des animations : affecte seulement l'animation, jamais la simulation.
var anim_speed := 1.0

## Test d'une animation isolée (debug) : lecture indépendante du match, avec sa propre horloge.
var preview_clip: AnimationClip
var preview_time := 0.0
var preview_playing := true
var preview_speed := 1.0

var rigs: Array[MannequinRig] = []
var animators: Array[RigAnimator] = []
var frames: Array[AnimFrame] = []
var preview_rig: MannequinRig
var preview_animator: RigAnimator
var preview_frame: AnimFrame
var overlay: MatchOverlay


func _ready() -> void:
	_ensure_overlay()


func _ensure_overlay() -> void:
	if overlay != null:
		return
	font = ThemeDB.fallback_font
	overlay = MatchOverlay.new()
	overlay.view = self
	overlay.z_as_relative = false
	overlay.z_index = 10
	add_child(overlay)


## Crée un mannequin par personnage de la composition (slots dans l'ordre). Appelé à chaque nouveau match.
func setup_players(library: ClipLibrary, lineup: Array[CharacterDefinition]) -> void:
	_ensure_overlay()
	for rig in rigs:
		rig.queue_free()
	rigs.clear()
	animators.clear()
	frames.clear()
	if preview_rig != null:
		preview_rig.queue_free()
		preview_rig = null
	for i in lineup.size():
		var team := i / 3 if lineup.size() == 6 else 0
		var animator := RigAnimator.new(library, lineup[i])
		var rig := MannequinRig.new()
		rig.name = "Mannequin%d" % i
		rig.build(animator.dims, COLOR_TEAM[team])
		add_child(rig)
		rigs.append(rig)
		animators.append(animator)
		frames.append(null)
	if not lineup.is_empty():
		preview_animator = RigAnimator.new(library, lineup[0])
		preview_rig = MannequinRig.new()
		preview_rig.name = "MannequinApercu"
		preview_rig.build(preview_animator.dims, COLOR_TEAM[0])
		preview_rig.visible = false
		add_child(preview_rig)
	move_child(overlay, get_child_count() - 1)


## Appelé par MatchRunner à chaque image.
func show_states(previous: MatchState, current: MatchState, render_alpha: float) -> void:
	previous_state = previous
	current_state = current
	alpha = render_alpha
	_update_fx()
	_update_rigs()
	queue_redraw()
	overlay.queue_redraw()


## Transmet les événements d'un tick aux effets (appelé par MatchRunner).
func on_events(events: Array[MatchEvent], state: MatchState) -> void:
	if fx_enabled():
		fx.on_events(events, state)


func fx_enabled() -> bool:
	return params == null or params.get_value(ParamIds.FX_ENABLED) >= 0.5


func fx_time() -> float:
	return ImpactFx.time_of(current_state) + alpha * current_state.tick_seconds


func _update_fx() -> void:
	if not fx_enabled():
		fx.clear()
		camera_px = Vector2.ZERO
		return
	fx.on_state(current_state, params.get_value(ParamIds.FX_TRAIL_S) if params != null else 0.4)
	camera_px = fx.camera_offset(fx_time(), params.get_value(ParamIds.FX_CAMERA_STRENGTH) if params != null else 0.5)


## Avance l'aperçu d'animation avec le temps réel (indépendant de la simulation, de la pause et du ralenti).
func _process(delta: float) -> void:
	if preview_clip == null:
		return
	if preview_playing:
		preview_time += delta * preview_speed
	if preview_rig != null and preview_animator != null:
		preview_frame = preview_animator.evaluate_clip(preview_clip, preview_time, preview_clip.grounded)
		preview_rig.visible = true
		preview_rig.apply(preview_frame)
		var k := pixels_per_meter() * PREVIEW_ZOOM
		var shift_air := Vector2(0.0, -1.0 * pixels_per_meter() * PREVIEW_ZOOM) if not preview_clip.grounded else Vector2.ZERO
		preview_rig.place(to_screen(Vector2(PREVIEW_X_M, 0.0)) + shift_air, k, 1)
	overlay.queue_redraw()


func start_preview(clip: AnimationClip) -> void:
	preview_clip = clip
	preview_time = 0.0
	preview_playing = true


func stop_preview() -> void:
	preview_clip = null
	preview_frame = null
	if preview_rig != null:
		preview_rig.visible = false
	overlay.queue_redraw()


func reset_animation_settings() -> void:
	anim_speed = 1.0
	preview_speed = 1.0


func _update_rigs() -> void:
	var k := pixels_per_meter()
	for i in mini(rigs.size(), current_state.players.size()):
		var now := current_state.players[i]
		var before: PlayerSnapshot = previous_state.players[i] if previous_state != null and i < previous_state.players.size() else null
		if params != null:
			var a := animators[i]
			a.variants_enabled = params.get_value(ParamIds.ANIM_SERVE_VARIANTS) >= 0.5
			a.intensity = params.get_value(ParamIds.ANIM_SERVE_INTENSITY)
			a.follow_scale = params.get_value(ParamIds.ANIM_FOLLOW_THROUGH_SCALE)
			a.blend_override = params.get_value(ParamIds.ANIM_SERVE_BLEND_S)
		var frame := animators[i].evaluate(now, before, alpha, current_state.tick, current_state.tick_seconds, anim_speed)
		frames[i] = frame
		rigs[i].apply(frame)
		rigs[i].place(to_screen(player_position(i)), k, now.facing)


## Position interpolée des pieds du joueur (m).
func player_position(i: int) -> Vector2:
	var now := current_state.players[i]
	if previous_state == null or i >= previous_state.players.size():
		return now.position
	return previous_state.players[i].position.lerp(now.position, alpha)


## Taille de la zone d'affichage (une valeur par défaut hors arbre de scène, par exemple dans les tests).
func viewport_size() -> Vector2:
	return get_viewport_rect().size if is_inside_tree() else Vector2(1600.0, 900.0)


func pixels_per_meter() -> float:
	return viewport_size().x / VISIBLE_WIDTH_M


## Mètres (x, y vers le haut) → pixels écran.
func to_screen(world: Vector2) -> Vector2:
	var size := viewport_size()
	var k := pixels_per_meter()
	return Vector2(size.x * 0.5 + world.x * k, size.y * GROUND_RATIO - world.y * k) + camera_px


func _draw() -> void:
	var size := viewport_size()
	var k := pixels_per_meter()
	var ground_y := size.y * GROUND_RATIO
	draw_rect(Rect2(Vector2.ZERO, size), COLOR_SKY)
	draw_rect(Rect2(0, ground_y, size.x, size.y - ground_y), COLOR_GROUND)
	for m in range(-11, 12):
		var x := to_screen(Vector2(m, 0)).x
		draw_line(Vector2(x, 0), Vector2(x, ground_y), COLOR_GRID, 1.0)
		if m % 3 == 0:
			draw_string(font, Vector2(x + 3, ground_y + 18), "%d m" % m, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, 0.5))
	for h in range(1, 8):
		var y := to_screen(Vector2(0, h)).y
		draw_line(Vector2(0, y), Vector2(size.x, y), COLOR_GRID, 1.0)
	draw_line(Vector2(0, ground_y), Vector2(size.x, ground_y), COLOR_LINE, 2.0)
	if current_state == null:
		return
	var half := current_state.court_half_length
	for side in [-1.0, 1.0]:
		var x := to_screen(Vector2(side * half, 0)).x
		draw_line(Vector2(x, ground_y - 6.0), Vector2(x, ground_y + 6.0), COLOR_LINE, 3.0)
	var top := to_screen(Vector2(0, current_state.net_height)).y
	var half_w := maxf(1.5, current_state.net_half_thickness * k)
	var net_x := to_screen(Vector2.ZERO).x
	draw_rect(Rect2(net_x - half_w, top, half_w * 2.0, ground_y - top), COLOR_NET)
	draw_rect(Rect2(net_x - half_w - 1.0, top, half_w * 2.0 + 2.0, 4.0), COLOR_NET_TAPE)
