class_name MannequinRig
extends Node2D
## Mannequin humanoïde : Skeleton2D + 17 Bone2D (hiérarchie de RigDef) et pièces rigides gris anthracite
## accrochées aux os. Un liseré d'équipe entoure la silhouette (pièces agrandies derrière le corps), le reste
## du corps n'est jamais coloré. Le rig ne lit que des AnimFrame : il ne touche jamais à la simulation.
## Pour passer à des sprites, remplacer `_build_pieces` : le squelette, les poses et l'animateur restent.

const COLOR_BODY := Color("3b4046")
const COLOR_BODY_FAR := Color("2c3035")
const COLOR_JOINT := Color("5a626b")
const TRIM_WIDTH_M := 0.022
const Z_TRIM := 1
const Z_FAR := 2
const Z_NEAR := 3
const ARC_STEPS := 8

var skeleton: Skeleton2D
var bones: Dictionary = {}   # nom -> Bone2D
var dims: RigDims
var offsets: Dictionary
var trim_color := Color.WHITE


func build(rig_dims: RigDims, team_color: Color) -> void:
	dims = rig_dims
	offsets = RigDef.rest_offsets(dims)
	trim_color = team_color
	skeleton = Skeleton2D.new()
	skeleton.name = "Skeleton"
	add_child(skeleton)
	for bone_name in RigDef.BONES:
		var bone := Bone2D.new()
		bone.name = bone_name
		bone.position = offsets[bone_name]
		bone.rest = Transform2D(0.0, offsets[bone_name])
		bone.auto_calculate_length_and_angle = false
		bone.set_length(_bone_length(bone_name))
		var parent: String = RigDef.PARENTS.get(bone_name, "")
		if parent == "":
			skeleton.add_child(bone)
		else:
			var parent_bone: Bone2D = bones[parent]
			parent_bone.add_child(bone)
		bones[bone_name] = bone
	_build_pieces()


## Applique une pose : rotations des os, décalage vertical pour poser les pieds.
func apply(frame: AnimFrame) -> void:
	for bone_name: String in bones:
		(bones[bone_name] as Bone2D).rotation = float(frame.pose.get(bone_name, 0.0))
	skeleton.position = Vector2(0.0, frame.shift_y)


## Place le rig à l'écran : pieds en `feet`, `pixels_per_meter` px par mètre, tourné vers `facing` (±1).
func place(feet: Vector2, pixels_per_meter: float, facing: int) -> void:
	position = feet
	scale = Vector2(pixels_per_meter * facing, pixels_per_meter)


func bone_position(bone_name: String) -> Vector2:
	return (bones[bone_name] as Bone2D).global_position


## Extrémité d'un os (l'origine de son enfant) : sert au tracé du squelette de debug.
func bone_tip(bone_name: String) -> Vector2:
	for child: String in RigDef.PARENTS:
		if RigDef.PARENTS[child] == bone_name:
			return bone_position(child)
	return bone_position(bone_name)


# ------------------------------------------------------------------ pièces
func _build_pieces() -> void:
	var t := dims.thickness
	var s := dims.scale
	_add("pelvis", _ellipse(Vector2(0.0, -0.03 * s), 0.125 * t, 0.095 * s))
	_add("torso", _capsule(dims.torso, 0.12 * t, 0.15 * t, true))
	_add("neck", _capsule(dims.neck + 0.03 * s, 0.045 * t, 0.045 * t, true))
	var head := _ellipse(Vector2(0.01, -dims.head * 0.48), 0.105 * s, dims.head * 0.5)
	head.append_array(PackedVector2Array([Vector2(0.10, -dims.head * 0.56) * s, Vector2(0.15, -dims.head * 0.42) * s, Vector2(0.10, -dims.head * 0.34) * s]))
	_add("head", Geometry2D.convex_hull(head))
	for side in ["l", "r"]:
		_add("upper_arm_" + side, _capsule(dims.upper_arm, 0.05 * t, 0.042 * t, false))
		_add("forearm_" + side, _capsule(dims.forearm, 0.042 * t, 0.034 * t, false))
		_add("hand_" + side, _ellipse(Vector2(0.0, dims.hand * 0.5), 0.036 * s, dims.hand * 0.55))
		_add("thigh_" + side, _capsule(dims.thigh, 0.078 * t, 0.058 * t, false))
		_add("shin_" + side, _capsule(dims.shin, 0.056 * t, 0.04 * t, false))
		_add("foot_" + side, _foot())
	for joint in ["upper_arm_l", "upper_arm_r", "forearm_l", "forearm_r", "thigh_l", "thigh_r", "shin_l", "shin_r", "foot_l", "foot_r"]:
		_add_joint(joint)


func _add(bone_name: String, shape: PackedVector2Array) -> void:
	var far := RigDef.FAR_BONES.has(bone_name)
	var trim := Polygon2D.new()
	var grown := Geometry2D.offset_polygon(shape, TRIM_WIDTH_M, Geometry2D.JOIN_ROUND)
	trim.polygon = grown[0] if not grown.is_empty() else shape
	trim.color = trim_color
	trim.antialiased = true
	trim.z_as_relative = false
	trim.z_index = Z_TRIM
	(bones[bone_name] as Bone2D).add_child(trim)
	var piece := Polygon2D.new()
	piece.polygon = shape
	piece.color = COLOR_BODY_FAR if far else COLOR_BODY
	piece.antialiased = true
	piece.z_as_relative = false
	piece.z_index = Z_FAR if far else Z_NEAR
	(bones[bone_name] as Bone2D).add_child(piece)


## Articulation légèrement visible : petit disque plus clair à l'origine de l'os.
func _add_joint(bone_name: String) -> void:
	var disc := Polygon2D.new()
	disc.polygon = _ellipse(Vector2.ZERO, 0.045 * dims.scale, 0.045 * dims.scale)
	disc.color = COLOR_JOINT
	disc.antialiased = true
	disc.z_as_relative = false
	disc.z_index = (Z_FAR if RigDef.FAR_BONES.has(bone_name) else Z_NEAR) + 0
	(bones[bone_name] as Bone2D).add_child(disc)


func _bone_length(bone_name: String) -> float:
	match bone_name:
		"torso": return dims.torso
		"neck": return dims.neck
		"head": return dims.head
		"upper_arm_l", "upper_arm_r": return dims.upper_arm
		"forearm_l", "forearm_r": return dims.forearm
		"hand_l", "hand_r": return dims.hand
		"thigh_l", "thigh_r": return dims.thigh
		"shin_l", "shin_r": return dims.shin
		"foot_l", "foot_r": return dims.foot_forward
	return 0.1


## Capsule le long de l'os : vers le bas (membres) ou vers le haut (tronc), rayons r0 → r1.
static func _capsule(length: float, r0: float, r1: float, up: bool) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var dir := -1.0 if up else 1.0
	for i in range(ARC_STEPS + 1):   # extrémité de départ (arc arrière)
		var a := PI + PI * float(i) / ARC_STEPS
		pts.append(Vector2(cos(a) * r0, dir * sin(a) * r0))
	for i in range(ARC_STEPS + 1):   # extrémité d'arrivée
		var a := PI * float(i) / ARC_STEPS
		pts.append(Vector2(cos(a) * r1, dir * length + dir * sin(a) * r1))
	return pts


static func _ellipse(center: Vector2, rx: float, ry: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 16:
		var a := TAU * float(i) / 16.0
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	return pts


func _foot() -> PackedVector2Array:
	var d := dims
	return PackedVector2Array([
		Vector2(-d.foot_back, d.ankle - 0.03 * d.scale), Vector2(-d.foot_back + 0.02, d.ankle),
		Vector2(d.foot_forward - 0.03, d.ankle), Vector2(d.foot_forward, d.ankle - 0.025 * d.scale),
		Vector2(0.07 * d.scale, -0.035 * d.scale), Vector2(-0.04 * d.scale, -0.035 * d.scale)])
