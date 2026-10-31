class_name Pose
extends RefCounted
## Aides sur les poses : dictionnaires {os: angle en radians}. Un os absent est au repos (0).
## Les angles s'interpolent par le plus court chemin (lerp_angle) : un bras qui passe de l'armé derrière
## l'épaule (+2,8) à la frappe haute (−3,05) tourne au-dessus de la tête, pas par le bas.


static func mix(a: Dictionary, b: Dictionary, u: float) -> Dictionary:
	var out := {}
	for bone: String in a:
		out[bone] = lerp_angle(float(a[bone]), float(b.get(bone, 0.0)), u)
	for bone: String in b:
		if not out.has(bone):
			out[bone] = lerp_angle(0.0, float(b[bone]), u)
	return out


## Copie de `base` dont les os `bones` viennent de `source`.
static func with_bones_from(base: Dictionary, source: Dictionary, bones: Array[String]) -> Dictionary:
	var out := base.duplicate()
	for bone in bones:
		if source.has(bone):
			out[bone] = source[bone]
		else:
			out.erase(bone)
	return out
