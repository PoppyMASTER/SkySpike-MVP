class_name AiMatch
extends RefCounted
## Joue un match complet IA contre IA sans affichage (mesures, tests, mode `--sim`).

const MAX_TICKS := 120 * 60 * 15   # 15 minutes de jeu


## Résultat : score, ticks, contacts, événements (texte), empreinte finale.
static func play(data: GameData, seed_value: int, max_ticks := MAX_TICKS, record_events := false) -> Dictionary:
	var lineup := MatchConfig.default_lineup(data.characters)
	var dt := 1.0 / data.params.get_value(ParamIds.SIM_HZ)
	var sim := MatchSim.new(data.params, seed_value, dt, lineup, -1)
	var ai := AiDirector.new(data.params, seed_value, dt, -1)
	ai.set_lineup(lineup)
	var counts := {"contacts": 0, "blocks": 0, "net_hits": 0, "faults": 0, "points": 0, "serve_faults": 0, "out": 0}
	var log := PackedStringArray()
	var state := sim.state()
	while sim.tick_count < max_ticks and state.phase != Enums.Phase.MATCH_OVER:
		for e in sim.tick(ai.intents(state)):
			match e.type:
				MatchEvent.Type.CONTACT:
					counts.contacts += 1
				MatchEvent.Type.BLOCK_RESOLVED:
					counts.blocks += 1
				MatchEvent.Type.NET_HIT:
					counts.net_hits += 1
				MatchEvent.Type.FAULT:
					counts.faults += 1
					if e.details.reason == "service_fault":
						counts.serve_faults += 1
					elif e.details.reason == "out":
						counts.out += 1
				MatchEvent.Type.POINT_AWARDED:
					counts.points += 1
			if record_events:
				log.append(e.to_text())
		state = sim.state()
	return {"score": state.score, "ticks": sim.tick_count, "finished": state.phase == Enums.Phase.MATCH_OVER,
		"winner": state.winner, "counts": counts, "events": "\n".join(log), "fingerprint": state.fingerprint()}
