class_name RigDef
extends RefCounted
## Squelette commun aux six personnages : 17 os, hiérarchie, longueurs, cinématique directe.
## Repère du rig : mètres, x vers l'avant du personnage, y vers le BAS (convention Godot), origine = sol sous
## le personnage. Les angles des poses sont en radians, relatifs au repos, sens de rotation de Godot :
## - os qui pendent (bras, cuisses, jambes, pieds) : angle négatif = balancé vers l'AVANT, positif = vers l'arrière ;
## - os qui montent (torse, cou, tête) : angle positif = penché vers l'AVANT.
## La morphologie (taille, envergure, longueur de jambe, corpulence) ne change que le dessin.

const BONES: Array[String] = [
	"root", "pelvis", "torso", "neck", "head",
	"upper_arm_l", "forearm_l", "hand_l", "upper_arm_r", "forearm_r", "hand_r",
	"thigh_l", "shin_l", "foot_l", "thigh_r", "shin_r", "foot_r",
]
const PARENTS: Dictionary = {
	"pelvis": "root", "torso": "pelvis", "neck": "torso", "head": "neck",
	"upper_arm_l": "torso", "forearm_l": "upper_arm_l", "hand_l": "forearm_l",
	"upper_arm_r": "torso", "forearm_r": "upper_arm_r", "hand_r": "forearm_r",
	"thigh_l": "pelvis", "shin_l": "thigh_l", "foot_l": "shin_l",
	"thigh_r": "pelvis", "shin_r": "thigh_r", "foot_r": "shin_r",
}
## Os de la jambe (pour reprendre les jambes d'une autre animation quand le joueur est en l'air).
const LEG_BONES: Array[String] = ["thigh_l", "shin_l", "foot_l", "thigh_r", "shin_r", "foot_r"]
## Côté « loin » (dessiné derrière le corps) et côté « près ».
const FAR_BONES: Array[String] = ["upper_arm_l", "forearm_l", "hand_l", "thigh_l", "shin_l", "foot_l"]

const MAX_ANGLE := PI

## Gabarit standard (m) pour un personnage de morphologie 1.0 : 1,80 m debout.
const THIGH := 0.45
const SHIN := 0.44
const ANKLE_HEIGHT := 0.07
const TORSO := 0.52
const NECK := 0.08
const HEAD := 0.24
const UPPER_ARM := 0.30
const FOREARM := 0.26
const HAND := 0.09
const FOOT_FORWARD := 0.20
const FOOT_BACK := 0.07
const SHOULDER_DROP := 0.05
const JOINT_DX := 0.02


## Dimensions du rig pour une morphologie (valeurs visuelles uniquement).
static func dims_for(morph: MorphologyDefinition) -> RigDims:
	var d := RigDims.new()
	var s := 1.0
	var leg := 1.0
	var arm := 1.0
	var w := 1.0
	if morph != null:
		s = morph.height
		leg = morph.leg_length
		arm = morph.arm_span
		w = morph.weight
	d.scale = s
	d.thigh = THIGH * s * leg
	d.shin = SHIN * s * leg
	d.ankle = ANKLE_HEIGHT * s
	d.torso = TORSO * s
	d.neck = NECK * s
	d.head = HEAD * s
	d.upper_arm = UPPER_ARM * s * arm
	d.forearm = FOREARM * s * arm
	d.hand = HAND * s * arm
	d.foot_forward = FOOT_FORWARD * s
	d.foot_back = FOOT_BACK * s
	d.thickness = sqrt(w)
	return d


## Position de repos de chaque os dans le repère de son parent.
static func rest_offsets(d: RigDims) -> Dictionary:
	var side_dx := JOINT_DX * d.scale
	return {
		"root": Vector2.ZERO,
		"pelvis": Vector2(0.0, -d.leg_total()),
		"torso": Vector2.ZERO,
		"neck": Vector2(0.0, -d.torso),
		"head": Vector2(0.0, -d.neck),
		"upper_arm_l": Vector2(-side_dx, -d.torso + SHOULDER_DROP * d.scale),
		"forearm_l": Vector2(0.0, d.upper_arm),
		"hand_l": Vector2(0.0, d.forearm),
		"upper_arm_r": Vector2(side_dx, -d.torso + SHOULDER_DROP * d.scale),
		"forearm_r": Vector2(0.0, d.upper_arm),
		"hand_r": Vector2(0.0, d.forearm),
		"thigh_l": Vector2(-side_dx, 0.0),
		"shin_l": Vector2(0.0, d.thigh),
		"foot_l": Vector2(0.0, d.shin),
		"thigh_r": Vector2(side_dx, 0.0),
		"shin_r": Vector2(0.0, d.thigh),
		"foot_r": Vector2(0.0, d.shin),
	}


static func is_bone(name: String) -> bool:
	return BONES.has(name)


## Transformation globale (repère du rig) de chaque os pour une pose {os: angle}.
static func forward_kinematics(angles: Dictionary, offsets: Dictionary) -> Dictionary:
	var out := {}
	for bone in BONES:
		var local := Transform2D(float(angles.get(bone, 0.0)), offsets[bone])
		var parent: String = PARENTS.get(bone, "")
		out[bone] = local if parent == "" else (out[parent] as Transform2D) * local
	return out


## Ordonnée (y vers le bas) du point le plus bas des deux pieds : 0 = semelles au sol.
static func lowest_sole(global: Dictionary, d: RigDims) -> float:
	var lowest := -INF
	for foot in ["foot_l", "foot_r"]:
		var t: Transform2D = global[foot]
		for local in [Vector2(-d.foot_back, d.ankle), Vector2(d.foot_forward, d.ankle)]:
			lowest = maxf(lowest, (t * local).y)
	return lowest
