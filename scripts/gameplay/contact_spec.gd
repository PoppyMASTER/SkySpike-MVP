class_name ContactSpec
extends RefCounted
## Paramètres d'une action à fenêtre (réception, passe, smash, feinte, service), lus depuis
## ParamStore : fenêtre [on, off], instant idéal, tolérance, zone dans le repère du joueur.

const RECEIVE := &"receive"
const SET := &"set"
const SPIKE := &"spike"
const FEINT := &"feint"
const SERVE := &"serve"

const IDS: Dictionary = {
	RECEIVE: [ParamIds.RECEIVE_ON, ParamIds.RECEIVE_OFF, ParamIds.RECEIVE_IDEAL, ParamIds.RECEIVE_TIME_TOL,
		ParamIds.RECEIVE_ZONE_DX, ParamIds.RECEIVE_ZONE_DY, ParamIds.RECEIVE_ZONE_RADIUS],
	SET: [ParamIds.SET_ON, ParamIds.SET_OFF, ParamIds.SET_IDEAL, ParamIds.SET_TIME_TOL,
		ParamIds.SET_ZONE_DX, ParamIds.SET_ZONE_DY, ParamIds.SET_ZONE_RADIUS],
	SPIKE: [ParamIds.SPIKE_ON, ParamIds.SPIKE_OFF, ParamIds.SPIKE_IDEAL, ParamIds.SPIKE_TIME_TOL,
		ParamIds.SPIKE_ZONE_DX, ParamIds.SPIKE_ZONE_DY, ParamIds.SPIKE_ZONE_RADIUS],
	FEINT: [ParamIds.FEINT_ON, ParamIds.FEINT_OFF, ParamIds.FEINT_IDEAL, ParamIds.FEINT_TIME_TOL,
		ParamIds.FEINT_ZONE_DX, ParamIds.FEINT_ZONE_DY, ParamIds.FEINT_ZONE_RADIUS],
	SERVE: [ParamIds.SERVE_ON, ParamIds.SERVE_OFF, ParamIds.SERVE_IDEAL, ParamIds.SERVE_TIME_TOL,
		ParamIds.SERVE_ZONE_DX, ParamIds.SERVE_ZONE_DY, ParamIds.SERVE_ZONE_RADIUS],
}

var kind: StringName
var t_on := 0.0
var t_off := 0.0
var ideal := 0.0
var tolerance := 0.1
var dx := 0.0
var dy := 0.0
var radius := 0.5


static func of(action_kind: StringName, p: ParamStore) -> ContactSpec:
	var ids: Array = IDS[action_kind]
	var s := ContactSpec.new()
	s.kind = action_kind
	s.t_on = p.get_value(ids[0])
	s.t_off = p.get_value(ids[1])
	s.ideal = p.get_value(ids[2])
	s.tolerance = p.get_value(ids[3])
	s.dx = p.get_value(ids[4])
	s.dy = p.get_value(ids[5])
	s.radius = p.get_value(ids[6])
	return s


## Centre de la zone pour un joueur aux pieds en `feet`, tourné dans le sens `facing`.
func center(feet: Vector2, facing: int) -> Vector2:
	return feet + Vector2(facing * dx, dy)
