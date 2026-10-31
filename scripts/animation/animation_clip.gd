class_name AnimationClip
extends RefCounted
## Clip d'animation chargé depuis `data/animations/clips/<id>.json` : poses clés absolues par os, interpolées.
## Le clip ne connaît ni la simulation ni le temps réel : on lui demande la pose à l'instant `t` (secondes du clip).
## Les repères d'événement (`impact`, `toss`…) servent à caler l'animation sur la simulation ; ils ne déclenchent
## jamais de contact.

const SCHEMA_VERSION := 1
const MAX_DURATION_S := 5.0
const ID_PATTERN := "^[a-z][a-z0-9_]*$"
const KEYS: Array[String] = ["schema_version", "id", "action", "duration_s", "loop", "time_domain", "pose_mode",
	"default_interpolation", "foot_lock", "grounded", "air_legs", "move_legs", "blend_in_s", "stride_m", "air_ref_speed",
	"window_start", "keyframes", "events"]

## Comment le temps du clip est choisi à partir de l'état de la simulation :
## seconds = secondes écoulées dans l'état ; window = caler le repère `impact` sur l'instant idéal de l'action ;
## loop_time = temps de jeu (boucle) ; distance = distance parcourue (cycle de course) ;
## air_velocity = vitesse verticale (montée → chute) ; length = durée de l'état (atterrissage) ;
## charge = charge du lancer de service (0 → 1).
const DOMAINS: Array[String] = ["seconds", "window", "loop_time", "distance", "air_velocity", "length", "charge"]

var id := ""
var action := ""
var duration_s := 1.0
var loop := false
var time_domain := "seconds"
var smooth := false
## « spline » : courbe d'Hermite monotone à travers les poses (angles déroulés). Le mouvement garde sa vitesse en
## traversant une pose clé quand il continue dans le même sens (accélération, impact) et ne s'arrête que là où il
## change de sens (armé, fin du suivi) ; jamais de dépassement entre deux poses (limites articulaires tenues).
var spline := false
## Cycle de course : longueur parcourue pour un tour de clip (m).
var stride_m := 1.9
## Vitesse verticale (m/s) correspondant au début / à la fin du clip (domaine air_velocity).
var air_ref_speed := 9.5
## Les poses supposent un joueur au sol (le rendu pose alors les pieds sur le sol) ; faux pour les clips aériens.
var grounded := true
## Si le joueur est en l'air, les jambes sont reprises de cette animation (ex. « jump ») ; "" = jambes du clip.
var air_legs := ""
## Si le joueur est au sol et se déplace, les jambes sont reprises de cette animation (ex. « run ») : pas de glissement.
var move_legs := ""
var blend_in_s := 0.08
## Repère de départ de la fenêtre (domaine window), "" = début du clip.
var window_start := ""
var times := PackedFloat32Array()
var poses: Array[Dictionary] = []
var markers: Dictionary = {}   # nom -> t (s)


## Pose {os: angle} à l'instant `t` (secondes du clip). Hors bornes : première / dernière pose (ou boucle).
func sample(t: float) -> Dictionary:
	if poses.is_empty():
		return {}
	if loop and duration_s > 0.0:
		t = fposmod(t, duration_s)
	if poses.size() == 1 or t <= times[0]:
		return poses[0].duplicate()
	var last := poses.size() - 1
	if t >= times[last]:
		if loop and duration_s > times[last]:   # retour vers la première pose
			return _blend(poses[last], poses[0], (t - times[last]) / (duration_s - times[last]))
		return poses[last].duplicate()
	var i := 0
	while i < last - 1 and t >= times[i + 1]:
		i += 1
	if spline:
		return _hermite(i, t)
	return _blend(poses[i], poses[i + 1], (t - times[i]) / (times[i + 1] - times[i]))


func marker(name: String, fallback: float) -> float:
	return float(markers.get(name, fallback))


func has_marker(name: String) -> bool:
	return markers.has(name)


## Segment [i, i+1] en Hermite monotone (Fritsch-Butland) : tangente nulle aux extrémités du clip et là où le
## mouvement change de sens, moyenne harmonique pondérée des pentes sinon.
func _hermite(i: int, t: float) -> Dictionary:
	var t0 := times[i]
	var t1 := times[i + 1]
	var h := t1 - t0
	var u := (t - t0) / h
	var out := {}
	var bones := {}
	for k in range(maxi(i - 1, 0), mini(i + 3, poses.size())):
		for bone: String in poses[k]:
			bones[bone] = true
	for bone: String in bones:
		var p0 := float(poses[i].get(bone, 0.0))
		var p1 := p0 + angle_difference(p0, float(poses[i + 1].get(bone, 0.0)))
		var m0 := 0.0
		var m1 := 0.0
		if i > 0:
			var pm := p0 - angle_difference(float(poses[i - 1].get(bone, 0.0)), float(poses[i].get(bone, 0.0)))
			m0 = _tangent((p0 - pm) / (t0 - times[i - 1]), (p1 - p0) / h, t0 - times[i - 1], h)
		if i + 2 < poses.size():
			var p2 := p1 + angle_difference(float(poses[i + 1].get(bone, 0.0)), float(poses[i + 2].get(bone, 0.0)))
			m1 = _tangent((p1 - p0) / h, (p2 - p1) / (times[i + 2] - t1), h, times[i + 2] - t1)
		var u2 := u * u
		var u3 := u2 * u
		out[bone] = (2.0 * u3 - 3.0 * u2 + 1.0) * p0 + (u3 - 2.0 * u2 + u) * h * m0 + (-2.0 * u3 + 3.0 * u2) * p1 + (u3 - u2) * h * m1
	return out


static func _tangent(left: float, right: float, h_left: float, h_right: float) -> float:
	if left * right <= 0.0:
		return 0.0
	return 3.0 * (h_left + h_right) / ((2.0 * h_right + h_left) / left + (h_right + 2.0 * h_left) / right)


func _blend(a: Dictionary, b: Dictionary, u: float) -> Dictionary:
	if smooth:
		u = u * u * (3.0 - 2.0 * u)
	return Pose.mix(a, b, u)


## Clip « pose de repos » (dernier recours quand un clip est introuvable).
static func rest_clip(clip_id: String, action_name: String) -> AnimationClip:
	var c := AnimationClip.new()
	c.id = clip_id
	c.action = action_name
	c.loop = true
	c.times = PackedFloat32Array([0.0])
	c.poses = [{}]
	return c


## Lit et valide un clip. Renvoie null (et note une erreur) si le fichier est inutilisable ; les défauts
## localisés (os inconnu, angle absurde…) sont corrigés en signalant le problème.
static func from_file(path: String, issues: Array[LoadIssue]) -> AnimationClip:
	var root: Variant = JsonLoader.load_object(path, issues)
	if root == null:
		return null
	var r := SchemaReader.new(path, root, issues)
	if not r.check_version(SCHEMA_VERSION):
		return null
	r.warn_unknown_keys(KEYS)
	var c := AnimationClip.new()
	c.id = r.require_string("id", ID_PATTERN)
	if c.id == "":
		return null
	if c.id != path.get_file().get_basename():
		r.error("id", "« %s » diffère du nom du fichier" % c.id)
		return null
	c.action = r.require_string("action", ID_PATTERN)
	if c.action == "":
		return null
	c.duration_s = r.read_float("duration_s", 0.05, MAX_DURATION_S, 1.0, true).value
	c.loop = r.read_bool("loop", false)
	c.time_domain = r.optional_string("time_domain", "seconds")
	if not DOMAINS.has(c.time_domain):
		r.error("time_domain", "domaine inconnu « %s » : seconds utilisé" % c.time_domain)
		c.time_domain = "seconds"
	var mode := r.optional_string("pose_mode", "absolute")
	if mode != "absolute":
		r.error("pose_mode", "« %s » non pris en charge en V1 : absolute utilisé" % mode)
	var interp := r.optional_string("default_interpolation", "linear")
	if interp != "linear" and interp != "smooth" and interp != "spline":
		r.error("default_interpolation", "« %s » inconnu : linear utilisé" % interp)
		interp = "linear"
	c.smooth = interp == "smooth"
	c.spline = interp == "spline"
	c.grounded = r.read_bool("grounded", true)
	c.air_legs = r.optional_string("air_legs", "")
	c.move_legs = r.optional_string("move_legs", "")
	c.window_start = r.optional_string("window_start", "")
	c.blend_in_s = r.read_float("blend_in_s", 0.0, 1.0, 0.08, false).value
	c.stride_m = r.read_float("stride_m", 0.2, 10.0, 1.9, false).value
	c.air_ref_speed = r.read_float("air_ref_speed", 1.0, 30.0, 9.5, false).value
	c._read_events(r)
	if not c._read_keyframes(r):
		return null
	if c.time_domain == "window" and not c.markers.has("impact"):
		r.warning("events", "domaine window sans repère « impact » : 40 %% de la durée utilisé")
		c.markers["impact"] = c.duration_s * 0.4
	if c.window_start != "" and not c.markers.has(c.window_start):
		r.error("window_start", "repère « %s » introuvable : début du clip utilisé" % c.window_start)
		c.window_start = ""
	return c


func _read_events(r: SchemaReader) -> void:
	if not r.has("events"):
		return
	var raw: Variant = r.data.events
	if not raw is Array:
		r.error("events", "tableau attendu")
		return
	for i in (raw as Array).size():
		var e: Variant = raw[i]
		if not e is Dictionary or not e.has("name") or not e.has("t") or not (e.t is int or e.t is float):
			r.error("events[%d]" % i, "repère invalide (attendu : {name, t, type})")
			continue
		var t := float(e.t)
		if t < 0.0 or t > duration_s:
			r.error("events[%d].t" % i, "%s hors du clip [0, %s]" % [t, duration_s])
			continue
		markers[String(e.name)] = t


func _read_keyframes(r: SchemaReader) -> bool:
	if not r.has("keyframes") or not r.data.keyframes is Array or (r.data.keyframes as Array).is_empty():
		r.error("keyframes", "au moins une pose clé attendue")
		return false
	var raw: Array = r.data.keyframes
	var previous_t := -1.0
	for i in raw.size():
		var k: Variant = raw[i]
		var field := "keyframes[%d]" % i
		if not k is Dictionary or not k.has("t") or not (k.t is int or k.t is float) or not k.has("pose") or not k.pose is Dictionary:
			r.error(field, "pose clé invalide (attendu : {t, pose})")
			continue
		var t := float(k.t)
		if t < 0.0 or t > duration_s or t <= previous_t:
			r.error(field + ".t", "%s : temps hors du clip ou non croissant, pose ignorée" % t)
			continue
		previous_t = t
		var pose := {}
		for bone: Variant in k.pose:
			var name := String(bone)
			var v: Variant = k.pose[bone]
			if not RigDef.is_bone(name):
				r.warning("%s.pose.%s" % [field, name], "os inconnu, ignoré")
			elif not (v is int or v is float) or absf(float(v)) > RigDef.MAX_ANGLE or is_nan(float(v)):
				r.error("%s.pose.%s" % [field, name], "angle invalide (%s) : repos utilisé" % [v])
			else:
				pose[name] = float(v)
		times.append(t)
		poses.append(pose)
	if poses.is_empty():
		r.error("keyframes", "aucune pose clé valide")
		return false
	return true
