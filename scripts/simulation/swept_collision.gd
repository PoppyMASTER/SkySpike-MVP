class_name SweptCollision
extends RefCounted
## Collisions balayées : on teste le trajet entier d'un cercle pendant un tick, pas seulement
## sa position finale. Un ballon rapide ne peut donc pas traverser un filet fin.
## Le trajet est approché par le segment départ → arrivée (erreur négligeable sur un tick).

const EPS := 1e-9
## Distance de séparation laissée après un rebond, pour ne pas ré-entrer dans la surface.
const SKIN := 1e-4


## Premier contact d'un cercle de rayon `radius` allant de `from` à `to` avec la boîte `box`
## (y vers le haut). Renvoie null s'il n'y a pas de contact ou si le cercle s'éloigne déjà.
## Un cercle déjà en recouvrement est repoussé : t = 0, normale = direction de sortie.
static func circle_vs_box(from: Vector2, to: Vector2, radius: float, box: Rect2) -> SweepHit:
	var move := to - from
	var closest := Vector2(clampf(from.x, box.position.x, box.end.x), clampf(from.y, box.position.y, box.end.y))
	var offset := from - closest
	if offset.length_squared() < radius * radius:
		return _overlap_hit(from, move, radius, box, offset)
	var best: SweepHit = null
	var lo := box.position
	var hi := box.end
	# Faces : plans décalés de `radius`, limités à l'étendue de l'arête.
	var faces: Array[Dictionary] = [
		{"n": Vector2(-1, 0), "axis": 0, "at": lo.x - radius, "span_axis": 1, "lo": lo.y, "hi": hi.y},
		{"n": Vector2(1, 0), "axis": 0, "at": hi.x + radius, "span_axis": 1, "lo": lo.y, "hi": hi.y},
		{"n": Vector2(0, -1), "axis": 1, "at": lo.y - radius, "span_axis": 0, "lo": lo.x, "hi": hi.x},
		{"n": Vector2(0, 1), "axis": 1, "at": hi.y + radius, "span_axis": 0, "lo": lo.x, "hi": hi.x},
	]
	for face: Dictionary in faces:
		var n: Vector2 = face.n
		if move.dot(n) >= -EPS:
			continue
		var axis: int = face.axis
		var t := (float(face.at) - from[axis]) / move[axis]
		if t < 0.0 or t > 1.0:
			continue
		var p := from + move * t
		var s: float = p[int(face.span_axis)]
		if s < float(face.lo) or s > float(face.hi):
			continue
		best = _closer(best, t, n, p)
	# Coins : cercles de rayon `radius` centrés sur les quatre sommets.
	for corner: Vector2 in [lo, Vector2(hi.x, lo.y), Vector2(lo.x, hi.y), hi]:
		var t_hit := _ray_circle(from, move, corner, radius)
		if t_hit < 0.0 or t_hit > 1.0:
			continue
		var p := from + move * t_hit
		var n := (p - corner).normalized()
		if move.dot(n) >= -EPS:
			continue
		best = _closer(best, t_hit, n, p)
	return best


## Plus petite distance entre le point `p` et le segment [a, b].
static func point_segment_distance(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var len2 := ab.length_squared()
	if len2 <= EPS:
		return p.distance_to(a)
	var u := clampf((p - a).dot(ab) / len2, 0.0, 1.0)
	return p.distance_to(a + ab * u)


## Fraction (0 à 1) du segment [a, b] la plus proche du point `p`.
static func closest_fraction(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var len2 := ab.length_squared()
	if len2 <= EPS:
		return 0.0
	return clampf((p - a).dot(ab) / len2, 0.0, 1.0)


## Rebond : composante normale inversée et multipliée par `restitution`, tangente conservée.
static func reflect(velocity: Vector2, normal: Vector2, restitution: float) -> Vector2:
	var vn := velocity.dot(normal)
	if vn >= 0.0:
		return velocity
	return velocity - normal * vn * (1.0 + restitution)


static func _closer(best: SweepHit, t: float, n: Vector2, p: Vector2) -> SweepHit:
	if best != null and best.t <= t:
		return best
	var hit := SweepHit.new()
	hit.t = t
	hit.normal = n
	hit.center = p
	return hit


static func _overlap_hit(from: Vector2, move: Vector2, radius: float, box: Rect2, offset: Vector2) -> SweepHit:
	var n: Vector2
	if offset.length_squared() > EPS:
		n = offset.normalized()
	else:
		# Centre dans la boîte : sortie par la face la plus proche.
		var to_left := from.x - box.position.x
		var to_right := box.end.x - from.x
		var to_bottom := from.y - box.position.y
		var to_top := box.end.y - from.y
		var m := minf(minf(to_left, to_right), minf(to_bottom, to_top))
		if m == to_left:
			n = Vector2(-1, 0)
		elif m == to_right:
			n = Vector2(1, 0)
		elif m == to_bottom:
			n = Vector2(0, -1)
		else:
			n = Vector2(0, 1)
	if move.dot(n) >= -EPS:
		return null   # déjà en train de s'éloigner : pas de blocage
	var hit := SweepHit.new()
	hit.t = 0.0
	hit.normal = n
	hit.center = from
	return hit


## Plus petit t ≥ 0 où le rayon from + move·t entre dans le cercle (centre c, rayon r) ; -1 sinon.
static func _ray_circle(from: Vector2, move: Vector2, c: Vector2, r: float) -> float:
	var f := from - c
	var a := move.dot(move)
	if a <= EPS:
		return -1.0
	var b := 2.0 * f.dot(move)
	var cc := f.dot(f) - r * r
	var disc := b * b - 4.0 * a * cc
	if disc < 0.0:
		return -1.0
	var t := (-b - sqrt(disc)) / (2.0 * a)
	return t if t >= 0.0 else -1.0
