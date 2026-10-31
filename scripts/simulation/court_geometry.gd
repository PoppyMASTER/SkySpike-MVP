class_name CourtGeometry
extends RefCounted
## Géométrie du terrain (mètres) : filet en x = 0, sol en y = 0. Figée au début du match.

var half_length := 9.0
var net_height := 2.43
var net_half_thickness := 0.05
var out_margin := 3.0


static func from_params(p: ParamStore) -> CourtGeometry:
	var c := CourtGeometry.new()
	c.half_length = p.get_value(ParamIds.COURT_HALF_LENGTH)
	c.net_height = p.get_value(ParamIds.NET_HEIGHT)
	c.net_half_thickness = p.get_value(ParamIds.NET_THICKNESS) * 0.5
	c.out_margin = p.get_value(ParamIds.COURT_OUT_MARGIN)
	return c


## Boîte de collision du filet, du sol au bord supérieur.
func net_box() -> Rect2:
	return Rect2(-net_half_thickness, 0.0, net_half_thickness * 2.0, net_height)
