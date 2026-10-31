class_name RigDims
extends RefCounted
## Dimensions (m) du rig d'un personnage, calculées par RigDef.dims_for à partir de sa morphologie.

var thigh := RigDef.THIGH
var shin := RigDef.SHIN
var ankle := RigDef.ANKLE_HEIGHT
var torso := RigDef.TORSO
var neck := RigDef.NECK
var head := RigDef.HEAD
var upper_arm := RigDef.UPPER_ARM
var forearm := RigDef.FOREARM
var hand := RigDef.HAND
var foot_forward := RigDef.FOOT_FORWARD
var foot_back := RigDef.FOOT_BACK
## Épaisseur relative des pièces (corpulence) et échelle générale.
var thickness := 1.0
var scale := 1.0


func leg_total() -> float:
	return thigh + shin + ankle


func standing_height() -> float:
	return leg_total() + torso + neck + head
