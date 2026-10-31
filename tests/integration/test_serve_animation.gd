extends TestCase
## Animations de service (J4.1 sous-jalon 1) : trois frappes distinctes pilotées par l'intention partagée avec la
## simulation, pieds plantés, impulsion immédiate, suivi et atterrissage selon le type CONFIRMÉ, aucun effet sur la physique.

const E := MatchEvent.Type
## Scénarios scriptés (humain) : ticks de maintien de L, du saut (Espace) et de la frappe (L), comptés après le lancer.
const GROUND := [0, -1, 18]
const FLOAT := [0, 40, 42]
const SMASH := [150, 12, 30]
const MISS := [0, -1, 150]

var _lib: ClipLibrary


func _library() -> ClipLibrary:
	if _lib == null:
		_lib = ClipLibrary.new()
		_lib.load_all("res://data")
	return _lib


func _animator(character_id := "std_attacker_01") -> RigAnimator:
	return RigAnimator.new(_library(), SimHelpers.data().characters.get_character(character_id))


## Joue un service scripté et note, à chaque tick, l'instantané, la pose et les événements.
func _trace(script: Array, animator_settings := {}) -> Dictionary:
	var lineup := MatchConfig.default_lineup(SimHelpers.data().characters)
	var sim := MatchSim.new(SimHelpers.fresh_params(), 1, 1.0 / 120.0, lineup, -1)
	sim.ctx.human_slot = sim.ctx.rally.server_slot
	var server := sim.actors[sim.ctx.rally.server_slot]
	var animator := RigAnimator.new(_library(), lineup[server.slot])
	for key: String in animator_settings:
		animator.set(key, animator_settings[key])
	var mk := func(i: PlayerIntent) -> Array[PlayerIntent]:
		var out: Array[PlayerIntent] = []
		for k in sim.actors.size():
			out.append(i if k == server.slot else PlayerIntent.make())
		return out
	for i in 2000:
		if server.state == Enums.ActionState.SERVE_HOLD:
			break
		sim.tick(mk.call(PlayerIntent.make()))
	sim.tick(mk.call(PlayerIntent.make(0, false, false, false, false, true, true)))
	for i in script[0]:
		sim.tick(mk.call(PlayerIntent.make(0, false, false, false, false, false, true)))
	sim.tick(mk.call(PlayerIntent.make()))
	var frames: Array[AnimFrame] = []
	var snaps: Array[PlayerSnapshot] = []
	var events: Array = []   # [tick, MatchEvent]
	var jump_tick := -1
	var last_window_frame: AnimFrame
	var contact_frame: AnimFrame
	var contact_snap: PlayerSnapshot
	var intent_before_contact := ""
	var previous: PlayerSnapshot
	for i in 500:
		var it := PlayerIntent.make(0.0, i == script[1])
		if i == script[2]:
			it = PlayerIntent.make(0, false, false, false, false, true, true)
		var before_intent := server.strike.intent
		var evs := sim.tick(mk.call(it))
		var snap := sim.state().players[server.slot]
		var frame := animator.evaluate(snap, previous, 1.0, sim.state().tick, 1.0 / 120.0)
		frames.append(frame)
		snaps.append(snap)
		previous = snap
		if snap.action == Enums.ActionState.SERVE_JUMP and jump_tick < 0:
			jump_tick = frames.size() - 1
		if snap.action == Enums.ActionState.SERVE_HIT:
			last_window_frame = frame
		for e in evs:
			events.append([frames.size() - 1, e])
			if e.type == E.CONTACT and e.details.action == "serve":
				contact_frame = last_window_frame
				contact_snap = snap
				intent_before_contact = String(e.details.serve_intent)
	return {"frames": frames, "snaps": snaps, "events": events, "jump_tick": jump_tick, "contact_frame": contact_frame, "contact_snap": contact_snap,
		"sim": sim, "server": server, "animator": animator}


func _contact(trace: Dictionary) -> MatchEvent:
	for pair: Array in trace.events:
		var e: MatchEvent = pair[1]
		if e.type == E.CONTACT and e.details.action == "serve":
			return e
	return null


# ------------------------------------------------------------------ clips
func test_new_clips_load_with_their_markers() -> void:
	var lib := _library()
	assert_eq(lib.issues.size(), 0, "aucun problème de chargement")
	for id in ["serve_ground_v1", "serve_float_v1", "serve_smash_v1"]:
		var c := lib.get_clip(id)
		assert_true(c != null and c.has_marker("cock") and c.has_marker("impact") and c.time_domain == "window", "%s : repères cock et impact, fenêtre" % id)
	var toss := lib.get_clip("serve_toss_v1")
	for m in ["squash", "squash_end", "release", "cock"]:
		assert_true(toss.has_marker(m), "lancer : repère %s" % m)
	assert_true(lib.get_clip("land_float_v1") != null and lib.get_clip("land_smash_v1") != null, "atterrissages flottant et smash")


# ------------------------------------------------------------------ pieds plantés
## Points d'appui au sol : talon du pied avant (gauche) et pointe du pied arrière (droit). Le service au sol
## transfère le poids en levant la pointe avant puis le talon arrière : ces deux points pivots ne bougent jamais.
## Renvoie [x talon avant, x pointe arrière, hauteur au-dessus du sol du talon avant, de la pointe arrière].
func _pivots(a: RigAnimator, pose: Dictionary) -> Array:
	var g := RigDef.forward_kinematics(pose, a.offsets)
	var ground := RigDef.lowest_sole(g, a.dims)
	var heel: Vector2 = (g["foot_l"] as Transform2D) * Vector2(-a.dims.foot_back, a.dims.ankle)
	var toe: Vector2 = (g["foot_r"] as Transform2D) * Vector2(a.dims.foot_forward, a.dims.ankle)
	return [heel.x, toe.x, ground - heel.y, ground - toe.y]


func test_feet_stay_planted_during_prep_toss_and_ground_strike() -> void:
	for character_id in ["std_attacker_01", "hammer_01", "std_setter_02"]:
		var a := _animator(character_id)
		for id in ["serve_prep_v1", "serve_toss_v1", "serve_ground_v1"]:
			var clip := _library().get_clip(id)
			var lo := [INF, INF]
			var hi := [-INF, -INF]
			for k in 21:
				var p := _pivots(a, clip.sample(clip.duration_s * k / 20.0))
				for f in 2:
					lo[f] = minf(lo[f], p[f])
					hi[f] = maxf(hi[f], p[f])
					assert_true(float(p[2 + f]) < 0.012 * a.dims.scale, "%s / %s : appui %d au sol (%.3f m)" % [character_id, id, f, p[2 + f]])
			for f in 2:
				assert_true(hi[f] - lo[f] < 0.015 * a.dims.scale, "%s / %s : appui %d planté (dérive %.3f m)" % [character_id, id, f, hi[f] - lo[f]])


# ------------------------------------------------------------------ choix du clip
func test_intent_selects_the_clip_and_variants_can_be_switched_off() -> void:
	var expected := {"ground": "serve_ground_v1", "float": "serve_float_v1", "smash": "serve_smash_v1", "": "serve_v1"}
	for intent: String in expected:
		var s := PlayerSnapshot.new()
		s.action = Enums.ActionState.SERVE_HIT
		s.action_ideal = 0.12
		s.action_time = 0.05
		s.serve_intent = intent
		assert_eq(_animator().evaluate(s, null, 1.0, 5, 0.01).clip_id, expected[intent], "intention « %s »" % intent)
	var off := _animator()
	off.variants_enabled = false
	var s2 := PlayerSnapshot.new()
	s2.action = Enums.ActionState.SERVE_HIT
	s2.action_ideal = 0.12
	s2.serve_intent = "smash"
	assert_eq(off.evaluate(s2, null, 1.0, 5, 0.01).clip_id, "serve_v1", "variantes désactivées : même geste pour tous")


func test_float_and_smash_are_visibly_different() -> void:
	var f := _library().get_clip("serve_float_v1")
	var s := _library().get_clip("serve_smash_v1")
	var at := func(c: AnimationClip, marker: String) -> Dictionary:
		return c.sample(c.marker(marker, 0.0))
	var windup := func(c: AnimationClip) -> Dictionary:   # armé : 2e pose clé, juste avant le geste
		return c.sample(c.times[1])
	assert_true(float(windup.call(s)["upper_arm_r"]) > float(windup.call(f)["upper_arm_r"]) + 0.5, "smash : bras plus armé derrière le corps")
	assert_true(float(windup.call(s)["torso"]) < float(windup.call(f)["torso"]) - 0.25, "smash : buste plus cambré avant la frappe")
	assert_true(float(at.call(s, "impact")["torso"]) > float(at.call(f, "impact")["torso"]) + 0.2, "smash : buste plus engagé à l'impact")
	assert_true(s.duration_s > f.duration_s + 0.2, "smash : suivi du geste plus long")
	var lf := _library().get_clip("land_float_v1")
	var ls := _library().get_clip("land_smash_v1")
	var flex := func(c: AnimationClip) -> float:
		var best := 0.0
		for k in 11:
			best = maxf(best, absf(float(c.sample(c.duration_s * k / 10.0)["thigh_l"])))
		return best
	assert_true(flex.call(ls) > flex.call(lf) + 0.1, "atterrissage du smash : jambes plus fléchies")


# ------------------------------------------------------------------ cohérence intention / clip / résultat
func test_intent_clip_and_real_result_agree_for_each_service() -> void:
	var cases := {"ground": GROUND, "float": FLOAT, "smash": SMASH}
	for kind: String in cases:
		var t := _trace(cases[kind])
		var contact := _contact(t)
		assert_true(contact != null, "%s : le service touche le ballon" % kind)
		if contact == null:
			continue
		assert_eq(contact.details.serve_kind, kind, "%s : type réel" % kind)
		assert_eq(contact.details.serve_intent, kind, "%s : intention annoncée = type réel" % kind)
		var frame: AnimFrame = t.contact_frame
		assert_true(frame != null and frame.clip_id == "serve_%s_v1" % kind, "%s : clip joué pendant la fenêtre (%s)" % [kind, frame.clip_id if frame != null else "-"])
		var last: PlayerSnapshot = t.contact_snap
		assert_eq(last.strike_kind, kind, "%s : type confirmé mémorisé pour le suivi" % kind)


func test_landing_uses_the_confirmed_serve_type() -> void:
	for pair in [["float", FLOAT], ["smash", SMASH]]:
		var t := _trace(pair[1])
		var seen := false
		for i in t.frames.size():
			var s: PlayerSnapshot = t.snaps[i]
			if s.action == Enums.ActionState.RECOVER and s.strike_age < RigAnimator.LAND_WINDOW_S:
				seen = seen or t.frames[i].clip_id == "land_%s_v1" % pair[0]
		assert_true(seen, "%s : atterrissage du bon type" % pair[0])


func test_ground_strike_plays_a_follow_through_without_leaving_the_floor() -> void:
	var t := _trace(GROUND)
	var follow := 0
	for i in t.frames.size():
		var s: PlayerSnapshot = t.snaps[i]
		if s.action != Enums.ActionState.SERVE_HIT and s.strike_age > 0.0 and s.strike_age < 0.2 and t.frames[i].clip_id == "serve_ground_v1":
			follow += 1
			assert_true(s.grounded, "suivi au sol")
	assert_true(follow > 5, "le suivi du geste est joué après le contact (%d images)" % follow)


func test_missed_strike_makes_no_contact_and_still_finishes_a_coherent_gesture() -> void:
	var t := _trace(MISS)
	assert_true(_contact(t) == null, "aucun contact artificiel")
	var missed := false
	for pair: Array in t.events:
		missed = missed or (pair[1].type == E.ACTION_MISSED and pair[1].details.action == "serve")
	assert_true(missed, "frappe manquée signalée par la simulation")
	var saw_hit_clip := false
	for i in t.frames.size():
		if (t.snaps[i] as PlayerSnapshot).action == Enums.ActionState.SERVE_HIT:
			saw_hit_clip = saw_hit_clip or t.frames[i].clip_id.begins_with("serve_")
	assert_true(saw_hit_clip, "le geste de frappe est joué jusqu'à la fin de la fenêtre")


func test_impact_marker_follows_the_real_contact_and_animation_never_changes_the_simulation() -> void:
	for script in [GROUND, FLOAT, SMASH]:
		var t := _trace(script)
		var frame: AnimFrame = t.contact_frame
		var clip := _library().get_clip(frame.clip_id)
		assert_true(absf(frame.clip_time - clip.marker("impact", 0.0)) < 0.08, "%s : l'impact visuel tombe sur le contact réel (écart %.3f s)" % [frame.clip_id, absf(frame.clip_time - clip.marker("impact", 0.0))])
	# Même service avec et sans évaluation de l'animation : empreinte identique, mêmes événements.
	var with := _trace(SMASH)
	var lineup := MatchConfig.default_lineup(SimHelpers.data().characters)
	var bare := MatchSim.new(SimHelpers.fresh_params(), 1, 1.0 / 120.0, lineup, -1)
	bare.ctx.human_slot = bare.ctx.rally.server_slot
	var server := bare.actors[bare.ctx.rally.server_slot]
	var mk := func(i: PlayerIntent) -> Array[PlayerIntent]:
		var out: Array[PlayerIntent] = []
		for k in bare.actors.size():
			out.append(i if k == server.slot else PlayerIntent.make())
		return out
	for i in 2000:
		if server.state == Enums.ActionState.SERVE_HOLD:
			break
		bare.tick(mk.call(PlayerIntent.make()))
	bare.tick(mk.call(PlayerIntent.make(0, false, false, false, false, true, true)))
	for i in SMASH[0]:
		bare.tick(mk.call(PlayerIntent.make(0, false, false, false, false, false, true)))
	bare.tick(mk.call(PlayerIntent.make()))
	for i in 500:
		var it := PlayerIntent.make(0.0, i == SMASH[1])
		if i == SMASH[2]:
			it = PlayerIntent.make(0, false, false, false, false, true, true)
		bare.tick(mk.call(it))
	assert_eq(bare.state().fingerprint(), (with.sim as MatchSim).state().fingerprint(), "l'évaluation de l'animation ne change pas la simulation")


# ------------------------------------------------------------------ impulsion et compression
func test_jump_impulse_is_immediate_and_the_visual_squash_is_brief() -> void:
	var t := _trace(SMASH)
	var j: int = t.jump_tick
	assert_true(j > 0, "le saut a lieu")
	var snap: PlayerSnapshot = t.snaps[j]
	assert_true(snap.velocity.y > 0.0, "vitesse verticale positive dès le tick de la commande (%.2f m/s)" % snap.velocity.y)
	var jump_clip := _library().get_clip("serve_jump_v1")
	var early: AnimFrame = t.frames[j]
	assert_eq(early.clip_id, "serve_jump_v1", "clip d'impulsion du service")
	var ext_t := jump_clip.marker("extension", -1.0)
	assert_true(ext_t > 0.0 and ext_t <= 0.08, "extension complète en moins de 0,08 s (%.3f s)" % ext_t)
	var squash := jump_clip.sample(0.0)
	var extended := jump_clip.sample(ext_t)
	var k := j + int(ceil(ext_t * 120.0))
	var late: AnimFrame = t.frames[k]
	assert_true(absf(float(early.pose["thigh_l"]) - float(squash["thigh_l"])) < absf(float(early.pose["thigh_l"]) - float(extended["thigh_l"])), "compression visuelle au déclenchement")
	assert_true(absf(float(late.pose["shin_l"]) - float(squash["shin_l"])) > 0.5 * absf(float(extended["shin_l"]) - float(squash["shin_l"])), "puis extension immédiate (jambes dépliées après %d ticks)" % (k - j))


# ------------------------------------------------------------------ transitions
func test_transitions_have_no_sudden_pops() -> void:
	# Un geste rapide (la frappe) a une vitesse élevée mais régulière : on cherche les à-coups, c'est-à-dire les
	# variations brutales de cette vitesse d'un tick à l'autre (accélération par tick). Un geste de frappe de 6 rad en
	# 0,12 s atteint ≈ 0,4 rad/tick² ; un vrai à-coup (changement de pose sans fondu) dépasse 1 rad/tick².
	for script in [GROUND, FLOAT, SMASH]:
		var t := _trace(script)
		var worst := 0.0
		var where := ""
		for i in range(2, t.frames.size()):
			var a: Dictionary = t.frames[i - 2].pose
			var b: Dictionary = t.frames[i - 1].pose
			var c: Dictionary = t.frames[i].pose
			for bone: String in c:
				var jerk := absf(angle_difference(float(b.get(bone, 0.0)), float(c[bone])) - angle_difference(float(a.get(bone, 0.0)), float(b.get(bone, 0.0))))
				if jerk > worst:
					worst = jerk
					where = "%s / %s" % [bone, t.frames[i].clip_id]
		assert_true(worst < 0.6, "transitions fluides, à-coup max %.3f rad/tick² (%s)" % [worst, where])


## Continuité articulation par articulation (épaules, coudes, poignets, buste, bassin/hanches, genoux) sur les trois
## services complets, du ballon tenu à la fin de l'atterrissage. Vitesse = rad/tick (120 ticks/s) ; à-coup =
## variation de vitesse d'un tick au suivant. Les mesures sont imprimées pour le rapport de livraison.
func test_joint_continuity_per_articulation() -> void:
	var groups := {
		"épaules": ["upper_arm_l", "upper_arm_r"], "coudes": ["forearm_l", "forearm_r"], "poignets": ["hand_l", "hand_r"],
		"buste": ["torso", "neck", "head"], "hanches": ["thigh_l", "thigh_r"], "genoux": ["shin_l", "shin_r"],
	}
	for name: String in {"sol": GROUND, "flottant": FLOAT, "smash": SMASH}:
		var script: Array = {"sol": GROUND, "flottant": FLOAT, "smash": SMASH}[name]
		var t := _trace(script)
		var line := "continuité %-9s" % name
		for g: String in groups:
			var speed := 0.0
			var jerk := 0.0
			var where := ""
			for i in range(2, t.frames.size()):
				var a: Dictionary = t.frames[i - 2].pose
				var b: Dictionary = t.frames[i - 1].pose
				var c: Dictionary = t.frames[i].pose
				for bone: String in groups[g]:
					var v1 := angle_difference(float(a.get(bone, 0.0)), float(b.get(bone, 0.0)))
					var v2 := angle_difference(float(b.get(bone, 0.0)), float(c.get(bone, 0.0)))
					if absf(v2) > speed:
						speed = absf(v2)
						where = "%s, %s t=%.3f" % [bone, t.frames[i].clip_id, t.frames[i].clip_time]
					jerk = maxf(jerk, absf(v2 - v1))
			line += " | %s v%.2f a%.2f" % [g, speed, jerk]
			# Le geste de frappe le plus rapide (bras) reste sous 0,6 rad/tick (≈ 70 rad/s) ; le reste du corps beaucoup moins.
			var max_speed := 0.6 if g in ["épaules", "coudes"] else 0.35
			assert_true(speed < max_speed, "%s / %s : vitesse max %.3f rad/tick (%s)" % [name, g, speed, where])
			assert_true(jerk < 0.6, "%s / %s : à-coup max %.3f rad/tick²" % [name, g, jerk])
		print(line)


# ------------------------------------------------------------------ autres personnages et réglages
func test_other_characters_and_missing_clips_stay_valid() -> void:
	for character_id in ["hammer_01", "std_defender_02", "std_setter_01"]:
		var a := _animator(character_id)
		for action in ["serve_prep", "serve_toss", "serve_jump", "serve_ground", "serve_float", "serve_smash", "land_float", "land_smash"]:
			var clip := _library().clip_for(a.anim_set, action)
			for k in 6:
				var frame := a.evaluate_clip(clip, clip.duration_s * k / 5.0, true)
				for bone: String in frame.pose:
					assert_true(is_finite(float(frame.pose[bone])), "%s / %s : angle fini" % [character_id, action])
				assert_true(absf(frame.shift_y) <= RigAnimator.MAX_SNAP_M + 1e-6, "%s / %s : calage au sol borné" % [character_id, action])
	var custom := SimHelpers.data().characters.get_character("std_attacker_01")
	var set := AnimationSetDefinition.new()
	set.overrides = {"serve_smash": "clip_inexistant"}
	custom.animation_set = set
	assert_eq(_library().clip_for(set, "serve_smash").id, "serve_smash_v1", "clip de remplacement introuvable : clip standard")


func test_display_settings_scale_the_gesture_but_not_the_legs_or_the_simulation() -> void:
	var s := PlayerSnapshot.new()
	s.action = Enums.ActionState.SERVE_HIT
	s.action_ideal = 0.12
	s.action_time = 0.12
	s.serve_intent = "smash"
	var base := _animator().evaluate(s, null, 1.0, 5, 0.01)
	var strong := _animator()
	strong.intensity = 1.5
	var big := strong.evaluate(s, null, 1.0, 5, 0.01)
	assert_near(float(big.pose["torso"]), float(base.pose["torso"]) * 1.5, 1e-4, "intensité : buste amplifié")
	assert_near(float(big.pose["thigh_l"]), float(base.pose["thigh_l"]), 1e-6, "les jambes ne changent pas : pieds plantés")
	var follow := PlayerSnapshot.new()
	follow.action = Enums.ActionState.AIR
	follow.grounded = false
	follow.strike_kind = "smash"
	follow.strike_age = 0.3
	follow.strike_ideal = 0.12
	follow.strike_window_time = 0.12
	var slow := _animator()
	slow.follow_scale = 2.0
	assert_true(slow.evaluate(follow, null, 1.0, 5, 0.01).clip_time < _animator().evaluate(follow, null, 1.0, 5, 0.01).clip_time, "durée du suivi : plus lent à 2")



func test_ai_services_announce_the_type_the_simulation_resolves() -> void:
	var total := 0
	var agree := 0
	for seed_value in range(1, 21):
		var lineup := MatchConfig.default_lineup(SimHelpers.data().characters)
		var sim := MatchSim.new(SimHelpers.fresh_params(), seed_value, 1.0 / 120.0, lineup, -1)
		var ai := AiDirector.new(sim.params, seed_value, 1.0 / 120.0, -1)
		ai.set_lineup(lineup)
		var done := false
		for i in 2500:
			for e in sim.tick(ai.intents(sim.state())):
				if e.type == E.CONTACT and e.details.action == "serve":
					total += 1
					agree += 1 if e.details.serve_intent == e.details.serve_kind else 0
					done = true
			if done:
				break
	assert_true(total >= 18, "services observés (%d)" % total)
	assert_eq(agree, total, "intention annoncée = type réel pour les %d services de l'IA" % total)
