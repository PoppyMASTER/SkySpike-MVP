class_name RigAnimator
extends RefCounted
## Transforme l'état d'un joueur (PlayerSnapshot) en pose du rig. Fonction pure du temps de SIMULATION
## (temps d'action, tick), jamais du nombre d'images affichées : même état → même pose à 30 ou 144 i/s,
## et la pause ou le ralenti figent ou ralentissent aussi l'animation. Ne modifie rien dans la simulation
## et ne décide d'aucun contact : l'instant d'impact du clip est calé sur l'instant idéal de la simulation.
## Un RigAnimator par joueur (il garde seulement la dernière pose pour le fondu).

const RUN_SPEED_THRESHOLD := 0.3
const MAX_SNAP_M := 0.6

var library: ClipLibrary
var anim_set: AnimationSetDefinition
var dims: RigDims
var offsets: Dictionary

## Réglages d'affichage du service (purement visuels, posés par la vue depuis le sandbox).
var variants_enabled := true      # faux = tous les services utilisent le clip « serve » d'origine
var intensity := 1.0              # amplitude du buste, des bras et de la tête sur les clips de service
var follow_scale := 1.0           # durée du suivi du geste (2 = deux fois plus long)
var blend_override := 0.0         # durée des fondus du service ; 0 = durée propre à chaque clip

## Os dont l'amplitude suit `intensity` : jamais les jambes, pour que les pieds restent plantés.
const STYLE_BONES: Array[String] = ["torso", "neck", "head", "upper_arm_l", "forearm_l", "hand_l", "upper_arm_r", "forearm_r", "hand_r"]
## Suivi du geste et atterrissage ne s'appliquent qu'un temps après la frappe.
const LAND_WINDOW_S := 2.0
## Vitesse maximale de lecture du clip de frappe (× temps réel) quand le contact attendu se précise.
const MAX_WINDOW_SPEED := 3.5
## Part maximale du temps avant le contact attendu consacrée au fondu d'entrée dans le geste de frappe.
const BLEND_SHARE_OF_STRIKE := 0.4

var _win_t := 0.0          # temps du clip de frappe lissé (jamais en arrière, vitesse bornée)
var _win_game := 0.0
var _win_active := false
var _key := ""
var _switch_time := 0.0
var _from: Dictionary = {}
var _last_pose: Dictionary = {}
var _last_time := -1.0


func _init(clip_library: ClipLibrary, character: CharacterDefinition) -> void:
	library = clip_library
	anim_set = character.animation_set
	dims = RigDef.dims_for(character.morphology)
	offsets = RigDef.rest_offsets(dims)


## `before` : état du tick précédent (peut être null). `alpha` : fraction du tick écoulée (0 → before, 1 → now).
## `anim_speed` : vitesse de lecture des animations (réglage de debug, sans effet sur la simulation).
func evaluate(now: PlayerSnapshot, before: PlayerSnapshot, alpha: float, tick: int, tick_seconds: float,
		anim_speed := 1.0) -> AnimFrame:
	var game_time := (float(tick) - 1.0 + alpha) * tick_seconds
	var state_time := _state_time(now, before, alpha)
	var choice := _choose(now)
	var forced_t := -1.0
	var follow := _follow_through(now)
	if not follow.is_empty() and choice.hold == "":
		choice = {"action": follow.action, "hold": ""}
		forced_t = follow.t
	var clip: AnimationClip = library.clip_for(anim_set, choice.action)
	var pos_x := now.position.x if before == null else lerpf(before.position.x, now.position.x, alpha)
	var vy := now.velocity.y
	var t := _clip_time(clip, choice.hold, now, state_time, game_time, pos_x, vy, anim_speed) if forced_t < 0.0 else forced_t
	t = _smooth_strike_time(now, clip, t, game_time)
	var target := clip.sample(t)
	if not now.grounded and clip.air_legs != "" and clip.air_legs != clip.action:
		var legs_clip := library.clip_for(anim_set, clip.air_legs)
		var legs_t := _clip_time(legs_clip, "", now, state_time, game_time, pos_x, vy, anim_speed)
		target = Pose.with_bones_from(target, legs_clip.sample(legs_t), RigDef.LEG_BONES)
	if now.grounded and clip.move_legs != "" and absf(now.velocity.x) > RUN_SPEED_THRESHOLD:
		var run_clip := library.clip_for(anim_set, clip.move_legs)   # jambes de course : les pieds ne glissent pas
		var run_t := _clip_time(run_clip, "", now, state_time, game_time, pos_x, vy, anim_speed)
		target = Pose.with_bones_from(target, run_clip.sample(run_t), RigDef.LEG_BONES)
	if now.action == Enums.ActionState.SERVE_JUMP:
		target = _launch_squash(target, clip, state_time)
	if _is_serve_style(clip.action) and intensity != 1.0:
		target = _scaled(target)
	var frame := AnimFrame.new()
	frame.clip_id = clip.id
	frame.action = clip.action
	frame.domain = clip.time_domain
	frame.clip_time = minf(t, clip.duration_s) if not clip.loop else fposmod(t, clip.duration_s)
	frame.duration = clip.duration_s
	var blend_s := blend_override if _is_serve_style(clip.action) else 0.0
	if now.action == Enums.ActionState.SERVE_HIT and clip.time_domain == "window" and now.serve_expected > 0.0:
		# Le fondu d'entrée ne doit pas durer plus qu'une fraction du temps restant avant le contact attendu.
		blend_s = minf(blend_s if blend_s > 0.0 else clip.blend_in_s, BLEND_SHARE_OF_STRIKE * now.serve_expected)
	frame.pose = _blend_in(target, "%s|%s" % [clip.id, choice.hold], clip, game_time, anim_speed, frame, blend_s)
	if now.grounded:
		var global := RigDef.forward_kinematics(frame.pose, offsets)
		frame.shift_y = clampf(-RigDef.lowest_sole(global, dims), -MAX_SNAP_M, MAX_SNAP_M)
	return frame


## Pose d'un clip lu isolément (outil de debug « tester une animation ») : temps = secondes du clip.
func evaluate_clip(clip: AnimationClip, t: float, ground_snap: bool) -> AnimFrame:
	var frame := AnimFrame.new()
	frame.clip_id = clip.id
	frame.action = clip.action
	frame.domain = clip.time_domain
	frame.duration = clip.duration_s
	frame.clip_time = fposmod(t, clip.duration_s) if clip.loop else minf(t, clip.duration_s)
	frame.pose = clip.sample(t)
	if ground_snap:
		var global := RigDef.forward_kinematics(frame.pose, offsets)
		frame.shift_y = clampf(-RigDef.lowest_sole(global, dims), -MAX_SNAP_M, MAX_SNAP_M)
	return frame


# ------------------------------------------------------------------ choix du clip
## Quel clip, et éventuellement quel repère de maintien (pose figée) pour cet état de la simulation.
func _choose(s: PlayerSnapshot) -> Dictionary:
	match s.action:
		Enums.ActionState.RECEIVE:
			return {"action": "receive", "hold": ""}
		Enums.ActionState.SET:
			return {"action": "set", "hold": ""}
		Enums.ActionState.SPIKE:
			return {"action": "spike", "hold": ""}
		Enums.ActionState.FEINT:
			return {"action": "feint", "hold": ""}
		Enums.ActionState.SERVE_HIT:   # geste annoncé par l'intention partagée avec la simulation (sol / flottant / smash)
			return {"action": _serve_action(s.serve_intent), "hold": ""}
		Enums.ActionState.SERVE_HOLD:   # attente avec ballon, puis préparation (accroupi selon la charge)
			return {"action": "serve_prep", "hold": ""}
		Enums.ActionState.SERVE_TOSS:   # lancer : le bras monte, l'autre s'arme
			return {"action": "serve_toss", "hold": ""}
		Enums.ActionState.SERVE_JUMP:   # impulsion : compression brève, extension, buste qui s'ouvre, coude qui s'arme
			if variants_enabled:
				return {"action": "serve_jump", "hold": ""}
			return {"action": "serve_toss", "hold": "cock"}
		Enums.ActionState.BLOCK_READY:
			return {"action": "block", "hold": "ready"}
		Enums.ActionState.BLOCK_AIR:
			return {"action": "block", "hold": ""}
		Enums.ActionState.RECOVER:
			if variants_enabled and s.strike_age < LAND_WINDOW_S and (s.strike_kind == "float" or s.strike_kind == "smash"):
				return {"action": "land_" + s.strike_kind, "hold": ""}   # atterrissage du type de frappe CONFIRMÉ
			return {"action": "land", "hold": ""}
		Enums.ActionState.AIR:
			return {"action": "jump", "hold": ""}
	if not s.grounded:
		return {"action": "jump", "hold": ""}
	return {"action": "run" if absf(s.velocity.x) > RUN_SPEED_THRESHOLD else "idle", "hold": ""}


## Lisse le temps du clip de frappe : le contact attendu se précise tick après tick ; le geste ne revient jamais en arrière
## et sa vitesse reste bornée (pas d'à-coup). Après la frappe, le suivi reprend exactement là où le geste en était.
func _smooth_strike_time(s: PlayerSnapshot, clip: AnimationClip, t: float, game_time: float) -> float:
	if s.action == Enums.ActionState.SERVE_HIT and clip.time_domain == "window":
		if _win_active and game_time > _win_game:
			t = clampf(t, _win_t, _win_t + MAX_WINDOW_SPEED * (game_time - _win_game))
		_win_t = t
		_win_game = game_time
		_win_active = true
		return t
	if _win_active and s.strike_kind != "" and s.strike_age < clip_follow_limit() and clip.time_domain == "window":
		var resumed := _win_t + (game_time - _win_game) / maxf(follow_scale, 0.05)
		return maxf(t, minf(resumed, clip.duration_s))
	if s.action != Enums.ActionState.SERVE_HIT and (s.strike_kind == "" or s.strike_age >= clip_follow_limit()):
		_win_active = false
	return t


func _serve_action(intent: String) -> String:
	if variants_enabled and (intent == "ground" or intent == "float" or intent == "smash"):
		return "serve_" + intent
	return "serve"


## Les clips dont la famille suit les réglages de service.
static func _is_serve_style(action: String) -> bool:
	return action.begins_with("serve") or action == "land_float" or action == "land_smash"


## Temps du clip de frappe à un temps d'état donné : l'instant `impact` tombe sur l'instant idéal de la simulation.
func _window_time(clip: AnimationClip, state_time: float, ideal: float, speed: float) -> float:
	var impact := clip.marker("impact", clip.duration_s * 0.4)
	var start := clip.marker(clip.window_start, 0.0) if clip.window_start != "" else 0.0
	if ideal <= 0.0:
		return impact
	if state_time <= ideal:
		return lerpf(start, impact, state_time / ideal)
	return impact + (state_time - ideal) * speed


## Suivi du geste après la fenêtre de contact (touchée ou ratée) : le clip de frappe reprend là où la fenêtre s'est
## fermée et se termine, sans rien imposer à la simulation. Au sol après un smash ou un flottant, c'est l'atterrissage.
func _follow_through(s: PlayerSnapshot) -> Dictionary:
	if s.strike_kind == "" or s.strike_age >= clip_follow_limit():
		return {}
	if s.action != Enums.ActionState.FREE and s.action != Enums.ActionState.AIR and s.action != Enums.ActionState.RECOVER:
		return {}   # une autre action a commencé : elle a la priorité
	if s.grounded and absf(s.velocity.x) > RUN_SPEED_THRESHOLD:
		return {}   # le joueur court : jambes de course, pas de geste figé
	var air := not s.grounded
	if s.strike_kind != "ground" and not air:
		return {}   # atterri : clip d'atterrissage
	var action := _serve_action(s.strike_kind)
	var clip: AnimationClip = library.clip_for(anim_set, action)
	var t := _window_time(clip, s.strike_window_time, s.strike_ideal, 1.0) + s.strike_age / maxf(follow_scale, 0.05)
	if t >= clip.duration_s:
		return {}
	return {"action": action, "t": t}


func clip_follow_limit() -> float:
	return 3.0


## Compression visuelle très brève au déclenchement du saut, puis extension immédiate : les jambes du lancer
## (marqueur « squash ») se fondent dans celles du saut. L'impulsion physique n'est jamais retardée.
func _launch_squash(target: Dictionary, clip: AnimationClip, state_time: float) -> Dictionary:
	if not clip.has_marker("squash") or not clip.has_marker("squash_end"):
		return target
	var length := clip.marker("squash_end", 0.0) - clip.marker("squash", 0.0)
	if length <= 0.0 or state_time >= length:
		return target
	var u := state_time / length
	u = u * u * (3.0 - 2.0 * u)
	var squash := clip.sample(clip.marker("squash", 0.0))
	return Pose.with_bones_from(target, Pose.mix(squash, target, u), RigDef.LEG_BONES)


func _scaled(pose: Dictionary) -> Dictionary:
	var out := pose.duplicate()
	for bone in STYLE_BONES:
		if out.has(bone):
			out[bone] = clampf(float(out[bone]) * intensity, -PI, PI)   # jamais de retournement au-delà de ±π
	return out


## Temps d'action interpolé entre deux ticks (secondes de simulation).
func _state_time(now: PlayerSnapshot, before: PlayerSnapshot, alpha: float) -> float:
	if before != null and before.action == now.action:
		return lerpf(before.action_time, now.action_time, alpha)
	return now.action_time * alpha


## Temps (s) dans le clip pour cet état.
func _clip_time(clip: AnimationClip, hold: String, s: PlayerSnapshot, state_time: float, game_time: float,
		pos_x: float, vy: float, speed: float) -> float:
	if hold != "":
		return clip.marker(hold, 0.0)
	match clip.time_domain:
		"charge":
			return clampf(s.serve_charge, 0.0, 1.0) * clip.duration_s
		"loop_time":
			return game_time * speed
		"distance":
			return fposmod(pos_x * s.facing / clip.stride_m, 1.0) * clip.duration_s
		"air_velocity":
			return clampf(0.5 - vy / (2.0 * clip.air_ref_speed), 0.0, 1.0) * clip.duration_s
		"length":
			return clampf(state_time / s.action_length, 0.0, 1.0) * clip.duration_s if s.action_length > 0.0 else clip.duration_s
		"window":
			# Pour le service : l'impact visuel tombe sur le contact ATTENDU par la simulation (sinon sur l'instant idéal).
			var ideal := s.serve_expected if s.action == Enums.ActionState.SERVE_HIT and s.serve_expected > 0.0 else s.action_ideal
			return _window_time(clip, state_time, ideal, speed)
	return state_time * speed


## Fondu depuis la pose précédente quand l'animation change (durée = `blend_in_s` du nouveau clip).
func _blend_in(target: Dictionary, key: String, clip: AnimationClip, game_time: float, speed: float,
		frame: AnimFrame, override_s := 0.0) -> Dictionary:
	if game_time < _last_time - 0.0005:   # le match a été relancé
		_key = ""
		_from = {}
		_last_pose = {}
	_last_time = game_time
	if key != _key:
		_from = _last_pose
		_key = key
		_switch_time = game_time
	var length := (override_s if override_s > 0.0 else clip.blend_in_s) / maxf(speed, 0.05)
	var b := 1.0 if length <= 0.0 or _from.is_empty() else clampf((game_time - _switch_time) / length, 0.0, 1.0)
	frame.blend = b
	var pose := target if b >= 1.0 else Pose.mix(_from, target, b * b * (3.0 - 2.0 * b))
	_last_pose = pose
	return pose
