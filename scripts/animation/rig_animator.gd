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
	var clip: AnimationClip = library.clip_for(anim_set, choice.action)
	var pos_x := now.position.x if before == null else lerpf(before.position.x, now.position.x, alpha)
	var vy := now.velocity.y
	var t := _clip_time(clip, choice.hold, now, state_time, game_time, pos_x, vy, anim_speed)
	var target := clip.sample(t)
	if not now.grounded and clip.air_legs != "" and clip.air_legs != clip.action:
		var legs_clip := library.clip_for(anim_set, clip.air_legs)
		var legs_t := _clip_time(legs_clip, "", now, state_time, game_time, pos_x, vy, anim_speed)
		target = Pose.with_bones_from(target, legs_clip.sample(legs_t), RigDef.LEG_BONES)
	var frame := AnimFrame.new()
	frame.clip_id = clip.id
	frame.action = clip.action
	frame.domain = clip.time_domain
	frame.clip_time = minf(t, clip.duration_s) if not clip.loop else fposmod(t, clip.duration_s)
	frame.duration = clip.duration_s
	frame.pose = _blend_in(target, "%s|%s" % [clip.id, choice.hold], clip, game_time, anim_speed, frame)
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
		Enums.ActionState.SERVE_HIT:
			return {"action": "serve", "hold": ""}
		Enums.ActionState.SERVE_HOLD:
			return {"action": "serve", "hold": "hold"}
		Enums.ActionState.SERVE_TOSS, Enums.ActionState.SERVE_JUMP:
			return {"action": "serve", "hold": "toss"}
		Enums.ActionState.BLOCK_READY:
			return {"action": "block", "hold": "ready"}
		Enums.ActionState.BLOCK_AIR:
			return {"action": "block", "hold": ""}
		Enums.ActionState.RECOVER:
			return {"action": "land", "hold": ""}
		Enums.ActionState.AIR:
			return {"action": "jump", "hold": ""}
	if not s.grounded:
		return {"action": "jump", "hold": ""}
	return {"action": "run" if absf(s.velocity.x) > RUN_SPEED_THRESHOLD else "idle", "hold": ""}


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
		"loop_time":
			return game_time * speed
		"distance":
			return fposmod(pos_x * s.facing / clip.stride_m, 1.0) * clip.duration_s
		"air_velocity":
			return clampf(0.5 - vy / (2.0 * clip.air_ref_speed), 0.0, 1.0) * clip.duration_s
		"length":
			return clampf(state_time / s.action_length, 0.0, 1.0) * clip.duration_s if s.action_length > 0.0 else clip.duration_s
		"window":
			# L'instant d'impact du clip tombe sur l'instant idéal de la simulation ; avant : on accélère ou
			# ralentit la préparation pour y arriver ; après : lecture à la vitesse normale.
			var impact := clip.marker("impact", clip.duration_s * 0.4)
			var start := clip.marker(clip.window_start, 0.0) if clip.window_start != "" else 0.0
			if s.action_ideal <= 0.0:
				return impact
			if state_time <= s.action_ideal:
				return lerpf(start, impact, state_time / s.action_ideal)
			return impact + (state_time - s.action_ideal) * speed
	return state_time * speed


## Fondu depuis la pose précédente quand l'animation change (durée = `blend_in_s` du nouveau clip).
func _blend_in(target: Dictionary, key: String, clip: AnimationClip, game_time: float, speed: float,
		frame: AnimFrame) -> Dictionary:
	if game_time < _last_time - 0.0005:   # le match a été relancé
		_key = ""
		_from = {}
		_last_pose = {}
	_last_time = game_time
	if key != _key:
		_from = _last_pose
		_key = key
		_switch_time = game_time
	var length := clip.blend_in_s / maxf(speed, 0.05)
	var b := 1.0 if length <= 0.0 or _from.is_empty() else clampf((game_time - _switch_time) / length, 0.0, 1.0)
	frame.blend = b
	var pose := target if b >= 1.0 else Pose.mix(_from, target, b * b * (3.0 - 2.0 * b))
	_last_pose = pose
	return pose
